{
  inputs,
  pkgs,
  userName,
  hostName,
  ...
}:
{
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
