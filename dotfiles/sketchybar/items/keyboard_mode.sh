#!/bin/bash

sketchybar --add event skhd_mode \
  --add item keyboard_mode left \
  --set keyboard_mode drawing=off icon.drawing=off \
  background.color="$SURFACE1" label.font="SF Pro:Semibold:12.0" \
  label.padding_left=8 label.padding_right=8 \
  popup.background.color="$BASE" popup.background.border_color="$SURFACE2" \
  popup.background.border_width=1 popup.background.corner_radius=7 \
  popup.height=26 popup.y_offset=6 \
  script="/bin/bash \"$HOME/.config/skhd/mode-indicator.sh\"" \
  update_freq=2 updates=on \
  --subscribe keyboard_mode skhd_mode system_woke front_app_switched \
  --add item keyboard_mode.keys popup.keyboard_mode \
  --set keyboard_mode.keys icon.drawing=off label.font="SF Pro:Medium:12.0" \
  --add item keyboard_mode.resize popup.keyboard_mode \
  --set keyboard_mode.resize icon.drawing=off label.font="SF Pro:Regular:12.0" \
  --add item keyboard_mode.actions popup.keyboard_mode \
  --set keyboard_mode.actions icon.drawing=off label.font="SF Pro:Regular:12.0" \
  --add item keyboard_mode.navigation popup.keyboard_mode \
  --set keyboard_mode.navigation icon.drawing=off label.font="SF Pro:Regular:12.0" \
  label.color="$SUBTEXT0"
