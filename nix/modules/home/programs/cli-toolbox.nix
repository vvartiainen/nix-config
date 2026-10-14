{
  pkgs,
  inputs,
  ...
}:
{
  home.packages = [
    inputs.cli-toolbox.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  programs.zsh.shellAliases = {
    ct = "cli-toolbox";
    fssh = "cli-toolbox ssh connect";
    faws = "eval \"$(cli-toolbox aws profile)\"";
    fkittysession = "cli-toolbox kitty select-session";
  };

  # Open the tool launcher with Ctrl+G. Runs in the current shell so the
  # export/cd instructions it prints on exit stay visible above the prompt.
  programs.zsh.initContent = ''
    _cli_toolbox_tui() {
      zle -I
      # Use the real pty ($TTY), not /dev/tty: crossterm's kqueue-based
      # reader on macOS can't poll /dev/tty.
      cli-toolbox tui <$TTY
      zle reset-prompt
    }
    zle -N _cli_toolbox_tui
    bindkey -M emacs '^G' _cli_toolbox_tui
    bindkey -M viins '^G' _cli_toolbox_tui
  '';
}
