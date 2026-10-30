#!/bin/sh

# Some events send additional information specific to the event in the $INFO
# variable. E.g. the front_app_switched event sends the name of the newly
# focused application in the $INFO variable:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

case "$SENDER" in
front_app_switched) APP="$INFO" ;;
# `sketchybar --update` sends no app name; the first line of lsappinfo's
# output is `"<name>" ASN:...`.
forced) APP="$(lsappinfo info "$(lsappinfo front)" | sed -n '1s/^"\(.*\)" ASN:.*/\1/p')" ;;
*) exit 0 ;;
esac

# icon_map.sh prints a trailing space after each icon.
ICON="$(icon_map.sh "$APP")"
sketchybar --set "$NAME" label="$APP" icon="${ICON% }"
