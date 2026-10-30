#!/bin/bash

source "$CONFIG_DIR/colors.sh"

sketchybar --add item cpu right \
	--set cpu update_freq=5 \
	icon=􀧓 \
	--set cpu icon.color="$GREY" \
	--set cpu label.color="$SKY" \
	label.width=43 \
	script="$PLUGIN_DIR/cpu.sh"
