# Maintenance and validation

## Validate and apply

The user validates private host configuration and applies it manually:

```sh
just check <HOSTNAME>      # lint, evaluate, validate installed agent config
just build <HOSTNAME>      # build and compare packages with the active system
just switch <HOSTNAME>     # apply
just switch <HOSTNAME> 1   # apply without Homebrew bundle
```

See [host data](design/host-data.md) for host selection and
[agent configuration validation](agents/config.md#configuration-validation)
for coverage. The package diff covers pending Nix changes, not Homebrew or mise
updates. After applying, reload the
[desktop](programs/desktop.md#reload-after-changes),
[terminal](programs/terminal.md#reload-changes) and
[Rex](programs/rex.md#reload) as needed.

## Repository checks

```sh
just lint                      # staged, unstaged and untracked files
just lint --base HEAD~1         # also include changes in the last commit
just lint --all                 # audit all owned files
just lint --format              # also check formatting without writing files
just lint --tests               # also run fast behavior tests after code changes
just test-fast                  # all fast behavior tests, without Nix
just test                       # full behavior suite with pinned dependencies/fixtures
just check-fixture              # Statix and public fixture evaluation, no build
just build-fixture              # public fixture system build, no apply
```

Formatting is opt-in while existing files have mixed styles. Vendored Yazi
plugins and flavors and symlinks are skipped. Missing tools fail the check;
apply the configuration to install them. Before applying, run the packaged
checker with its Nix-provided tools instead:

```sh
nix run .#check-repository --override-input host "path:$PWD/nix/fixtures/host" -- --all --tests
```

`just test` uses the public fixture and pinned dependencies, and the
configured Kitty on `PATH` for its runtime tests. A missing prerequisite fails
rather than skipping a suite. None of these commands applies configuration,
and none replaces the [fixture evaluation and build](../AGENTS.md#validation-commands-no-apply)
or manual private-host validation.

Two runtime suites run separately on macOS. The `agent-git` sandbox tests use
synthetic repositories under `/private/tmp`:

```sh
AGENT_GIT_RUNTIME=1 python3 -B -m unittest discover -s tests/ai -p test_agent_git.py -v
```

The integration tests need an existing disposable directory outside `/tmp`
(Safehouse grants `/tmp` itself, which would invalidate denial tests) and an
existing Neovim plugin directory containing lazy.nvim, LazyVim, mason.nvim and
conform.nvim. They use synthetic identity and credentials and never install
plugins. Run them outside the agent sandbox if it blocks starting a macOS
sandbox or binding local test sockets:

```sh
PI_SANDBOX_TEST_ROOT=/absolute/path/to/disposable-test-root \
NVIM_TEST_PLUGINS=/absolute/path/to/existing/lazy/plugins just test-integration
```

After applying, start fresh Codex, Claude and Copilot sessions to load the
repository validation hooks, and approve them in the agent UI if asked. Their
scope is in [AGENTS.md](../AGENTS.md#validation-commands-no-apply).

## Updates and rollback

```sh
just up <INPUT>...             # selected inputs; omit names to update all
just generations
just rollback                  # previous system and Home Manager generation
just rollback-to <GENERATION>
just clean                     # remove generations older than 7 days and GC
```

Review `flake.lock` and `just build` before switching. The main `nixpkgs` input
tracks unstable. Agents preview updates with
[`flake-update-preview`](agents/permissions.md#flake-update-previews). Some
inputs have their own update steps:
[Rosetta image](programs/linux-builders.md#update-the-rosetta-image),
[Neovim nightly](programs/neovim.md#change-or-update-nightly) and
[Rex](programs/rex.md#update).
Weekly GC removes old system generations; `just clean` also handles user
Home Manager generations. Garbage-collected generations cannot be restored.

Activation prints a reminder when managed mise inputs change but does not
install or prune tools. Run installation manually from the home context:

```sh
mise -C ~ install
mise prune --dry-run
```

Review the preview before running `mise prune`: projects may still need those
versions. See [tool ownership](design/tool-ownership.md) for which manager owns
which tools; use `type -a <tool>` to diagnose competing installations.

## Homebrew app data

Activation removes undeclared Homebrew packages
(`homebrew.onActivation.cleanup = "uninstall"`) but keeps cask preferences and
app data for rollback. After accepting a removal, delete that data manually:

```sh
brew uninstall --cask --zap --force CASK_NAME
```

`--force` allows zapping an already uninstalled cask. Zap removes the files
listed by the cask, which can include shared files; back up anything needed
first. `brew cleanup` removes old downloads and versions, not app data.

## Backups and Spotlight

Time Machine excludes the Nix store, VM disks and rebuildable tool caches.
Check with `tmutil isexcluded /nix`. Treat VM disks as rebuildable; keep
important data elsewhere. Agent sessions are archived separately; see
[session history](agents/sessions.md#session-history).

Activation disables Spotlight indexing on a separately mounted `/nix` volume
when `mdutil` can. Time Machine exclusions do not affect Spotlight; exclude
cache folders in System Settings → Spotlight → Search Privacy.
