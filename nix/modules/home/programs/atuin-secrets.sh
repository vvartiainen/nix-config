# Scan Atuin and zsh history for secrets with gitleaks, and optionally delete
# the entries that contain them. Secrets are never printed.

usage() {
  cat <<'EOF'
Usage: atuin-secrets [--delete]

Scan Atuin history and ~/.zsh_history for secrets with gitleaks and list
the findings with the secret redacted.

  --delete  Delete the matching Atuin entries (synced as deletions) and
            remove the matching lines from ~/.zsh_history, after confirming.
EOF
}

delete=false
case "${1:-}" in
  "") ;;
  --delete) delete=true ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

umask 077
work=$(mktemp -d "${TMPDIR:-/tmp}/atuin-secrets.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/scan"

zsh_history="$HOME/.zsh_history"
atuin history list --cmd-only >"$work/scan/atuin"
if [ -f "$zsh_history" ]; then
  cp "$zsh_history" "$work/scan/zsh"
fi

gitleaks dir "$work/scan" --no-banner --log-level error --exit-code 0 \
  --report-format json --report-path "$work/report.json"

count=$(jq length "$work/report.json")
if [ "$count" -eq 0 ]; then
  echo "No secrets found."
  exit 0
fi

# Show each finding as source:line, rule and the match with the secret masked.
jq -r '.[] | [
    "\(.File | split("/") | last):\(.StartLine)",
    .RuleID,
    (.Secret as $secret | .Match | split($secret) | join("****") | .[0:120])
  ] | join("  ")' "$work/report.json"
echo
echo "$count finding(s)."

if [ "$delete" = false ]; then
  echo "Run 'atuin-secrets --delete' to delete them; review false positives first."
  exit 0
fi

jq -r '.[].Secret' "$work/report.json" | sort -u >"$work/secrets"

# Only delete a secret from Atuin when every command the search matches
# really contains it, since full-text search treats some characters as
# operators.
: >"$work/atuin-secrets"
atuin_entries=0
while IFS= read -r secret; do
  [ -n "$secret" ] || continue
  matched=0
  exact=true
  while IFS= read -r -d '' command; do
    matched=$((matched + 1))
    if [[ $command != *"$secret"* ]]; then
      exact=false
    fi
  done < <(atuin search --filter-mode global --search-mode fulltext \
    --include-duplicates --cmd-only --print0 -- "$secret")
  if [ "$matched" -eq 0 ]; then
    continue
  fi
  if [ "$exact" = false ]; then
    echo "Skipping a secret whose search also matches other commands;" \
      "delete it with 'atuin search -i'." >&2
    continue
  fi
  printf '%s\n' "$secret" >>"$work/atuin-secrets"
  atuin_entries=$((atuin_entries + matched))
done <"$work/secrets"

zsh_lines=0
if [ -f "$zsh_history" ]; then
  zsh_lines=$(LC_ALL=C grep -c -F -f "$work/secrets" "$zsh_history" || true)
fi

echo "This deletes $atuin_entries Atuin entries and $zsh_lines ~/.zsh_history lines."
printf 'Continue? [y/N] '
read -r answer || answer=""
case "$answer" in
  y | Y) ;;
  *)
    echo "Nothing deleted."
    exit 0
    ;;
esac

while IFS= read -r secret; do
  atuin search --filter-mode global --search-mode fulltext --delete -- "$secret"
done <"$work/atuin-secrets"

if [ "$zsh_lines" -gt 0 ]; then
  LC_ALL=C grep -v -F -f "$work/secrets" "$zsh_history" >"$work/zsh_history" || true
  # Overwrite in place to keep the file's permissions.
  cat "$work/zsh_history" >"$zsh_history"
fi

echo "Done. Restart open shells so they don't write old history back, and"
echo "run 'atuin-secrets' again to check."
