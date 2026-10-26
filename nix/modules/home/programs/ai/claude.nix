{
  lib,
  pkgs,
  config,
  ...
}:
let
  mergeConfig = import ../../merge-config.nix { inherit lib pkgs config; };
in
{
  # The desktop app is installed by the Darwin Homebrew module. Keep its
  # config writable so extensions and manually added MCP servers persist.
  home.activation.claudeDesktopConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (mergeConfig {
    name = "claude-desktop-config";
    path = "${config.home.homeDirectory}/Library/Application Support/Claude/claude_desktop_config.json";
    # Apps launched from the Dock get no Nix PATH, so name the store path.
    settings.mcpServers.nixos.command = lib.getExe pkgs.mcp-nixos;
  });
}
