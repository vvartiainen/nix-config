{
  lib,
  pkgs,
  config,
  ...
}:
let
  mergeConfig = import ./merge-config.nix { inherit lib pkgs config; };
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
      networkAccess = "user_config_with_defaults";
    };
    attribution = {
      attributeCommitsToAgent = false;
      attributePRsToAgent = false;
      notifications = true;
    };
  };

  sandboxSettings = {
    additionalReadonlyPaths = permissions.sandboxReadonlyPaths config;
  };

  mcpSettings.mcpServers = lib.mapAttrs (
    _: server:
    lib.hm.mcp.transformMcpServer {
      inherit server;
      extraTransforms = [ lib.hm.mcp.addType ];
    }
  ) config.programs.mcp.servers;
in
{
  home = {
    sessionVariables.CURSOR_CONFIG_DIR = cursorConfigDir;

    packages = [
      pkgs.cursor-cli
      (pkgs.runCommand "cursor-cli-agent" { } ''
        mkdir -p $out/bin
        ln -s ${lib.getExe pkgs.cursor-cli} $out/bin/agent
      '')
    ];

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
      + mergeConfig {
        name = "cursor-mcp";
        path = "${cursorConfigDir}/mcp.json";
        settings = mcpSettings;
      }
    );
  };
}
