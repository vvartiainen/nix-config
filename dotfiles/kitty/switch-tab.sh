#!/bin/sh
# Runs in an overlay and fuzzy-finds a tab across all OS windows to focus,
# previewing the screen of each tab's active window.
set -eu

tabs=$(kitten @ ls | jq -r --arg home "$HOME" '
  [.[].tabs[]] | to_entries[] | .key as $i | .value as $tab
  | ($tab.windows | map(select(.is_self | not))) as $wins
  | (($wins | map(select(.is_active))) + $wins)[0] as $win
  # This overlay is the active window of the current tab, so use the window below it
  | (if any($tab.windows[]; .is_self) then $win.title else $tab.title end) as $title
  | ($win.cwd | if startswith($home) then "~" + ltrimstr($home) else . end) as $cwd
  | [$tab.id, $win.id, "\(if $tab.is_focused then "*" else " " end) \($i + 1): \($title)  \u001b[2m\($cwd)\u001b[0m"]
  | @tsv
')

choice=$(printf '%s\n' "$tabs" |
  fzf --ansi --reverse --delimiter='\t' --with-nth=3 --prompt='tab> ' \
    --preview='kitten @ get-text --ansi --match id:{2}' \
    --preview-window='down,60%,follow') || exit 0

kitten @ focus-tab --match "id:$(printf %s "$choice" | cut -f1)"
