{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.agents;
  rulesync = import ./rulesync.nix { inherit lib pkgs; };
  # Generic skills that live in this repo; one directory per skill.
  skillsDir = ./skills;
  repoSkills = lib.optionalAttrs (builtins.pathExists skillsDir) (
    lib.mapAttrs (name: _: "${skillsDir}/${name}") (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDir)
    )
  );
in
{
  options.agents = {
    mcpServers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = ''
        Opt-in stdio MCP servers ({ command; args; env; }), enabled per project
        with `ct agents`. Servers every project needs go in programs.mcp.servers.
      '';
    };
    localSkills = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Extra skill directories (with SKILL.md) for the library, e.g. private skills from host data.";
    };
    skillSources = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      example = [
        {
          source = "anthropics/skills";
          skills = [ "skill-creator" ];
        }
      ];
      description = "Rulesync skill sources, downloaded by `ct agents library install`.";
    };
  };

  config = {
    home.packages = [ rulesync ];

    # The `ct agents` catalog: everything a project can opt into. Choices live
    # outside the projects, so no project paths are recorded here, and agents
    # get them through `ct agents launch`.
    xdg.configFile."cli-toolbox/agents/catalog.json".source =
      (pkgs.formats.json { }).generate "agents-catalog.json"
        {
          version = 1;
          mcp = lib.mapAttrs (_: server: { type = "stdio"; } // server) cfg.mcpServers;
          sources = cfg.skillSources;
          # Interpolation copies path values into the store.
          localSkills = lib.mapAttrs (_: path: "${path}") (repoSkills // cfg.localSkills);
        };
  };
}
