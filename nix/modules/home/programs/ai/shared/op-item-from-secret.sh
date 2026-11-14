# shellcheck shell=bash
# Store a T3 request_secret file as a new 1Password item, then delete the file.
# The value goes to `op` through a JSON template on stdin, never through argv
# or output, and only files under T3's secret directory are accepted.
usage() {
  echo "usage: op-item-from-secret --vault <vault> --title <title> [--category <category>] [--field <field>] <file>" >&2
  exit 2
}

vault="" title="" category="API Credential" field="credential" file=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --vault | --title | --category | --field)
      [[ $# -ge 2 && -n $2 ]] || usage
      declare "${1#--}=$2"
      shift 2
      ;;
    -*) usage ;;
    *)
      [[ -z $file ]] || usage
      file=$1
      shift
      ;;
  esac
done
[[ -n $vault && -n $title && -n $file ]] || usage

secrets=$(realpath "$HOME/.t3/userdata/secrets")
path=$(realpath "$file")
if [[ $path != "$secrets"/* || ! -f $path || -L $file || ! -s $path ]]; then
  echo "op-item-from-secret: expected a non-empty file under $secrets" >&2
  exit 1
fi

# Fill the category's field with this id, or add it as a concealed field.
# One trailing newline from the secret file is dropped.
op item template get "$category" \
  | jq --rawfile secret "$path" --arg field "$field" '
      ($secret | rtrimstr("\n")) as $value
      | if any(.fields[]?; .id == $field)
        then .fields |= map(if .id == $field then .value = $value else . end)
        else .fields += [{id: $field, label: $field, type: "CONCEALED", value: $value}]
        end' \
  | op item create --vault "$vault" --title "$title" --format json - \
  | jq '{id, title, vault: .vault.name}'

rm -f -- "$path"
