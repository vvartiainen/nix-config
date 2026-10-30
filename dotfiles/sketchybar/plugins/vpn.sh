#!/bin/bash

# On while any system VPN service, such as Tailscale, is connected.

source "$CONFIG_DIR/colors.sh"

if scutil --nc list | grep -q '(Connected)'; then
	sketchybar --set "$NAME" icon=":vpn:" icon.color="$GREEN"
else
	sketchybar --set "$NAME" icon=":vpnoff:" icon.color="$GREY"
fi
