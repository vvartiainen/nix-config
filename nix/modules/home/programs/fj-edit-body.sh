# shellcheck shell=bash
# Replace a Forgejo PR or issue body with a file's contents.
# `fj pr edit <n> body` and `fj issue edit <n> body` take the body only as an
# argument, while `fj pr create`, `fj pr comment` and `fj issue comment` have
# --body-file. Extra arguments go to the body subcommand, e.g. `-R origin`.
usage() {
  echo "usage: fj-edit-body pr|issue <number> <file> [fj option...]" >&2
  exit 2
}

[[ $# -ge 3 ]] || usage
kind=$1 number=$2 file=$3
shift 3
[[ $kind == pr || $kind == issue ]] || usage
[[ $number =~ ^[0-9]+$ ]] || usage
if [[ ! -f $file || ! -s $file ]]; then
  echo "fj-edit-body: $file is not a non-empty regular file" >&2
  exit 1
fi

# `--` keeps a body that starts with `-` from being parsed as an option.
exec fj "$kind" edit "$number" body "$@" -- "$(<"$file")"
