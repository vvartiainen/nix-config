#!/bin/bash

sketchybar --add item agent_status left \
  --set agent_status drawing=off icon="!" icon.color="$YELLOW" \
  label.font="SF Pro:Semibold:12.0" label.max_chars=55 \
  script="/bin/bash \"$PLUGIN_DIR/agent_status.sh\"" update_freq=3 updates=on \
  --subscribe agent_status mouse.clicked system_woke
