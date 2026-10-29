{
  lib,
  pkgs,
  config,
  ...
}:
let
  mergeConfig = import ../../merge-config.nix { inherit lib pkgs config; };
  permissions = import ./permissions.nix { inherit lib config; };
  inherit (permissions)
    commands
    paths
    network
    caches
    ;
  commandString = lib.concatStringsSep " ";

  toCursorShell =
    cmd:
    let
      bin = builtins.head cmd;
      args = builtins.tail cmd;
    in
    if args == [ ] then
      [ "Shell(${bin}:*)" ]
    else
      [
        "Shell(${bin}:${commandString args})"
        "Shell(${bin}:${commandString args} *)"
      ];

  cursorConfigDir = "${config.xdg.configHome}/cursor";

  permissionSettings = {
    allow =
      (lib.concatMap toCursorShell commands.allowed)
      ++ map (cmd: "Shell(${builtins.head cmd}:${commandString (builtins.tail cmd)})") commands.exact
      ++ [ "Read(**)" ]
      ++ map (domain: "WebFetch(${domain})") network.fetch
      ++ map (name: "Mcp(${name}:*)") permissions.mcpServers;
    deny =
      (lib.concatMap toCursorShell commands.denied)
      ++ [
        "Read(.env)"
        "Read(.env.*)"
        "Read(**/.env)"
        "Read(**/.env.*)"
      ]
      ++ map (path: "Read(${config.home.homeDirectory}/${path})") paths.homeSecrets
      ++ map (pattern: "Read(${pattern})") paths.secretFiles;
  };

  # Cursor CLI self-repairs and persists some keys into cli-config.json, so
  # this file has to stay writable. Nix settings are merged on activation.
  settings = {
    version = 1;
    editor.vimMode = false;
    permissions = permissionSettings;
    sandbox = {
      mode = "enabled";
      # The allowlist below plus Cursor's defaults.
      networkAccess = "user_config_with_defaults";
      networkAllowlist = network.sandbox;
    };
    attribution = {
      attributeCommitsToAgent = false;
      attributePRsToAgent = false;
      notifications = true;
    };
  };

  sandboxSettings = {
    additionalReadonlyPaths = paths.readonly;
    additionalReadwritePaths = caches.writePaths;
  };

  # Cursor has no env setting, so its binary sets the agent caches.
  cursorCli = pkgs.symlinkJoin {
    name = "cursor-cli-agent-caches";
    paths = [ pkgs.cursor-cli ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/cursor-agent ${
        lib.concatStringsSep " " (
          lib.mapAttrsToList (name: value: "--set ${name} ${lib.escapeShellArg value}") caches.env
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
