#!/bin/bash

sketchybar --add event agent_status_update

for item in agent_status.running agent_status; do
  icon="▶"
  color="$GREEN"
  if [[ $item == agent_status ]]; then
    icon="!"
    color="$YELLOW"
  fi
  sketchybar --add item "$item" left \
    --set "$item" drawing=off icon="$icon" icon.color="$color" \
    label.font="SF Pro:Semibold:12.0" icon.padding_right=3 \
    popup.background.color="$BASE" popup.background.border_color="$SURFACE2" \
    popup.background.border_width=1 popup.background.corner_radius=7 \
    popup.height=26 popup.y_offset=6 \
    script="/bin/bash \"$PLUGIN_DIR/agent_status.sh\"" update_freq=30 updates=on \
    --subscribe "$item" agent_status_update mouse.clicked mouse.exited.global system_woke
done
