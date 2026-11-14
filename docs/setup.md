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
Silicon and macOS 14.4 or newer; macOS support is currently beta. Homebrew installs the app; Nix
manages preferences and launchd startup. The Homebrew build is used because
the Nix build's Qt launcher breaks macOS permission checks. Homebrew removes
Raycast during activation using `cleanup = "uninstall"`, preserving its
settings and data. Raycast's Nix preference module is inactive.

1. Export Raycast's settings using its export command and store the backup
   privately. Disable Raycast's launch at login, then quit it to release
   Cmd+Space. Keep its local data and backup until the trial is accepted.
2. Quit Vicinae and disable its login item. Keep a private backup of
   launcher settings and data.
   From the checkout containing this change, run
   `just check <HOSTNAME>` and `just build <HOSTNAME>`, then apply manually
   with `just switch <HOSTNAME>`.
   A worktree still uses the private host's `repoRoot` for dotfile links.
3. Home Manager starts Vicinae through launchd. Finish onboarding and grant
   the macOS permissions it requests for the features you use. Leave the
   app's separate login item disabled to avoid duplicate startup. Restart
   with `launchctl kickstart -k gui/$(id -u)/org.nix-community.home.vicinae`
   if you have quit it. The agent starts the app bundle's CLI directly with
   the declared settings, so permissions are requested for Vicinae rather than
   a shell. If Homebrew installs the app after the agent's first start,
   restart it the same way.
   The declared launcher shortcut `control+SPACE` in
   `nix/modules/darwin/programs/vicinae.nix` is Cmd+Space, because Qt maps
   `control` to Cmd on macOS.
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
They are written to a Nix store JSON file passed as `VICINAE_OVERRIDES` to
the launchd agent and login shells. These values take precedence over
writable `~/.config/vicinae/settings.json`; GUI changes to unmanaged values
remain local. Removing a declared value exposes the app's saved value again,
including values saved by the previous merge helper. Keep app-specific data
and extension credentials local; do not commit the live config. Emacs
navigation enables
Ctrl+N/P inside the launcher without depending on macOS's frontmost app.

To return to Raycast, re-add `programs/raycast.nix` alongside
`programs/vicinae.nix` in the host's imports and disable
`launchd.agents.vicinae.enable`. Quit Vicinae, then validate and apply
manually with Homebrew enabled to reinstall Raycast. Launch Raycast and
restore its Cmd+Space shortcut and login setting. Its saved data remains
available unless you explicitly zap it. See [manual Homebrew data cleanup](maintenance.md#homebrew-app-data)
when accepting the migration; Nix rollback cannot restore deleted app data.

## Opening files and directories

After applying, macOS opens Markdown, plain text, code and configuration files
in Kitty with the stable Homebrew Neovim. These macOS defaults are managed in
`nix/modules/darwin/default-apps.nix` and apply to Finder and links from other
apps. Directories open in Finder. Source and script types claimed by Xcode
explicitly select the editor; Xcode projects, PDFs, images and office documents
keep their existing associations. HTML documents and web URLs keep using the
browser; editor activation rejects browser types and schemes.
If an earlier switch selected Kitty as your browser, reselect your preferred
browser in [System Settings → Desktop & Dock → Default web browser](https://support.apple.com/en-gb/102362).

Inside Kitty, directory links open Yazi in a pane, text links open Neovim,
HTML links use the browser, images use `icat`, and `.log` links follow the log.
Other files use their macOS default app. Files sent to Kitty through macOS open
in a new OS window;
scripts open for editing. These rules are in `dotfiles/kitty/open-actions.conf`
and `launch-actions.conf`. Kitty needs these launch rules because macOS selects
an application bundle as its default handler, rather than a terminal command.

Check an association with `duti -x md` or `duti -d public.folder`. Change the
`editor` bundle ID in the defaults module to select another editor app.
Removing a managed association does not automatically restore the previous app.
Activation checks current defaults before setting them; macOS may ask for
confirmation when a default actually changes.
macOS may reject an extension that has no declared file type, such as `.conf`.
Activation warns with the skipped extension and continues applying the other
defaults. For a skipped extension, use Finder's Get Info → Open with → Change
All and check opening a file afterwards. Other association failures stop
activation.

## Remote files

In kitty, `ssh` runs `kitten ssh`, so nothing needs installing on the remote:

- `e <file>` (`edit-in-kitty`) edits a remote file in local nvim and saves back.
- Ctrl+Shift-click a file in `ls` or `rg` output to edit, open or save it locally.
- `kt` (`kitten transfer`) or `F7 t` copies files between local and remote.

To browse remote files, run `yy sftp://<name>` for hosts listed in
`programs.yazi.vfs.sftp` (see [Host data](#host-data)). Yank in one yazi tab and
paste in another to copy between local and remote. Opening a remote file edits a
local cached copy; press `g U` on it afterwards to upload the changes.
