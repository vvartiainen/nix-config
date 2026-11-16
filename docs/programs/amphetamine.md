# Amphetamine

Amphetamine keeps the Mac awake for a session. Nix declares the App Store app
and installs [Power Protect](https://github.com/x74353/Amphetamine-Power-Protect)
for closed-display sessions on Apple silicon, including when power is connected
or disconnected. Apply the configuration normally; do not run the upstream
Power Protect installer as well.

## Closed-lid sessions

After the first activation, quit and reopen Amphetamine. In its session settings,
turn off **Allow system sleep when display is closed**, then start a new session.
If macOS asks Amphetamine to control System Events, allow it under System
Settings → Privacy & Security → Automation. That grant remains manual.

Use a timed session for a build or coding agent. Test once with the lid closed
and no external display, including unplugging and reconnecting power; confirm
the job continues and normal sleep returns when the session ends. Keep the Mac
on a ventilated surface while running a closed-lid session.

## Managed files

`nix/modules/darwin/programs/amphetamine.nix` pins the official installer and
extracts its AppleScript without running the installer scripts. Home Manager
copies it to `~/Library/Application Scripts/com.if.Amphetamine/powerProtect.scpt`.
Nix-darwin manages `/etc/sudoers.d/amphetamine_PowerProtect`, allowing only the
configured user to run `/usr/bin/pmset -a disablesleep 1` and the matching `0`
command as root without a password. This grants that user the commands outside
Amphetamine too; it does not grant general access to `pmset`.

Activation installs support files; it does not disable sleep or start a session.
Session preferences remain app-managed. Amphetamine Enhancer is a separate,
optional helper and is not installed by this module.

## Troubleshooting

If Power Protect is not detected, restart Amphetamine and start a fresh session.
Check the Automation grant if Power Protect reports a failure.

If sleep remains disabled after ending a session, restore it from Terminal:

```sh
sudo /usr/bin/pmset -a disablesleep 0
```

Before removing the module, end active sessions and restore normal sleep.
Nix-darwin removes its managed sudoers file on the next activation; remove the
copied AppleScript manually if no longer needed. Update the installer commit
and hash together when updating Power Protect.
