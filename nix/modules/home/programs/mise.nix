{
  config,
  lib,
  pkgs,
  repoRoot,
  ...
}:
let
  inherit (import ../link-dotfiles.nix { inherit lib config repoRoot; }) linkTree;
  miseDir = "${config.xdg.configHome}/mise";
  stateDir = "${config.xdg.stateHome}/nix-config/mise";
in
{
  xdg.configFile = linkTree "mise";

  home.activation.miseConfigReminder = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    miseStateFile=${lib.escapeShellArg "${stateDir}/last-notified-inputs.sha256"}
    # Read the live files: both old and new generations link to the same checkout.
    if miseInputs="$(${pkgs.coreutils}/bin/sha256sum -- ${
      lib.escapeShellArgs [
        "${miseDir}/config.toml"
        "${miseDir}/mise.lock"
      ]
    })"; then
      if [[ ! -r "$miseStateFile" ]] || [[ "$miseInputs" != "$(${pkgs.coreutils}/bin/cat -- "$miseStateFile")" ]]; then
        echo "mise config.toml / mise.lock changed, or this is the first tracked activation."
        echo "Install the declared global tools: mise -C ~ install"
        echo "Preview obsolete tools: mise prune --dry-run"
        echo "After reviewing the removals, optionally run: mise prune"
        run ${pkgs.coreutils}/bin/mkdir -p -- ${lib.escapeShellArg stateDir}
        run ${pkgs.coreutils}/bin/tee -- "$miseStateFile" <<< "$miseInputs" > /dev/null
      fi
    else
      echo "mise reminder: cannot read config.toml / mise.lock; notification state was not updated." >&2
    fi
    unset miseInputs miseStateFile
  '';
}
