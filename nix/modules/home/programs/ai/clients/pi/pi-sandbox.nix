{
  lib,
  pkgs,
  config,
  ...
}:
let
  policy = import ../../shared/permissions.nix { inherit lib config; };
  agentDir = config.programs.pi-coding-agent.configDir;
  permissionFile = "${agentDir}/extensions/pi-permission-system/config.json";
  commandString = cmd: builtins.unsafeDiscardStringContext (lib.concatStringsSep " " cmd);
  rules = value: commands: lib.genAttrs (map (cmd: "${commandString cmd} *") commands) (_: value);
  # Mirror the OS deny list on the permission layer. The sandbox is the
  # boundary, but an exact-path deny misses a directory read, so deny each
  # secret path and everything beneath it too.
  secretPathRules = lib.genAttrs (
    lib.concatMap (path: [
      path
      "${path}/*"
    ]) policy.paths.denied
  ) (_: "deny");
  permissionSettings = {
    yoloMode = false;
    permissionReviewLog = true;
    promptNotifications = [ "bell" ];
    permission = {
      "*" = "ask";
      read = "allow";
      write = "allow";
      edit = "allow";
      grep = "allow";
      find = "allow";
      ls = "allow";
      skill = "allow";
      # The kernel enforces external filesystem boundaries. Unknown tools,
      # including direct MCP tools, still require approval.
      external_directory = "allow";
      mcp = "ask";
      # Safehouse bounds what a command can touch and the path rules above still
      # deny secrets, so asking per command only prompted for ordinary work and
      # ended in session-wide `*` grants. Allow bash instead and keep asking for
      # work that leaves the sandbox: Nix hands builds to the host daemon, and
      # Rex can type into an unsandboxed terminal. The extension still floors
      # `sh -c`/`eval`, indirection wrappers (`sudo`, `xargs`, `find -exec`) and
      # unparseable input to ask, and the deny list still denies.
      bash =
        {
          "*" = "allow";
        }
        // rules "ask" policy.commands.sandboxAsk
        // rules "deny" policy.commands.denied;
      path =
        {
          "*" = "allow";
          "*.env" = "deny";
          "*.env.*" = "deny";
          "*.env.example" = "allow";
          "*.pem" = "deny";
          "*.key" = "deny";
          # Pi itself needs its credentials; model tools do not.
          "${agentDir}/auth.json" = "deny";
        }
        // secretPathRules;
    };
  };
  sandboxSpec = pkgs.writeText "pi-safehouse.json" (
    builtins.toJSON {
      inherit agentDir;
      readable =
        policy.paths.readonly ++ policy.paths.runtime ++ [ "${config.home.homeDirectory}/.agents" ];
      writable = policy.caches.writePaths ++ [ agentDir ];
      denied = policy.paths.denied;
      protected = [
        permissionFile
        "${agentDir}/settings.json"
        "${agentDir}/models.json"
        "${agentDir}/keybindings.json"
        "${agentDir}/agents"
        # Persisting an MCP server would run its command in later sessions.
        "${agentDir}/mcp.json"
      ];
      # Nixpkgs' OpenSSL, which Node uses, has no roots when SSL_CERT_FILE is
      # unreadable. Safehouse can't follow /etc/ssl/certs through /etc/static.
      env = policy.caches.env // {
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
    }
  );
in
{
  programs.pi-coding-agent.package = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.git ];
    text = ''
      exec ${lib.getExe pkgs.python3} ${./pi-safehouse.py} \
        ${sandboxSpec} ${lib.getExe pkgs.agent-safehouse} ${lib.getExe pkgs.pi-coding-agent} "$@"
    '';
  };

  home.file."${permissionFile}".text = builtins.toJSON permissionSettings;
}
