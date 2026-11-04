#!/bin/bash

# Kitty helpers for skhd:
#   enter        select Herdr or Kitty mode from the focused window's title
#   action ARGS  run a Kitty mappable action in the focused Kitty window
window=$(/opt/yabai/bin/yabai -m query --windows --window 2>/dev/null)

case "${1:-}" in
  enter)
    # skhd ignores keys it posts itself, but handles keys from `skhd --key`.
    case "$(jq -r '.title // empty' <<<"$window")" in
      'herdr · '*) exec /opt/skhd/bin/skhd --key f17 ;;
      *) exec /opt/skhd/bin/skhd --key f18 ;;
    esac
    ;;
  action)
    shift
    # listen_on in kitty.conf creates one socket per Kitty process.
    socket="$HOME/.local/state/kitty/rc-$(jq -r '.pid // empty' <<<"$window")"
    [ -S "$socket" ] || exit 1
    exec kitten @ --to "unix:$socket" action "$@"
    ;;
  *) exit 1 ;;
esac
