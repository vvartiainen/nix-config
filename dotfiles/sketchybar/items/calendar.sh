#!/bin/bash

source "$CONFIG_DIR/colors.sh"

sketchybar --add item calendar right \
	--set calendar icon=􀧞 \
	--set calendar icon.color="$MAUVE" \
	--set calendar label.color="$SKY" \
	update_freq=10 \
	script="$PLUGIN_DIR/calendar.sh"
