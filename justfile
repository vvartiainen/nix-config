flake_ref := "."
system_profile := "/nix/var/nix/profiles/system"
# Flake config name. `$HOST` when exported, otherwise this machine's hostname.
default_host := `hostname`
host := env("HOST", default_host)
# Per-machine host data, kept outside the repo (see README).
host_dir := home_directory() / ".config/nix-config-host"
host_flags := "--override-input host 'path:" + host_dir + "'"

# Stop early without host data.
[private]
require-host:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -e '{{ host_dir }}/default.nix' ]; then
      exit 0
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

# Leftovers predate merge-config.nix tracking what Nix applied. Remove this
# recipe once every machine has run it.
# TEMPORARY: clean up old agent MCP config once, after `just switch`, CLIs closed.
cleanup-agent-config:
    #!/usr/bin/env bash
    set -euo pipefail
    config_home=${XDG_CONFIG_HOME:-$HOME/.config}
    # Servers Nix manages now, from programs.mcp.
    if [[ ! -f $config_home/mcp/mcp.json ]]; then
      echo "No $config_home/mcp/mcp.json; run \`just switch\` first." >&2
      exit 1
    fi
    keep=$(jq -c '.mcpServers | keys' "$config_home/mcp/mcp.json")
    changed=0

    # edit <file> <jq|awk> <program>: rewrite the file, back up if it changed.
    edit() {
      local file=$1 tool=$2 program=$3 tmp
      [[ -f $file && ! -L $file ]] || return 0
      tmp=$(mktemp "$file.XXXXXX")
      if [[ $tool == awk ]]; then
        awk -v keep=" $(jq -r 'join(" ")' <<<"$keep") " "$program" "$file" >"$tmp"
      else
        jq --argjson keep "$keep" "$program" "$file" >"$tmp"
      fi
      if cmp -s "$file" "$tmp"; then
        rm -f "$tmp"
        return 0
      fi
      cp -p "$file" "$file.pre-cleanup"
      chmod "$(stat -f %Lp "$file")" "$tmp"
      mv "$tmp" "$file"
      echo "cleaned $file (backup: $file.pre-cleanup)"
      changed=1
    }

    # Backlog servers whose project is no longer configured.
    drop_stale='if .mcpServers then .mcpServers |= with_entries(select((.key | startswith("backlog-") | not) or (.key | IN($keep[])))) else . end'

    # Claude Code now gets the Nix servers from the generated `hm` plugin.
    claude_json=$HOME/.claude.json
    claude_filter='(.key | IN($keep[])) or (.key | startswith("backlog-"))'
    if [[ -f $claude_json ]]; then
      if command -v claude >/dev/null; then
        for name in $(jq -r --argjson keep "$keep" ".mcpServers // {} | to_entries[] | select($claude_filter) | .key" "$claude_json"); do
          claude mcp remove "$name" -s user
          changed=1
        done
      else
        edit "$claude_json" jq "if .mcpServers then .mcpServers |= with_entries(select($claude_filter | not)) else . end"
      fi
    fi

    edit "$HOME/.pi/agent/mcp.json" jq "$drop_stale"
    edit "$config_home/cursor/mcp.json" jq "$drop_stale"
    # Drop stale [mcp_servers.backlog-*] tables and subtables; keep formatting.
    edit "$HOME/.codex/config.toml" awk '
      /^[[:space:]]*\[/ {
        skip = 0
        if (match($0, /^[[:space:]]*\[mcp_servers\."?backlog-[^]".]*/)) {
          name = substr($0, RSTART, RLENGTH)
          sub(/^[[:space:]]*\[mcp_servers\."?/, "", name)
          skip = index(keep, " " name " ") == 0
        }
      }
      !skip'

    # OpenCode loads these from the home-manager.json / cli layers now.
    edit "$config_home/opencode/opencode.json" jq '
      del(."$schema", .model, .lsp.typescript, .permission)
      | if .mcp then .mcp |= with_entries(select((.key | IN($keep[])) or (.key | startswith("backlog-")) | not)) else . end
      | with_entries(select(.value != {}))'
    edit "$config_home/opencode/cli.json" jq '
      del(."$schema", .theme.name, .keybinds."prompt.editor", .keybinds."session.first", .keybinds."model.list")
      | with_entries(select(.value != {}))'

    if [[ $changed == 0 ]]; then
      echo "nothing to clean"
    fi
