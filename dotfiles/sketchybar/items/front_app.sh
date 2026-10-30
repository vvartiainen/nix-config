#!/bin/bash

sketchybar --add item front_app left \
	--set front_app background.color="$SURFACE1" \
	icon.color="$MAUVE" \
	icon.font="sketchybar-app-font:Regular:16.0" \
	icon.padding_left=8 \
	label.color="$SKY" \
	label.padding_right=8 \
	script="$PLUGIN_DIR/front_app.sh" \
	--subscribe front_app front_app_switched
