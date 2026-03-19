{
  lib,
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
    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        if [ -d /opt/homebrew/share/zsh/site-functions ]; then
          fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
        fi
      '')
      ''
        source "$HOME/prog/dotfiles/tool-configs/fzf.sh"

        # Edit current command line in $EDITOR with Ctrl+X Ctrl+E.
        autoload -Uz edit-command-line
        zle -N edit-command-line
        bindkey -M emacs '^X^E' edit-command-line
        bindkey -M viins '^X^E' edit-command-line

        # Expands history expressions like !! or !$ when you press space
        bindkey ' ' magic-space

        # Init tools
        eval "$(thefuck --alias)"
        eval "$(zoxide init --cmd cd zsh)"
        eval "$(mise activate zsh)"

        # Load host-specific env/settings when present.
        if [ -f "$HOME/.zsh_local" ]; then
          source "$HOME/.zsh_local"
        fi

        if whence -w _docker >/dev/null 2>&1; then
          # Support setups where docker is aliased to podman.
          compdef _docker docker=podman
        fi

        # terraform from mise does not provide a native zsh completion function.
        # Fall back to terraform's own completion protocol via bash compatibility.
        if ! whence -w _terraform >/dev/null 2>&1 && command -v terraform >/dev/null 2>&1; then
          autoload -Uz bashcompinit
          bashcompinit
          complete -o nospace -C "$(command -v terraform)" terraform
        fi

        yy() {
          local tmp
          tmp="$(mktemp -t yazi-cwd.XXXXXX)"
          yazi "$@" --cwd-file="$tmp"
          if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd" || return
          fi
          rm -f -- "$tmp"
        }
      ''
    ];
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
