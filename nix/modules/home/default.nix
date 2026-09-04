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

    # Old generations linked whole config dirs. Remove those directory
    # symlinks before Home Manager creates per-file links, otherwise it
    # follows the dir link and writes into the repo (circular symlinks).
    activation.unlinkDotfileDirSymlinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      configHome="${config.xdg.configHome}"
      for dir in btop kitty lazygit mise nvim yazi opencode sketchybar skhd yabai; do
        target="$configHome/$dir"
        if [ -L "$target" ]; then
          echo "Removing directory symlink $target so files can be linked individually"
          if [[ ! -v DRY_RUN ]]; then
            rm -f "$target"
          fi
        fi
      done
    '';
  };

  xdg = {
    enable = true;
    configFile = lib.mkMerge [
      (linkTree "btop")
      (linkTree "kitty")
      (linkTree "lazygit")
      (linkTree "mise")
      (linkTree "nvim")
      (linkTree "yazi")
      (linkTree "opencode")
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
