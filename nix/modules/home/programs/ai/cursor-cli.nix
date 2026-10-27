{
  lib,
  pkgs,
  config,
  ...
}:
let
  mergeConfig = import ../../merge-config.nix { inherit lib pkgs config; };
  permissions = import ./permissions.nix { inherit lib; };
  cursorConfigDir = "${config.xdg.configHome}/cursor";

  # Cursor CLI self-repairs and persists some keys into cli-config.json, so
  # this file has to stay writable. Nix settings are merged on activation.
  settings = {
    version = 1;
    editor.vimMode = false;
    permissions = {
      inherit (permissions.cursor config) allow deny;
    };
    sandbox = {
      mode = "enabled";
      # The allowlist below plus Cursor's defaults.
      networkAccess = "user_config_with_defaults";
      networkAllowlist = permissions.sandboxNetworkDomains;
    };
    attribution = {
      attributeCommitsToAgent = false;
      attributePRsToAgent = false;
      notifications = true;
    };
  };

  sandboxSettings = {
    additionalReadonlyPaths = permissions.sandboxReadonlyPaths config;
    additionalReadwritePaths = (permissions.agentCaches config).writePaths;
  };

  # Cursor has no env setting, so its binary sets the agent caches.
  cursorCli = pkgs.symlinkJoin {
    name = "cursor-cli-agent-caches";
    paths = [ pkgs.cursor-cli ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/cursor-agent ${
        lib.concatStringsSep " " (
          lib.mapAttrsToList (name: value: "--set ${name} ${lib.escapeShellArg value}") (
            permissions.agentCaches config
          ).env
        )
      }
      ln -s $out/bin/cursor-agent $out/bin/agent
    '';
  };
in
{
  home = {
    sessionVariables.CURSOR_CONFIG_DIR = cursorConfigDir;

    packages = [ cursorCli ];

    activation.cursorCliConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (
      mergeConfig {
        name = "cursor-cli-config";
        path = "${cursorConfigDir}/cli-config.json";
        inherit settings;
      }
      + mergeConfig {
        name = "cursor-sandbox";
        path = "${cursorConfigDir}/sandbox.json";
        settings = sandboxSettings;
      }
    );
  };
}
