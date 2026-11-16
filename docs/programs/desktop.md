# Desktop

yabai, skhd, SketchyBar and JankyBorders run as Nix-managed launchd services;
Vicinae is the launcher. Shortcuts are in [keybindings](../keybindings.md);
one-time permissions and Spaces are in
[new Mac setup](../runbooks/new-mac.md#after-the-first-activation).

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

The create-Space shortcut runs `~/.config/yabai/create-space.sh`. It tries
`yabai -m space --create` first, then opens Mission Control and presses the
current display's add button through System Events if yabai fails. It searches
WindowManager and Dock, waits for a new thumbnail, and closes Mission Control
on success or failure. SIP can stay enabled. It does not focus the new Space.
Failures go to skhd's stderr log; a timeout after pressing may mean creation
succeeded, so inspect your Spaces before retrying.

Diagnose the UI without adding a Space (this opens and closes Mission Control):

```sh
~/.config/yabai/create-space.sh --diagnose
```

`--dry-run` is an alias. Output lists the Mission Control owner, display IDs
and whether the current display's add button was found. Permissions are in
[new Mac setup](../runbooks/new-mac.md#after-the-first-activation).

Creation fills empty labels for Spaces 1–6 and refreshes SketchyBar's Space
associations and app icons without reloading it. The bar has items for Spaces
1–10; higher Spaces have no bar item. Creation does not rerun startup app
assignments or move Spaces to other displays.

Destroy still uses `yabai -m space --destroy`. Mission Control's close button
usually requires hover. The upstream workaround also uses `AXRemoveDesktop`,
but its availability and thumbnail mapping on macOS 27.2 are unverified here,
so there is no accessibility fallback for destroy; remove Spaces manually in
Mission Control when yabai cannot.

## Window borders

JankyBorders outlines the focused window in bsp layout only; stack and float
layouts hide the borders. JankyBorders flashes while Spaces change with stacked
windows. `~/.config/yabai/borders-layout.sh` follows the focused Space's layout,
hiding the borders outside bsp layout and re-running the Home Manager bordersrc
in bsp. Yabai signals run it after Space and display changes, and the layout
keybindings run it after switching layouts; run it by hand after changing a
layout some other way. The Space keybindings hide borders before leaving bsp,
but native trackpad or Mission Control switches can still flash briefly because
macOS switches before yabai reports it.

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

**Toggle Function Keys** flips `com.apple.keyboard.fnState`, the same switch as
System Settings → Keyboard → "Use F1, F2, etc. keys as standard function keys".
The stored preference only reaches the keyboard at login, so the command also
hands it to macOS with the `activateSettings` helper and the top row switches
without logging out. Applying the configuration again writes the declared value
from `nix/modules/darwin/system-settings.nix`, which enables function keys.

**Start Time Machine Backup** requests a backup using the destinations already
configured in System Settings → General → Time Machine. Connect your backup disk
or network destination first. The command returns once macOS accepts the request;
it does not wait for completion. An existing backup keeps running.
**Time Machine Backup Status** shows current activity (`Running = 0` means idle).
Both commands display `tmutil` output, including errors. If macOS reports a Full
Disk Access error, grant Vicinae access in Privacy & Security → Full Disk Access
and restart Vicinae before retrying.

If Vicinae has quit, restart it with:

```sh
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.vicinae
```

## yabai sudoers rule

Activation rewrites `/etc/sudoers.d/yabai` only when the yabai binary changes.
Endpoint security tools may kill activation (exit 137) during that write; it
then fails on every switch until the file holds the rule for the new hash, so
install that rule manually.
