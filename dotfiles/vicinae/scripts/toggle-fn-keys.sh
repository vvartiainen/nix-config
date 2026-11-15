#!/bin/sh
# @vicinae.schemaVersion 1
# @vicinae.title Toggle Function Keys
# @vicinae.mode silent
# @vicinae.icon ⌨️
# @vicinae.description Switch the top row between media keys and F1-F12
# @vicinae.keywords ["fn", "keyboard", "media keys", "brightness", "volume"]

set -eu

current=$(/usr/bin/defaults read NSGlobalDomain com.apple.keyboard.fnState 2>/dev/null || echo 0)

case "$current" in
  1 | true)
    target=false
    message="Media keys: top row controls brightness, volume and playback"
    ;;
  *)
    target=true
    message="Function keys: top row sends F1-F12"
    ;;
esac

if ! /usr/bin/defaults write NSGlobalDomain com.apple.keyboard.fnState -bool "$target"; then
  echo "Could not change the fn key setting"
  exit 1
fi

echo "$message"
