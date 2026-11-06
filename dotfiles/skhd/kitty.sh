#!/bin/bash

# Kitty helpers for skhd:
#   enter        select Herdr or Kitty mode from the focused window's title
#   action ARGS  run a Kitty mappable action in the focused Kitty window

# The quick access window runs as the separate kitty-quick-access app, which
# yabai may not manage. skhd runs these helpers from the focused app, so its
# pid identifies the right Kitty process either way.
window=$(/opt/yabai/bin/yabai -m query --windows --window 2>/dev/null)
window_pid=$(jq -r '.pid // empty' <<<"$window" 2>/dev/null)
front_pid=$(lsappinfo info -only pid "$(lsappinfo front)" 2>/dev/null | grep -o '[0-9][0-9]*' | head -n 1)

case "${1:-}" in
  enter)
    # Trust the yabai title only when it belongs to the focused app; for an
    # unmanaged quick access panel yabai still reports the previous window.
    title=
    if [ -n "$window_pid" ] && [ "$window_pid" = "$front_pid" ]; then
      title=$(jq -r '.title // empty' <<<"$window")
    fi
    # skhd ignores keys it posts itself, but handles keys from `skhd --key`.
    case "$title" in
      'herdr · '*) exec /opt/skhd/bin/skhd --key f17 ;;
      *) exec /opt/skhd/bin/skhd --key f18 ;;
    esac
    ;;
  action)
    shift
    # listen_on in kitty.conf creates one socket per Kitty process.
    socket="$HOME/.local/state/kitty/rc-${front_pid:-$window_pid}"
    [ -S "$socket" ] || exit 1
    exec kitten @ --to "unix:$socket" action "$@"
    ;;
  *) exit 1 ;;
esac
