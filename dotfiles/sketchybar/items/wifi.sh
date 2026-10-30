#!/bin/bash

sketchybar --add item wifi right \
	--set wifi update_freq=10 \
	icon.font="sketchybar-app-font:Regular:16.0" \
	label.drawing=off \
	script="$PLUGIN_DIR/wifi.sh" \
	--subscribe wifi wifi_change system_woke
