#!/bin/bash

source "$CONFIG_DIR/colors.sh"

sketchybar --add item ram right \
  --set ram update_freq=2 \
  icon=":ram:" \
  icon.font="sketchybar-app-font:Regular:16.0" \
  icon.color="$GREY" \
  label.color="$SKY" \
  script="$PLUGIN_DIR/ram.sh"
