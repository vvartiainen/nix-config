{
  lib,
  pkgs,
  config,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  jq = lib.getExe pkgs.jq;
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

  staticSettings = jsonFormat.generate "claude-code-settings.json" {
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
      defaultMode = "default";
    };
    sandbox = {
      enabled = true;
      autoAllowBashIfSandboxed = false;
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
    activation.claudeCodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      config_path="${config.programs.claude-code.configDir}/settings.json"
      mkdir -p "$(dirname "$config_path")"
      if [ ! -e "$config_path" ]; then
        echo '{}' > "$config_path"
      fi
      config_tmp=$(mktemp "$config_path.XXXXXX")
      if ! ${jq} -e -S 'if type == "object" then . * $static[0] else error("expected an object") end' \
        --slurpfile static ${staticSettings} \
        "$config_path" > "$config_tmp"; then
        rm -f "$config_tmp"
        echo >&2 "Could not merge Claude Code settings: $config_path"
        exit 1
      fi
      mv "$config_tmp" "$config_path"
    '';
  };
}
