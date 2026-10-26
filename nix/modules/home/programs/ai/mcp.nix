{
  lib,
  pkgs,
  config,
  ...
}:
{
  home.packages = [ pkgs.mcp-nixos ];

  # Stdio MCP servers for every agent CLI. Each program module turns these
  # into its own config, through Home Manager's MCP integration when it has
  # one.
  programs.mcp = {
    enable = true;
    servers = {
      nixos.command = lib.getExe pkgs.mcp-nixos;
    }
    # One server per agent backlog, started by each agent CLI on demand.
    // lib.listToAttrs (
      map (
        name:
        lib.nameValuePair "backlog-${name}" {
          command = lib.getExe config.backlog.package;
          args = [
            "mcp"
            "start"
            "--cwd"
            "${config.backlog.vault}/${name}"
          ];
        }
      ) config.backlog.projects
    );
  };
}
