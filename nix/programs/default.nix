{
  pkgs,
  config,
  repoRoot,
  ...
}:
let
  dotfilesPath = "${repoRoot}/dotfiles";
in
{
  xdg = {
    enable = true;
    configFile = {
      "btop".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/btop";
      "kitty".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/kitty";
      "mise".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/mise";
      "nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/nvim";
      "sketchybar".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/sketchybar";
      "skhd".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/skhd";
      "starship.toml".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/starship.toml";
      "tmux".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tmux";
      "yabai".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/yabai";
      "yazi".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/yazi";
    };
  };

  home.file.".rgignore".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.rgignore";

  home.packages = with pkgs; [
    fzf
    git
    jq
    lazydocker
    lazygit
    statix
    yazi
  ];
}
