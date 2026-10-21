{ pkgs, ... }:
{
  programs.pi-coding-agent = {
    enable = true;

    # Pi installs configured npm packages on first launch. Make npm/npx
    # available to both the package manager and extensions such as MCP.
    extraPackages = [ pkgs.nodejs ];

    # MCP is built in and reads ~/.pi/agent/mcp.json (see mcp-nixos.nix).
    settings = {
      theme = "catppuccin-mocha";
      defaultProvider = "openai-codex";
      defaultModel = "gpt-6.1-sol";
      defaultThinkingLevel = "medium";

      packages = [
        "npm:pi-web-access@0.40.0"
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
