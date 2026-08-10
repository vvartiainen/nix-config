{
  config,
  repoRoot,
  ...
}:
let
  dotfilesPath = "${repoRoot}/dotfiles";
in
{
  xdg.configFile = {
    "skhd".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/skhd";
  };

  programs.zsh.shellAliases = {
    reloadskhd = "skhd --restart-service";
    reloadall = "sudo yabai --load-sa ; yabai --restart-service ; skhd --restart-service ; sketchybar --reload";
  };
}
