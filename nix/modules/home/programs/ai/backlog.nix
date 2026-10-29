{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.backlog;
  # Backlog.md's npm package wraps this standalone binary.
  backlog = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "backlog-md";
    version = "1.55.1";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/backlog.md-darwin-arm64/-/backlog.md-darwin-arm64-${finalAttrs.version}.tgz";
      hash = "sha512-BOcIMb/DW4uuhMwQbOAE1lJtY8tfacHgjAEE8MSFC5s9G216k9HQahhF/aLPG6JlJ5STG0bEQFqmH//ylP20KQ==";
    };
    # Bun appends the bundled program to the executable; stripping drops it.
    dontStrip = true;
    installPhase = ''
      install -Dm755 backlog $out/bin/backlog
    '';
    meta.mainProgram = "backlog";
  });

  # Keep explicit project selection for MCP; infer it for interactive use.
  bl = pkgs.writeShellApplication {
    name = "bl";
    runtimeInputs = [ pkgs.git ];
    text = ''
      projects=(${lib.escapeShellArgs cfg.projects})

      known_project() {
        local candidate
        for candidate in "''${projects[@]}"; do
          if [[ $candidate == "$1" ]]; then
            return 0
          fi
        done
        return 1
      }

      usage() {
        echo "usage: bl [project] [backlog args]   (default: task list)"
        echo "       bl [project] review [list options]"
        echo "       bl [project] handoffs [list options]"
        echo "Project: explicit name, current directory, then BACKLOG_PROJECT."
        echo "projects: ''${projects[*]}"
      }

      if [[ ''${1:-} == --help || ''${1:-} == -h ]]; then
        usage
        exit 0
      fi

      project=
      if [[ $# -gt 0 ]] && known_project "$1"; then
        project=$1
        shift
      elif repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
        # Prefer the main checkout, even if a worktree has another known name.
        if common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
          if [[ $common_dir == */.git ]]; then
            main_root=''${common_dir%/.git}
            if known_project "''${main_root##*/}"; then
              project=''${main_root##*/}
            fi
          fi
        fi
        if [[ -z $project ]] && known_project "''${repo_root##*/}"; then
          project=''${repo_root##*/}
        fi
      else
        # Also support a backlog folder or project directory without Git.
        project_dir=$PWD
        while [[ $project_dir != / ]]; do
          if known_project "''${project_dir##*/}"; then
            project=''${project_dir##*/}
            break
          fi
          project_dir=''${project_dir%/*}
          project_dir=''${project_dir:-/}
        done
      fi

      if [[ -z $project && -n ''${BACKLOG_PROJECT:-} ]]; then
        if ! known_project "$BACKLOG_PROJECT"; then
          echo "bl: unknown BACKLOG_PROJECT: $BACKLOG_PROJECT" >&2
          exit 2
        fi
        project=$BACKLOG_PROJECT
      fi
      if [[ -z $project ]]; then
        echo "bl: could not detect a configured project; provide its name." >&2
        usage >&2
        exit 2
      fi

      if [[ $# -eq 0 ]]; then
        set -- task list
      fi
      case $1 in
        review)
          shift
          set -- task list --labels needs-review "$@"
          ;;
        handoffs)
          shift
          set -- task list --labels handoff,needs-review "$@"
          ;;
      esac
      export BACKLOG_CWD=${lib.escapeShellArg cfg.vault}/$project
      exec ${lib.getExe cfg.package} "$@"
    '';
  };
in
{
  options.backlog = {
    package = lib.mkOption {
      type = lib.types.package;
      default = backlog;
      description = "The Backlog.md command.";
    };
    # Each project folder is its own Backlog.md root. Where they live differs
    # per machine (e.g. an Obsidian vault in iCloud), so the host data sets
    # this; it is only read when projects are set.
    vault = lib.mkOption {
      type = lib.types.str;
      description = "Directory that holds one folder per backlog.";
    };
    projects = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # Machines have different backlogs, so the host data sets this.
      default = [ ];
      description = "Backlogs: folder names in the vault. Each gets an opt-in MCP server in the ct agents catalog (mcp.nix).";
    };
  };

  config.home.packages = [ cfg.package ] ++ lib.optional (cfg.projects != [ ]) bl;
}
