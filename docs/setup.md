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
private host data; see [agent validation](../AGENTS.md#validation-commands-no-apply).

## Vicinae launcher

Vicinae is the daily launcher, opened with **Cmd+Space**. Homebrew installs it;
Nix manages preferences and startup. Complete onboarding and grant the macOS
permissions requested for the features you use. Leave Vicinae's separate login
item disabled, since Home Manager starts it through launchd.

Configure extensions and sign-ins in Vicinae. Managed preferences live in
`nix/modules/darwin/programs/vicinae.nix` and override the corresponding GUI
settings; extension credentials and app data stay local.

The managed **Eject All Disks** command asks Finder to eject disks without
forcing busy volumes. Approve Finder control under Privacy & Security →
Automation if prompted. Use **Reload Script Directories** if the command is
missing, and check Finder before unplugging a drive.

If Vicinae has quit, restart it with:

```sh
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.vicinae
```

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
