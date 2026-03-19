# nix-config

macOS setup managed with Nix flakes, `nix-darwin`, and Home Manager.

## Repository layout

- `flake.nix`: flake entrypoint, inputs, and `darwinConfigurations.<hostName>`
- `nix/darwin/`: system-level nix-darwin modules
  - `default.nix`: core macOS and Nix settings
  - `homebrew.nix`: Homebrew taps, brews, casks, and MAS apps
  - `home-manager.nix`: Home Manager integration for the user
- `nix/programs/default.nix`: user-level tools, shell setup, and dotfile mappings
- `dotfiles/`: actual config files for apps (`nvim`, `tmux`, `yabai`, `skhd`, etc.)
- `scripts/`: helper scripts sourced by shell config etc.

## Prerequisites

- macOS (Apple Silicon expected by current config)
- Xcode license accepted:

```bash
sudo xcodebuild -license accept
```

## Installation (first machine)

1. Install Nix (with flakes support):

```bash
sh <(curl -L https://nixos.org/nix/install)
```

1. Restart your shell and verify Nix:

```bash
nix --version
```

1. Clone this repository and `cd` into it.

2. Edit `flake.nix`:
   - set `userName`
   - set `hostName`
   - set `repoRoot` if your local path differs

3. Bootstrap `nix-darwin` from this flake (first activation):

```bash
sudo nix run nix-darwin -- switch --flake .#<hostName>
```

## First-time setup and validation

1. Edit `flake.nix`:
   - set `userName`
   - set `hostName`
   - set `repoRoot` if your local path differs
2. Validate the flake (no apply):

```bash
nix flake show
nix flake check
nix eval .#darwinConfigurations.<hostName>.system
nix build .#darwinConfigurations.<hostName>.system
darwin-rebuild build --flake .#<hostName>
```

1. Apply manually when ready:

```bash
sudo darwin-rebuild switch --flake .#<hostName>
```

## Notes

- Home Manager uses out-of-store symlinks to `dotfiles/`, so edits there are reflected directly.
