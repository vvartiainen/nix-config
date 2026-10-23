{
  config,
  lib,
  pkgs,
  ...
}:
let
  herdr-here = pkgs.writeShellApplication {
    name = "herdr-here";
    runtimeInputs = [
      config.programs.herdr.package
      pkgs.git
      pkgs.jq
    ];
    text = ''
      dir=$(cd "''${1:-$PWD}" && pwd -P)
      target=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")

      # Prefer a pane exactly at the target, then one anywhere below it.
      ws=$(herdr pane list | jq -r --arg t "$target" '
        .result.panes as $p
        | ([$p[] | select(.cwd == $t or .foreground_cwd == $t)]
           + [$p[] | select((.cwd | startswith($t + "/")) or ((.foreground_cwd // "") | startswith($t + "/")))])
        | first | .workspace_id // empty
      ')

      if [[ -n "$ws" ]]; then
        herdr workspace focus "$ws" >/dev/null
      else
        herdr workspace create --cwd "$target" --label "$(basename "$target")" --focus >/dev/null
      fi
    '';
  };

  # Clear the focused pane: new conversation in agent CLIs, Ctrl+L in a shell.
  herdr-clear = pkgs.writeShellApplication {
    name = "herdr-clear";
    runtimeInputs = [
      config.programs.herdr.package
      pkgs.jq
    ];
    text = ''
      pane=''${HERDR_ACTIVE_PANE_ID:?}
      read -r status agent < <(herdr pane get "$pane" | jq -r '.result.pane | "\(.agent_status) \(.agent // "")"')

      case "$agent" in
        "") herdr pane send-keys "$pane" ctrl+l; exit ;;
        claude) cmd=/clear ;;
        *) cmd=/new ;;
      esac

      # Don't queue the command as a message while a turn is running.
      [[ "$status" == working ]] && exit

      herdr pane send-text "$pane" "$cmd"
      sleep 0.1
      herdr pane send-keys "$pane" enter
    '';
  };
in
{
  home.packages = [
    herdr-here
    herdr-clear
  ];
  programs.zsh.shellAliases.hh = "herdr-here";

  # The Pi extension is versioned with herdr, so reinstall it on every
  # activation to keep state reporting and session restore current.
  home.activation.herdrPiIntegration = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${lib.getExe config.programs.herdr.package} integration install pi >/dev/null
  '';

  programs.herdr = {
    enable = true;
    settings = {
      onboarding = false;

      # kitty only maps the right Option key to alt (macos_option_as_alt = right).
      keys = {
        previous_agent = "alt+k";
        next_agent = "alt+j";
        focus_agent = "alt+1..9";
        goto = "alt+g";
        workspace_picker = "alt+w";
        previous_workspace = "alt+h";
        next_workspace = "alt+l";
        switch_workspace = "alt+shift+1..9";
        new_tab = "alt+n";
        new_workspace = "alt+shift+n";

        command = [
          {
            key = "alt+c";
            type = "shell";
            command = lib.getExe herdr-clear;
            description = "clear pane / new conversation";
          }
        ];
      };

      ui = {
        sidebar_width = 36;
        sidebar_min_width = 30;
        sidebar_max_width = 48;
        agent_panel_sort = "spaces";
        status_indicators = "symbols";

        # Keep host/workspace context separate from agent identity and title.
        sidebar = {
          agents = {
            row_gap = 1;
            rows = [
              [
                "state_icon"
                {
                  token = "agent";
                  bold = true;
                }
                "tab"
                "pane"
              ]
              [
                {
                  token = "machine";
                  fg = "#f9e2af";
                }
                {
                  token = "workspace";
                  fg = "#89b4fa";
                  bold = true;
                }
              ]
              [ "terminal_title_stripped" ]
            ];
          };
          spaces = {
            row_gap = 1;
            rows = [
              [
                "state_icon"
                {
                  token = "workspace";
                  bold = true;
                }
              ]
              [
                "branch"
                "git_status"
              ]
            ];
          };
        };
        show_agent_labels_on_pane_borders = true;
        window_title = "{hostname}: {workspace} / {tab} / {pane}";
        toast.delivery = "system";
        sound.enabled = true;
      };

      theme = {
        name = "catppuccin";
        auto_switch = false;
        # Make the active agent/workspace stand out from the sidebar background.
        custom.active_row_bg = "#45475a";
        custom.selection_bg = "#585b70";
      };
    };
  };
}
