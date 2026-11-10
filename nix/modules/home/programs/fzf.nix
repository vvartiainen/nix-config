{ options, pkgs, ... }:
let
  clipboard = if pkgs.stdenv.hostPlatform.isDarwin then "pbcopy" else "wl-copy";
in
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f";
    defaultOptions = [
      "--height 80%"
      "--bind 'ctrl-y:execute-silent(${clipboard} <<< {})+abort'"
    ];
    colors = {
      "bg+" = "#313244";
      bg = "#1e1e2e";
      spinner = "#f5e0dc";
      hl = "#f38ba8";
      fg = "#cdd6f4";
      header = "#f38ba8";
      info = "#cba6f7";
      pointer = "#f5e0dc";
      marker = "#f5e0dc";
      "fg+" = "#cdd6f4";
      prompt = "#cba6f7";
      "hl+" = "#f38ba8";
    };
  }
  # Home Manager releases up to 26.05 use flat widget option names. There
  # fzf binds Ctrl+R unconditionally; Atuin initializes later and wins.
  // (
    if options.programs.fzf ? fileWidget then
      {
        historyWidget.command = "";
        fileWidget.command = "fd --type f";
      }
    else
      { fileWidgetCommand = "fd --type f"; }
  );
}
