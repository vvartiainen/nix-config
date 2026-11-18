# Amphetamine

Amphetamine keeps the Mac awake; Nix installs the App Store app and
[Power Protect](https://github.com/x74353/Amphetamine-Power-Protect) for
closed-lid sessions. Do not run the upstream Power Protect installer.

## Closed-lid sessions

1. After the first activation, quit and reopen Amphetamine.
2. In its session settings, turn off **Allow system sleep when display is
   closed**.
3. Allow Amphetamine to control System Events if asked (Privacy & Security →
   Automation).
4. Start a timed session. Test once with the lid closed, no external display,
   and power unplugged and reconnected.

Keep the Mac on a ventilated surface during closed-lid sessions.

## Troubleshooting

If Power Protect is not detected or fails, restart Amphetamine, check the
Automation grant and start a fresh session. If sleep stays disabled after a
session:

```sh
sudo /usr/bin/pmset -a disablesleep 0
```

The module's sudoers rule allows exactly that command, and `disablesleep 1`,
without a password. Before removing the module, end sessions, restore sleep
and delete the copied AppleScript under `~/Library/Application Scripts/`.
