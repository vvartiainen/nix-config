#!/bin/bash

sketchybar --add item volume right \
	--set volume script="$PLUGIN_DIR/volume.sh" \
	--set volume icon.color="$PEACH" \
	--set volume label.color="$SKY" \
	--subscribe volume volume_change
