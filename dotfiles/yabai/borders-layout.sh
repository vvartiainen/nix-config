#!/usr/bin/env sh

# yabai stacks every window of a Space at the same frame, and JankyBorders
# redraws their borders while Spaces change, which flashes. Show the borders in
# bsp layout only, and hide them before leaving bsp so the target Space does not
# draw a border for a frame.

# yabairc runs this with --reset after a restart.
state_file="/tmp/yabai-borders-layout-$(id -u)"
bordersrc="${XDG_CONFIG_HOME:-$HOME/.config}/borders/bordersrc"
mode=${1:-}

hide_borders() {
  borders width=0.0 active_color=0x00000000 inactive_color=0x00000000
}

# Called by the skhd Space bindings: hide before switching away from bsp unless
# the target Space is bsp too. The space_changed signal then applies the target
# layout.
if [ "$mode" = "--focus" ]; then
  target=${2:?usage: borders-layout.sh --focus <space selector>}

  space=$(yabai -m query --spaces --space 2>/dev/null) || space=
  current_type=$(printf '%s' "$space" | jq -r '.type // empty' 2>/dev/null)

  if [ "$current_type" = "bsp" ]; then
    current_index=$(printf '%s' "$space" | jq -r '.index // empty' 2>/dev/null)

    target_index=$target
    if [ -n "$current_index" ]; then
      case "$target" in
      prev) target_index=$((current_index - 1)) ;;
      next) target_index=$((current_index + 1)) ;;
      esac
    fi

    target_type=$(yabai -m query --spaces --space "$target_index" 2>/dev/null |
      jq -r '.type // empty' 2>/dev/null)

    if [ -n "$target_type" ] && [ "$target_type" != "bsp" ]; then
      if /usr/bin/pgrep -x borders >/dev/null 2>&1; then
        hide_borders && rm -f "$state_file"
      fi
    fi
  fi

  yabai -m space --focus "$target"
  exit
fi

if [ "$mode" = "--reset" ]; then
  rm -f "$state_file"
fi

# The Spaces query's "type" field holds the layout: bsp, stack or float.
layout=$(yabai -m query --spaces --space 2>/dev/null |
  jq -r '.type // empty' 2>/dev/null) || exit 0
[ -n "$layout" ] || exit 0

# Do not start another borders instance when the launchd service is not up.
borders_pid=$(/usr/bin/pgrep -x borders | /usr/bin/head -n 1)
[ -n "$borders_pid" ] || exit 0

previous=
if [ -r "$state_file" ]; then
  previous=$(cat "$state_file") || previous=
fi
if [ "$previous" = "$borders_pid $layout" ]; then
  exit 0
fi

if [ "$layout" = "bsp" ]; then
  [ -x "$bordersrc" ] || exit 0
  "$bordersrc" || exit 0
else
  hide_borders || exit 0
fi
printf '%s %s\n' "$borders_pid" "$layout" >"$state_file"
