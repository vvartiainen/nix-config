#!/bin/bash

# Called with a mode by skhd, or without arguments to render SketchyBar.
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/skhd"
state_file="$state_dir/mode"
pid_file="/tmp/skhd_${USER}.pid"
daemon_pid=
if [ -r "$pid_file" ]; then
  read -r daemon_pid < "$pid_file"
fi

if [ "$#" -gt 0 ]; then
  case "$1" in
    default) rm -f "$state_file" ;;
    window|resize|herdr)
      # skhd writes its PID before loading the configuration.
      case "$daemon_pid" in
        ''|*[!0-9]*) exit 0 ;;
      esac
      mkdir -p "$state_dir"
      temporary=$(mktemp "$state_dir/.mode.XXXXXX") || exit 1
      printf '%s %s\n' "$1" "$daemon_pid" > "$temporary"
      mv -f "$temporary" "$state_file"
      ;;
    *) exit 1 ;;
  esac
  sketchybar --trigger skhd_mode >/dev/null 2>&1 || true
  exit 0
fi

mode=default
owner=
if [ -r "$state_file" ]; then
  read -r mode owner < "$state_file"
fi
case "$owner" in
  ''|*[!0-9]*) mode=default ;;
  *)
    if [ "$owner" != "$daemon_pid" ] || ! kill -0 "$owner" 2>/dev/null; then
      mode=default
    fi
    ;;
esac

# Herdr capture belongs to Kitty. Events provide the app immediately; polling
# also recovers if the bar restarted or missed an app-switch event.
if [ "$mode" = herdr ]; then
  if [ "${SENDER:-}" = front_app_switched ]; then
    front_app="${INFO:-}"
  else
    front_app=$(lsappinfo info "$(lsappinfo front)" 2>/dev/null | sed -n '1s/^"\(.*\)" ASN:.*/\1/p')
  fi
  case "$front_app" in
    ''|kitty|Kitty) ;;
    *)
      # A reload returns skhd to default; its native callback clears the state.
      if /opt/skhd/bin/skhd --reload >/dev/null 2>&1; then
        mode=default
      fi
      ;;
  esac
fi

# shellcheck source=dotfiles/sketchybar/colors.sh
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"
case "$mode" in
  window)
    title=WINDOW
    color="$BLUE"
    keys="H J K L  focus    Shift+H J K L  warp"
    resize_keys="Cmd+HJKL resize 100    Cmd+Shift+HJKL fine 25"
    actions="B balance    Shift+B BSP    S stack    F zoom    1-6 move + follow"
    extra_rows=on
    navigation="R resize mode    Esc / Return exit"
    ;;
  resize)
    title=RESIZE
    color="$PEACH"
    keys="H J K L  resize"
    resize_keys=
    actions=
    extra_rows=off
    navigation="W window mode    Esc / Return exit"
    ;;
  herdr)
    title=HERDR
    color="$TEAL"
    keys="H / L tabs    J / K agents"
    resize_keys="Shift+J / K workspaces    1-9 agents"
    actions="Shift+1-9 tabs    G Go To    S workspaces"
    extra_rows=on
    navigation="Esc / Return exit    Right Cmd+Option+H toggle"
    ;;
  *)
    sketchybar --set keyboard_mode drawing=off popup.drawing=off
    exit 0
    ;;
esac

sketchybar --set keyboard_mode drawing=on label="$title" label.color="$color" \
  popup.drawing=on \
  --set keyboard_mode.keys label="$keys" \
  --set keyboard_mode.resize drawing="$extra_rows" label="$resize_keys" \
  --set keyboard_mode.actions drawing="$extra_rows" label="$actions" \
  --set keyboard_mode.navigation label="$navigation"
