#!/bin/bash

source "$CONFIG_DIR/colors.sh"

BATT=$(pmset -g batt)
PERCENTAGE=$(echo "$BATT" | grep -Eo "[0-9]+%" | cut -d% -f1)

if [ "$PERCENTAGE" = "" ]; then
	exit 0
fi

COLOR="$GREEN"
case ${PERCENTAGE} in
9[0-9] | 100)
	ICON="􀛨"
	;;
[6-8][0-9])
	ICON="􀺸"
	;;
[3-5][0-9])
	ICON="􀺶"
	;;
[1-2][0-9])
	ICON="􀛩"
	COLOR="$YELLOW"
	;;
*)
	ICON="􀛪"
	COLOR="$RED"
	;;
esac

if [[ $BATT == *"AC Power"* ]]; then
	ICON="􀢋"
	COLOR="$GREEN"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="${PERCENTAGE}%"
