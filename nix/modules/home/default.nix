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
      GOPATH = "$HOME/golang";
    };

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/golang/bin"
    ];

    file = {
      ".bunfig.toml".source = link ".bunfig.toml";
      ".npmrc".source = link ".npmrc";
      ".yarnrc.yml".source = link ".yarnrc.yml";
      ".rgignore".source = link ".rgignore";
    };

    packages = with pkgs; [
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
        "tmux/tmux.conf".source = link "tmux/tmux.conf";
        "uv/uv.toml".source = link "uv/uv.toml";
      }
    ];
  };
}
