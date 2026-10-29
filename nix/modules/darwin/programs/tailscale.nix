{
  # The Mac App Store variant bundles the CLI inside the app but does not
  # install a standalone `tailscale` launcher on PATH.
  home.sessionPath = [ "/Applications/Tailscale.app/Contents/MacOS" ];
  programs.zsh.shellAliases.tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
}
