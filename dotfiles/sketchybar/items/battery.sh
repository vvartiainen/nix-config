#!/bin/bash

source "$CONFIG_DIR/colors.sh"

sketchybar --add item battery right \
	--set battery update_freq=120 \
	script="$PLUGIN_DIR/battery.sh" \
	--set battery icon.color="$GREEN" \
	--set battery label.color="$SKY" \
	label.width=50 \
	--subscribe battery system_woke power_source_change
