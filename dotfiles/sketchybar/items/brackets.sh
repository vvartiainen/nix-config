#!/bin/bash

# Shared backgrounds behind item groups. Members can be regexes in slashes.
pill=(
	background.color="$SURFACE0"
	background.corner_radius=7
	background.height=28
)

sketchybar --add bracket left_side '/space\..*/' space_separator front_app \
	--set left_side "${pill[@]}" \
	--add bracket system cpu ram battery volume \
	--set system "${pill[@]}" \
	--add bracket status vpn wifi mic yabai_layout \
	--set status "${pill[@]}" \
	--add bracket clock calendar \
	--set clock "${pill[@]}"
