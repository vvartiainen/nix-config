#!/bin/bash

sketchybar --add item mic right \
	--set mic update_freq=10 \
	icon.font="sketchybar-app-font:Regular:16.0" \
	label.drawing=off \
	script="$PLUGIN_DIR/mic.sh" \
	--subscribe mic mouse.clicked
