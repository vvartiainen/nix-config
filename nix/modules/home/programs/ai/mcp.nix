{
  lib,
  pkgs,
  config,
  ...
}:
{
  home.packages = [ pkgs.mcp-nixos ];

  # Stdio MCP servers every project gets, in every agent CLI. Each program
  # module turns these into its own config, through Home Manager's MCP
  # integration when it has one.
  programs.mcp.enable = true;

  # Opt-in servers for the `ct agents` catalog (agents-catalog.nix); projects
  # enable them with `ct agents set mcp <name> enable`. Their commands end up
  # in committed project files, so they are names on PATH, not store paths.
  agents.mcpServers = {
    nixos.command = "mcp-nixos";
  }
  # One server per agent backlog; `bl` (backlog.nix) finds its folder.
  // lib.listToAttrs (
    map (
      name:
      lib.nameValuePair "backlog-${name}" {
        command = "bl";
        args = [
          name
          "mcp"
          "start"
        ];
      }
    ) config.backlog.projects
  );
}
