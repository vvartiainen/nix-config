flake_ref := "path:."
system_profile := "/nix/var/nix/profiles/system"

# Create local host overrides if missing.
generate-local-config host:
    if [ ! -f local-config.nix ]; then printf '{\n  userName = "%s";\n  hostName = "%s";\n  repoRoot = "%s";\n}\n' "$USER" '{{ host }}' '{{ justfile_directory() }}' > local-config.nix; fi

# Bootstrap nix-darwin from this flake.
bootstrap host:
    just generate-local-config '{{ host }}'
    sudo nix run nix-darwin -- switch --flake '{{ flake_ref }}#{{ host }}'

# Show flake outputs.
show:
    nix flake show

# Run flake checks.
check:
    nix flake check

# Evaluate the darwin system derivation.
eval-system host:
    nix eval '{{ flake_ref }}#darwinConfigurations.{{ host }}.system'

# Build the darwin system derivation.
build-system host:
    nix build '{{ flake_ref }}#darwinConfigurations.{{ host }}.system'

# Build the nix-darwin activation package without applying it.
build host:
    darwin-rebuild build --flake '{{ flake_ref }}#{{ host }}'

# Apply the nix-darwin configuration.
switch host:
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
