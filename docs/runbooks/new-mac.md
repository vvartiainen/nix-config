# Set up a new Mac

Set the configuration up from scratch on a new or wiped Mac.

## Prerequisites

- macOS on Apple Silicon
- Xcode installed at `/Applications/Xcode.app`
- Homebrew
- just (`brew install just`)

Finish installing Xcode, then run (safe to re-run):

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
softwareupdate --install-rosetta --agree-to-license
```

Verify:

```sh
xcode-select --print-path # expected: /Applications/Xcode.app/Contents/Developer
xcrun --find clang
```

## Installation

1. Install Nix with flakes support:

   ```sh
   sh <(curl -L https://nixos.org/nix/install)
   ```

2. Restart your shell and verify Nix:

   ```sh
   nix --version
   ```

3. Clone this repository and `cd` into it.

4. Generate [host data](../design/host-data.md), then review the file:

   ```sh
   just init-host <HOSTNAME>
   ```

5. Bootstrap nix-darwin from this flake (first activation):

   ```sh
   just bootstrap <HOSTNAME>
   ```

   Add private modules and SFTP hosts to the host file later as needed.

## After the first activation

- Grant Accessibility to `/opt/yabai/bin/yabai` and `/Applications/skhd.app` in
  System Settings → Privacy & Security. Grant skhd Input Monitoring if
  requested.
- For the [create-Space fallback](../programs/desktop.md#create-spaces),
  allow skhd to control System Events (Privacy & Security → Automation). To
  run `create-space.sh --diagnose` from a terminal, grant the terminal app the
  same Accessibility and Automation access. Do not grant Dock or
  WindowManager.
- Create missing Mission Control Spaces before relying on yabai routing:
  Notes apps use Space 5; Mail and Calendar use Space 6.
- Complete Vicinae's onboarding and grant the permissions it asks for. Leave
  its login item disabled; launchd starts it.
- Run `rex terminfo setup` once for the SSH fallback, then
  [select the Rex theme](../programs/rex.md#theme) and
  [add remote hosts](../programs/rex.md#remote-access).
- Open T3 Code and sign in to the providers you use
  ([permission modes](../agents/permissions.md#t3-code-permission-modes)).
- Sign in to Codex and Claude Code so [CodexBar](../agents/sessions.md#quotas)
  can read quotas.
- Install the [Apple Intelligence profile](#apple-intelligence-profile).
- In each Slack workspace, select dark mode and import this theme under
  Appearance → Custom theme:

  ```text
  #1E1E2E,#F8F8FA,#CBA6F7,#1E1E2E,#11111B,#CDD6F4,#CBA6F7,#EBA0AC,#1E1E2E,#CDD6F4
  ```

## Apple Intelligence profile

Open `/etc/apple-intelligence.mobileconfig` and approve it under System
Settings → General → Device Management. Reinstall it after profile changes and
verify it after major macOS updates. It blocks new model downloads only.
Remove the installed profile before dropping its module.
