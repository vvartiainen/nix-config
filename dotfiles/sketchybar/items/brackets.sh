#!/bin/bash

# Shared backgrounds behind item groups. Members can be regexes in slashes.
pill=(
	background.color="$SURFACE0"
	background.corner_radius=7
	background.height=28
)

sketchybar --add bracket left_side '/space\..*/' space_separator front_app \
	--set left_side "${pill[@]}" \
	--add bracket status vpn mic \
	--set status "${pill[@]}" \
	--add bracket system cpu ram battery volume wifi calendar clock \
	--set system "${pill[@]}"

# The fixed-width values leave room after short values, so items inside the
# system pill get less padding. Its outer edges keep the default 5.
inner=(padding_left=2 padding_right=2)
sketchybar --set cpu padding_right=2 \
	--set ram "${inner[@]}" \
	--set battery "${inner[@]}" \
	--set volume "${inner[@]}" \
	--set wifi "${inner[@]}" \
	--set calendar padding_left=2
