{ pkgs, ... }:
{
  programs.pi-coding-agent = {
    enable = true;

    # Pi installs configured npm packages on first launch. Make npm/npx
    # available to both the package manager and extensions such as MCP.
    extraPackages = [ pkgs.nodejs ];

    # MCP is built in; projects list their servers in .pi/mcp.json (`ct agents`).
    settings = {
      theme = "catppuccin-mocha";
      defaultProvider = "deepseek";
      defaultModel = "deepseek-flash";
      defaultThinkingLevel = "medium";
      # Compact at 80% of the default model's 1M-token window, like the
      # other CLIs: Pi compacts when fewer than reserveTokens remain.
      compaction = {
        enabled = true;
        modelOverrides."deepseek/deepseek-flash".reserveTokens = 200000;
        modelOverrides."openai-codex/gpt-6.1-sol".reserveTokens = 100000;
      };

      packages = [
        "npm:pi-web-access@0.40.0"
        # Subscription 5h/weekly limits in the footer and /usage, like the
        # Claude Code status line and Codex limit items.
        "npm:@narumitw/pi-usage@0.64.1"
      ];
    };

    keybindings = {
      "$schema" = "https://pi.dev/schemas/keybindings.schema.json";
      "app.model.select" = [
        "alt+p"
        "ctrl+l"
      ];
      # Shift+Tab changes modes in the other CLIs; Pi uses Alt+T for effort.
      "app.thinking.cycle" = "alt+t";
    };
  };

  home.file.".pi/agent/themes/catppuccin-mocha.json".source =
    ../../../../../dotfiles/pi/themes/catppuccin-mocha.json;
}
