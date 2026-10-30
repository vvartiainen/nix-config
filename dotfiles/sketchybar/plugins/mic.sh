#!/bin/bash

# Muted means input volume 0. Clicking mutes, or restores the level saved at
# the last mute.

source "$CONFIG_DIR/colors.sh"

saved="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar/mic_volume"
VOLUME=$(osascript -e 'input volume of (get volume settings)')

# "missing value" when there's no input device.
case "$VOLUME" in
'' | *[!0-9]*)
	sketchybar --set "$NAME" drawing=off
	exit 0
	;;
esac

if [ "$SENDER" = "mouse.clicked" ]; then
	if [ "$VOLUME" -gt 0 ]; then
		mkdir -p "$(dirname "$saved")"
		echo "$VOLUME" >"$saved"
		VOLUME=0
	else
		VOLUME=$(cat "$saved" 2>/dev/null)
		VOLUME=${VOLUME:-75}
	fi
	osascript -e "set volume input volume $VOLUME"
fi

if [ "$VOLUME" -gt 0 ]; then
	sketchybar --set "$NAME" drawing=on icon=":mic_on:" icon.color="$TEXT"
else
	sketchybar --set "$NAME" drawing=on icon=":mic_off:" icon.color="$RED"
fi
