# Terminal and files

Kitty is the terminal, Yazi the file manager and Neovim the editor; Herdr runs
inside Kitty. Keybindings are in [keybindings](../keybindings.md#kitty) and the
editor in [Neovim](neovim.md).

## Opening files and directories

macOS opens Markdown, plain text, code and configuration files in Kitty with
the stable Homebrew Neovim, set in `nix/modules/darwin/default-apps.nix`.
Directories open in Finder; HTML, web URLs, Xcode projects, PDFs, images and
office documents keep their usual apps. Inside Kitty, directory links open
Yazi, text links Neovim, images `icat`, and `.log` links follow the log
(`dotfiles/kitty/open-actions.conf`). Scripts sent to Kitty open for editing,
not execution.

Check an association with `duti -x md` or `duti -d public.folder`. Removing a
managed association does not restore the previous app. macOS may ask to
confirm a changed default, and may reject an extension without a declared file
type, such as `.conf`: activation warns and continues, so set that one in
Finder's Get Info → Open with → Change All.

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
