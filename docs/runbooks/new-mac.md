# Set up a new Mac

Set the configuration up from scratch on a new or wiped Mac. The steps after
the first activation are manual because macOS and the apps do not expose them
as configuration options.

## Prerequisites

- macOS on Apple Silicon
- Xcode installed at `/Applications/Xcode.app`
- Homebrew
- just (`brew install just`)

Finish installing Xcode, then run these once on a new machine (safe to re-run).
Apple does not expose them as nix-darwin options:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
softwareupdate --install-rosetta --agree-to-license
```

Verify the active developer directory and tool lookup:

```sh
xcode-select --print-path # expected: /Applications/Xcode.app/Contents/Developer
xcrun --find clang
```

Rosetta is required by the rosetta-builder and for `x86_64-linux` builds on the
VZ linux-builder. The Xcode
license must be accepted before `xcodebuild` and some Homebrew formulas work.

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

4. Generate [host data](../design/host-data.md) from the current user,
   hostname, chip, and repository path, then review the generated file:

   ```sh
   just init-host <HOSTNAME>
   ```

5. Bootstrap nix-darwin from this flake (first activation):

   ```sh
   just bootstrap <HOSTNAME>
   ```

   Bootstrap also creates host data if it is missing. Add private modules and
   SFTP hosts to the host file later as needed.

## After the first activation

- Grant Accessibility to `/opt/yabai/bin/yabai` and `/Applications/skhd.app` in
  System Settings → Privacy & Security. Grant skhd Input Monitoring if
  requested.
- Create missing Mission Control Spaces before relying on yabai routing:
  Notes apps use Space 5; Mail and Calendar use Space 6.
- Complete Vicinae's onboarding and grant the macOS permissions requested for
  the features you use. Leave Vicinae's separate login item disabled, since
  Home Manager starts it through launchd.
- Run `rex terminfo setup` once for the SSH fallback, then
  [select the Rex theme](../programs/rex.md#theme) and
  [add remote hosts](../programs/rex.md#remote-access).
- Open T3 Code after activation and sign in to the providers you use. Default
  provider paths and new-thread permissions are configured automatically; see
  [T3 Code permission modes](../agents/permissions.md#t3-code-permission-modes).
- Sign in to Codex and Claude Code so [CodexBar](../agents/sessions.md#quotas)
  can read quotas.
- Install the [Apple Intelligence profile](#apple-intelligence-profile).
- Slack theme is a manual per-workspace preference. Select dark mode and import
  the Catppuccin Mocha string under Appearance → Custom theme:

  ```text
  #1E1E2E,#F8F8FA,#CBA6F7,#1E1E2E,#11111B,#CDD6F4,#CBA6F7,#EBA0AC,#1E1E2E,#CDD6F4
  ```

## Apple Intelligence profile

Apple Intelligence restrictions require installing the generated profile: open
`/etc/apple-intelligence.mobileconfig` and approve it under System Settings →
General → Device Management. Reinstall after profile changes. It blocks new
downloads; existing models may remain. Apple has deprecated these restriction
keys, so verify after major updates. Remove the installed profile before
dropping its module if re-enabling the features.
