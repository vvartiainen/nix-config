{
  config,
  repoRoot,
  ...
}:
let
  link = rel: config.lib.file.mkOutOfStoreSymlink "${repoRoot}/dotfiles/${rel}";
in
{
  xdg.configFile."sketchybar".source = link "sketchybar";

  programs.zsh.shellAliases = {
    reloadsketchybar = "sketchybar --reload";
  };
}
