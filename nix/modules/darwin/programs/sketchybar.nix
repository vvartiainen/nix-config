{
  lib,
  config,
  repoRoot,
  ...
}:
let
  inherit (import ../../home/link-dotfiles.nix { inherit lib config repoRoot; }) linkTree;
in
{
  xdg.configFile = linkTree "sketchybar";

  programs.zsh.shellAliases = {
    reloadsketchybar = "sketchybar --reload";
  };
}
