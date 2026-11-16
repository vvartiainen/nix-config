#!/bin/sh
# Use the native path wherever it works; UI scripting is only the fallback.
set -eu

case "${1:-}" in
  '') mode=create ;;
  --diagnose|--dry-run) mode=diagnose ;;
  *) echo 'Usage: create-space.sh [--diagnose|--dry-run]' >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { echo 'create-space: too many arguments' >&2; exit 2; }

if [ "$mode" = diagnose ] || ! yabai -m space --create; then
  display=$(yabai -m query --displays --display | jq -er '.id') || {
    echo 'create-space: cannot determine the current display from yabai' >&2
    exit 1
  }
  script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
  /usr/bin/osascript -l JavaScript "$script_dir/mission-control-space.js" "$mode" "$display" || {
    echo 'create-space: Mission Control failed; check Accessibility and System Events Automation permissions (docs/programs/desktop.md)' >&2
    exit 1
  }
fi
[ "$mode" = create ] || exit 0

# Label newly available routing destinations without restarting yabai or moving
# Spaces between displays (as yabairc's startup setup would do).
for entry in 1:Start 2:Browser 3:Code 4:Misc 5:Notes 6:Mail; do
  index=${entry%%:*}
  label=${entry#*:}
  space=$(yabai -m query --spaces --space "$index" 2>/dev/null) || continue
  if [ "$(printf '%s' "$space" | jq -r '.label')" = '' ]; then
    yabai -m space "$index" --label "$label" ||
      echo "create-space: created Space, but could not label Space $index" >&2
  fi
done

# items/spaces.sh already has items 1-10. Recompute their display associations,
# selection and app icons; --update alone does not rebuild Space associations.
if command -v sketchybar >/dev/null 2>&1; then
  sketchybar --trigger space_change --trigger space_windows_change ||
    echo 'create-space: created Space, but SketchyBar refresh failed' >&2
fi
