# shellcheck shell=bash
# Answer git credential requests from the Forgejo token file the sandbox can
# read. `fj` keeps its token in that 0600 JSON file, so a restricted token gives
# sandboxes pushes and forge calls without an SSH key, SSH agent or keychain.
#
# `FORGE_KEYSTORE` names the file; the packaged wrapper sets it.
set -eu

keystore=${FORGE_KEYSTORE:-}
operation=${1:-get}
# Only answer lookups. Storing or erasing would rewrite the user's token file
# from a sandboxed process, so both do nothing.
case $operation in
  get) ;;
  store | erase) exit 0 ;;
  *)
    echo "usage: git-credential-forgejo get|store|erase" >&2
    exit 2
    ;;
esac
[ -n "$keystore" ] && [ -f "$keystore" ] || exit 0
host=$(awk '/^host=/ { sub(/^host=/, ""); print; exit }')
[ -n "$host" ] || exit 0
token=$(jq -r --arg host "$host" '.hosts[$host].token // empty' "$keystore" 2>/dev/null) || exit 0
[ -n "$token" ] || exit 0
# Forgejo accepts any user name with an application token.
printf 'username=forge-token\npassword=%s\n' "$token"
