# Desktop

yabai, skhd and SketchyBar run as Nix-managed launchd services; Vicinae is the
launcher. Shortcuts are in [keybindings](../keybindings.md); one-time
permissions and Spaces are in
[new Mac setup](../runbooks/new-mac.md#after-the-first-activation).

## Reload after changes

After applying configuration, `reloadall` reloads yabai rules, skhd bindings,
SketchyBar and Rex Lua configuration. It reports each step and exits nonzero
if any fails. It does not restart GUI apps or terminal sessions.

Use `reloadyabai` after removing or renaming rules/signals, and `reloadskhd`
when skhd itself needs restarting. Nix manages their launchd services; avoid
upstream skhd service-install commands, which create a competing service.

Quit Zen before applying its GUI preferences, then reopen it.

## Vicinae

Vicinae is the daily launcher, opened with **Cmd+Space**. Homebrew installs it;
Nix manages preferences and startup. Configure extensions and sign-ins in
Vicinae. Managed preferences live in `nix/modules/darwin/programs/vicinae.nix`
and override the corresponding GUI settings; extension credentials and app data
stay local.

The managed **Eject All Disks** command asks Finder to eject disks without
forcing busy volumes. Approve Finder control under Privacy & Security →
Automation if prompted. Use **Reload Script Directories** if the command is
missing, and check Finder before unplugging a drive.

If Vicinae has quit, restart it with:

```sh
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.vicinae
```

## yabai sudoers rule

Activation rewrites `/etc/sudoers.d/yabai` only when the yabai binary changes.
Endpoint security tools may kill activation (exit 137) during that write; it
then fails on every switch until the file holds the rule for the new hash, so
install that rule manually.
