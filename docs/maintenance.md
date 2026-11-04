# Maintenance and validation

## Validate and apply

The user validates private host configuration and applies it manually:

```sh
just check <HOSTNAME>      # lint, evaluate, validate installed agent config
just build <HOSTNAME>      # build and compare packages with the active system
just switch <HOSTNAME>     # apply
just switch <HOSTNAME> 1   # apply without Homebrew bundle
```

See [setup](setup.md#host-data) for host selection and
[agent configuration validation](agent-project-tools.md#configuration-validation)
for coverage. The package diff includes all pending Nix changes; it excludes
Homebrew and mise updates.

Agents follow [AGENTS.md](../AGENTS.md) and use the public fixture:

```sh
statix check .
nix build --no-link '.#darwinConfigurations.agent-fixture.system' \
  --override-input host "path:$PWD/nix/fixtures/host"
```

The fixture covers public configuration only. It excludes private modules,
real identity and nested virtualization. Never activate it. Documentation-only
changes need diff review and `git diff --check`, without a system build.

## Updates and rollback

```sh
just up <INPUT>...             # selected inputs; omit names to update all
just generations
just rollback                  # previous system and Home Manager generation
just rollback-to <GENERATION>
just clean                     # remove generations older than 7 days and GC
```

Review `flake.lock` and `just build` before switching. The main `nixpkgs` input
tracks unstable; the Rosetta VM image uses `nixpkgs-stable`. Update the image
intentionally with `just up nixpkgs-stable nix-rosetta-builder`.
Weekly GC removes old system generations; `just clean` also handles user
Home Manager generations. Garbage-collected generations cannot be restored.

Nix activation prints a reminder when managed mise inputs change; it does not
install or prune tools. Run installation manually from the home context:

```sh
mise -C ~ install
mise prune --dry-run
```

Review the preview before running `mise prune`: projects may still need those
versions. Nix owns common language servers and btop; mise owns runtimes and uv.
Use `type -a <tool>` to diagnose competing installations.

## Homebrew app data

Activation uses `homebrew.onActivation.cleanup = "uninstall"`: undeclared
Homebrew packages are removed, while cask preferences and app data are kept
for rollback. Review and delete that data manually after accepting a removal.
For example, after the Vicinae migration is accepted:

```sh
brew uninstall --cask --zap --force raycast
```

`--force` allows zapping an already uninstalled cask. Zap removes the files
listed by the cask, which can include shared files; back up anything needed
first. See [Homebrew's uninstall options](https://docs.brew.sh/Manpage#uninstall-remove-rm-options-installed_formulainstalled_cask-).
Do not zap Vicinae after moving it to Nix: both installations use the same
local settings and data. `brew cleanup` only removes old downloads and package
versions; it does not replace a cask zap.

## Linux builders and containers

The Rosetta builder handles everyday Linux builds and starts on demand. The
VZ linux-builder handles KVM tests when nested virtualization is enabled.
It stays off at boot because an idle VM can spin the CPU after sleep/wake:

```sh
just builder-start
# Run builds or VM tests, then:
just builder-stop
podman machine start
podman machine stop
```

Start the VZ builder before the first Rosetta image build. Stopped VZ builders
can cause KVM tests to fall back to slow emulation. Nested virtualization
requires M3+ and macOS 15+; only aarch64 guests are accelerated.
Podman is also manual-start; `docker` invokes Podman. Builder disk recreation,
provider/size changes and removal procedures are in Backlog doc-6.

## Desktop reloads and permissions

After applying configuration, `reloadall` reloads yabai rules, skhd bindings,
SketchyBar and Rex Lua configuration. It reports each step and exits nonzero
if any fails. It does not restart GUI apps or terminal sessions.

Use `reloadyabai` after removing or renaming rules/signals, and `reloadskhd`
when skhd itself needs restarting. Nix manages their launchd services; avoid
upstream skhd service-install commands, which create a competing service.
Grant Accessibility to `/opt/yabai/bin/yabai` and `/Applications/skhd.app` in
System Settings → Privacy & Security. Grant skhd Input Monitoring if requested.
Signing/permission recovery is documented in Backlog doc-5.

Restart Kitty after changing remote-control or menu settings. Reload Herdr
with `herdr server reload-config`; Rex Lua uses `rex config reload`.
Quit Zen and Rex before applying GUI preferences, then reopen them.
Rex in the Nix store is updated through Nix. Bump the flake's pinned `rex`
snapshot and the GUI DMG pin in `nix/modules/darwin/programs/rex.nix` together;
the CLI and app share an API revision. Run `rex terminfo setup` once for SSH
fallback. Select **Apply Catppuccin Mocha** in Rex's palette once per Mac
and again after changing the palette; reloading Lua alone does not select it.

## Quotas and agent status

[Global shortcuts](keybindings.md#global-shortcuts) open CodexBar or the separate
Metrics dashboard. CodexBar needs to be running. In Metrics, **Esc, Q, Ctrl+C
or Cmd+W** hides the dashboard; **R** refreshes, **Ctrl+D** stops it. It hides
on focus loss. Last successful reports stay visible while independent refreshes
run; report ages and errors show stale data. Stop and reopen after dashboard
changes. Codex needs its OAuth login; Claude Code must be installed and signed in.
For repeated Claude credential prompts in CodexBar, choose **Providers → Claude →
Usage source → CLI** to avoid repeated Keychain re-grants.

Kitty tab labels show the repository or `repository:worktree`; manual names
win. Agent lifecycle hooks also drive SketchyBar's green running count and
amber attention count. Click either icon for read-only session details;
clicks do not focus terminals. Empty groups hide. This works in Rex too.
Codex reports Kitty status natively; Claude and Copilot need the configured
interactive zsh launch functions for Kitty status. Use fresh sessions after
changing hooks and approve new hooks in the agent UI if requested.
Status delivery failures do not stop an agent; detailed integration checks
are in Backlog doc-5.

## Backups and session history

Time Machine excludes the Nix store, VM disks and rebuildable tool caches.
Check with `tmutil isexcluded /nix`. Treat VM disks as rebuildable; keep
important data elsewhere.

Claude, Codex and Pi JSONL sessions are copied hourly into
`~/.local/share/agent-transcripts/<host>/`; source deletions do not delete the
archive. Run `agent-transcripts-archive` to sync now; its log is
`~/Library/Logs/agent-transcripts-archive.log`.
`agentsview` provides local session search and analytics; use `--offline` to
avoid fetching model prices.

## Manual macOS settings

- Apple Intelligence restrictions require installing the generated profile:
  open `/etc/apple-intelligence.mobileconfig` and approve it under System
  Settings → General → Device Management. Reinstall after profile changes.
  It blocks new downloads; existing models may remain. Apple has deprecated
  these restriction keys, so verify after major updates. Remove the installed
  profile before dropping its module if re-enabling the features.
- Slack theme is a manual per-workspace preference. Select dark mode and import
  the Catppuccin Mocha string under Appearance → Custom theme:

  ```text
  #1E1E2E,#F8F8FA,#CBA6F7,#1E1E2E,#11111B,#CDD6F4,#CBA6F7,#EBA0AC,#1E1E2E,#CDD6F4
  ```

- Create missing Mission Control Spaces before relying on yabai routing:
  Notes apps use Space 5; Mail and Calendar use Space 6.

## Remote Rex access

Each agent host needs its own Rex server. Add each host separately in the Mac
app, iPhone and CLI; the Mac is not a proxy for Linux sessions. Keep enrollment
state and pairing addresses private. Check access after a server restart and
from the phone on cellular before relying on it.

Tailscale enrollment, persistent personal Linux servers and VM state handling:
Backlog **doc-6 — Maintenance and builder implementation notes**.
Desktop service, signing, theme and hook details: Backlog **doc-5 — Desktop and
terminal integration details**.
