#!/bin/bash

# Shown while any system VPN service, such as Tailscale, is connected.

if scutil --nc list | grep -q '(Connected)'; then
	sketchybar --set "$NAME" drawing=on
else
	sketchybar --set "$NAME" drawing=off
fi
