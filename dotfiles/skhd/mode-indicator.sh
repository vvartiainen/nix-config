#!/bin/bash

# Called with a mode by skhd, or without arguments to render SketchyBar.
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/skhd"
state_file="$state_dir/mode"
pid_file="/tmp/skhd_${USER}.pid"
daemon_pid=
if [ -r "$pid_file" ]; then
  read -r daemon_pid < "$pid_file"
fi

if [ "$#" -gt 0 ]; then
  case "$1" in
    default) rm -f "$state_file" ;;
    window|resize|herdr|kitty|zen|rex)
      # skhd writes its PID before loading the configuration.
      case "$daemon_pid" in
        ''|*[!0-9]*) exit 0 ;;
      esac
      mkdir -p "$state_dir"
      temporary=$(mktemp "$state_dir/.mode.XXXXXX") || exit 1
      printf '%s %s\n' "$1" "$daemon_pid" > "$temporary"
      mv -f "$temporary" "$state_file"
      ;;
    *) exit 1 ;;
  esac
  sketchybar --trigger skhd_mode >/dev/null 2>&1 || true
  exit 0
fi

mode=default
owner=
if [ -r "$state_file" ]; then
  read -r mode owner < "$state_file"
fi
case "$owner" in
  ''|*[!0-9]*) mode=default ;;
  *)
    if [ "$owner" != "$daemon_pid" ] || ! kill -0 "$owner" 2>/dev/null; then
      mode=default
    fi
    ;;
esac

# App-specific capture follows its app. Events provide the app immediately;
# polling also recovers if the bar restarted or missed an app-switch event.
if [ "$mode" = herdr ] || [ "$mode" = kitty ] || [ "$mode" = zen ] || [ "$mode" = rex ]; then
  if [ "${SENDER:-}" = front_app_switched ]; then
    front_app="${INFO:-}"
  else
    front_app=$(lsappinfo info "$(lsappinfo front)" 2>/dev/null | sed -n '1s/^"\(.*\)" ASN:.*/\1/p')
  fi
  in_app=
  case "$mode:$front_app" in
    *:|herdr:kitty|herdr:Kitty|kitty:kitty|kitty:Kitty|zen:zen|zen:Zen|zen:'Zen Browser'|zen:'Zen Browser (Beta)'|rex:Rex|rex:'Rex Beta') in_app=1 ;;
  esac
  # Herdr prefixes the Kitty title with "herdr · " (window_title in
  # herdr.nix), including remote sessions. An unknown title keeps the mode.
  if [ -n "$in_app" ] && [ "$mode" = herdr ]; then
    title=$(/opt/yabai/bin/yabai -m query --windows --window 2>/dev/null | jq -r '.title // empty')
    case "$title" in
      ''|'herdr · '*) ;;
      *) in_app= ;;
    esac
  fi
  # A reload returns skhd to default; its native callback clears the state.
  if [ -z "$in_app" ] && /opt/skhd/bin/skhd --reload >/dev/null 2>&1; then
    mode=default
  fi
fi

# shellcheck source=dotfiles/sketchybar/colors.sh
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"
case "$mode" in
  window)
    title=WINDOW
    color="$BLUE"
    keys="H J K L  focus    Shift+H J K L  warp"
    resize_keys="Cmd+HJKL resize 100    Cmd+Shift+HJKL fine 25"
    actions="B balance    Shift+B BSP    S stack    F zoom    1-6 move + follow"
    extra_rows=on
    navigation="R resize mode    Esc / Return exit"
    ;;
  resize)
    title=RESIZE
    color="$PEACH"
    keys="H J K L  resize"
    resize_keys=
    actions=
    extra_rows=off
    navigation="W window mode    Esc / Return exit"
    ;;
  herdr)
    title=HERDR
    color="$TEAL"
    keys="H / L tabs    J / K agents    Ctrl+HJKL swap pane"
    resize_keys="Shift+J / K workspaces    1-9 agents    Shift+1-9 tabs"
    actions="T tab    W workspace    V / Shift+V split    Ctrl+ closes    G Go To    S workspaces"
    extra_rows=on
    navigation="Esc / Return exit    Right Cmd+Option+Space toggle"
    ;;
  kitty)
    title=KITTY
    color="$GREEN"
    keys="H / L tabs    J / K windows    1-9 tabs    Ctrl+HJKL swap window"
    resize_keys="Shift+H / L move tab    Shift+J / K move window"
    actions="N window    T tab    Ctrl+ closes    O next layout    Z stack    F tab switcher"
    extra_rows=on
    navigation="Esc / Return exit    Right Cmd+Option+Space toggle"
    ;;
  rex)
    title=REX
    color="$PEACH"
    keys="H / L tabs    J / K panes    Ctrl+HJKL focus    1-9 tabs"
    resize_keys="T tab    V / Shift+V split    Z zoom    B balance"
    actions="Ctrl+T close tab    Ctrl+V close pane    F palette    S sessions"
    extra_rows=on
    navigation="Esc / Return exit    Right Cmd+Option+Space toggle"
    ;;
  zen)
    title=ZEN
    color="$MAUVE"
    keys="H / L workspaces    J / K vertical tabs"
    resize_keys="N new tab    O address bar    F find"
    actions="New tabs and search exit mode for typing"
    extra_rows=on
    navigation="Esc / Return exit    Right Cmd+Option+Space toggle"
    ;;
  *)
    sketchybar --set keyboard_mode drawing=off popup.drawing=off
    exit 0
    ;;
esac

sketchybar --set keyboard_mode drawing=on label="$title" label.color="$color" \
  popup.drawing=on \
  --set keyboard_mode.keys label="$keys" \
  --set keyboard_mode.resize drawing="$extra_rows" label="$resize_keys" \
  --set keyboard_mode.actions drawing="$extra_rows" label="$actions" \
  --set keyboard_mode.navigation label="$navigation"
