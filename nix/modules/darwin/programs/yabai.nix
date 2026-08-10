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
    "yabai".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/yabai";
  };

  programs.zsh.shellAliases = {
    reloadyabai = "sudo yabai --load-sa && yabai --restart-service";
  };
}
