#!/bin/sh
# @vicinae.schemaVersion 1
# @vicinae.title Start Time Machine Backup
# @vicinae.mode fullOutput
# @vicinae.icon 💾
# @vicinae.description Start a backup using your configured Time Machine destinations
# @vicinae.keywords ["backup", "time machine", "tmutil"]

set -eu

# Return once macOS accepts the request; a backup can take hours.
/usr/bin/tmutil startbackup --rotation
echo "Time Machine backup requested. Use Time Machine Backup Status to check progress."
