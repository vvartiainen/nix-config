flake_ref := "."
system_profile := "/nix/var/nix/profiles/system"
# Flake config name. `$HOST` when exported, otherwise this machine's hostname.
default_host := `hostname`
host := env("HOST", default_host)
# Per-machine host data, kept outside the repo (see README).
host_dir := home_directory() / ".config/nix-config-host"
host_flags := "--override-input host 'path:" + host_dir + "'"

# Stop early without host data; migrates the old local files once.
[private]
require-host:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -e '{{ host_dir }}/default.nix' ]; then
      exit 0
    fi
    # TODO(TASK-61): remove once both machines have migrated.
    if [ -e local-config.nix ]; then
      exec '{{ just_executable() }}' init-host
    fi
    echo "No host data at {{ host_dir }}/default.nix; run \`just init-host\` (see README)." >&2
    exit 1

# Create the host data file if missing.
init-host host=host:
    #!/usr/bin/env bash
    set -euo pipefail
    dir='{{ host_dir }}'
    file="$dir/default.nix"
    if [ -e "$file" ]; then
      echo "$file already exists" >&2
      exit 0
    fi
    user=$USER
    hostName='{{ host }}'
    repoRoot='{{ justfile_directory() }}'
    nested=
    homeModules=' '
    # TODO(TASK-61): migration from the pre-host-input local files. Remove
    # once both machines have migrated.
    legacy() {
      nix eval --raw --impure --expr "(import ./$1).$2 or \"$3\""
    }
    if [ -e local-config.nix ]; then
      user=$(legacy local-config.nix userName "$user")
      hostName=$(legacy local-config.nix hostName "$hostName")
      repoRoot=$(legacy local-config.nix repoRoot "$repoRoot")
      echo "Migrating local-config.nix" >&2
    fi
    if [ -e hardware.local.nix ]; then
      nested=$(nix eval --impure --expr '(import ./hardware.local.nix).nestedVirtualization')
    fi
    zenLocal=nix/modules/home/programs/zen-browser.local.nix
    if [ -e "$zenLocal" ]; then
      mkdir -p "$dir"
      cp "$zenLocal" "$dir/zen-browser.local.nix"
      homeModules=' ./zen-browser.local.nix '
      echo "Copied $zenLocal to $dir" >&2
    fi
    if [ -z "$nested" ]; then
      # Nested virtualization needs M3+ and macOS 15+.
      nested=false
      gen=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | sed -nE 's/^Apple M([0-9]+).*/\1/p' || true)
      os=$(sw_vers -productVersion | cut -d. -f1)
      if [ "${gen:-0}" -ge 3 ] && [ "$os" -ge 15 ]; then
        nested=true
      fi
    fi
    mkdir -p "$dir"
    cat > "$file" <<EOF
    {
      userName = "$user";
      hostName = "$hostName";
      repoRoot = "$repoRoot";
      nestedVirtualization = $nested;
      # Private modules that stay out of the repo.
      darwinModules = [ ];
      homeModules = [$homeModules];
    }
    EOF
    echo "Wrote $file" >&2

# Bootstrap nix-darwin from this flake.
bootstrap host=host: (init-host host)
    sudo nix run nix-darwin -- switch --flake '{{ flake_ref }}#{{ host }}' {{ host_flags }}

# Show flake outputs.
show: require-host
    nix flake show {{ host_flags }}

# Run flake checks and lint nix files.
check: require-host
    statix check .
    nix flake check {{ host_flags }}

# Evaluate the darwin system derivation.
eval-system host=host: require-host
    nix eval '{{ flake_ref }}#darwinConfigurations.{{ host }}.system' {{ host_flags }}

# Build the darwin system derivation.
build-system host=host: require-host
    nix build '{{ flake_ref }}#darwinConfigurations.{{ host }}.system' {{ host_flags }}

# Build the nix-darwin activation package without applying it.
build host=host: require-host
    darwin-rebuild build --flake '{{ flake_ref }}#{{ host }}' {{ host_flags }}

# Apply the nix-darwin configuration.
# SKIP_HOMEBREW=1 skips brew bundle during activation.
switch host=host: require-host
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
