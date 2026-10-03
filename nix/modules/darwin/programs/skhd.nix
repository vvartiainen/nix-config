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

  # skhd's hotloader can reload mid-relink and silently drop bindings from `.load`ed files.
  home.activation.reloadSkhd = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -x /opt/homebrew/bin/skhd ] && /usr/bin/pgrep -x skhd >/dev/null; then
      run /opt/homebrew/bin/skhd --reload
    fi
  '';

  programs.zsh.shellAliases = {
    reloadskhd = "skhd --restart-service";
    reloadall = "sudo yabai --load-sa ; yabai --restart-service ; skhd --restart-service ; sketchybar --reload";
  };
}
