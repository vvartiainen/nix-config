{
  pkgs,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };

  # Copilot CLI stores user-editable settings in settings.json. The
  # home-manager `settings` option still writes config.json, which the CLI
  # now treats as runtime state (auth, plugins) and must remain writable.
  settings = {
    model = "gpt-5.6-sol";
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
in
{
  programs.github-copilot-cli = {
    enable = true;

    lspServers.typescript = {
      command = "typescript-language-server";
      args = [ "--stdio" ];
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

    skills.lsp-setup = ../../../../dotfiles/.copilot/skills/lsp-setup;
  };

  home.file.".copilot/settings.json".source =
    jsonFormat.generate "github-copilot-cli-settings.json" settings;
}
