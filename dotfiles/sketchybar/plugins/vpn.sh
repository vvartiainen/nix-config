#!/bin/bash

# On while any system VPN service, such as Tailscale, is connected.

source "$CONFIG_DIR/colors.sh"

# Nerd Font md-shield_check and md-shield_off_outline.
if scutil --nc list | grep -q '(Connected)'; then
	sketchybar --set "$NAME" icon="󰕥" icon.color="$GREEN"
else
	sketchybar --set "$NAME" icon="󰦜" icon.color="$GREY"
fi
