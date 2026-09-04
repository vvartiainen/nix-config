{ pkgs, ... }:
{
  # Home Manager's lazygit module always declares config.yml (disabled when
  # settings is empty), which conflicts with the linked dotfiles/lazygit
  # config. Install the package here and keep the yaml as the source of truth.
  home.packages = [ pkgs.lazygit ];
}
