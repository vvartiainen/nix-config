# shellcheck shell=bash
# Run betterleaks with a throwaway HOME. Its regex engine caches compiled
# native code under ~/Library/Caches, which the sandboxes block; a per-run cache
# can't be poisoned for later runs outside the sandbox.
home=$(mktemp -d "${TMPDIR:-/tmp}/agent-betterleaks.XXXXXX")
trap 'rm -rf "$home"' EXIT
# Git scans still read the user's Git config.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HOME="$home" betterleaks "$@"
