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

  # `bl nix-config board` instead of cd-ing into the iCloud folder. Without a
  # project it falls back to $BACKLOG_PROJECT.
  bl = pkgs.writeShellApplication {
    name = "bl";
    text = ''
      projects=(${lib.escapeShellArgs cfg.projects})
      if [[ $# -gt 0 && " ''${projects[*]} " == *" $1 "* ]]; then
        project=$1
        shift
      elif [[ -n ''${BACKLOG_PROJECT:-} ]]; then
        project=$BACKLOG_PROJECT
      else
        echo "usage: bl <project> [backlog args]   (default: task list)" >&2
        echo "projects: ''${projects[*]}" >&2
        exit 2
      fi
      if [[ $# -eq 0 ]]; then
        set -- task list
      fi
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
    # The agent backlogs are folders of an Obsidian vault in iCloud, so they
    # sync to the phone. Each project folder is its own Backlog.md root.
    vault = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Library/Mobile Documents/iCloud~md~obsidian/Documents/Agents";
      description = "Obsidian vault that holds one folder per backlog.";
    };
    projects = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # Machines have different backlogs, so the host data sets this.
      default = [ ];
      description = "Backlogs: folder names in the vault. Each gets an MCP server in the agent CLIs (mcp.nix).";
    };
  };

  config.home.packages = [
    cfg.package
    bl
  ];
}
