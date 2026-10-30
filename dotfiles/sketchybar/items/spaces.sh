#!/bin/bash

SPACE_SIDS=(1 2 3 4 5 6 7 8 9 10)

source "$CONFIG_DIR/colors.sh"

for sid in "${SPACE_SIDS[@]}"; do
  sketchybar --add space space."$sid" left \
    --set space."$sid" space="$sid" \
    padding_left=5 \
    padding_right=1 \
    icon="$sid" \
    icon.color="$SKY" \
    icon.padding_left=8 \
    label.font="sketchybar-app-font:Regular:16.0" \
    label.color="$MAUVE" \
    label.padding_right=12 \
    background.color="$MANTLE" \
    label.y_offset=-1 \
    script="$PLUGIN_DIR/space.sh"
done

# Highlight boxes sit 2pt inside the pill on every side: pill radius 7 - 2 = box radius 5.
sketchybar --set space.1 padding_left=2

sketchybar --add item space_separator left \
  --set space_separator icon="􀆊" \
  --set space_separator icon.color="$GREEN" \
  icon.padding_left=4 \
  label.drawing=off \
  background.drawing=off \
  script="$PLUGIN_DIR/space_windows.sh" \
  --subscribe space_separator space_windows_change
