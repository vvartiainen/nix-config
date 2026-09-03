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
      ".bunfig.toml".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.bunfig.toml";
      ".npmrc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.npmrc";
      ".yarnrc.yml".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.yarnrc.yml";
      ".rgignore".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.rgignore";
      ".tmux.conf".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tmux/tmux.conf";
    };

    packages = with pkgs; [
      fzf
      git
      jq
      lazydocker
      lazygit
      lnav
      statix
      yazi
    ];

  };

  xdg = {
    enable = true;
    configFile = {
      "btop".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/btop";
      "kitty".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/kitty";
      "mise".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/mise";
      "nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/nvim";
      "pip/pip.conf".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/pip/pip.conf";
      "pnpm/config.yaml".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/pnpm/config.yaml";
      "starship.toml".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/starship.toml";
      "uv/uv.toml".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/uv/uv.toml";
      "yazi".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/yazi";
      "opencode".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/opencode";
    };
  };
}
