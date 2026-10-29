# Flake config name. `$HOST` when exported, otherwise this machine's hostname.
host := env("HOST", `hostname`)
# Per-machine host data, kept outside the repo (see README).
host_dir := home_directory() / ".config/nix-config-host"
host_flags := "--override-input host 'path:" + host_dir + "'"

# Stop early without host data.
[private]
require-host:
    @test -e '{{ host_dir }}/default.nix' || { echo "No host data at {{ host_dir }}/default.nix; run \`just init-host\` (see README)." >&2; exit 1; }

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
    # Nested virtualization needs M3+ and macOS 15+.
    nested=false
    gen=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | sed -nE 's/^Apple M([0-9]+).*/\1/p' || true)
    os=$(sw_vers -productVersion | cut -d. -f1)
    if [ "${gen:-0}" -ge 3 ] && [ "$os" -ge 15 ]; then
      nested=true
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
      homeModules = [ ];
    }
    EOF
    echo "Wrote $file" >&2

# Bootstrap nix-darwin from this flake.
bootstrap host=host: (init-host host)
    sudo nix run nix-darwin -- switch --flake '.#{{ host }}' {{ host_flags }}

# Lint nix files and evaluate the darwin system derivation.
check host=host: require-host
    statix check .
    nix eval --raw '.#darwinConfigurations.{{ host }}.system.drvPath' {{ host_flags }}

# Build the darwin system derivation without applying it.
build host=host: require-host
    nix build '.#darwinConfigurations.{{ host }}.system' {{ host_flags }}

# Apply the nix-darwin configuration (skip_homebrew=1 skips brew bundle).
switch host=host skip_homebrew="0": require-host
    printf '%s\n' {{ quote(skip_homebrew) }} | sudo tee /tmp/nix-darwin-skip-homebrew >/dev/null
    sudo darwin-rebuild switch --flake '.#{{ host }}' {{ host_flags }}

# Reset global agent tools (also runs automatically during switch).
cleanup-agent-config *args:
    cleanup-agent-config {{ args }}

# Start the linux-builder VM.
builder-start:
    sudo launchctl kickstart system/org.nixos.linux-builder

# Stop the linux-builder VM.
builder-stop:
    sudo launchctl kill SIGTERM system/org.nixos.linux-builder

# Roll back to the previous nix-darwin generation.
rollback:
    sudo darwin-rebuild switch --rollback

# Show nix-darwin generations.
generations:
    sudo darwin-rebuild --list-generations

# Roll back to a specific nix-darwin generation.
rollback-to generation:
    sudo darwin-rebuild switch --switch-generation '{{ generation }}'

# Update flake inputs, all of them when none are given.
up *inputs:
    nix flake update {{ inputs }}

# Weekly automatic gc runs as root only and keeps user (Home Manager) generations.
# Remove system and user generations older than 7 days, then collect garbage.
clean:
    sudo nix-collect-garbage --delete-older-than 7d
    nix-collect-garbage --delete-older-than 7d
