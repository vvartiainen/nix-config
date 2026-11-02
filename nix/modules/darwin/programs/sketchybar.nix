{
  pkgs,
  repoRoot,
  userName,
  ...
}:
{
  # App icons for the spaces and front app items.
  fonts.packages = [ pkgs.sketchybar-app-font ];

  home-manager.users.${userName} =
    { config, lib, ... }:
    let
      inherit (import ../../home/link-dotfiles.nix { inherit lib config repoRoot; }) linkTree;
    in
    {
      # Runs ~/.config/sketchybar/sketchybarrc from the linked dotfiles.
      programs.sketchybar = {
        enable = true;
        # Plugins parse event payloads with jq. sketchybar-app-font provides
        # icon_map.sh, the app name to icon mapping that matches the font above.
        extraPackages = [
          pkgs.jq
          pkgs.sketchybar-app-font
        ];
      };

      xdg.configFile = linkTree "sketchybar";

      programs.zsh.shellAliases = {
        reloadsketchybar = "sketchybar --reload";
      };
    };
}
