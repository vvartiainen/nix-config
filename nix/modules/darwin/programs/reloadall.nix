{ config, pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "reloadall";
      runtimeInputs = [
        pkgs.sketchybar
        config.programs.rex.package
      ];
      text = ''
        failed=0
        reload() {
          local service="$1"
          shift
          printf 'Reloading %s...\n' "$service"
          if ! "$@"; then
            printf 'reloadall: %s failed\n' "$service" >&2
            failed=1
          fi
        }

        gui_domain="gui/$(/usr/bin/id -u)"
        reload "yabai scripting addition" /usr/bin/sudo -n /opt/yabai/bin/yabai --load-sa
        reload yabai /bin/launchctl kickstart -k "$gui_domain/org.nixos.yabai"
        reload skhd /bin/launchctl kickstart -k "$gui_domain/org.nixos.skhd"
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
