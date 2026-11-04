#!/bin/bash

# Hooks publish state and trigger agent_status_update; no Kitty status queries.
exec nix-config-terminal-status sketchybar "$NAME" "$SENDER"
