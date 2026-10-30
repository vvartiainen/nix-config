#!/bin/bash

# Shared backgrounds behind the left and right item groups. Members can be
# regexes in slashes.
pill=(
	background.color="$SURFACE0"
	background.corner_radius=7
	background.height=28
)

sketchybar --add bracket left_side '/space\..*/' space_separator front_app yabai_layout \
	--set left_side "${pill[@]}" \
	--add bracket status calendar volume mic wifi vpn battery ram cpu \
	--set status "${pill[@]}"
