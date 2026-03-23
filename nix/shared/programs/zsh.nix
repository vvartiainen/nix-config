{
  lib,
  pkgs,
  config,
  repoRoot,
  ...
}:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = config.home.homeDirectory;
    # Cache completions for 24h
    # completionInit = ''
    #   autoload -U compinit
    #   zmodload zsh/datetime
    #   zmodload zsh/stat
    #   typeset -A __zcompdump_stat
    #   if ! zstat -H __zcompdump_stat -- ~/.zcompdump 2>/dev/null; then
    #     compinit
    #   elif (( EPOCHSECONDS - __zcompdump_stat[mtime] > 86400 )); then
    #     compinit
    #   else
    #     compinit -C
    #   fi
    #   unset __zcompdump_stat
    # '';
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
    };
    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        if [[ -n "$ZSH_PROFILE" ]]; then
          zmodload zsh/zprof
        fi
      '')
      ''

        source "${repoRoot}/scripts/fzf.sh"

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

        if [[ -n "$ZSH_PROFILE" ]]; then
          zprof
        fi
      ''
    ];
  };
}
