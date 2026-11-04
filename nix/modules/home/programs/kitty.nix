{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Protect the remote-control sockets from other local users. Kitty does not
  # create the parent directory itself.
  home.activation.kittySocketDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg "${config.home.homeDirectory}/.local/state/kitty"}
  '';

  # kitten ssh brings kitty shell integration to the remote: edit-in-kitty,
  # hyperlinked remote files and kitten transfer. Only in kitty itself; tmux
  # and other terminals keep plain ssh.
  programs.zsh.initContent = ''
    # Kitty injects integration only into its initial shell. Load it again
    # after `exec zsh`; _ksi_state prevents duplicate hooks in the first shell.
    if [[ $TERM == xterm-kitty && -n $KITTY_INSTALLATION_DIR &&
          -r $KITTY_INSTALLATION_DIR/shell-integration/zsh/kitty-integration ]] &&
       (( ! $+_ksi_state )); then
      export KITTY_SHELL_INTEGRATION=enabled
      autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
      kitty-integration
      unfunction kitty-integration
    fi

    [[ $TERM == xterm-kitty ]] && alias ssh='kitten ssh'
  '';
}
