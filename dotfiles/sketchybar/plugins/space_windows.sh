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

	if [ "${apps}" != "" ]; then
		app_list=()
		while read -r app; do
			app_list+=("$app")
		done <<<"${apps}"
		# icon_map.sh maps each argument and prints them space-separated, with
		# a trailing space.
		icon_strip="$(icon_map.sh "${app_list[@]}")"
		icon_strip="${icon_strip% }"
	else
		icon_strip="—"
	fi

	sketchybar --set space."$space" label="$icon_strip"
fi
