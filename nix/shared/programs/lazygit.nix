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
    "lazygit".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/lazygit";
  };
}
