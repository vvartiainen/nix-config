#!/usr/bin/env bash
set -euo pipefail

duti=$1
app=$2
file_type=$3

# Launch Services may ask for consent on each change. Do not submit a setter
# when the effective default already matches, including inherited defaults.
if [[ $file_type == .* ]]; then
  if current=$("$duti" -x "${file_type#.}" 2>/dev/null); then
    # -x prints the app name, path and bundle ID on separate lines.
    if [[ ${current##*$'\n'} == "$app" ]]; then
      exit 0
    fi
  fi
elif current=$("$duti" -d "$file_type" 2>/dev/null) && [[ $current == "$app" ]]; then
  exit 0
fi

if output=$("$duti" -s "$app" "$file_type" all 2>&1); then
  if [[ -n $output ]]; then
    printf '%s\n' "$output"
  fi
else
  status=$?
  if [[ $file_type == .* && $output == "failed to set $app as handler for dyn."*" (error -50)" ]]; then
    printf 'warning: skipping %s: macOS rejected its dynamic file type; set its app manually in Finder.\n' "$file_type" >&2
  else
    printf 'Failed to set default app for %s:\n%s\n' "$file_type" "$output" >&2
    exit "$status"
  fi
fi
