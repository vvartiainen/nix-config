{
  lib,
  pkgs,
  config,
  repoRoot,
  ...
}:
let
  mergeConfig = import ../../merge-config.nix { inherit lib pkgs config; };
  permissions = import ./permissions.nix { inherit lib config; };
  inherit (permissions)
    commands
    paths
    network
    caches
    ;

  commandString = lib.concatStringsSep " ";

  # Copilot has no config file setting for tool rules or file tool paths,
  # only the `--allow-tool` / `--deny-tool` / `--add-dir` CLI flags.
  toolPermissions = {
    # Copilot has no "approve if sandboxed" setting, so allow all shell
    # commands like the other CLIs' sandbox approval. Deny rules still win,
    # and running outside the sandbox is a separate bypass prompt.
    allowTools = [ "shell" ] ++ permissions.mcpServers;
    # A relative write() path matches trailing components in any directory.
    # Copilot has no read() rule, so reads can't be denied this way.
    denyTools = map (cmd: "shell(${commandString cmd}:*)") commands.denied ++ [
      "write(.env)"
      "write(.git/config)"
    ];
    # Reads there need no path prompt, like Claude's Read(//nix/store/**).
    # Edits still prompt, and the sandbox keeps the paths read-only.
    addDirs = paths.readonly;
  };

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
        readonlyPaths =
          paths.readonly
          ++ paths.runtime
          ++ paths.readable
          ++ [
            "${config.programs.github-copilot-cli.configDir}/hooks"
          ];
        # Connecting to a socket needs write. Nix builds run unprivileged
        # through the daemon, outside the agent sandbox.
        readwritePaths = [
          "${config.xdg.configHome}/herdr/herdr.sock"
          paths.nixDaemonSocket
        ]
        # allowDevToolAccess grants a moved cache instead of its default
        # location, but only to its own ecosystem; mise has none.
        ++ caches.writePaths
        ++ paths.tmp
        # The backlog MCP servers (`bl <project> mcp start`) edit tasks there.
        ++ lib.optional (config.backlog.projects != [ ]) config.backlog.vault;
        deniedPaths = paths.denied;
        clearPolicyOnExit = true;
      };
      # Shell commands run without approval, so limit the network like the
      # other sandboxes. Blocked hosts offer a sandbox bypass prompt.
      userPolicy.network.allowedHosts = network.sandbox;
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
    allowedUrls = network.fetch;
    # Skills come from the projects (`ct agents`), not the built-in ones.
    disabledSkills = [
      "customize-cloud-agent"
      "github-pr-media"
    ];
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
  ]) toolPermissions.allowTools
  ++ lib.concatMap (tool: [
    "--deny-tool"
    tool
  ]) toolPermissions.denyTools
  ++ lib.concatMap (dir: [
    "--add-dir"
    dir
  ]) toolPermissions.addDirs;

  cacheEnv = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: value: "${name}=${lib.escapeShellArg value}") caches.env
  );
in
{
  programs.github-copilot-cli = {
    enable = true;
    # The wrapper execs node, so the process is named `node` and herdr can't
    # detect Copilot. Exec node through a symlink named `copilot` instead;
    # macOS takes the process name from the exec'd path. The package also
    # ships no shell completions, so generate them from the CLI.
    package = pkgs.github-copilot-cli.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.installShellFiles ];
      postInstall = ''
        mkdir -p "$out"/libexec
        ln -s ${pkgs.nodejs}/bin/node "$out"/libexec/copilot
      ''
      + lib.replaceStrings [ "${pkgs.nodejs}/bin/node" ] [ ''"$out"/libexec/copilot'' ] old.postInstall
      + ''
        export HOME="$TMPDIR"
        installShellCompletion --cmd copilot \
          --zsh <("$out"/bin/copilot completion zsh) \
          --bash <("$out"/bin/copilot completion bash) \
          --fish <("$out"/bin/copilot completion fish)
      '';
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
      format = "jsonc";
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
