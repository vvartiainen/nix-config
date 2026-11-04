#!/bin/bash

# Read live Kitty records rather than maintaining another session registry.
# Each Kitty instance appends its PID to the configured socket name.
records=$(
  for socket in /tmp/kitty-*; do
    [ -S "$socket" ] || continue
    /opt/homebrew/bin/kitten @ --to "unix:$socket" ls 2>/dev/null |
      jq -c --arg socket "$socket" '
        .[] | .tabs[] | .windows[] | . as $window |
        .program_status[]? | select(.state == "blocked") |
        {socket: $socket, id: $window.id, app: .app, kind: .kind,
         cwd: ($window.cwd | split("/") | last)}'
  done | jq -s '.'
)

count=$(jq 'length' <<<"$records")
if [ "$count" -eq 0 ]; then
  sketchybar --set "$NAME" drawing=off
  exit
fi

if [ "$SENDER" = mouse.clicked ]; then
  socket=$(jq -r '.[0].socket' <<<"$records")
  window=$(jq -r '.[0].id' <<<"$records")
  /opt/homebrew/bin/kitten @ --to "unix:$socket" focus-window --match "id:$window"
else
  label=$(jq -r '.[0] | "\(.app): \(if .kind == "permission" then "approval" elif .kind == "question" then "answer" else "input" end) · \(.cwd)"' <<<"$records")
  [ "$count" -le 1 ] || label="$label (+$((count - 1)))"
  sketchybar --set "$NAME" drawing=on label="$label"
fi
