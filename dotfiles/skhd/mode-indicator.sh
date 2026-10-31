#!/bin/bash

# Called with a mode by skhd, or without arguments to render SketchyBar.
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/skhd"
state_file="$state_dir/mode"

if [ "$#" -gt 0 ]; then
  case "$1" in
    default) rm -f "$state_file" ;;
    window|resize)
      # The launch wrapper exports the PID preserved by exec into skhd.
      [ -n "${SKHD_MODE_PID:-}" ] || exit 0
      mkdir -p "$state_dir"
      temporary=$(mktemp "$state_dir/.mode.XXXXXX") || exit 1
      printf '%s %s\n' "$1" "$SKHD_MODE_PID" > "$temporary"
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
  *) kill -0 "$owner" 2>/dev/null || mode=default ;;
esac

# shellcheck source=dotfiles/sketchybar/colors.sh
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"
case "$mode" in
  window)
    title=WINDOW
    color="$BLUE"
    keys="H J K L  focus    Shift+H J K L  warp"
    navigation="R resize    Esc / Return exit"
    ;;
  resize)
    title=RESIZE
    color="$PEACH"
    keys="H J K L  resize"
    navigation="W window mode    Esc / Return exit"
    ;;
  *)
    sketchybar --set keyboard_mode drawing=off popup.drawing=off
    exit 0
    ;;
esac

sketchybar --set keyboard_mode drawing=on label="$title" label.color="$color" \
  popup.drawing=on \
  --set keyboard_mode.keys label="$keys" \
  --set keyboard_mode.navigation label="$navigation"
