#!/bin/bash

# Shows the focused space's yabai layout. Clicking cycles bsp -> stack -> float.

layout() { yabai -m query --spaces --space 2>/dev/null | jq -r '.type // empty'; }

if [ "$SENDER" = "mouse.clicked" ]; then
	case "$(layout)" in
	bsp) next=stack ;;
	stack) next=float ;;
	*) next=bsp ;;
	esac
	yabai -m space --layout "$next"
fi

LAYOUT="$(layout)"
if [ -z "$LAYOUT" ]; then
	sketchybar --set "$NAME" drawing=off
	exit 0
fi

sketchybar --set "$NAME" drawing=on label="$LAYOUT"
