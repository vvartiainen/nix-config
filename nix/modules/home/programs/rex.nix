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

      -- Kitty's nth_window: focus the active tab's Nth pane in layout order.
      local function pane_leaves(node, out)
        if node.split then
          pane_leaves(node.split.before, out)
          pane_leaves(node.split.after, out)
        elseif node.block_id then
          out[#out + 1] = node.block_id
        end
        return out
      end

      rex.action{
        name = "pane_goto",
        title = "Go to Pane",
        category = "Pane",
        args = {
          type = "object",
          properties = { index = { type = "integer", minimum = 1 } },
          required = { "index" },
        },
        run = function(ctx, args)
          local view = rex.call("session.view", { session_id = ctx.session_id })
          for _, window in ipairs(view.windows or {}) do
            if window.window_id == view.active_window_id then
              for _, layer in ipairs(window.layers or {}) do
                if layer.kind == "tiled" and layer.layout then
                  local block = pane_leaves(layer.layout, {})[args.index]
                  if block then
                    rex.call("session.focus_block", {
                      session_id = ctx.session_id,
                      block_id = block,
                    })
                  end
                  return block
                end
              end
            end
          end
        end,
      }

      -- Kitty-style direct navigation: Ctrl+Shift (kitty_mod) for vertical
      -- tabs and side-by-side panes, Cmd+1–9 for panes.
      rex.bind("ctrl+shift+k", "client.tab.previous")
      rex.bind("ctrl+shift+j", "client.tab.next")
      rex.bind("ctrl+shift+h", "pane.focus_previous")
      rex.bind("ctrl+shift+l", "pane.focus_next")
      rex.bind("ctrl+shift+z", "pane.zoom")
      rex.bind("cmd+t", "client.tab.new")
      -- Kitty's clear_terminal (Cmd+K), which also drops scrollback. This
      -- replaces Rex's default Cmd+K for the session picker.
      rex.bind("cmd+k", "com.superlogical.terminal.clear")
      for i = 1, 9 do
        rex.bind("cmd+" .. i, "pane_goto", { index = i })
        rex.bind("ctrl+shift+" .. i, "client.tab.goto", { index = i })
      end
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
        rex.bind("ctrl+alt+cmd+" .. key, "pane.resize", { direction = direction })
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
