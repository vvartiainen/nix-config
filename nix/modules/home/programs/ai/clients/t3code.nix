# T3 Code keeps one settings file per environment and writes it itself, so
# merge the policies declared here into it on activation. See merge-config.py.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  mergeConfig = import ../../../merge-config.nix { inherit lib pkgs config; };

  settings = {
    # Settle a thread once every pull request linked to it is merged. This is
    # the factory default; declare it so a local toggle cannot outlive a switch.
    sidebarAutoSettleOnMerge = true;
    storageCleanup = {
      # Remove a worktree once commits from its merged pull request are in the
      # remote default branch. Squash and rebase merges count while the worktree
      # still sits at the pull request's last commit.
      worktreeOnMerge = true;
    };
  };
in
{
  home.activation.t3codeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (mergeConfig {
    name = "t3code-settings";
    path = "${config.home.homeDirectory}/.t3/userdata/settings.json";
    inherit settings;
  });
}
