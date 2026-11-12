{
  lib,
  pkgs,
  config,
  ...
}:
{
  home.packages = [ pkgs.mcp-nixos ];

  # Opt-in servers for the `ct agents` catalog (agents-catalog.nix); projects
  # enable them with `ct agents set mcp <name> enable`. Their commands end up
  # in committed project files, so they are names on PATH, not store paths.
  # agent-sandbox's guests write the same `nixos` and `backlog-<project>`
  # entries (its tests/vm-config.nix pins them); keep the two in step, or
  # agents see two conflicting servers of one name.
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
