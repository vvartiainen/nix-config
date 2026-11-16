# Desktop

yabai, skhd, SketchyBar and JankyBorders run as Nix-managed launchd services;
Vicinae is the launcher. Shortcuts are in [keybindings](../keybindings.md);
one-time permissions and Spaces are in
[new Mac setup](../runbooks/new-mac.md#after-the-first-activation).

For keeping builds and coding agents running with the lid closed, see
[Amphetamine](amphetamine.md).

## Reload after changes

After applying configuration, `reloadall` reloads yabai rules, skhd bindings,
SketchyBar and Rex Lua configuration. It reports each step and exits nonzero
if any fails. It does not restart GUI apps or terminal sessions. JankyBorders
restarts during activation when its settings change, so `reloadall` does not
touch it.

Use `reloadyabai` after removing or renaming rules/signals, and `reloadskhd`
when skhd itself needs restarting. Nix manages their launchd services; avoid
upstream skhd service-install commands, which create a competing service.

Quit Zen before applying its GUI preferences, then reopen it.

## Create Spaces

The create-Space shortcut runs `~/.config/yabai/create-space.sh`. When
`yabai -m space --create` fails, it presses Mission Control's add button
through System Events instead, so SIP can stay enabled. Failures go to skhd's
stderr log; a timeout after pressing may mean creation succeeded, so inspect
your Spaces before retrying.

Diagnose the UI without adding a Space (this opens and closes Mission Control):

```sh
~/.config/yabai/create-space.sh --diagnose
```

Permissions are in
[new Mac setup](../runbooks/new-mac.md#after-the-first-activation).
SketchyBar shows Spaces 1–10 only. Destroy has no fallback: remove Spaces
manually in Mission Control when `yabai -m space --destroy` cannot.

## Window borders

JankyBorders outlines the focused window in bsp layout only. Yabai signals
and the layout keybindings run `~/.config/yabai/borders-layout.sh` to follow
the layout; run it by hand after changing a layout some other way. Trackpad or
Mission Control Space switches can still flash the borders briefly.

Change the border colours or width in
`nix/modules/darwin/programs/jankyborders.nix`; applying the configuration
restarts it. To restart it by hand:

```sh
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.jankyborders
```

## Vicinae

Vicinae is the daily launcher, opened with **Cmd+Space**. Homebrew installs it;
Nix manages preferences and startup. Configure extensions and sign-ins in
Vicinae. Managed preferences live in `nix/modules/darwin/programs/vicinae.nix`
and override the corresponding GUI settings; extension credentials and app data
stay local.

The managed **Eject All Disks** command asks Finder to eject disks without
forcing busy volumes. Approve Finder control under Privacy & Security →
Automation if prompted. Use **Reload Script Directories** if a command is
missing, and check Finder before unplugging a drive.

**Toggle Function Keys** flips "Use F1, F2, etc. keys as standard function
keys" without logging out. Applying the configuration restores the declared
standard function keys.

**Start Time Machine Backup** requests a backup to the configured destinations
without waiting for it; connect the backup disk first. **Time Machine Backup
Status** shows current activity (`Running = 0` means idle). On a Full Disk
Access error, grant Vicinae access in Privacy & Security → Full Disk Access and
restart it.

If Vicinae has quit, restart it with:

```sh
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.vicinae
```

## yabai sudoers rule

Activation rewrites `/etc/sudoers.d/yabai` only when the yabai binary changes.
Endpoint security tools may kill activation (exit 137) during that write; it
then fails on every switch until the file holds the rule for the new hash, so
install that rule manually.
