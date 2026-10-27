{
  lib,
  pkgs,
  config,
  repoRoot,
  ...
}:
let
  mergeConfig = import ../../merge-config.nix { inherit lib pkgs config; };
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
        readwritePaths = [
          "${config.xdg.configHome}/herdr/herdr.sock"
        ]
        # allowDevToolAccess grants a moved cache instead of its default
        # location, but only to its own ecosystem; mise has none.
        ++ (permissions.agentCaches config).writePaths
        # The backlog MCP servers (`bl <project> mcp start`) edit tasks there.
        ++ lib.optional (config.backlog.projects != [ ]) config.backlog.vault;
        deniedPaths = permissions.sandboxDeniedPaths config;
      };
      # No allowedHosts: a non-empty list blocks other hosts without a
      # prompt, and Copilot already prompts for every unlisted command.
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

  lspSettings = {
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
  permissionSettings.locations.${repoRoot}.tool_approvals = [ { kind = "read"; } ];

  # Copilot reads tool rules only from CLI flags. MCP servers come from the
  # projects (`ct agents`), not the built-in GitHub ones.
  toolFlags = [
    "--disable-builtin-mcps"
  ]
  ++ lib.concatMap (tool: [
      "--allow-tool"
      tool
    ]) (permissions.copilot config).allowTools
    ++ lib.concatMap (tool: [
      "--deny-tool"
      tool
    ]) (permissions.copilot config).denyTools;

  cacheEnv = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: value: "${name}=${lib.escapeShellArg value}") (
      permissions.agentCaches config
    ).env
  );
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
  # Sessions also get the agent caches; Copilot has no env setting.
  programs.zsh.initContent = ''
    copilot() {
      case "$1" in
        app|login|help|init|update|version|workflow|sessions|memories|plugin|mcp|skill|instruction|lsp|sandbox|completion)
          command copilot "$@" ;;
        *)
          ${cacheEnv} command copilot ${lib.escapeShellArgs toolFlags} "$@" ;;
      esac
    }
  '';

  home.activation.githubCopilotCliSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    mergeConfig {
      name = "github-copilot-cli-settings";
      path = "${config.programs.github-copilot-cli.configDir}/settings.json";
      inherit settings;
    }
    + mergeConfig {
      name = "github-copilot-cli-lsp";
      path = "${config.programs.github-copilot-cli.configDir}/lsp-config.json";
      settings = lspSettings;
    }
    + mergeConfig {
      name = "github-copilot-cli-permissions";
      path = "${config.programs.github-copilot-cli.configDir}/permissions-config.json";
      settings = permissionSettings;
    }
  );
}
