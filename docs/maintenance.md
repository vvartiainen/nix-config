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

Nested virtualization gives the guest `/dev/kvm` and enables the `kvm` and
`nixos-test` features. It requires M3 or newer and macOS 15+; set
`nestedVirtualization = false` in host data on older Macs. Only `aarch64-linux`
guests are accelerated; `x86_64-linux` NixOS tests use slow emulation.

Activation excludes the Nix store volume, linux-builder disk, and rebuildable
caches/toolchains from Time Machine. The path list lives in
[`system-settings.nix`](../nix/modules/darwin/system-settings.nix). Check the
store exclusion with `tmutil isexcluded /nix`, or set it manually with
`sudo tmutil addexclusion -v /nix`.

## Desktop and tool notes

- Yabai sends Obsidian, Notion, Notes, and Linear to Space 5 (`Notes`), and Mail
  and Calendar to Space 6 (`Mail`). Create missing Spaces in Mission Control,
  then restart yabai with Ctrl+Alt+Cmd+R.
- Globe/Fn opens Emoji & Symbols; changing this action requires a restart.
  Standard function keys and Tab/Shift-Tab navigation are configured in
  [`system-settings.nix`](../nix/modules/darwin/system-settings.nix), alongside
  Finder, Dock, trackpad, and screenshot defaults. Screenshots target the
  clipboard; saved captures use PNG. Native drag tiling and inline text
  predictions are disabled.
- Go telemetry, including local collection, is disabled in
  [`go.nix`](../nix/modules/home/programs/go.nix). After applying, `go telemetry`
  should report `off`.
