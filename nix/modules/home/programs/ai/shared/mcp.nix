{ pkgs, ... }:
{
  home.packages = [ pkgs.mcp-nixos ];

  # Opt-in servers for the `ct agents` catalog (agents-catalog.nix); projects
  # enable them with `ct agents set mcp <name> enable`. Their commands end up
  # in committed project files, so they are names on PATH, not store paths.
  agents.mcpServers.nixos.command = "mcp-nixos";
}
