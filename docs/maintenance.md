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
([NixOS/nix#8508](https://github.com/NixOS/nix/issues/8508)). Clean both manually:

```sh
just clean            # delete system and user generations older than 7 days, then GC
```

Update flake inputs deliberately:

```sh
just up               # all inputs
just up <INPUT>...    # selected inputs
```

## Linux builder and backups

The linux-builder does not start at boot. An always-on VM can spin the host CPU
after sleep/wake, so start it before Linux builds and stop it afterwards:

```sh
just builder-start
just builder-stop
```

The builder disk grows up to `diskSize` and never shrinks. A smaller
`diskSize` applies only to a new disk: stop the builder and delete
`/var/lib/linux-builder/nixos.qcow2` after switching.

The podman machine is declared in
[`podman.nix`](../nix/modules/darwin/programs/podman.nix) and also does not
start automatically. Activation creates it if missing and removes undeclared
machines. `DOCKER_HOST` points Docker clients at its API socket. The provider
is pinned to libkrun. Size and provider changes need `podman machine rm` and a
new switch:

```sh
podman machine start
podman machine stop
```

Nested virtualization gives the guest `/dev/kvm` and enables the `kvm` and
`nixos-test` features. It requires M3 or newer and macOS 15+; set
`nestedVirtualization = false` in host data on older Macs. Only `aarch64-linux`
guests are accelerated; `x86_64-linux` NixOS tests use slow emulation.

Activation excludes the Nix store volume, linux-builder and podman machine
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
Intelligence features and blocks the model downloads. After a switch that
changes it, install it again:

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
- Globe/Fn opens Emoji & Symbols; changing this action requires a restart.
  Standard function keys and Tab/Shift-Tab navigation are configured in
  [`system-settings.nix`](../nix/modules/darwin/system-settings.nix), alongside
  Finder, Dock, trackpad, and screenshot defaults. Screenshots target the
  clipboard; saved captures use PNG. Native drag tiling and inline text
  predictions are disabled.
- Go telemetry, including local collection, is disabled in
  [`go.nix`](../nix/modules/home/programs/go.nix). After applying, `go telemetry`
  should report `off`.
- Homebrew analytics are disabled with `HOMEBREW_NO_ANALYTICS` in
  [`homebrew.nix`](../nix/modules/darwin/homebrew.nix). In a new shell after
  applying, `brew analytics state` should report them disabled.
