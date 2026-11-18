# Terminal and files

Kitty is the terminal, Yazi the file manager and [Neovim](neovim.md) the
editor; Herdr runs inside Kitty. Keybindings are in
[keybindings](../keybindings.md#kitty).

## Opening files and directories

Text, code and config files open in Kitty with Neovim
(`nix/modules/darwin/default-apps.nix`); directories open in Finder. Inside
Kitty, directory links open Yazi, text links Neovim, images `icat` and `.log`
links follow the log (`dotfiles/kitty/open-actions.conf`).

```sh
duti -x md                 # check an association
duti -d public.folder
```

If activation warns that macOS rejected an extension (such as `.conf`), set
it in Finder's Get Info → Open with → Change All.

## Remote files

In Kitty, `ssh` runs `kitten ssh`, so nothing needs installing remotely:

- `e <file>` edits a remote file in local Neovim and saves it back.
- Ctrl+Shift-click a file in `ls` or `rg` output to edit, open or save it.
- `kt` or **F7 → T** copies files between local and remote.
- `yy sftp://<name>` browses hosts from `programs.yazi.vfs.sftp`
  ([host data](../design/host-data.md)); press `g U` to upload an edited file.

## Restore and restart Kitty

Kitty restores its windows and scrollback after logout or restart; start it
normally (an explicit `--session` skips this).

**F7 → R** saves, quits and reopens the current Kitty process with its
windows, tabs and layouts, without scrollback or running programs.
**F7 → S** saves a session file. If reopening fails, see
`~/.local/state/kitty/restart.log` and reopen the snapshot:

```sh
kitty --detach --session ~/.local/state/kitty/restart-<old-pid>.kitty-session
```

## Reload changes

Reload Kitty with **Ctrl+Shift+F5**; restart it after remote-control or menu
changes. Reload Herdr with `herdr server reload-config`.
