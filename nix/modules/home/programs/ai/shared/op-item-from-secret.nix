{ pkgs, ... }:
{
  # Saves a secret the user handed over with T3's request_secret to
  # 1Password without exposing it to the agent. `op` comes from Homebrew, so
  # it stays on PATH rather than in runtimeInputs.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "op-item-from-secret";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.jq
      ];
      text = builtins.readFile ./op-item-from-secret.sh;
    })
  ];
}
