#!/usr/bin/env bash
set -euo pipefail

duti=$1
app=$2
file_type=$3

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
