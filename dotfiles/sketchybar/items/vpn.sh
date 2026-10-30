#!/bin/bash

sketchybar --add item vpn right \
	--set vpn update_freq=10 \
	icon.font="sketchybar-app-font:Regular:16.0" \
	label.drawing=off \
	script="$PLUGIN_DIR/vpn.sh" \
	--subscribe vpn system_woke
