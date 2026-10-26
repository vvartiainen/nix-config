{
  lib,
  pkgs,
  config,
  ...
}:
let
  mergeConfig = import ./merge-config.nix { inherit lib pkgs config; };
in
{
  programs.pi-coding-agent = {
    enable = true;

    # Pi installs configured npm packages on first launch. Make npm/npx
    # available to both the package manager and extensions such as MCP.
    extraPackages = [ pkgs.nodejs ];

    # MCP is built in and reads ~/.pi/agent/mcp.json (see below).
    settings = {
      theme = "catppuccin-mocha";
      defaultProvider = "openai-codex";
      defaultModel = "gpt-6.1-sol";
      defaultThinkingLevel = "medium";

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

  # The MCP servers from mcp.nix.
  home.activation.piMcpConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (mergeConfig {
    name = "pi-mcp";
    path = "${config.home.homeDirectory}/.pi/agent/mcp.json";
    settings.mcpServers = lib.mapAttrs (
      _: server: lib.hm.mcp.transformMcpServer { inherit server; }
    ) config.programs.mcp.servers;
  });
}
