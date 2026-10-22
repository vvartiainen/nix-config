flake_ref := "path:."
system_profile := "/nix/var/nix/profiles/system"
# Flake config name. `$HOST` when exported, otherwise this machine's hostname.
default_host := `hostname`
host := env("HOST", default_host)

# Create local host overrides if missing.
generate-local-config host=host:
    if [ ! -f local-config.nix ]; then printf '{\n  userName = "%s";\n  hostName = "%s";\n  repoRoot = "%s";\n}\n' "$USER" '{{ host }}' '{{ justfile_directory() }}' > local-config.nix; fi

# Write hardware.local.nix; pure flake eval cannot probe the chip.
# Nested virtualization needs M3+ and macOS 15+.
detect-hardware:
    @if ! brand="$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"; then if [ -f hardware.local.nix ]; then echo "sysctl unavailable (sandbox?); keeping hardware.local.nix" >&2; exit 0; fi; echo "sysctl unavailable; cannot write hardware.local.nix" >&2; exit 1; fi; gen="$(printf '%s\n' "$brand" | sed -nE 's/^Apple M([0-9]+).*/\1/p')"; os="$(sw_vers -productVersion | cut -d. -f1)"; nested=false; if [ "${gen:-0}" -ge 3 ] && [ "$os" -ge 15 ]; then nested=true; fi; printf '{ nestedVirtualization = %s; }\n' "$nested" > hardware.local.nix

# Bootstrap nix-darwin from this flake.
bootstrap host=host: detect-hardware
    just generate-local-config '{{ host }}'
    sudo nix run nix-darwin -- switch --flake '{{ flake_ref }}#{{ host }}'

# Show flake outputs.
show:
    nix flake show

# Run flake checks and lint nix files.
check: detect-hardware
    statix check .
    nix flake check

# Evaluate the darwin system derivation.
eval-system host=host: detect-hardware
    nix eval '{{ flake_ref }}#darwinConfigurations.{{ host }}.system'

# Build the darwin system derivation.
build-system host=host: detect-hardware
    nix build '{{ flake_ref }}#darwinConfigurations.{{ host }}.system'

# Build the nix-darwin activation package without applying it.
build host=host: detect-hardware
    darwin-rebuild build --flake '{{ flake_ref }}#{{ host }}'

# Apply the nix-darwin configuration.
# SKIP_HOMEBREW=1 skips brew bundle during activation.
switch host=host: detect-hardware
    printf '%s\n' "${SKIP_HOMEBREW:-0}" | sudo tee /tmp/nix-darwin-skip-homebrew >/dev/null
    sudo darwin-rebuild switch --flake '{{ flake_ref }}#{{ host }}'

# Roll back to the previous nix-darwin generation.
rollback:
    sudo darwin-rebuild switch --rollback

# Show nix-darwin generations.
generations:
    sudo darwin-rebuild --list-generations

# Roll back to a specific nix-darwin generation.
rollback-to generation:
    sudo darwin-rebuild switch --switch-generation '{{ generation }}'

# Update all flake inputs.
up:
    nix flake update

# Update a specific flake input.
upp input:
    nix flake update '{{ input }}'

# Show system profile history.
history:
    nix profile history --profile '{{ system_profile }}'

# Remove generations older than 7 days.
clean:
    sudo nix-collect-garbage --delete-older-than 7d
    nix-collect-garbage --delete-older-than 7d

# Garbage collect unused store paths.
gc:
    sudo nix-collect-garbage
    nix-collect-garbage
