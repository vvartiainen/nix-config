#!/bin/sh
# Detached from Kitty: wait for shutdown before creating the replacement.
set -eu
old_pid=$1
kitty=$2
snapshot=$3
shift 3

attempts=0
while kill -0 "$old_pid" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 300 ]; then
        echo 'Kitty did not exit within 30 seconds; restart cancelled.' >&2
        exit 1
    fi
    sleep 0.1
done

exec "$kitty" --detach "$@" --session "$snapshot"
