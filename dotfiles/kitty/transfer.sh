#!/bin/sh
# Runs locally in an overlay and types a `kitten transfer` command into the
# kitten ssh session of window $1, so nothing needs to be installed remotely.
# Downloads are staged in /tmp/kcp so they can be uploaded to another host.
set -eu

wid=${1:?usage: transfer.sh <kitty-window-id>}
stage=/tmp/kcp
mkdir -p "$stage"

quote() { printf "'%s'" "$(printf %s "$1" | sed "s/'/'\\\\''/g")"; }

send() { printf '%s\r' "$1" | kitten @ send-text --match "id:$wid" --stdin; }

direction=$(printf 'download  remote -> %s\nupload    local -> remote\n' "$stage" |
  fzf --reverse --height=~10 --prompt='transfer> ') || exit 0

case $direction in
download*)
  printf 'Remote path(s), globs allowed, relative to remote cwd:\n> '
  read -r paths
  [ -n "$paths" ] || exit 0
  send "kitten transfer -- $paths $(quote "$stage/")"
  ;;
upload*)
  files=$({
    find "$stage" -mindepth 1 -maxdepth 1
    fd --hidden --max-depth 4 . "$HOME"
  } | fzf --multi --reverse --prompt='upload (tab to multi-select)> ') || exit 0
  printf 'Remote destination [/tmp/]: '
  read -r dest
  args=""
  while IFS= read -r f; do
    args="$args $(quote "$f")"
  done <<EOF
$files
EOF
  send "kitten transfer --direction=upload --$args ${dest:-/tmp/}"
  ;;
esac
