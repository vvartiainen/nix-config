# Setup and host data

## Prerequisites

- macOS on Apple Silicon
- Xcode installed at `/Applications/Xcode.app`
- Homebrew
- just (`brew install just`)

Finish installing Xcode, then run these once on a new machine (safe to re-run).
Apple does not expose them as nix-darwin options:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
softwareupdate --install-rosetta --agree-to-license
```

Verify the active developer directory and tool lookup:

```sh
xcode-select --print-path # expected: /Applications/Xcode.app/Contents/Developer
xcrun --find clang
```

Rosetta is required for `x86_64-linux` builds on the VZ linux-builder. The Xcode
license must be accepted before `xcodebuild` and some Homebrew formulas work.

## Installation

1. Install Nix with flakes support:

   ```sh
   sh <(curl -L https://nixos.org/nix/install)
   ```

2. Restart your shell and verify Nix:

   ```sh
   nix --version
   ```

3. Clone this repository and `cd` into it.

4. Generate [host data](#host-data) from the current user, hostname, chip, and
   repository path, then review the generated file:

   ```sh
   just init-host <HOSTNAME>
   ```

5. Bootstrap nix-darwin from this flake (first activation):

   ```sh
   just bootstrap <HOSTNAME>
   ```

   Bootstrap also creates host data if it is missing.

## Host data

Machine identity and private configuration stay outside this repo in
`~/.config/nix-config-host/default.nix`:

```nix
{
  userName = "your-user";
  hostName = "YOUR-HOSTNAME"; # also the darwinConfigurations name
  repoRoot = "/Users/your-user/prog/nix-config";
  nestedVirtualization = true; # M3+ and macOS 15+; false on older Macs
  darwinModules = [ ];
  homeModules = [
    ./zen-work.nix # optional private module; remove if unused
    {
      # Backlog.md folders under this vault; each gets an agent MCP server.
      backlog.vault = "/Users/your-user/backlogs";
      backlog.projects = [ "nix-config" ];
      # SFTP hosts for yazi (`yy sftp://my-server`); auth via SSH_AUTH_SOCK.
      programs.yazi.vfs.sftp.my-server = {
        host = "203.0.113.10";
        user = "me";
        port = 22;
      };
    }
  ];
}
```

The flake's `host` input defaults to a stub that fails with an error. The `just`
recipes select the real directory with
`--override-input host "path:$HOME/.config/nix-config-host"`. This implies
`--no-write-lock-file`, so the path never ends up in `flake.lock`. Use the same
flag with raw `nix` or `darwin-rebuild` commands for your machine.

Only that directory and tracked repository files are copied into the Nix store.
New repository files need `git add` before a build sees them. Never commit real
hostnames, usernames, or work-specific configuration.

Use `hostName` for `<HOSTNAME>` in recipes; it defaults to `hostname` (or `HOST`
if exported). Recipes stop with a hint when host data is missing.

For routine agent validation, use the tracked public fixture instead of reading
private host data; see [maintenance and validation](maintenance.md).

## Remote files

In kitty, `ssh` runs `kitten ssh`, so nothing needs installing on the remote:

- `e <file>` (`edit-in-kitty`) edits a remote file in local nvim and saves back.
- Ctrl+Shift-click a file in `ls` or `rg` output to edit, open or save it locally.
- `kt` (`kitten transfer`) or `F7 t` copies files between local and remote.

To browse remote files, run `yy sftp://<name>` for hosts listed in
`programs.yazi.vfs.sftp` (see [Host data](#host-data)). Yank in one yazi tab and
paste in another to copy between local and remote.
