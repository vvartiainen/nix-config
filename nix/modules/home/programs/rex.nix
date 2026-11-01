{ inputs, lib, ... }:
{
  imports = [ inputs.rex.homeManagerModules.default ];

  # The GUI package runs the macOS server; this flake supplies CLI and terminfo.
  programs.rex = {
    enable = true;
    # SSH is managed outside Home Manager. Run `rex terminfo setup` once
    # to add the fallback to that configuration (see docs/maintenance.md).
    sshGuard = false;
    config = ''
      -- Aliases forwarded by skhd's Rex mode to the focused client.
      rex.bind("ctrl+alt+h", "client.tab.previous")
      rex.bind("ctrl+alt+l", "client.tab.next")
      rex.bind("ctrl+alt+j", "pane.focus_next")
      rex.bind("ctrl+alt+k", "pane.focus_previous")
      rex.bind("ctrl+alt+t", "client.tab.new")
      rex.bind("ctrl+alt+v", "pane.split", { direction = "right" })
      rex.bind("ctrl+alt+shift+v", "pane.split", { direction = "down" })
      rex.bind("ctrl+alt+z", "pane.zoom")
      rex.bind("ctrl+alt+b", "pane.balance")
      rex.bind("ctrl+alt+shift+t", "client.tab.close")
      rex.bind("ctrl+alt+x", "pane.close")
      rex.bind("ctrl+alt+f", "client.palette.toggle")
      rex.bind("ctrl+alt+s", "session.switch")
      for i = 1, 9 do
        rex.bind("ctrl+alt+" .. i, "client.tab.goto", { index = i })
      end
      for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
        rex.bind("ctrl+alt+shift+" .. key, "pane.focus", { direction = direction })
      end
    '';
  };

  # Keep the app's matching CLI first inside Rex terminals, after Nix's PATH setup.
  programs.zsh.initContent = lib.mkAfter ''
    if [[ -n "$REX_BIN_DIR" ]]; then
      export PATH="$REX_BIN_DIR:$PATH"
    fi
  '';
}
