#!/bin/bash

sketchybar --add item media right \
	--set media label.color="$PEACH" \
	label.max_chars=16 \
	icon.padding_left=0 \
	scroll_texts=on \
	icon=􀑪 \
	icon.color="$PEACH" \
	background.drawing=off \
	script="$PLUGIN_DIR/media.sh" \
	--subscribe media media_change
