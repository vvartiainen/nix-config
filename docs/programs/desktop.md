# Desktop

yabai, skhd, SketchyBar and JankyBorders run as Nix-managed launchd services;
Vicinae is the launcher. Shortcuts are in [keybindings](../keybindings.md);
permissions and Spaces are in
[new Mac setup](../runbooks/new-mac.md#after-the-first-activation). For
closed-lid sessions, see [Amphetamine](amphetamine.md).

## Reload after changes

```sh
reloadall      # yabai rules, skhd bindings, SketchyBar and Rex Lua config
reloadyabai    # after removing or renaming yabai rules or signals
reloadskhd     # restart skhd
```

JankyBorders restarts during activation. Quit Zen before applying its
preferences. Do not use upstream skhd service-install commands.

## Create Spaces

The create-Space shortcut runs `~/.config/yabai/create-space.sh`, which falls
back to Mission Control's add button when `yabai -m space --create` fails, so
SIP can stay enabled. Errors go to skhd's log; check your Spaces before
retrying after a timeout. Diagnose without adding a Space:

```sh
~/.config/yabai/create-space.sh --diagnose
```

SketchyBar shows Spaces 1–10. Remove Spaces in Mission Control when
`yabai -m space --destroy` cannot.

## Window borders

JankyBorders outlines the focused window in bsp layout only. After changing
layout outside the bindings, run `~/.config/yabai/borders-layout.sh`. Colours
and width are in `nix/modules/darwin/programs/jankyborders.nix`. Restart it:

```sh
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.jankyborders
```

## Vicinae

**Cmd+Space** opens Vicinae. Managed preferences live in
`nix/modules/darwin/programs/vicinae.nix` and override GUI settings;
extensions and sign-ins stay local. Managed commands:

- **Eject All Disks**: asks Finder to eject non-busy disks; check Finder
  before unplugging.
- **Toggle Function Keys**: flips standard F1–F12 keys; applying restores the
  declared setting.
- **Start Time Machine Backup** and **Time Machine Backup Status**
  (`Running = 0` means idle); they need Full Disk Access for Vicinae.

Use **Reload Script Directories** if a command is missing. Restart Vicinae:

```sh
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.vicinae
```

## yabai sudoers rule

Activation rewrites `/etc/sudoers.d/yabai` when the yabai binary changes.
If endpoint security kills activation (exit 137) there, install the rule for
the new hash manually.
