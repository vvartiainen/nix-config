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
  home = {
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      LANG = "en_US.UTF-8";
      SSH_AUTH_SOCK = "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
      GOPATH = "$HOME/golang";
      GOROOT = "/opt/homebrew/opt/go/libexec";
      FZF_DEFAULT_COMMAND = "fd --type f";
      FZF_CTRL_T_COMMAND = "fd --type f";
      FZF_DEFAULT_OPTS = "--height 80% --bind 'ctrl-y:execute-silent(pbcopy <<< {})+abort' --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8";
    };

    sessionPath = [
      "/opt/homebrew/opt/libpq/bin"
      "$HOME/golang/bin"
      "/opt/homebrew/opt/go/libexec/bin"
    ];

    file = {
      ".rgignore".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.rgignore";
      ".tmux.conf".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tmux/tmux.conf";
    };

    packages = with pkgs; [
      fzf
      git
      jq
      lazydocker
      lazygit
      statix
      yazi
    ];

  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      # Atuin sets this at runtime; avoid conflicting static defaults.
      strategy = [ ];
    };
    plugins = [
      {
        name = "fast-syntax-highlighting";
        src = pkgs.zsh-fast-syntax-highlighting;
        file = "share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh";
      }
    ];
    history = {
      path = "$HOME/.zsh_history";
      size = 100000;
      save = 100000;
    };
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      # In Nix, oh-my-zsh is store-managed and not self-updated.
      extraConfig = ''
        zstyle ':omz:update' mode disabled
      '';
      plugins = [
        "kitty"
        "aws"
        "git"
        "terraform"
        "npm"
        "golang"
        "poetry"
        "bun"
        "docker"
        "docker-compose"
        "rsync"
      ];
    };
    shellAliases = {
      rm = "rm -i";
      cp = "cp -i";
      mv = "mv -i";
      rg = "rg --hyperlink-format=kitty";
      ls = "lsd --hyperlink=auto";
      la = "lsd -la --hyperlink=auto";
      lt = "lsd --tree --hyperlink=auto";
      vi = "nvim";
      vim = "nvim";
      lg = "lazygit";
      vimode = "bindkey -v";
      sshc = "vi ~/.ssh/config";
      sshkh = "vi ~/.ssh/known_hosts";
      reloadyabai = "sudo yabai --load-sa && yabai --restart-service";
      reloadsketchybar = "sketchybar --reload";
      reloadskhd = "skhd --restart-service";
      reloadall = "sudo yabai --load-sa ; yabai --restart-service ; skhd --restart-service ; sketchybar --reload";
    };
    initContent = ''
      source "$HOME/prog/dotfiles/tool-configs/fzf.sh"

      # Init tools
      eval "$(thefuck --alias)"
      eval "$(zoxide init --cmd cd zsh)"
      eval "$(mise activate zsh)"

      yy() {
        local tmp
        tmp="$(mktemp -t yazi-cwd.XXXXXX)"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          builtin cd -- "$cwd" || return
        fi
        rm -f -- "$tmp"
      }
    '';
  };

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
      "yabai".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/yabai";
      "yazi".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/yazi";
    };
  };

}
