#!/bin/sh

# Some events send additional information specific to the event in the $INFO
# variable. E.g. the front_app_switched event sends the name of the newly
# focused application in the $INFO variable:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

source "$CONFIG_DIR/colors.sh"

if [ "$SENDER" = "front_app_switched" ]; then
	sketchybar --set "$NAME" label="$INFO" icon="$("$CONFIG_DIR"/plugins/icon_map_fn.sh "$INFO")" icon.color="$MAUVE" label.color="$SKY" icon.padding_left=10 label.padding_right=10
fi
