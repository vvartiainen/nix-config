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
  xdg.configFile = linkTree "skhd";

  programs.zsh.shellAliases = {
    reloadskhd = "skhd --restart-service";
    reloadall = "sudo yabai --load-sa ; yabai --restart-service ; skhd --restart-service ; sketchybar --reload";
  };
}
