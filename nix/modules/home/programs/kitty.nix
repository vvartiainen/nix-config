_:
{
  # kitten ssh brings kitty shell integration to the remote: edit-in-kitty,
  # hyperlinked remote files and kitten transfer. Only in kitty itself; tmux
  # and other terminals keep plain ssh.
  programs.zsh.initContent = ''
    [[ $TERM == xterm-kitty ]] && alias ssh='kitten ssh'
  '';
}
