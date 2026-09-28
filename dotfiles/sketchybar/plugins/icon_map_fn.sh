#!/bin/bash

# Resolves an app name to its sketchybar-app-font glyph using the mapping the
# font embeds in its `meta` table (APPM), so icons always match the installed font.
# https://github.com/kvndrsslr/sketchybar-app-font#configure-sketchybar

font="${SKETCHYBAR_APP_FONT:-$HOME/Library/Fonts/sketchybar-app-font.ttf}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar/app_icons.json"

bytes() { od -An -tu1 -j "$1" -N "$2" "$font" | tr -s ' \n' ' '; }
u32() { bytes "$1" 4 | awk '{ print $1 * 16777216 + $2 * 65536 + $3 * 256 + $4 }'; }

read_appm() {
  local tables meta i o
  tables=$(bytes 4 2 | awk '{ print $1 * 256 + $2 }')
  for ((i = 0; i < tables; i++)); do
    o=$((12 + i * 16))
    if [ "$(tail -c +$((o + 1)) "$font" | head -c 4)" = "meta" ]; then
      meta=$(u32 $((o + 8)))
      break
    fi
  done
  [ -n "$meta" ] || return 1
  tail -c +$((meta + $(u32 $((meta + 20))) + 1)) "$font" | head -c "$(u32 $((meta + 24)))"
}

build_cache() {
  mkdir -p "$(dirname "$cache")"
  read_appm | jq -c '
		[.icons[] | .[1] |= ([.] | implode)] as $icons
		| {
			default: ($icons | map(select(.[0] == ":default:"))[0][1]),
			exact: ([$icons[] | .[1] as $g | (.[2] // [])[] | select(endswith("*") | not) | {key: ., value: $g}] | from_entries),
			prefix: [$icons[] | .[1] as $g | (.[2] // [])[] | select(endswith("*")) | [rtrimstr("*"), $g]]
		}' >"$cache.tmp" && mv "$cache.tmp" "$cache"
}

if [ ! -s "$cache" ] || [ "$font" -nt "$cache" ]; then
  build_cache || exit 1
fi

jq -r --arg app "$1" '
	.exact[$app]
	// (first(.prefix[] | select(.[0] as $p | $app | startswith($p)) | .[1]))
	// .default' "$cache"
