#!/bin/bash

source "$CONFIG_DIR/colors.sh"

sketchybar --add item ram right \
  --set ram update_freq=5 \
  icon=":ram:" \
  icon.font="sketchybar-app-font:Regular:16.0" \
  icon.color="$GREY" \
  label.color="$SKY" \
  label.width=43 \
  script="$PLUGIN_DIR/ram.sh"
