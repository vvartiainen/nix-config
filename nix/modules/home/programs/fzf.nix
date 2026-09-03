{ ... }:
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    historyWidget.command = "";
    defaultCommand = "fd --type f";
    fileWidget.command = "fd --type f";
    defaultOptions = [
      "--height 80%"
      "--bind 'ctrl-y:execute-silent(pbcopy <<< {})+abort'"
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
  };
}
