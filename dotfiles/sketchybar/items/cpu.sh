#!/bin/bash

source "$CONFIG_DIR/colors.sh"

sketchybar --add item cpu right \
	--set cpu update_freq=2 \
	icon=􀧓 \
	--set cpu icon.color="$GREY" \
	--set cpu label.color="$SKY" \
	script="$PLUGIN_DIR/cpu.sh"
