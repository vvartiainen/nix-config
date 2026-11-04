{ config, pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "reloadall";
      runtimeInputs = [
        pkgs.sketchybar
        pkgs.jq
        config.programs.rex.package
      ];
      text = ''
        failed=0
        reload() {
          local service="$1"
          local started=$SECONDS
          shift
          printf 'Reloading %s...\n' "$service"
          if ! "$@"; then
            printf 'reloadall: %s failed\n' "$service" >&2
            failed=1
          fi
          printf '%s finished in %ss\n' "$service" "$((SECONDS - started))"
        }

        # Reapply settings without taking desktop controls offline. yabairc
        # loads the scripting addition and replaces rules/signals by label.
        export PATH="/opt/yabai/bin:$PATH"
        reload "yabai configuration" /bin/sh -e "''${XDG_CONFIG_HOME:-$HOME/.config}/yabai/yabairc"
        reload skhd /opt/skhd/bin/skhd --reload
        reload SketchyBar sketchybar --reload

        # Inside Rex, use the CLI bundled with the running app/server.
        rex_command=rex
        if [[ -n "''${REX_BIN_DIR:-}" ]]; then
          rex_command="$REX_BIN_DIR/rex"
        fi
        reload Rex "$rex_command" --autostart=false config reload
        exit "$failed"
      '';
    })
  ];
}
