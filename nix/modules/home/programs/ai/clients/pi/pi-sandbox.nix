{
  lib,
  pkgs,
  config,
  ...
}:
let
  policy = import ../../shared/permissions.nix { inherit lib config; };
  forge = import ../../shared/forge.nix { inherit config lib pkgs; };
  agentDir = config.programs.pi-coding-agent.configDir;
  sshDir = "${config.home.homeDirectory}/.ssh";
  # Safehouse's ssh integration denies the whole `~/.ssh` subtree and then
  # allows the connection files, so the shared directory deny would undo it.
  # Drop it here and deny key material on the permission layer instead.
  denied = builtins.filter (path: path != sshDir) policy.paths.denied;
  permissionFile = "${agentDir}/extensions/pi-permission-system/config.json";
  commandString = cmd: builtins.unsafeDiscardStringContext (lib.concatStringsSep " " cmd);
  rules = value: commands: lib.genAttrs (map (cmd: "${commandString cmd} *") commands) (_: value);
  # Pi is the only client that reaches the forge from inside a sandbox with a
  # repository-restricted token, and this repository's workflow fetches, pushes
  # a branch and opens a pull request on every task. Allow those routine forms.
  # Guard keys continue an allowed prefix without the space before the
  # wildcard: that also matches an option directly after the remote, and sorts
  # after the allow (a space sorts before `*`), so the generated
  # last-match-wins order puts the guard last.
  pushPrefixes = [
    "git push origin"
    "git push -u origin"
  ];
  pushGuards =
    action: suffixes:
    lib.genAttrs (
      lib.concatMap (prefix: map (suffix: "${prefix}${suffix}") suffixes) pushPrefixes
    ) (_: action);
  # Fetching is routine and only adds objects and refs, but agents put option
  # flags before the remote (`git fetch --prune origin`), which a remote-first
  # allow does not match. List those spellings instead of a `git fetch -*`
  # wildcard, so options such as `--upload-pack` still fall through to the ask.
  fetchPrefixes = [
    "git fetch origin"
    "git fetch --quiet origin"
    "git fetch -q origin"
    "git fetch --prune origin"
    "git fetch -p origin"
    "git fetch --prune --quiet origin"
    "git fetch --quiet --prune origin"
  ];
  fetchGuards = lib.genAttrs (
    lib.concatMap (prefix: [
      "${prefix}*--upload-pack*"
      "${prefix}*://*"
      "${prefix}*@*"
    ]) fetchPrefixes
  ) (_: "ask");
  routineBash =
    lib.genAttrs (map (prefix: "${prefix} *") (pushPrefixes ++ fetchPrefixes)) (_: "allow")
    // rules "allow" (map (subcommand: [ "fj" "pr" subcommand ]) [ "create" "edit" ])
    // pushGuards "deny" [
      "*--force*"
      "* -f*"
    ]
    // pushGuards "ask" [
      # Destructive or broad remote mutations.
      "*--delete*"
      "*--mirror*"
      "*--prune*"
      "*--all*"
      "*--tags*"
      # Options that run a command on the remote.
      "*--exec*"
      "*--receive-pack*"
      # Refspecs that rename, delete or force an update, and direct main pushes.
      "*:*"
      "*+*"
      "* main*"
      "* master*"
      "*refs/heads/main*"
      # Short-flag clusters such as -qf, and long flags the exact denies miss.
      "* -?f*"
    ]
    // fetchGuards;
  # Pi matches the command name as typed, so a path with spaces also needs
  # its quoted and escaped spellings, e.g. Rex's app-bundled CLI. Rules are
  # last-match-wins and toJSON sorts keys, so a key must not sort before the
  # "*" catch-all: `?` stands for either quote.
  spellings =
    exe:
    [ exe ]
    ++ lib.optionals (lib.hasInfix " " exe) [
      "?${exe}?"
      (lib.replaceStrings [ " " ] [ "\\ " ] exe)
    ];
  # Mirror the OS deny list on the permission layer. The sandbox is the
  # boundary, but an exact-path deny misses a directory read, so deny each
  # secret path and everything beneath it too.
  secretPathRules = lib.genAttrs (
    lib.concatMap (path: [
      path
      "${path}/*"
    ]) denied
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
      # Pi's deferred-tool discovery reads tool metadata, not files.
      tool_search = "allow";
      # The pinned web extension runs inside Safehouse too. Allow its exact
      # research surfaces without approving arbitrary new extension tools.
      web_enable = "allow";
      web_search = "allow";
      source_check = "allow";
      fetch_content = "allow";
      get_search_content = "allow";
      # The kernel enforces external filesystem boundaries. Unknown tools,
      # including direct MCP tools, still require approval.
      external_directory = "allow";
      # T3 Code injects its own server over its loopback endpoint and gates every
      # call with its runtime mode, so asking on the permission layer would
      # prompt twice for the same tool. Both spellings come from the bridge's
      # public and hidden tool names; T3 itself is the endpoint's owner.
      mcp =
        {
          "*" = "ask";
        }
        // lib.genAttrs [
          "t3-code"
          "t3_code"
        ] (_: "allow");
      # Safehouse bounds what a command can touch and the path rules above still
      # deny secrets, so asking per command only prompted for ordinary work and
      # ended in session-wide `*` grants. Allow bash instead and keep asking for
      # work that leaves the sandbox: Nix hands builds to the host daemon, and
      # Rex can type into an unsandboxed terminal. The extension still floors
      # `sh -c`/`eval`, indirection wrappers (`sudo`, `xargs`, `find -exec`) and
      # unparseable input to ask, and the deny list still denies. The routine
      # forge workflow in `routineBash` is the narrow exception.
      bash =
        {
          "*" = "allow";
        }
        // rules "ask" (
          policy.commands.review
          ++ map (exe: [ exe ]) (lib.concatMap spellings policy.commands.hostExecutables)
        )
        // rules "allow" policy.commands.hostInspection
        // lib.genAttrs (map commandString policy.commands.hostExact) (_: "allow")
        // routineBash
        // rules "deny" policy.commands.denied
        // lib.genAttrs policy.commands.deniedPatterns (_: "deny");
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
          # The sandbox denies private keys outright; keep the model from asking
          # for them, while `ssh` still reads config and known_hosts.
          "${sshDir}/id_*" = "deny";
          "${sshDir}/*.pem" = "deny";
          "${sshDir}/*.key" = "deny";
        }
        // secretPathRules;
    };
  };
  sandboxSpec = pkgs.writeText "pi-safehouse.json" (
    builtins.toJSON {
      inherit agentDir;
      readable =
        policy.paths.readonly
        ++ policy.paths.runtime
        ++ policy.paths.hostShared
        # The agent-only forge home: its `fj` wrapper shadows the profile one,
        # and this grant lets `fj` and git read the restricted token there
        # instead of relying on the keychain or SSH authentication.
        ++ [
          "${config.home.homeDirectory}/.agents"
          forge.keystoreDir
        ];
      # Sandbox-only commands, ahead of the profile on PATH.
      pathPrepend = [ "${forge.fj}/bin" ];
      writable = policy.caches.writePaths ++ [ agentDir ];
      inherit denied;
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
      env =
        policy.caches.env
        // {
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          # Forge SSH remotes switch to HTTPS with the restricted token, and the
          # keychain credential helper is dropped.
          GIT_CONFIG_GLOBAL = "${forge.gitConfig}";
          # `fj` has no configurable default host, so repository arguments can
          # leave it out.
          FJ_FALLBACK_HOST = "https://${forge.host}";
        }
        # A GUI host may supply launchd's agent even when workstation SSH
        # selects 1Password. Use the declared agent for both policy and tools.
        // lib.optionalAttrs (config.home.sessionVariables ? SSH_AUTH_SOCK) {
          SSH_AUTH_SOCK =
            lib.replaceStrings [ "$HOME" "\${HOME}" ] [ config.home.homeDirectory config.home.homeDirectory ]
              config.home.sessionVariables.SSH_AUTH_SOCK;
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

  # App-hosted sessions (T3 Code drives Pi over RPC and injects its own
  # extension) can start the unwrapped binary from this stable path instead of
  # a store path that moves with every update. The tradeoff is explicit: no
  # Safehouse boundary, only the host app's own approvals.
  home.file.".local/bin/pi-unsandboxed".source = lib.getExe pkgs.pi-coding-agent;
}
