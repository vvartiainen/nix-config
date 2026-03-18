#!/bin/bash

# The $SELECTED variable is available for space components and indicates if
# the space invoking this script (with name: $NAME) is currently selected:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item

source "$CONFIG_DIR/colors.sh"

if [ "$SELECTED" = true ]; then
	sketchybar --set "$NAME" background.drawing=on \
		background.color="$SURFACE1" \
		--set "$NAME" label.color="$MAUVE" \
		--set "$NAME" icon.color="$SKY" \
		--set "$NAME" icon.padding_left=10 \
		--set "$NAME" label.padding_left=2
else
	sketchybar --set "$NAME" background.drawing=off \
		--set "$NAME" label.color="$MAUVE" \
		--set "$NAME" icon.color="$SKY" \
		--set "$NAME" icon.padding_left=10 \
		--set "$NAME" label.padding_left=2

fi
