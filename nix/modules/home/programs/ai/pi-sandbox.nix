{
  lib,
  pkgs,
  config,
  ...
}:
let
  policy = import ./permissions.nix { inherit lib config; };
  agentDir = config.programs.pi-coding-agent.configDir;
  permissionFile = "${agentDir}/extensions/pi-permission-system/config.json";
  commandString = cmd: builtins.unsafeDiscardStringContext (lib.concatStringsSep " " cmd);
  rules = value: commands: lib.genAttrs (map (cmd: "${commandString cmd} *") commands) (_: value);
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
      bash = {
        "*" = "ask";
      }
      // rules "allow" (policy.commands.allowed ++ policy.commands.routine)
      // lib.genAttrs (map commandString policy.commands.exact) (_: "allow")
      // rules "ask" policy.commands.sandboxAsk
      // rules "deny" policy.commands.denied;
      path = {
        "*" = "allow";
        "*.env" = "deny";
        "*.env.*" = "deny";
        "*.env.example" = "allow";
        "*.pem" = "deny";
        "*.key" = "deny";
        # Pi itself needs its credentials; model tools do not.
        "${agentDir}/auth.json" = "deny";
      };
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
    text = ''
      exec ${lib.getExe pkgs.python3} ${./pi-safehouse.py} \
        ${sandboxSpec} ${lib.getExe pkgs.agent-safehouse} ${lib.getExe pkgs.pi-coding-agent} "$@"
    '';
  };

  home.file."${permissionFile}".text = builtins.toJSON permissionSettings;
}
