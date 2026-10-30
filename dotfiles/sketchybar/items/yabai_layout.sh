#!/bin/bash

# skhd triggers yabai_layout_change after changing the layout.
sketchybar --add event yabai_layout_change \
	--add item yabai_layout left \
	--set yabai_layout icon.drawing=off \
	label.color="$SKY" \
	label.padding_left=8 \
	label.padding_right=8 \
	script="$PLUGIN_DIR/yabai_layout.sh" \
	--subscribe yabai_layout space_change display_change yabai_layout_change mouse.clicked
