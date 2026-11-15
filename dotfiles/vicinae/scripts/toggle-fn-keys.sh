#!/bin/sh
# @vicinae.schemaVersion 1
# @vicinae.title Toggle Function Keys
# @vicinae.mode silent
# @vicinae.icon ⌨️
# @vicinae.description Switch the top row between media keys and F1-F12
# @vicinae.keywords ["fn", "keyboard", "media keys", "brightness", "volume"]

set -eu

defaults=/usr/bin/defaults
# Private helper macOS uses to push stored keyboard preferences to the running
# HID system; a bare `defaults write` would only apply at the next login.
activate_settings=/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings

current=$("$defaults" read NSGlobalDomain com.apple.keyboard.fnState 2>/dev/null || echo 0)

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

if ! "$defaults" write NSGlobalDomain com.apple.keyboard.fnState -bool "$target"; then
  echo "Could not change the fn key setting"
  exit 1
fi

if [ -x "$activate_settings" ] && ! "$activate_settings" -u >/dev/null 2>&1; then
  echo "Saved the fn key setting, but macOS did not apply it; log out and back in"
  exit 1
fi

echo "$message"
