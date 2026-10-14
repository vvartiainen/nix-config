input=$(cat)

IFS=$'\x1f' read -r model effort dir ctx five five_reset week week_reset cost added removed <<<"$(
  jq -r '
    def int: if . == null then "" else floor end;
    [
      .model.display_name // "",
      .effort.level // "",
      .workspace.current_dir // .cwd // "",
      (.context_window.used_percentage // 0 | int),
      (.rate_limits.five_hour.used_percentage | int),
      (.rate_limits.five_hour.resets_at | int),
      (.rate_limits.seven_day.used_percentage | int),
      (.rate_limits.seven_day.resets_at | int),
      .cost.total_cost_usd // 0,
      .cost.total_lines_added // 0,
      .cost.total_lines_removed // 0
    ] | map(tostring) | join("\u001f")
  ' <<<"$input"
)"

# Catppuccin Mocha
reset=$'\033[0m'
mauve=$'\033[38;2;203;166;247m'
blue=$'\033[38;2;137;180;250m'
teal=$'\033[38;2;148;226;213m'
green=$'\033[38;2;166;227;161m'
yellow=$'\033[38;2;249;226;175m'
peach=$'\033[38;2;250;179;135m'
red=$'\033[38;2;243;139;168m'
subtext=$'\033[38;2;166;173;200m'
overlay=$'\033[38;2;108;112;134m'
surface=$'\033[38;2;69;71;90m'
sep=" ${overlay}│${reset} "

level() {
  if (($1 >= 80)); then
    printf '%s' "$red"
  elif (($1 >= 50)); then
    printf '%s' "$yellow"
  else
    printf '%s' "$green"
  fi
}

meter() {
  local label=$1 pct=$2 width=8 filled i out
  filled=$(((pct * width + 50) / 100))
  out="${subtext}${label}${reset} $(level "$pct")"
  for ((i = 0; i < width; i++)); do
    if ((i == filled)); then
      out+="$surface"
    fi
    out+="━"
  done
  printf '%s %s%s%%%s' "$out" "$(level "$pct")" "$pct" "$reset"
}

line1="${mauve}${model}${reset}"
if [[ -n $effort ]]; then
  line1+=" ${overlay}${effort}${reset}"
fi
line1+="${sep}${blue}${dir/#"$HOME"/\~}${reset}"
if branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null) && [[ -n $branch ]]; then
  line1+=" ${teal} ${branch}${reset}"
fi
if ((added || removed)); then
  line1+="${sep}${green}+${added}${reset} ${red}-${removed}${reset}"
fi

line2=$(meter ctx "$ctx")
if [[ -n $five ]]; then
  line2+="${sep}$(meter 5h "$five")"
  if [[ -n $five_reset ]]; then
    line2+=" ${overlay}↻ $(date -d "@$five_reset" +%H:%M)${reset}"
  fi
fi
if [[ -n $week ]]; then
  line2+="${sep}$(meter 7d "$week")"
  if [[ -n $week_reset ]]; then
    line2+=" ${overlay}↻ $(date -d "@$week_reset" '+%a %H:%M')${reset}"
  fi
fi
printf -v cost_fmt '$%.2f' "$cost"
line2+="${sep}${peach}${cost_fmt}${reset}"

printf '%s\n%s\n' "$line1" "$line2"
