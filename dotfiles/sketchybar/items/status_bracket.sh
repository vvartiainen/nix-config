#!/bin/bash

# One shared background behind the right-side status items.
sketchybar --add bracket status calendar volume mic wifi vpn battery ram cpu \
	--set status background.color="$SURFACE0" \
	background.corner_radius=7 \
	background.height=28
