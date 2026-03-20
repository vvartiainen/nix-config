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
    "sketchybar".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/sketchybar";
  };

  programs.zsh.shellAliases = {
    reloadsketchybar = "sketchybar --reload";
  };
}
