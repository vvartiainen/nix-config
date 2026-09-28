{ config, pkgs, ... }:
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
in
{
  home.packages = [ herdr-here ];
  programs.zsh.shellAliases.hh = "herdr-here";

  programs.herdr = {
    enable = true;
    settings = {
      onboarding = false;

      # kitty only maps the right Option key to alt (macos_option_as_alt = right).
      keys = {
        switch_workspace = "alt+1..9";
        previous_workspace = "alt+shift+left";
        next_workspace = "alt+shift+right";
        previous_agent = "alt+shift+up";
        next_agent = "alt+shift+down";
      };

      ui = {
        status_indicators = "symbols";
        toast.delivery = "system";
        sound.enabled = true;
      };

      theme = {
        name = "catppuccin";
        auto_switch = false;
      };
    };
  };
}
