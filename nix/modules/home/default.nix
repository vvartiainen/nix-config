{
  pkgs,
  lib,
  config,
  repoRoot,
  ...
}:
let
  inherit (import ./link-dotfiles.nix { inherit lib config repoRoot; }) link linkTree;
in
{
  imports = [ ./programs ];

  home = {
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      LANG = "en_US.UTF-8";
    };

    sessionPath = [
      "$HOME/.local/bin"
    ];

    file = {
      ".bunfig.toml".source = link ".bunfig.toml";
      ".npmrc".source = link ".npmrc";
      ".yarnrc.yml".source = link ".yarnrc.yml";
      ".rgignore".source = link ".rgignore";
      # TPM treats ~/.config/tmux/tmux.conf as an XDG install and then loads
      # plugins from ~/.config/tmux/plugins, not ~/.tmux/plugins.
      ".tmux.conf".source = link "tmux/tmux.conf";
    };

    packages = with pkgs; [
      gdu
      lnav
      statix
    ];
  };

  xdg = {
    enable = true;
    configFile = lib.mkMerge [
      (linkTree "kitty")
      (linkTree "mise")
      (linkTree "nvim")
      (linkTree "yazi")
      {
        "pip/pip.conf".source = link "pip/pip.conf";
        "pnpm/config.yaml".source = link "pnpm/config.yaml";
        "starship.toml".source = link "starship.toml";
        "uv/uv.toml".source = link "uv/uv.toml";
      }
    ];
  };
}
