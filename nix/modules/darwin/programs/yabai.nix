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
  xdg.configFile = linkTree "yabai";

  programs.zsh.shellAliases = {
    reloadyabai = "sudo yabai --load-sa && yabai --restart-service";
  };
}
