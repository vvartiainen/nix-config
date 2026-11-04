#!/bin/bash

# Shared backgrounds behind item groups. Members can be regexes in slashes.
pill=(
	background.color="$SURFACE0"
	background.corner_radius=7
	background.height=28
)

sketchybar --add bracket left_side '/space\..*/' space_separator front_app \
	--set left_side "${pill[@]}" \
	--add bracket right_side cpu ram battery volume mic vpn wifi calendar clock \
	--set right_side "${pill[@]}"

# The fixed-width values leave room after short values, so items inside the
# right pill get less padding. Its outer edges keep the default 5.
inner=(padding_left=2 padding_right=2)
sketchybar --set cpu padding_right=2 \
	--set ram "${inner[@]}" \
	--set battery "${inner[@]}" \
	--set volume "${inner[@]}" \
	--set mic "${inner[@]}" \
	--set vpn "${inner[@]}" \
	--set wifi "${inner[@]}" \
	--set calendar padding_left=2
