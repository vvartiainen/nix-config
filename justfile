flake_ref := "."
system_profile := "/nix/var/nix/profiles/system"
# Flake config name. `$HOST` when exported, otherwise this machine's hostname.
default_host := `hostname`
host := env("HOST", default_host)
# Per-machine host data, kept outside the repo (see README).
host_dir := home_directory() / ".config/nix-config-host"
host_flags := "--override-input host 'path:" + host_dir + "'"

# Create the host data file if missing.
init-host host=host:
    #!/usr/bin/env bash
    set -euo pipefail
    file='{{ host_dir }}/default.nix'
    if [ -e "$file" ]; then
      echo "$file already exists" >&2
      exit 0
    fi
    # Nested virtualization needs M3+ and macOS 15+.
    nested=false
    gen=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | sed -nE 's/^Apple M([0-9]+).*/\1/p' || true)
    os=$(sw_vers -productVersion | cut -d. -f1)
    if [ "${gen:-0}" -ge 3 ] && [ "$os" -ge 15 ]; then
      nested=true
    fi
    mkdir -p "$(dirname "$file")"
    cat > "$file" <<EOF
    {
      userName = "$USER";
      hostName = "{{ host }}";
      repoRoot = "{{ justfile_directory() }}";
      nestedVirtualization = $nested;
      # Private modules that stay out of the repo.
      darwinModules = [ ];
      homeModules = [ ];
    }
    EOF
    echo "Wrote $file"

# Bootstrap nix-darwin from this flake.
bootstrap host=host: (init-host host)
    sudo nix run nix-darwin -- switch --flake '{{ flake_ref }}#{{ host }}' {{ host_flags }}

# Show flake outputs.
show:
    nix flake show {{ host_flags }}

# Run flake checks and lint nix files.
check:
    statix check .
    nix flake check {{ host_flags }}

# Evaluate the darwin system derivation.
eval-system host=host:
    nix eval '{{ flake_ref }}#darwinConfigurations.{{ host }}.system' {{ host_flags }}

# Build the darwin system derivation.
build-system host=host:
    nix build '{{ flake_ref }}#darwinConfigurations.{{ host }}.system' {{ host_flags }}

# Build the nix-darwin activation package without applying it.
build host=host:
    darwin-rebuild build --flake '{{ flake_ref }}#{{ host }}' {{ host_flags }}

# Apply the nix-darwin configuration.
# SKIP_HOMEBREW=1 skips brew bundle during activation.
switch host=host:
    printf '%s\n' "${SKIP_HOMEBREW:-0}" | sudo tee /tmp/nix-darwin-skip-homebrew >/dev/null
    sudo darwin-rebuild switch --flake '{{ flake_ref }}#{{ host }}' {{ host_flags }}

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
