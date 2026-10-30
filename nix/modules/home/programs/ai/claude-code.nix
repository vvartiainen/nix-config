{
  lib,
  pkgs,
  config,
  repoRoot,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  mergeConfig = import ../../merge-config.nix { inherit lib pkgs config; };
  permissions = import ./permissions.nix { inherit lib config; };
  inherit (permissions)
    commands
    paths
    network
    caches
    ;

  commandString = lib.concatStringsSep " ";

  permissionSettings = {
    allow =
      map (cmd: "Bash(${commandString cmd}:*)") commands.allowed
      ++ map (cmd: "Bash(${commandString cmd})") commands.exact
      ++ [ "Read(//nix/store/**)" ]
      # WebFetch allows also widen the Bash sandbox's network allowlist.
      ++ map (domain: "WebFetch(domain:${domain})") network.sandbox
      # Projects list these in .mcp.json (`ct agents sync`).
      ++ map (name: "mcp__${name}__*") permissions.mcpServers;
    # Terraform is deliberately excluded from Claude's sandbox for macOS TLS
    # compatibility, so validation still needs explicit review there.
    ask = map (cmd: "Bash(${commandString cmd}:*)") (
      commands.sandboxAsk
      ++ [
        [
          "terraform"
          "validate"
        ]
      ]
    );
    deny =
      map (cmd: "Bash(${commandString cmd}:*)") commands.denied
      ++ [
        "Read(**/.env)"
        "Read(**/.env.*)"
        "Edit(**/.env)"
        "Edit(**/.env.*)"
      ]
      ++ map (path: "Read(~/${path})") paths.homeSecrets
      ++ map (pattern: "Read(${pattern})") paths.secretFiles;
  };

  statusLine = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
    ];
    text = builtins.readFile ./claude-statusline.sh;
  };

  catppuccinMocha = jsonFormat.generate "claude-code-catppuccin-mocha.json" {
    name = "Catppuccin Mocha";
    base = "dark";
    overrides = {
      claude = "#cba6f7";
      claudeShimmer = "#f5c2e7";
      text = "#cdd6f4";
      inverseText = "#1e1e2e";
      inactive = "#7f849c";
      inactiveShimmer = "#9399b2";
      subtle = "#585b70";
      suggestion = "#b4befe";
      permission = "#89b4fa";
      permissionShimmer = "#b4befe";
      remember = "#f9e2af";
      success = "#a6e3a1";
      error = "#f38ba8";
      warning = "#fab387";
      warningShimmer = "#f9e2af";
      merged = "#cba6f7";
      promptBorder = "#6c7086";
      promptBorderShimmer = "#9399b2";
      planMode = "#94e2d5";
      autoAccept = "#f5c2e7";
      bashBorder = "#f38ba8";
      ide = "#74c7ec";
      fastMode = "#f9e2af";
      fastModeShimmer = "#f5e0dc";
      diffAdded = "#394545";
      diffRemoved = "#493446";
      diffAddedDimmed = "#2c323a";
      diffRemovedDimmed = "#33293a";
      diffAddedWord = "#4e6356";
      diffRemovedWord = "#694459";
      userMessageBackground = "#313244";
      userMessageBackgroundHover = "#45475a";
      bashMessageBackgroundColor = "#313244";
      memoryBackgroundColor = "#313244";
      selectionBg = "#45475a";
      rate_limit_fill = "#cba6f7";
      rate_limit_empty = "#45475a";
      briefLabelYou = "#89b4fa";
      briefLabelClaude = "#cba6f7";
      red_FOR_SUBAGENTS_ONLY = "#f38ba8";
      blue_FOR_SUBAGENTS_ONLY = "#89b4fa";
      green_FOR_SUBAGENTS_ONLY = "#a6e3a1";
      yellow_FOR_SUBAGENTS_ONLY = "#f9e2af";
      purple_FOR_SUBAGENTS_ONLY = "#cba6f7";
      orange_FOR_SUBAGENTS_ONLY = "#fab387";
      pink_FOR_SUBAGENTS_ONLY = "#f5c2e7";
      cyan_FOR_SUBAGENTS_ONLY = "#89dceb";
    };
  };

  settings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    model = "opus";
    effortLevel = "medium";
    theme = "custom:catppuccin-mocha";
    statusLine = {
      type = "command";
      command = lib.getExe statusLine;
    };
    attribution = {
      commit = "";
      pr = "";
    };
    permissions = permissionSettings // {
      # Like Codex: workspace edits and sandboxed commands run without
      # prompts; ask rules and sandbox escapes still prompt.
      defaultMode = "acceptEdits";
    };
    env = caches.env // {
      # nixpkgs sets CLAUDE_CODE_CERT_STORE=system, which on macOS holds only
      # keychain certificates, not Apple's roots. Add the Nix bundle, which
      # follows cacert and nix-darwin distrust updates.
      NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt";
    };
    # MCP servers come from the projects (`ct agents`), not claude.ai.
    disableClaudeAiConnectors = true;
    # Skills and plugins come from the projects too: nothing syncs from
    # claude.ai, and bundled skills stay out of context but typable with `/`.
    # disableBundledSkills would also drop the artifact skills, which stay on.
    syncClaudeAiPlugins = false;
    syncClaudeAiSkills = false;
    skillOverrides = lib.genAttrs [
      "claude-api"
      "claude-in-chrome"
      "code-review"
      "dataviz"
      "fewer-permission-prompts"
      "init"
      "keybindings-help"
      "loop"
      "plugin-authoring"
      "run"
      "schedule"
      "security-review"
      "simplify"
      "update-config"
    ] (_: "user-invocable-only");
    sandbox = {
      enabled = true;
      autoAllowBashIfSandboxed = true;
      # Go CLIs can't verify TLS under Seatbelt, so these run outside the
      # sandbox through the normal permission flow: allow rules run without
      # prompting, deny rules still apply, everything else asks. Only Go's
      # module downloads leave; builds and tests run project code.
      excludedCommands = [
        "gh *"
        "terraform *"
        "go get *"
        "go mod download"
        "go mod download *"
        "go mod tidy"
        "go mod tidy *"
      ];
      # Would let Go tools reach trustd inside the sandbox, at the cost of a
      # possible exfiltration channel through it.
      enableWeakerNetworkIsolation = false;
      filesystem = {
        allowWrite = caches.writePaths ++ paths.tmp;
        # Git hooks and config run outside the sandbox.
        denyWrite = [
          "**/.git/hooks"
          "**/.git/config"
        ];
        # The home directory stays readable: user settings can't name the
        # project, so a `~/` deny would block it too. Credential paths are
        # denied through the Read rules above.
        # ~/.npmrc links to this tracked file; flake evaluation copies every
        # tracked file, so nix must be able to read it.
        allowRead = [ "/${repoRoot}/dotfiles/.npmrc" ];
      };
      network = {
        allowedDomains = network.sandbox;
        # Other hosts prompt instead of failing (auto mode still refuses them
        # unless the command declares the host).
        strictAllowlist = false;
        # Let sandboxed nix commands reach the daemon; the user is not a
        # trusted nix user, so builds run unprivileged as nixbld.
        allowUnixSockets = [ paths.nixDaemonSocket ];
      };
    };
  };
in
{
  programs.claude-code = {
    enable = true;
    # Global ~/.claude/CLAUDE.md; repo instructions add to or narrow these.
    context = ''
      # Global instructions

      - Never add trailers to git commit messages or PR descriptions, such as
        Co-Authored-By or Claude-Session.
      - In Bash commands, avoid shell variables, `$(...)` and backticks: Claude
        Code can't check them against permission rules and prompts. Use literal
        absolute paths and split dependent steps into separate tool calls.
      - For temporary files, use literal paths under `/tmp` instead of
        `$TMPDIR`; `/tmp` is writable in the sandbox.
    '';
  };

  home = {
    # claude ships no zsh completion; this one is derived from `--help` output.
    packages = [
      (pkgs.writeTextDir "share/zsh/site-functions/_claude" (builtins.readFile ./claude-completion.zsh))
    ];

    file."${config.programs.claude-code.configDir}/themes/catppuccin-mocha.json".source =
      catppuccinMocha;

    file."${config.programs.claude-code.configDir}/keybindings.json".source =
      jsonFormat.generate "claude-code-keybindings.json" {
        "$schema" = "https://www.schemastore.org/claude-code-keybindings.json";
        bindings = [
          {
            context = "Chat";
            bindings."alt+t" = "command:effort";
          }
        ];
      };

    # Claude Code persists /config changes here, so merge defaults into a
    # regular file instead of using the Home Manager settings symlink.
    activation.claudeCodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (mergeConfig {
      name = "claude-code-settings";
      schema = "claude";
      path = "${config.programs.claude-code.configDir}/settings.json";
      inherit settings;
    });
  };
}
