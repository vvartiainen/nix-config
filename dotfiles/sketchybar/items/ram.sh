#!/bin/bash

source "$CONFIG_DIR/colors.sh"

sketchybar --add item ram right \
  --set ram update_freq=2 \
  icon=󰍛 \
  --set ram icon.color="$GREY" \
  --set ram label.color="$SKY" \
  script="$PLUGIN_DIR/ram.sh"
