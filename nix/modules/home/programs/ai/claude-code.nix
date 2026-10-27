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
  permissions = import ./permissions.nix { inherit lib; };

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
    permissions = permissions.claude config // {
      # Like Codex: workspace edits and sandboxed commands run without
      # prompts; ask rules and sandbox escapes still prompt.
      defaultMode = "acceptEdits";
    };
    env = (permissions.agentCaches config).env;
    sandbox = {
      enabled = true;
      autoAllowBashIfSandboxed = true;
      filesystem = {
        allowWrite = (permissions.agentCaches config).writePaths;
        # Git hooks and config run outside the sandbox.
        denyWrite = [
          "**/.git/hooks"
          "**/.git/config"
        ];
        # ~/.npmrc links to this tracked file; flake evaluation copies every
        # tracked file, so nix must be able to read it.
        allowRead = [ "/${repoRoot}/dotfiles/.npmrc" ];
      };
      network = {
        allowedDomains = permissions.sandboxNetworkDomains;
        # Let sandboxed nix commands reach the daemon; the user is not a
        # trusted nix user, so builds run unprivileged as nixbld.
        allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ];
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
    '';
  };

  home = {
    # claude ships no zsh completion; this one is derived from `--help` output.
    packages = [
      (pkgs.writeTextDir "share/zsh/site-functions/_claude" (builtins.readFile ./claude-completion.zsh))
    ];

    file."${config.programs.claude-code.configDir}/themes/catppuccin-mocha.json".source =
      catppuccinMocha;

    # Claude Code persists /config changes here, so merge defaults into a
    # regular file instead of using the Home Manager settings symlink.
    activation.claudeCodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (mergeConfig {
      name = "claude-code-settings";
      path = "${config.programs.claude-code.configDir}/settings.json";
      inherit settings;
    });
  };
}
