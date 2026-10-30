#!/bin/sh

# The volume_change event supplies a $INFO variable in which the current volume
# percentage is passed to the script. `sketchybar --update` doesn't, so read it.

case "$SENDER" in
volume_change) VOLUME=$INFO ;;
forced) VOLUME=$(osascript -e 'output volume of (get volume settings)') ;;
*) exit 0 ;;
esac

case $VOLUME in
  [6-9][0-9]|100) ICON="􀊩"
  ;;
  [3-5][0-9]) ICON="􀊥"
  ;;
  [1-9]|[1-2][0-9]) ICON="􀊡"
  ;;
  *) ICON="􀊣"
esac

sketchybar --set "$NAME" icon="$ICON" label="$VOLUME%"
