{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.agents;
  rulesync = import ./rulesync.nix { inherit lib pkgs; };
in
{
  options.agents = {
    mcpServers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = ''
        Opt-in stdio MCP servers ({ command; args; env; }), enabled per project
        with `ct agents`.
      '';
    };
  };

  config = {
    home.packages = [ rulesync ];

    # The `ct agents` MCP catalog. Project choices live outside the projects;
    # agents get them through `ct agents launch`.
    xdg.configFile."cli-toolbox/agents/catalog.json".source =
      (pkgs.formats.json { }).generate "agents-catalog.json"
        {
          version = 1;
          mcp = lib.mapAttrs (_: server: { type = "stdio"; } // server) cfg.mcpServers;
        };
  };
}
