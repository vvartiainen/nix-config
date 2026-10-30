#!/bin/bash

# Online means there's a default route, over Wi-Fi or Ethernet.

source "$CONFIG_DIR/colors.sh"

if route -n get default 2>/dev/null | grep -q 'interface:'; then
	sketchybar --set "$NAME" icon=":wifi:" icon.color="$GREEN"
else
	sketchybar --set "$NAME" icon=":wifi_off:" icon.color="$RED"
fi
