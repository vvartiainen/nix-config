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

Rosetta is required by the rosetta-builder and for `x86_64-linux` builds on the
VZ linux-builder. The Xcode
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

## Vicinae launcher trial

[Vicinae for macOS](https://docs.vicinae.com/install/macos) requires Apple
Silicon and macOS 14.4 or newer; macOS support is currently beta. The upstream
Vicinae flake manages the app, CLI, preferences and launchd startup.
Homebrew removes Raycast and the old Vicinae cask during activation using
`cleanup = "uninstall"`, preserving their settings and data. Raycast's Nix
preference module is inactive.

1. Export Raycast's settings using its export command and store the backup
   privately. Disable Raycast's launch at login, then quit it to release
   Cmd+Space. Keep its local data and backup until the trial is accepted.
2. Quit Vicinae and disable its old login item if it was installed through
   Homebrew. Keep a private backup of launcher settings and data.
   From the checkout containing this change, run
   `just check <HOSTNAME>` and `just build <HOSTNAME>`, then apply manually
   with `just switch <HOSTNAME>`.
   A worktree still uses the private host's `repoRoot` for dotfile links.
3. Home Manager starts Vicinae through launchd. Finish onboarding and grant
   the macOS permissions it requests for the features you use. Leave the
   app's separate login item disabled to avoid duplicate startup. Restart
   with `vicinae server` if you have quit it; use the CLI so declared settings
   are loaded through its wrapper.
   The current declared launcher shortcut is Ctrl+Space, which conflicts
   with the quick-access terminal. Change `global_shortcuts.toggle` in
   `nix/modules/darwin/programs/vicinae.nix` if you want to reserve Ctrl+Space
   for the terminal; Cmd+Space is available once Raycast is quit.
4. Recreate aliases, quicklinks and command shortcuts in Vicinae. Reinstall
   needed extensions from its store integration and configure/sign in to each
   again. [Raycast extension compatibility](https://docs.vicinae.com/) varies
   by extension; test each workflow. Do not assume Raycast's settings export,
   snippets or clipboard history can be imported. The existing skhd app and
   window shortcuts work independently of either launcher.
5. Test app launch, calculator, file search, clipboard history, your essential
   extensions, the chosen launcher shortcut and startup after logging in
   again. Keep Spotlight on Left Cmd+Option+Space as a fallback.

The main workflows to verify during this trial:

| Raycast workflow | Vicinae setup |
| --- | --- |
| System Settings | Search for **Sound**, **Bluetooth** or another pane in the launcher and select its System Settings result to open it directly. The built-in provider is enabled declaratively; test Sound on the real host. |
| Clipboard history | Use the built-in Clipboard History command; assign a shortcut in settings. Copy fresh text and an image, then test search and paste. Existing Raycast history stays in Raycast. |
| Amphetamine | The app remains installed through the existing App Store entry. Install the [Amphetamine extension](https://www.raycast.com/gstvds/amphetamine) through Vicinae's Raycast store integration and test starting/ending a session and a timed session. Compatibility is unverified; use Amphetamine's menu bar controls if needed. |
| Eject all disks | Run the managed **Eject All Disks** script command. It asks Finder to eject its ejectable disks without forcing busy volumes. Approve Finder control under Privacy & Security → Automation if prompted. Test with a spare external drive; check Finder before unplugging. |

The script is linked under `~/.local/share/vicinae/scripts/`.
Run **Reload Script Directories** if the eject command is missing after
activation. Useful extras to try are the built-in calculator and file search;
keep window management on the existing yabai/skhd bindings during the trial.

Declare Vicinae preferences in `nix/modules/darwin/programs/vicinae.nix`.
The upstream Home Manager module supplies `programs.vicinae.settings` via
`VICINAE_OVERRIDES` in its CLI wrapper. These values take precedence over
writable `~/.config/vicinae/settings.json`; GUI changes to unmanaged values
remain local. Removing a declared value exposes the app's saved value again,
including values saved by the previous merge helper. Keep app-specific data
and extension credentials local; do not commit the live config. Nix updates
use the upstream binary cache when available. Emacs navigation enables
Ctrl+N/P inside the launcher without depending on macOS's frontmost app.

To return to Raycast, re-add `programs/raycast.nix` alongside
`programs/vicinae.nix` in the host's imports and disable
`programs.vicinae.launchd.enable`. Quit Vicinae, then validate and apply
manually with Homebrew enabled to reinstall Raycast. Launch Raycast and
restore its Cmd+Space shortcut and login setting. Its saved data remains
available unless you explicitly zap it. See [manual Homebrew data cleanup](maintenance.md#homebrew-app-data)
when accepting the migration; Nix rollback cannot restore deleted app data.

## Remote files

In kitty, `ssh` runs `kitten ssh`, so nothing needs installing on the remote:

- `e <file>` (`edit-in-kitty`) edits a remote file in local nvim and saves back.
- Ctrl+Shift-click a file in `ls` or `rg` output to edit, open or save it locally.
- `kt` (`kitten transfer`) or `F7 t` copies files between local and remote.

To browse remote files, run `yy sftp://<name>` for hosts listed in
`programs.yazi.vfs.sftp` (see [Host data](#host-data)). Yank in one yazi tab and
paste in another to copy between local and remote. Opening a remote file edits a
local cached copy; press `g U` on it afterwards to upload the changes.
