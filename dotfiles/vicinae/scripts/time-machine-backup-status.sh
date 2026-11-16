#!/bin/sh
# @vicinae.schemaVersion 1
# @vicinae.title Time Machine Backup Status
# @vicinae.mode fullOutput
# @vicinae.icon 💾
# @vicinae.description Show the current Time Machine backup activity
# @vicinae.keywords ["backup", "time machine", "tmutil", "progress"]

exec /usr/bin/tmutil status
