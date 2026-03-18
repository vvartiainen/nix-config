{
  pkgs,
  config,
  repoRoot,
  ...
}:
let
  nvimPath = "${repoRoot}/dotfiles/nvim";
  starshipPath = "${repoRoot}/dotfiles/starship.toml";
in
{
  xdg = {
    enable = true;
    configFile = {
      "nvim".source = config.lib.file.mkOutOfStoreSymlink nvimPath;
      "starship.toml".source = config.lib.file.mkOutOfStoreSymlink starshipPath;
    };
  };

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
