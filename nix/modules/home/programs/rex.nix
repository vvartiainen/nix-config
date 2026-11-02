{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  # Generate the vendor's bootstrap skill with the pinned CLI, away from HOME.
  # Its guide is read from the running Rex CLI, including the app's CLI in Rex.
  skill = pkgs.runCommand "rex-skill" { } ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$HOME"
    ${lib.getExe config.programs.rex.package} --autostart=false skill setup \
      --agent claude --agent codex
    mkdir -p "$out"
    cp "$HOME/.agents/skills/rex/SKILL.md" "$out/SKILL.md"
    cmp "$HOME/.claude/skills/rex/SKILL.md" "$out/SKILL.md"
  '';

  # The package ships no completions; the generated script supports autoload.
  zshCompletion = pkgs.runCommand "rex-zsh-completion" { } ''
    mkdir -p "$out/share/zsh/site-functions"
    ${lib.getExe config.programs.rex.package} --autostart=false completion zsh \
      > "$out/share/zsh/site-functions/_rex"
  '';
in
{
  imports = [ inputs.rex.homeManagerModules.default ];

  home = {
    packages = [ zshCompletion ];

    # Codex, OpenCode and Pi share .agents/skills; Claude uses its own directory.
    # Cleanup archives the previous copies before linkGeneration restores these.
    file = lib.genAttrs [ ".agents/skills/rex" ".claude/skills/rex" ] (_: {
      source = skill;
      force = true;
    });

    # The pinned CLI recognizes the identical linked skills as unchanged and
    # reconciles only its hooks, preserving other integrations and settings.
    activation.rexAgentHooks =
      lib.hm.dag.entryAfter
        [
          "linkGeneration"
          "claudeCodeConfig"
          "codexMutableConfig"
        ]
        ''
          run ${lib.getExe config.programs.rex.package} --autostart=false skill setup \
            --agent claude --agent codex
        '';
  };

  # The GUI package runs the macOS server; this flake supplies CLI and terminfo.
  programs.rex = {
    enable = true;
    # SSH is managed outside Home Manager. Run `rex terminfo setup` once
    # to add the fallback to that configuration (see docs/maintenance.md).
    sshGuard = false;
    config = ''
      -- GUI themes use client actions rather than server configuration fields.
      rex.action{
        name = "catppuccin_mocha",
        title = "Apply Catppuccin Mocha",
        category = "Appearance",
        run = function()
          rex.client.queue("client.appearance.switch_mode", { mode = "dark" })
          rex.client.queue("client.theme.import", {
            path = "${../../../../dotfiles/rex/Catppuccin-Mocha}",
          })
        end,
      }

      -- Direct navigation follows vertical tabs and side-by-side panes.
      rex.bind("alt+k", "client.tab.previous")
      rex.bind("alt+j", "client.tab.next")
      rex.bind("alt+h", "pane.focus_previous")
      rex.bind("alt+l", "pane.focus_next")
      rex.bind("alt+n", "client.tab.new")
      rex.bind("cmd+enter", "pane.split", { direction = "right" })
      rex.bind("cmd+shift+enter", "pane.split", { direction = "down" })

      -- Aliases forwarded by skhd's Rex mode to the focused client.
      rex.bind("ctrl+alt+h", "pane.focus_previous")
      rex.bind("ctrl+alt+l", "pane.focus_next")
      rex.bind("ctrl+alt+j", "client.tab.next")
      rex.bind("ctrl+alt+k", "client.tab.previous")
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
