#!/bin/sh
# @vicinae.schemaVersion 1
# @vicinae.title Eject All Disks
# @vicinae.mode fullOutput
# @vicinae.description Eject Finder's ejectable disks without forcing busy volumes
# @vicinae.keywords ["unmount", "usb", "external drives"]

exec /usr/bin/osascript <<'APPLESCRIPT'
tell application "Finder"
    set targets to every disk whose ejectable is true
    if (count targets) is 0 then return "No ejectable disks mounted."
    eject targets
end tell
return "Eject requests completed. Check Finder before disconnecting drives."
APPLESCRIPT
