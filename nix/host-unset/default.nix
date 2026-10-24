# Placeholder for the `host` flake input. Each machine keeps its real host
# data outside this repo and passes it in; the justfile does this for you:
#
#   --override-input host path:$HOME/.config/nix-config-host
#
# Run `just init-host` to create that file. See README.md.
throw "No host data. Build through the justfile, or pass --override-input host path:<dir> (see README.md)."
