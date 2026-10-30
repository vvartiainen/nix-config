#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# The time changes every minute, so it gets its own fixed-width item to keep
# the items to its left from shifting. The date changes once a day.
# Widths cover the widest value in SF Pro Semibold 15 plus label padding.
sketchybar --add item clock right \
	--set clock label.color="$SKY" \
	icon.drawing=off \
	padding_left=0 \
	label.padding_left=2 \
	label.width=78 \
	--add item calendar right \
	--set calendar icon=􀧞 \
	--set calendar icon.color="$MAUVE" \
	--set calendar label.color="$SKY" \
	padding_right=0 \
	label.padding_right=2 \
	update_freq=10 \
	script="$PLUGIN_DIR/calendar.sh"
