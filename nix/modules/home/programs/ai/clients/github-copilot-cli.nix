{
  lib,
  pkgs,
  config,
  repoRoot,
  ...
}:
let
  mergeConfig = import ../../../merge-config.nix { inherit lib pkgs config; };
  permissions = import ../shared/permissions.nix { inherit lib config; };
  inherit (permissions)
    commands
    paths
    network
    caches
    ;

  commandString = lib.concatStringsSep " ";

  # Copilot has no config file setting for tool rules or file tool paths,
  # only the `--allow-tool` / `--deny-tool` / `--add-dir` CLI flags.
  # No ask override: exclude any development prefix that would also approve
  # a reviewed operation, notably `just switch`. Keep `just lint` scoped.
  sandboxedDevelopment = lib.filter (
    cmd: !(lib.any (review: lib.take (lib.length cmd) review == cmd) commands.review)
  ) commands.development;
  toolPermissions = {
    # Copilot has no per-command ask override for a blanket shell grant.
    # Keep host control, arbitrary runners and wrappers subject to approval.
    allowTools =
      map (cmd: "shell(${commandString cmd}:*)") (
        commands.inspection ++ sandboxedDevelopment ++ commands.hostInspection
      )
      ++ map (cmd: "shell(${commandString cmd})") (commands.exact ++ commands.hostExact)
      ++ [ "write" ]
      ++ permissions.mcpServers;
    # A relative write() path matches trailing components in any directory.
    denyTools =
      map (cmd: "shell(${commandString cmd}:*)") commands.denied
      ++ [
        "write(.env)"
        "write(.git/config)"
      ]
      ++ lib.concatMap (path: [
        "read(${path})"
        "read(${path}/**)"
        "write(${path})"
        "write(${path}/**)"
      ]) paths.denied
      ++ lib.concatMap (pattern: [
        "read(${pattern})"
        "write(${pattern})"
      ]) paths.workspaceSecrets
      ++ [ "write(**/.git/hooks/**)" ];
    # Reads there need no path prompt, like Claude's Read(//nix/store/**).
    # File tools follow the sandbox policy on a best-effort basis; shell
    # writes to these paths remain blocked by the OS sandbox.
    # Added dirs also load repo settings, skills and agents; Homebrew's git
    # checkout ships a .claude/settings.json Stop hook (`brew lgtm`), so it
    # only gets the sandbox read grant.
    addDirs = lib.remove "/opt/homebrew" paths.readonly;
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
        # Copilot resolves symlinks and fails to start a sandbox on a dangling
        # one. ~/.nix-profile dangles when packages live in the per-user
        # profile; its target under XDG state is granted on its own.
        readonlyPaths =
          lib.subtractLists [ "${config.home.homeDirectory}/.nix-profile" ] (
            paths.readonly ++ paths.runtime ++ paths.readable
          )
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
        ++ paths.tmp;
        deniedPaths = paths.denied ++ paths.workspaceSecrets;
        clearPolicyOnExit = true;
      };
      # Local access otherwise adds localhost to a nonempty host allowlist,
      # exposing user-session services such as Rex outside this sandbox.
      userPolicy.network = {
        allowedHosts = network.sandbox;
        allowLocalNetwork = false;
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
  };

  lspSettings = {
    lspServers.typescript = {
      # Generated package path works without mise activation or shim access.
      command = lib.getExe pkgs.typescript;
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
    "--sandbox"
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
      # Temporary release pin until nixpkgs catches up (Apple Silicon host).
      version = "1.0.110";
      src = pkgs.fetchurl {
        url = "https://github.com/github/copilot-cli/releases/download/v1.0.110/github-copilot-1.0.110-darwin-arm64.tgz";
        hash = "sha256-GJ4ljgK3rgMd15moSoVX5zoNStgva3AVhusbd7Uv1i8=";
      };
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
