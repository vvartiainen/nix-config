{
  config,
  repoRoot,
  ...
}:
let
  link = rel: config.lib.file.mkOutOfStoreSymlink "${repoRoot}/dotfiles/${rel}";
in
{
  xdg.configFile = {
    "yabai".source = link "yabai";
    "skhd".source = link "skhd";
    "sketchybar".source = link "sketchybar";
  };

  programs.zsh.shellAliases = {
    reloadyabai = "sudo yabai --load-sa && yabai --restart-service";
    reloadskhd = "skhd --restart-service";
    reloadsketchybar = "sketchybar --reload";
    reloadall = "sudo yabai --load-sa ; yabai --restart-service ; skhd --restart-service ; sketchybar --reload";
  };
}
