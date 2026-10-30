#!/bin/bash

source "$CONFIG_DIR/colors.sh"

if [ "$SENDER" = "space_windows_change" ]; then
	space="$(echo "$INFO" | jq -r '.space')"
	# items/spaces.sh only creates spaces 1-10; others would log "Item not found".
	case "$space" in
	[1-9] | 10) ;;
	*) exit 0 ;;
	esac
	apps="$(echo "$INFO" | jq -r '.apps | keys[]')"

	icon_strip=""
	if [ "${apps}" != "" ]; then
		while read -r app; do
			icon_strip+="${icon_strip:+ }$("$CONFIG_DIR"/plugins/icon_map_fn.sh "$app")"
		done <<<"${apps}"
	else
		icon_strip="—"
	fi

	sketchybar --set space."$space" label="$icon_strip"
fi
