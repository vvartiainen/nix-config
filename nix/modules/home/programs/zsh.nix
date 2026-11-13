{
  lib,
  config,
  options,
  ...
}:
let
  # Home Manager releases up to 26.05 lack fastSyntaxHighlighting.
  highlighting =
    if options.programs.zsh ? fastSyntaxHighlighting then
      "fastSyntaxHighlighting"
    else
      "syntaxHighlighting";
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = config.home.homeDirectory;
    ${highlighting}.enable = true;
    autosuggestion = {
      enable = true;
      # Atuin sets this at runtime; avoid conflicting static defaults.
      strategy = [ ];
    };
    history = {
      path = "$HOME/.zsh_history";
      size = 100000;
      save = 100000;
    };
    shellAliases = {
      ".." = "cd ..";

      rg = "rg --hyperlink-format=kitty";
      ls = "lsd --hyperlink=auto";
      la = "lsd -la --hyperlink=auto";
      lt = "lsd --tree --hyperlink=auto";

      falias = "alias | fzf";
      fhistory = "history | fzf";
      fbinds = "bindkey | fzf";
      fenv = "env | fzf";

      lg = "lazygit";
      z = "cd";
      zi = "cdi";
      vimode = "bindkey -v";
      sshc = "vi ~/.ssh/config";
      sshkh = "vi ~/.ssh/known_hosts";
      ginit = "git init && touch .gitignore && touch README.md && git add . && git commit -m 'chore: initial commit'";
    };
    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        if [[ -n "$ZSH_PROFILE" ]]; then
          zmodload zsh/zprof
        fi
      '')
      ''

        # Functions rather than aliases: kitty session restore evals the saved
        # command with no_aliases set.
        if (( $+commands[nvim] )); then
          vi() { nvim "$@" }
          vim() { nvim "$@" }
        fi

        # Edit current command line in $EDITOR with Ctrl+X Ctrl+E.
        autoload -Uz edit-command-line
        zle -N edit-command-line
        bindkey -M emacs '^X^E' edit-command-line
        bindkey -M viins '^X^E' edit-command-line

        # Expands history expressions like !! or !$ when you press space
        bindkey ' ' magic-space

        # Init tools when installed (Homebrew on the Mac).
        if (( $+commands[mise] )); then
          eval "$(mise activate zsh)"
        fi

        # Load host-specific env/settings when present.
        if [ -f "$HOME/.zsh_local" ]; then
          source "$HOME/.zsh_local"
        fi

        # terraform and tofu from mise do not provide native zsh completion
        # functions. Fall back to their own completion protocol via bash
        # compatibility.
        for tf_cmd in terraform tofu; do
          if ! whence -w "_$tf_cmd" >/dev/null 2>&1 && command -v "$tf_cmd" >/dev/null 2>&1; then
            autoload -Uz bashcompinit
            bashcompinit
            complete -o nospace -C "$(command -v "$tf_cmd")" "$tf_cmd"
          fi
        done
        unset tf_cmd

        if [[ -n "$ZSH_PROFILE" ]]; then
          zprof
        fi
      ''
    ];
  };
}
