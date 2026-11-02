# Maintenance and validation

## Validate and apply

Validate your real host configuration manually before applying it:

```sh
just check <HOSTNAME>      # statix, system evaluation, installed agent config
just build <HOSTNAME>      # system build and installed agent config validation
just switch <HOSTNAME>     # apply manually when ready
```

Pass `1` as the optional `skip_homebrew` parameter to skip Homebrew bundle:

```sh
just switch <HOSTNAME> 1
```

Host selection and private modules are described in the [setup guide](setup.md).
See the [agent configuration guide](agent-project-tools.md#configuration-validation)
for validation coverage and limits.

## Public fixture validation

Agents validate the public configuration from the repository root with the
tracked [`nix/fixtures/host`](../nix/fixtures/host/default.nix) input:

```sh
statix check .
nix eval --raw '.#darwinConfigurations.agent-fixture.system.drvPath' \
  --override-input host "path:$PWD/nix/fixtures/host"
nix build --no-link '.#darwinConfigurations.agent-fixture.system' \
  --override-input host "path:$PWD/nix/fixtures/host"
```

The fixture uses synthetic identity and a synthetic `repoRoot` for generated
dotfile links; that path need not exist. It disables nested virtualization and
imports no private modules. This covers only the public configuration, not the
real machine identity, private modules, or nested virtualization. Never activate
the fixture system.

Agents do not read or request private host data for routine validation. Build
and network approval rules still apply. Follow [AGENTS.md](../AGENTS.md) for
agent verification requirements; documentation-only changes need a diff review
and `git diff --check`, without a system build.

## Rollback, updates, and cleanup

Home Manager is integrated with nix-darwin, so rolling back the system generation
also rolls back the Home Manager state from that generation:

```sh
just rollback                   # previous generation
just generations                # list generations
just rollback-to <GENERATION>   # specific generation
```

Garbage collection runs weekly as root and deletes system generations older
than 7 days. It does not delete per-user Home Manager generations
([NixOS/nix#8508](https://github.com/NixOS/nix/issues/8508)). GC and store
optimisation run at background priority, and builds collect garbage on their
own when free space drops below 5 GiB. Clean both manually:

```sh
just clean            # delete system and user generations older than 7 days, then GC
```

Update flake inputs deliberately:

```sh
just up               # all inputs
just up <INPUT>...    # selected inputs
```

## Linux builders and backups

Two Linux builders handle `aarch64-linux` and `x86_64-linux` builds:

- [`rosetta-builder.nix`](../nix/modules/darwin/rosetta-builder.nix) wraps
  [nix-rosetta-builder](https://github.com/cpick/nix-rosetta-builder), a Lima
  VM that uses Rosetta for `x86_64-linux`. It takes everyday Linux builds. A
  build starts it automatically and it powers off after 30 idle minutes. It has
  no `/dev/kvm`, although it advertises the `kvm` and `nixos-test` features.
- [`linux-builder.nix`](../nix/modules/darwin/linux-builder.nix) is the
  nix-darwin VZ linux-builder with nested virtualization. With nested
  virtualization it takes only builds that require `kvm`, such as NixOS VM
  tests. Without nested virtualization it is a slower fallback for the
  rosetta-builder.

The linux-builder does not start at boot. An always-on VM can spin the host CPU
after sleep/wake, so start it before VM tests and stop it afterwards:

```sh
just builder-start
just builder-stop
```

When the linux-builder is stopped, Nix reports `cannot build on
'ssh-ng://builder@linux-builder'` and runs `kvm` builds on the rosetta-builder,
where tests fall back to slow emulation.

The rosetta-builder VM image is an `aarch64-linux` build from this flake's
nixpkgs. The first switch with it needs another Linux builder, so run
`just builder-start` first. The image build requires `kvm`, which the
linux-builder advertises even without nested virtualization; there it runs
under slow emulation. If the applied `/etc/nix/machines` lacks `kvm` on the
linux-builder, the switch fails with `missing system features`. Pass that line
with `kvm` added once: `sudo darwin-rebuild switch ... --option builders
'<line from /etc/nix/machines with kvm>'`. Later updates are built by the running
rosetta-builder. A changed image or VM setting recreates the VM and its disk.
To remove it, set `nix-rosetta-builder.enable = false` and switch before
removing the module import: only the disabled module removes its
`_rosettabuilder` user and `/var/lib/rosetta-builder`.

The linux-builder disk grows up to `diskSize` and never shrinks. A smaller
`diskSize` applies only to a new disk: stop the builder and delete
`/var/lib/linux-builder/nixos.qcow2` after switching.

The podman machine is declared in
[`podman.nix`](../nix/modules/darwin/programs/podman.nix) and also does not
start automatically. Activation creates it if missing and removes undeclared
machines. `docker` is a symlink to podman, `docker-compose` provides
`podman compose`, and `DOCKER_HOST` points Docker clients at its API socket.
The provider is pinned to libkrun. Size and provider changes need
`podman machine rm` and a new switch:

```sh
podman machine start
podman machine stop
```

Nested virtualization gives the linux-builder guest `/dev/kvm` and enables the
`kvm` and `nixos-test` features. It requires M3 or newer and macOS 15+; set
`nestedVirtualization = false` in host data on older Macs. Only `aarch64-linux`
guests are accelerated; `x86_64-linux` NixOS tests use slow emulation.

Activation excludes the Nix store volume, Linux builder and podman machine
disks, and rebuildable caches/toolchains from Time Machine. The path list lives
in [`system-settings.nix`](../nix/modules/darwin/system-settings.nix). Check the
store exclusion with `tmutil isexcluded /nix`, or set it manually with
`sudo tmutil addexclusion -v /nix`.

Agent session transcripts are copied hourly into
`~/.local/share/agent-transcripts/<host>/{claude,codex,pi}/` by the
`agent-transcripts-archive` launchd agent
([`agent-transcripts.nix`](../nix/modules/darwin/programs/agent-transcripts.nix)).
It copies only the JSONL session files from `~/.claude/projects`,
`~/.codex/sessions` and `~/.pi/agent/sessions`, and never deletes from the
archive, so sessions the agents prune stay available for analysis. Claude Code
keeps its own sessions for 365 days (`cleanupPeriodDays`). Run
`agent-transcripts-archive` to sync now; errors go to
`~/Library/Logs/agent-transcripts-archive.log`.

`agentsview` indexes the live session directories into
`~/.agentsview/sessions.db` and serves a local web UI for browsing, search and
token/cost analytics. It keeps sessions that the agents have since deleted. Its
wrapper in [`agentsview.nix`](../nix/modules/darwin/programs/agentsview.nix)
disables anonymous telemetry and the GitHub update check. Model prices are still
fetched from LiteLLM and OpenRouter; pass `--offline` to use the bundled rates.

## Apple Intelligence

macOS 27 has no Apple Intelligence switch, and nix-darwin cannot install
configuration profiles.
[`apple-intelligence.nix`](../nix/modules/darwin/apple-intelligence.nix)
writes `/etc/apple-intelligence.mobileconfig`, which turns off Siri and Apple
Intelligence features and blocks the model downloads. It also turns off Mac
Analytics, personalized ads, Improve Siri & Dictation, Improve Search, and
Spotlight and Look Up internet suggestions. After a switch that changes it,
install it again:

```sh
open /etc/apple-intelligence.mobileconfig
```

Approve it in System Settings > General > Device Management. The profile only
stops new downloads; models already on disk stay until Apple's asset service
removes them (its `ResetAssetSets` operation, as used by RemoveMacAI). The
restriction keys are deprecated since macOS 26.4, so check them after major
updates.

To turn Apple Intelligence back on:

1. Remove the profile in System Settings > General > Device Management, or with
   `sudo profiles remove -identifier nix-config.apple-intelligence`. Every
   setting it locked is released, and model downloads are unblocked.
2. Turn Siri and the features you want back on in System Settings.
3. To stop shipping the profile, drop `apple-intelligence.nix` from the host
   imports and switch. Removing the module does not remove an installed
   profile, so do step 1 first.

macOS downloads the models again in the background when a feature needs them,
and Xcode downloads its completion model when predictive code completion is
turned on.

## Desktop and tool notes

- Yabai sends Obsidian, Notion, Notes, and Linear to Space 5 (`Notes`), and Mail
  and Calendar to Space 6 (`Mail`). Create missing Spaces in Mission Control,
  then restart yabai with Ctrl+Alt+Cmd+R.
- Yabai is built from the `Christian-SC26/yabai` fork, pinned to a release tag
  in `flake.nix`, and installed to `/opt/yabai/bin`. The `org.nixos.yabai`
  launchd agent logs to `/tmp/yabai_<user>.{out,err}.log`. Review the fork's
  changes before bumping the tag: its scripting addition runs inside Dock.
- skhd is built from [jackielii/skhd.zig](https://github.com/jackielii/skhd.zig),
  pinned in [`skhd-package.nix`](../nix/modules/darwin/programs/skhd-package.nix).
  Activation installs the signed bundle to `/Applications/skhd.app` and links
  `/opt/skhd/bin/skhd` to its executable. Launchd starts that signed executable
  directly; a shell wrapper can cause macOS to attribute Accessibility requests
  to Bash. A small source patch runs default-mode callbacks at startup and
  successful reload to reset the visual indicator. Nix-darwin owns the
  `org.nixos.skhd` LaunchAgent; use `reloadskhd` to restart it and
  `skhd --reload` to reload bindings. Do not use upstream's `--install-service`, `--start-service`,
  `--stop-service`, `--restart-service` or `--uninstall-service`: they manage a
  separate `com.jackielii.skhd` service. Upstream `--status` also expects that
  service; inspect ours with `launchctl print gui/"$(id -u)"/org.nixos.skhd`.
  Runtime diagnostics go to `~/Library/Logs/skhd.log`; launchd also captures
  startup output in `/tmp/skhd_<user>.{out,err}.log`. If login startup is blocked,
  check System Settings > General > Login Items & Extensions for approval.
- Existing skhd configuration remains compatible; the Zen tab shortcuts use
  native key forwarding. Modifier aliases, `.define` commands/application
  groups, mouse bindings and hotkey sequences are available without another
  daemon. Advanced tap/hold and held-layer remapping can require the optional
  root `skhd-grabber` daemon and Karabiner DriverKit component, which this
  configuration does not install or manage. Plan their lifecycle separately
  before enabling rules that require them; do not run `--install-service` to
  install them alongside the Nix agent.
- Sketchybar comes from nixpkgs. Home Manager runs it and logs to
  `~/Library/Logs/sketchybar`.
- Activation signs yabai and skhd with a local certificate, kept root-only in
  `/var/db/nix-config/code-signing`
  ([`signed-binaries.nix`](../nix/modules/darwin/signed-binaries.nix)).
  Accessibility grants are tied to that certificate and signing identity.
  Grant Accessibility again after the first signed install, or if the key is
  deleted and recreated: in System Settings > Privacy & Security >
  Accessibility, remove the old `yabai` and `skhd` entries, add the binary
  from `/opt/yabai/bin` and add `/Applications/skhd.app`. If macOS requests it,
  also grant skhd Input Monitoring; then run `reloadskhd`. Verify shortcuts,
  `skhd --reload`, and startup after logout/login. macOS may require permission
  to be toggled again after an update even with the same certificate.
  If an earlier shell-launcher generation prompted for Bash Accessibility,
  remove that Bash grant after switching to the direct-launch configuration;
  only skhd needs Accessibility for these hotkeys.
  The certificate is not trusted by
  default. If a grant is listed but the tool still reports no Accessibility
  access, trust the certificate for code signing once (this prompts for an
  administrator password):

  ```sh
  sudo security add-trusted-cert -d -r trustRoot -p codeSign \
    -k /Library/Keychains/System.keychain /var/db/nix-config/code-signing/cert.pem
  ```
- Globe/Fn opens Emoji & Symbols; changing this action requires a restart.
  Standard function keys and Tab/Shift-Tab navigation are configured in
  [`system-settings.nix`](../nix/modules/darwin/system-settings.nix), alongside
  Finder, Dock, trackpad, and screenshot defaults. Screenshots target the
  clipboard; saved captures use PNG. Native drag tiling and inline text
  predictions are disabled.
- Go telemetry, including local collection, is disabled in
  [`go.nix`](../nix/modules/home/programs/go.nix). After applying, `go telemetry`
  should report `off`.
- Rex's [official flake](https://www.superlogical.com/rex/docs/linux/installation)
  is pinned to the snapshot channel in `flake.lock`. Home Manager installs its
  CLI and terminfo through `programs.rex`. The nix-darwin
  [`rex.nix`](../nix/modules/darwin/programs/rex.nix) module packages the signed
  GUI DMG and exposes `Rex Beta.app` through `/Applications/Nix Apps`.
  Update its version, URL and checksum together using the official preview
  appcast linked in that module; update the CLI input with `just up rex`.
  The GUI runs the macOS server; no Linux server service is enabled.
  After applying, quit Rex and move the old `/Applications/Rex Beta.app` aside
  manually, then launch `/Applications/Nix Apps/Rex Beta.app` and update any
  Dock or login-item references. Keep the old app until the Nix copy works.
  Use Nix for GUI updates rather than accepting in-app updates: the app in the
  store is read-only. The vendor's automatic update checks still run.
  In Rex terminals, zsh keeps `REX_BIN_DIR` first in PATH so the CLI matches
  the running app/server. Outside Rex, the pinned Nix CLI is available.
  SSH is managed outside Home Manager, so run `rex terminfo setup` once after
  applying to add the SSH terminal fallback, then check `rex terminfo status`.

  Existing app-installed terminfo may need to be moved aside if Home Manager
  reports a collision; inspect it before replacing it. The Lua configuration
  at `~/.config/rex/init.lua` is managed by Home Manager; reload it with
  `rex config reload`. See [Rex mode](agent-keybindings.md#rex) for shortcuts.

  Home Manager installs Rex's official bootstrap skill in `~/.agents/skills/rex`
  (Codex, OpenCode and Pi) and `~/.claude/skills/rex`. It is generated from the
  pinned Rex CLI; the guide comes from the running CLI when invoked. Global
  cleanup runs before Home Manager restores these declared skills on each
  switch. After linking the skills and merging agent settings, activation runs
  the pinned CLI's `rex skill setup --agent claude --agent codex` to reconcile
  its global session-start hooks. Identical linked skills are left untouched;
  unrelated settings and hooks are preserved. Session naming stays at its
  previously installed choice (off for a new setup). OpenCode and Pi share the
  skill but have no Rex command hooks. No manual hook setup is needed.

  Herdr's Home Manager module likewise reconciles the global Claude, Codex,
  Copilot, Cursor, OpenCode and Pi integrations on every activation, after Rex
  and the agent settings. The pinned `herdr integration install` updates its
  own hooks/plugins without duplicating existing registrations, including ones
  installed manually. Cursor uses the declared `CURSOR_CONFIG_DIR`; required
  plugin directories are created even before the first agent launch. These
  vendor-owned files remain writable so the installers can update them.

  After applying manually, inspect `herdr integration status` and
  `rex --autostart=false skill status`, then start fresh agent sessions in each
  terminal and check session association and state reporting. Approve newly
  registered hooks in the agent UI if prompted. Reapplying should leave one
  registration per integration, alongside any custom hooks. The fixture build
  checks the public configuration and activation script, not live terminal
  reporting or private host modules.

  Codex and Claude require approval for Rex CLI calls, including the skill's
  guide command. Their sandbox socket allowlists exclude Rex, since a running
  server can execute commands with the user's normal permissions. See
  [Rex control permissions](agent-permissions.md#rex-control-requires-review)
  for supported agents and remaining limits.

  GUI settings are separate from Lua: the Darwin module selects dark
  appearance and expanded vertical tabs on the left. It sets right Option to
  act as Alt, matching Kitty, while left Option keeps character composition.
  Quit Rex before applying preferences, then relaunch it. To test immediately,
  choose **Option Key Behavior** in Settings and select the right-Option Alt
  behavior. Verify your terminal Alt shortcuts with the right Option key.
  For Catppuccin Mocha, after applying and running `rex config reload`, choose
  **Apply Catppuccin Mocha** from Rex's command palette. This action selects
  dark appearance and imports the Nix-store copy of the tracked
  [`Mocha theme`](../dotfiles/rex/Catppuccin-Mocha). The Ghostty-format file
  matches the Kitty palette; Rex derives both GUI and terminal colors from it.
  The palette and import action are declarative; the app stores the selected
  imported theme. Run the action once on each Mac, or again after changing the
  palette. `rex config reload` alone does not select a GUI theme. To import
  before applying, use **Import Theme File** and select the theme in this
  checkout. CLI invocation requires Remote Control enabled under
  **Settings → Rex Server**: `rex do catppuccin_mocha`.
- Homebrew analytics are disabled with `HOMEBREW_NO_ANALYTICS` in
  [`homebrew.nix`](../nix/modules/darwin/homebrew.nix). In a new shell after
  applying, `brew analytics state` should report them disabled.

## Rex remote access over Tailscale

Each machine that runs agents needs its own Rex server. The Mac and iPhone
connect to those servers as clients. Connecting the Mac app to a Linux host
does not make the Mac a proxy for that host: add the Linux host separately on
the iPhone to control its sessions directly. See the official
[remote access](https://www.superlogical.com/rex/docs/linux/remote-access) and
[server modes](https://www.superlogical.com/rex/docs/linux/server-modes) guides.

### iPhone to Mac

In the Mac app's settings, find **Serve over Tailscale** and keep access limited
to your Tailscale account. Rex embeds its own Tailscale node, separate from the
Mac's Tailscale app. Use a distinct device name such as `rex-mac` and sign in
with the same account used by Tailscale on the iPhone. Enable MagicDNS and HTTPS
certificates in the tailnet's DNS settings, and approve the new device if the
tailnet requires it.

The running server can also be enabled without restarting existing sessions:

```sh
rex --autostart=false server tailscale on --hostname rex-mac
rex --autostart=false server tailscale login
rex --autostart=false server status
```

Open the sign-in link locally. Once status reports Tailscale running and HTTPS
available, display the pairing address or QR code:

```sh
rex --autostart=false server tailscale pair
```

Connect Tailscale on the iPhone and add the displayed address in Rex, or scan
the pairing code if the client offers it. Keep addresses, enrollment links and
Tailscale state out of this repository. Leave access limited to the node's
owner; `--allow-tailnet-members` broadens access and is unnecessary here.

The CLI's `tailscale on` changes only the running server. Its sign-in is saved,
but a restarted server returns to its startup flags. Check the app's **Serve
over Tailscale** setting and verify access after a planned app/server restart;
do not assume a CLI enable persists. `rex config reload` reloads Lua bindings,
not server startup flags. Keep the Mac awake and Rex running for access. Test
from the phone on cellular, with Wi-Fi off, before relying on remote access.

### Mac and iPhone to Linux agent hosts

For one user's agents, run a personal Rex server as that user so it uses the
intended home directory, repositories and agent configuration. The packaged
system `rex.service` instead runs as the shared `rex` account. Install Rex
using the vendor's [Linux installation guide](https://www.superlogical.com/rex/docs/linux/installation).
For an initial connection on a host with no running Rex server:

```sh
rex server start --tailscale --tailscale-hostname rex-agent
rex server status
```

Sign in through the reported link. Startup options do not reconfigure an
existing server. For a server already running, `rex server tailscale on` enables
remote access without ending sessions, but only for that run of the server.
Use a different node name for each VM or physical host.

On Linux with Nix and systemd, import the official
`inputs.rex.homeManagerModules.default` into that user's Home Manager config
and configure a persistent personal server there:

```nix
{
  programs.rex.enable = true;
  services.rex = {
    enable = true;
    tailscale = {
      enable = true;
      hostname = "rex-agent";
    };
  };
}
```

Use a pinned Rex input in the Linux configuration. This repository currently
configures only the Mac; this example is for the Linux host's configuration,
including NixOS hosts using Home Manager. Enable lingering for the agent user
with `loginctl enable-linger` on that host if the service should start at boot
and remain running after logout. Enrollment is interactive once; do not put an
auth key in Nix source. Without Home Manager, arrange a supervised personal
server using the host's service manager, including the Tailscale startup flags.

For microVMs, keep the user's home and Rex state (`~/.local/state/rex`, or
`$XDG_STATE_HOME/rex`) on persistent storage. Each VM needs outbound networking
and working DNS; embedded Tailscale does not require a guest TUN device or
inbound port forwarding. Do not clone enrolled Rex state into another VM;
enroll each guest separately. Sessions run only while the guest is running,
and pausing or sleeping the Mac also interrupts access to its guests.

After HTTPS is available, choose **Add Remote Host…** in the Mac app and enter
the address shown by the Linux server. Add it separately on the iPhone. For
CLI access, register it separately using the actual address:

```sh
rex hosts add agent https://rex-agent.example.ts.net
rex -S agent ls
```

`rex hosts` currently manages only CLI hosts; it does not populate the Mac app
or sync to the iPhone. Validate each host from both clients and verify its
service after a planned reboot. An external mini PC can remain available
while the Mac sleeps when the phone connects directly to that server.
