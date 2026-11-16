#!/usr/bin/env sh

# yabai stacks every window of a Space at the same frame, and JankyBorders
# redraws their borders while Spaces change, which flashes. Hide the borders in
# stack layout, and restore the configured border in bsp by re-running the Home
# Manager bordersrc.

# yabairc runs this with --reset after a restart.
state_file="/tmp/yabai-borders-layout-$(id -u)"
bordersrc="${XDG_CONFIG_HOME:-$HOME/.config}/borders/bordersrc"

if [ "${1:-}" = "--reset" ]; then
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

if [ "$layout" = "stack" ]; then
  borders width=0.0 active_color=0x00000000 inactive_color=0x00000000 || exit 0
else
  [ -x "$bordersrc" ] || exit 0
  "$bordersrc" || exit 0
fi
printf '%s %s\n' "$borders_pid" "$layout" >"$state_file"
