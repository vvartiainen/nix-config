# Terminal and files

Kitty is the terminal, Yazi the file manager and Neovim the editor; Herdr runs
inside Kitty. Keybindings are in [keybindings](../keybindings.md#kitty) and the
editor in [Neovim](neovim.md).

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
`programs.yazi.vfs.sftp` (see [host data](../design/host-data.md)).
Yank in one yazi tab and paste in another to copy between local and remote.
Opening a remote file edits a local cached copy; press `g U` on it afterwards
to upload the changes.

## Restore and restart Kitty

Kitty 0.50+ restores all running instances after logout or a computer restart,
including window geometry and scrollback, with fresh shells. Start Kitty normally
to restore; an explicit `--session` bypasses logout restore.

Press **F7 → R** and confirm to save, quit and automatically reopen the current
Kitty process with all its OS windows, tabs, layouts, working directories and
window geometry. Other Kitty processes remain running. Apply the configuration
manually once to link the restart helpers, then reload with **Ctrl+Shift+F5**.

This restart omits scrollback and live process state. Programs started inside
shells need to be resumed manually; commands launched directly by a session
can run again. Window placement remains subject to yabai. A failed save leaves
Kitty running. If reopening fails, inspect `~/.local/state/kitty/restart.log`;
the recovery snapshot is `~/.local/state/kitty/restart-<old-pid>.kitty-session`.
Reopen it from another terminal with `kitty --detach --session <snapshot>`.
**F7 → S** still saves a reviewed session file, including foreground commands.

## Reload changes

Restart Kitty after changing remote-control or menu settings, including macOS
menu shortcuts. Reload Herdr with `herdr server reload-config`.
