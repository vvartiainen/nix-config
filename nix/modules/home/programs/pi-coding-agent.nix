{ pkgs, ... }:
{
  programs.pi-coding-agent = {
    enable = true;

    # Pi installs configured npm packages on first launch. Make npm/npx
    # available to both the package manager and extensions such as MCP.
    extraPackages = [ pkgs.nodejs ];

    settings = {
      theme = "catppuccin-mocha";
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.6-sol";
      defaultThinkingLevel = "medium";

      packages = [
        "npm:pi-mcp-adapter@2.32.1"
        "npm:pi-web-access@0.27.0"
        "npm:@ifi/oh-pi-themes@0.5.1"
      ];
    };
  };
}
