{
  lib,
  pkgs,
  config,
  ...
}:
let
  mergeConfig = import ../../../merge-config.nix { inherit lib pkgs config; };
  permissions = import ../shared/permissions.nix { inherit lib config; };
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
      (lib.concatMap toCursorShell commands.hostInspection)
      ++ map (cmd: "Shell(${builtins.head cmd}:${commandString (builtins.tail cmd)})") (
        commands.exact ++ commands.hostExact
      )
      ++ map (domain: "WebFetch(${domain})") network.fetch
      ++ map (name: "Mcp(${name}:*)") permissions.mcpServers;
    deny =
      (lib.concatMap toCursorShell commands.denied)
      ++ [
        "Read(.env)"
        "Read(.env.*)"
        "Read(**/.env)"
        "Read(**/.env.*)"
        "Write(.env)"
        "Write(.env.*)"
        "Write(**/.env)"
        "Write(**/.env.*)"
        # The sandbox protects these from shell writes; this covers file tools.
        "Write(**/.git/hooks/**)"
        "Write(**/.git/config)"
      ]
      ++ lib.concatMap (path: [
        "Read(${path})"
        "Read(${path}/**)"
        "Write(${path})"
        "Write(${path}/**)"
      ]) paths.denied
      ++ lib.concatMap (pattern: [
        "Read(${pattern})"
        "Write(${pattern})"
      ]) paths.secretFiles;
  };

  # Shell permissions have no ask tier; use the native pre-execution hook.
  shellPolicy = pkgs.writeText "cursor-shell-policy.json" (builtins.toJSON commands);
  shellReview = pkgs.writeShellScript "nix-config-shell-review-cursor" ''
    exec ${pkgs.python3}/bin/python3 ${../shared/shell-review.py} cursor ${shellPolicy}
  '';

  # Cursor rewrites cli-config.json, so merge into a regular file on activation.
  settings = {
    version = 1;
    editor.vimMode = false;
    approvalMode = "allowlist";
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

  # Cursor grants temp writes by default (`disableTmpWrite`); list /tmp
  # explicitly like the other CLIs.
  readwritePaths =
    caches.writePaths
    ++ paths.tmp
    ++ [
      # The desktop app uses ~/.cursor; this CLI relocates its config via
      # CURSOR_CONFIG_DIR. Grant only their managed checkout directories.
      "${config.home.homeDirectory}/.cursor/worktrees"
      "${cursorConfigDir}/worktrees"
    ];

  sandboxSettings = {
    additionalReadonlyPaths = paths.readonly;
    additionalReadwritePaths = readwritePaths;
    # The default `system` boundary lets file tools and sandboxed commands
    # read anywhere without asking. Outside the workspace and these paths,
    # reads ask. This list replaces Read(...) allow rules as the allowlist.
    readBoundary = "workspace";
    additionalReadPaths = lib.unique (
      paths.readonly ++ paths.runtime ++ paths.readable ++ readwritePaths
    );
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
  agentHooks = {
    commandMarkers = [ "nix-config-shell-review-cursor" ];
    cursor.beforeShellExecution = [ { command = "${shellReview}"; } ];
  };

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
