{
  lib,
  pkgs,
  config,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  jq = lib.getExe pkgs.jq;

  # Copilot CLI stores user-editable settings in settings.json and rewrites
  # that file in place. A home-manager symlink into the Nix store gets
  # replaced on the first CLI settings change, so keep the file writable and
  # merge Nix settings on activation instead.
  #
  # The home-manager `settings` option still writes config.json, which the CLI
  # now treats as runtime state (auth, plugins) and must remain writable.
  settings = {
    model = "gpt-5.6-sol";
    effortLevel = "medium";
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
    allowedUrls = [ "https://docs.github.com" ];
    disabledSkills = [ ];
    theme = "github";
    beep = true;
    notifications = true;
    scrollbar = true;
    voice.enabled = false;
    planModel = "gpt-5.6-sol";
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
in
{
  programs.github-copilot-cli = {
    enable = true;

    # TypeScript 7 from mise is a native compiler and speaks LSP itself
    # (`tsc --lsp`). It no longer ships `tsserver.js`, so
    # `typescript-language-server` cannot start. Use the mise shim so Copilot
    # does not need zsh/`mise activate` on PATH.
    lspServers.typescript = {
      command = "${config.xdg.dataHome}/mise/shims/tsc";
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

  home.activation.githubCopilotCliSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    config_path="${config.programs.github-copilot-cli.configDir}/settings.json"
    mkdir -p "$(dirname "$config_path")"
    if [ -L "$config_path" ]; then
      rm -f "$config_path"
    fi
    if [ ! -e "$config_path" ]; then
      echo '{}' > "$config_path"
    fi
    if ! ${jq} -S '. * $static[0]' \
      --slurpfile static ${staticSettings} \
      "$config_path" > "$config_path.tmp" 2>/dev/null; then
      ${jq} -S '.' ${staticSettings} > "$config_path.tmp"
    fi
    mv "$config_path.tmp" "$config_path"
  '';
}
