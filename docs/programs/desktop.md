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

## Window borders

JankyBorders outlines the focused window; yabai keeps windows fully opaque.
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

If Vicinae has quit, restart it with:

```sh
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.vicinae
```

## yabai sudoers rule

Activation rewrites `/etc/sudoers.d/yabai` only when the yabai binary changes.
Endpoint security tools may kill activation (exit 137) during that write; it
then fails on every switch until the file holds the rule for the new hash, so
install that rule manually.
