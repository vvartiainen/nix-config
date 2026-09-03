{
  config,
  repoRoot,
  ...
}:
let
  link = rel: config.lib.file.mkOutOfStoreSymlink "${repoRoot}/dotfiles/${rel}";
in
{
  xdg.configFile."skhd".source = link "skhd";

  programs.zsh.shellAliases = {
    reloadskhd = "skhd --restart-service";
    reloadall = "sudo yabai --load-sa ; yabai --restart-service ; skhd --restart-service ; sketchybar --reload";
  };
}
