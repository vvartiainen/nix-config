#!/bin/bash

sketchybar --add event agent_status_update \
  --add item agent_status left \
  --set agent_status drawing=off icon="!" icon.color="$YELLOW" \
  label.font="SF Pro:Semibold:12.0" label.max_chars=55 \
  script="/bin/bash \"$PLUGIN_DIR/agent_status.sh\"" update_freq=30 updates=on \
  --subscribe agent_status agent_status_update mouse.clicked system_woke
