{
  config,
  repoRoot,
  ...
}:
let
  link = rel: config.lib.file.mkOutOfStoreSymlink "${repoRoot}/dotfiles/${rel}";
in
{
  xdg.configFile."yabai".source = link "yabai";

  programs.zsh.shellAliases = {
    reloadyabai = "sudo yabai --load-sa && yabai --restart-service";
  };
}
