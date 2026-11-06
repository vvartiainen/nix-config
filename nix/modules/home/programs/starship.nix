_:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Replaces Starship's add_newline, which also pads the first prompt of a new
  # shell or after `clear` away from the top edge and the tab bar.
  programs.zsh.initContent = ''
    _prompt_spacing_precmd() {
      (( _prompt_spacing )) && print
      _prompt_spacing=1
    }
    _prompt_spacing_preexec() {
      [[ $1 == clear || $1 == reset ]] && _prompt_spacing=0
    }
    precmd_functions+=(_prompt_spacing_precmd)
    preexec_functions+=(_prompt_spacing_preexec)
  '';
}
