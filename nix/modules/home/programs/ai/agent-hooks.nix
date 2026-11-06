{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.agentHooks;
  json = pkgs.formats.json { };
  installer = pkgs.writeShellScriptBin "nix-config-install-agent-hooks" ''
    exec ${pkgs.python3}/bin/python3 ${./agent-hooks.py} "$@"
  '';
  generate = agent: json.generate "${agent}-hooks.json" { hooks = cfg.${agent}; };
  install = agent: destination: ''
    run ${lib.getExe installer} ${generate agent} ${
      lib.escapeShellArgs ([ destination ] ++ cfg.commandMarkers)
    }
  '';
in
{
  options.agentHooks = {
    commandMarkers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Stable command fragments identifying hooks managed by this configuration.";
    };
  }
  // lib.genAttrs [ "codex" "claude" "copilot" ] (
    _:
    lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
      default = { };
      description = "Native event hooks, merged from the modules that consume agent events.";
    }
  );

  config.home = {
    file."${config.programs.github-copilot-cli.configDir}/hooks/nix-config.json".source =
      json.generate "copilot-hooks.json"
        {
          version = 1;
          hooks = cfg.copilot;
        };

    # Integrations reconcile their own hooks first; preserve those and all
    # user hooks while replacing the handlers registered through agentHooks.
    activation.agentHooks =
      lib.hm.dag.entryAfter
        [
          "claudeCodeConfig"
          "codexMutableConfig"
          "rexAgentHooks"
          "herdrAgentIntegrations"
        ]
        (
          install "claude" "${config.programs.claude-code.configDir}/settings.json"
          + install "codex" "${config.home.homeDirectory}/.codex/hooks.json"
        );
  };
}
