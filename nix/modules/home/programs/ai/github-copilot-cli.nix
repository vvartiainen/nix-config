{
  lib,
  pkgs,
  config,
  repoRoot,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  jq = lib.getExe pkgs.jq;
  permissions = import ./permissions.nix { inherit lib; };

  # Copilot CLI stores user-editable settings in settings.json and rewrites
  # that file in place. A home-manager symlink into the Nix store gets
  # replaced on the first CLI settings change, so keep the file writable and
  # merge Nix settings on activation instead.
  #
  # The home-manager `settings` option still writes config.json, which the CLI
  # now treats as runtime state (auth, plugins) and must remain writable.
  settings = {
    model = "claude-opus-5.5";
    effortLevel = "medium";
    # Local sandboxing is experimental. PATH dirs are auto-granted read-only,
    # but Nix binaries resolve into the store and mise shims into XDG dirs.
    experimental = true;
    sandbox = {
      enabled = true;
      # Hooks run inside the sandbox; herdr installs its hook script here and
      # the hook reports the session over herdr's socket (connect needs write).
      userPolicy.filesystem = {
        readonlyPaths = permissions.sandboxReadonlyPaths config ++ [
          "${config.programs.github-copilot-cli.configDir}/hooks"
        ];
        readwritePaths = [ "${config.xdg.configHome}/herdr/herdr.sock" ];
      };
    };
    footer = {
      showModelEffort = true;
      showDirectory = true;
      showBranch = true;
      showContextWindow = true;
      showQuota = true;
      showAgent = true;
      showCodeChanges = false;
      showUsername = false;
      showCustom = true;
    };
    includeCoAuthoredBy = false;
    allowedUrls = permissions.fetchDomains;
    disabledSkills = [ ];
    theme = "github";
    beep = true;
    notifications = true;
    scrollbar = true;
    voice.enabled = false;
    planModel = "claude-opus-5";
    planEffortLevel = "medium";
    subagents.agents = {
      task = {
        model = "inherit";
        effortLevel = "medium";
        contextTier = "default";
      };
      "general-purpose".model = "inherit";
      "code-review".model = "inherit";
      research.model = "inherit";
      "security-review".model = "inherit";
    };
  };

  staticSettings = jsonFormat.generate "github-copilot-cli-settings.json" settings;
  staticLspSettings = jsonFormat.generate "github-copilot-cli-lsp.json" {
    lspServers.typescript = {
      # The mise shim execs /opt/homebrew/Cellar/mise, which the sandbox can't
      # read; the install's `latest` symlink stays within granted mise paths.
      command = "${config.xdg.dataHome}/mise/installs/npm-typescript/latest/node_modules/.bin/tsc";
      args = [
        "--lsp"
        "--stdio"
      ];
      fileExtensions = {
        ".ts" = "typescript";
        ".tsx" = "typescriptreact";
        ".js" = "javascript";
        ".jsx" = "javascriptreact";
        ".mjs" = "javascript";
        ".cjs" = "javascript";
        ".mts" = "typescript";
        ".cts" = "typescript";
      };
    };
  };
  staticPermissions = jsonFormat.generate "github-copilot-cli-permissions.json" {
    locations.${repoRoot}.tool_approvals = [ { kind = "read"; } ];
  };

  # Copilot reads tool rules only from CLI flags.
  toolFlags =
    lib.concatMap (tool: [
      "--allow-tool"
      tool
    ]) permissions.copilot.allowTools
    ++ lib.concatMap (tool: [
      "--deny-tool"
      tool
    ]) permissions.copilot.denyTools;
in
{
  programs.github-copilot-cli = {
    enable = true;
    # The wrapper execs node, so the process is named `node` and herdr can't
    # detect Copilot. Exec node through a symlink named `copilot` instead;
    # macOS takes the process name from the exec'd path.
    package = pkgs.github-copilot-cli.overrideAttrs (old: {
      postInstall = ''
        mkdir -p "$out"/libexec
        ln -s ${pkgs.nodejs}/bin/node "$out"/libexec/copilot
      ''
      + lib.replaceStrings [ "${pkgs.nodejs}/bin/node" ] [ ''"$out"/libexec/copilot'' ] old.postInstall;
    });
  };

  # The flags break subcommands, so only add them when starting a session.
  programs.zsh.initContent = ''
    copilot() {
      case "$1" in
        app|login|help|init|update|version|workflow|sessions|memories|plugin|mcp|skill|instruction|lsp|sandbox|completion)
          command copilot "$@" ;;
        *)
          command copilot ${lib.escapeShellArgs toolFlags} "$@" ;;
      esac
    }
  '';

  home.activation.githubCopilotCliSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    merge_copilot_config() {
      config_path="$1"
      static_path="$2"
      mkdir -p "$(dirname "$config_path")"
      if [ -L "$config_path" ]; then
        rm -f "$config_path"
      fi
      if [ ! -e "$config_path" ]; then
        echo '{}' > "$config_path"
      fi
      if ! ${jq} -S '. * $static[0]' \
        --slurpfile static "$static_path" \
        "$config_path" > "$config_path.tmp" 2>/dev/null; then
        ${jq} -S '.' "$static_path" > "$config_path.tmp"
      fi
      mv "$config_path.tmp" "$config_path"
    }

    merge_copilot_config \
      "${config.programs.github-copilot-cli.configDir}/settings.json" \
      ${staticSettings}
    merge_copilot_config \
      "${config.programs.github-copilot-cli.configDir}/lsp-config.json" \
      ${staticLspSettings}
    merge_copilot_config \
      "${config.programs.github-copilot-cli.configDir}/permissions-config.json" \
      ${staticPermissions}
  '';
}
