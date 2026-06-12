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
      FZF_DEFAULT_COMMAND = "fd --type f";
      FZF_CTRL_T_COMMAND = "fd --type f";
      FZF_DEFAULT_OPTS = "--height 80% --bind 'ctrl-y:execute-silent(pbcopy <<< {})+abort' --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8";
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
      ".copilot/skills".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.copilot/skills";
      ".copilot/lsp-config.json".source =
        config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.copilot/lsp-config.json";
      ".copilot/settings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.copilot/settings.json";
      ".cursor/cli-config.json".source =
        config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.cursor/cli-config.json";
      ".agents/skills".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.agents/skills";
    };

    packages = with pkgs; [
      inputs.cli-toolbox.packages.${system}.default

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
