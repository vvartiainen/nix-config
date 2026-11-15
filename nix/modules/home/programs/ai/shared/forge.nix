{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Self-hosted Forgejo. Repositories clone over its SSH port, which sandboxes
  # cannot use, and reach the same instance over HTTPS with a token.
  host = "git.lab.vartiainen.io";
  sshPort = 2222;
  # `fj` reads its token from a data directory below the home directory and has
  # no override, so sandboxes get their own home with an agent-only token. The
  # user's own login under `~/Library/Application Support` stays untouched.
  agentHome = "${config.home.homeDirectory}/.local/share/agent-forge";
  keystore = "${agentHome}/Library/Application Support/forgejo-cli.forgejo-cli/keys.json";
  # Answers git's credential requests from that key file, so sandboxed git needs
  # neither the keychain nor an SSH key.
  credentialHelper = pkgs.writeShellApplication {
    name = "git-credential-forgejo";
    runtimeInputs = [
      pkgs.gawk
      pkgs.jq
    ];
    text = ''
      FORGE_KEYSTORE=${lib.escapeShellArg keystore}
      export FORGE_KEYSTORE
    ''
    + builtins.readFile ./git-credential-forgejo.sh;
  };
in
{
  inherit agentHome host keystore;

  keystoreDir = builtins.dirOf keystore;

  # Shadows `fj` in a sandbox's PATH: inside a sandbox the command uses the
  # agent token, outside it keeps the user's own login. A store path keeps the
  # real binary available, so the wrapper never calls itself.
  fj = pkgs.writeShellApplication {
    name = "fj";
    text = ''
      HOME=${lib.escapeShellArg agentHome}
      export HOME
      exec "${pkgs.forgejo-cli}/bin/fj" "$@"
    '';
  };

  # Git configuration for sandboxed agents: keep the user's config, then send
  # the forge's SSH remotes over HTTPS with the restricted token. The empty
  # helper resets the keychain helper, which cannot work inside a sandbox.
  gitConfig = pkgs.writeText "agent-forge.gitconfig" ''
    [include]
      path = "${config.home.homeDirectory}/.config/git/config"
    [credential "https://${host}"]
      helper =
      helper = ${lib.getExe credentialHelper}
    [url "https://${host}/"]
      insteadOf = ssh://git@${host}:${toString sshPort}/
  '';
}
