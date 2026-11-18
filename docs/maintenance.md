# Maintenance and validation

## Validate and apply

```sh
just check <HOSTNAME>      # lint, evaluate, validate installed agent config
just build <HOSTNAME>      # build and compare packages with the active system
just switch <HOSTNAME>     # apply
just switch <HOSTNAME> 1   # apply without Homebrew bundle
```

The package diff covers Nix only, not Homebrew or mise. After applying, reload
the [desktop](programs/desktop.md#reload-after-changes),
[terminal](programs/terminal.md#reload-changes) and
[Rex](programs/rex.md#reload) as needed, and start fresh agent sessions to
load the validation hooks.

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

Formatting is opt-in while existing files have mixed styles. Missing tools
fail the check; before the first apply, run the packaged checker instead:

```sh
nix run .#check-repository --override-input host "path:$PWD/nix/fixtures/host" -- --all --tests
```

macOS runtime suites run separately, outside the agent sandbox if it blocks
them:

```sh
# agent-git sandbox tests, with synthetic repositories under /private/tmp
AGENT_GIT_RUNTIME=1 python3 -B -m unittest discover -s tests/ai -p test_agent_git.py -v

# needs a disposable directory outside /tmp and a lazy.nvim plugin directory
# with LazyVim, mason.nvim and conform.nvim
PI_SANDBOX_TEST_ROOT=/absolute/path/to/disposable-test-root \
NVIM_TEST_PLUGINS=/absolute/path/to/existing/lazy/plugins just test-integration
```

## Updates and rollback

```sh
just up <INPUT>...             # selected inputs; omit names to update all
just generations
just rollback                  # previous system and Home Manager generation
just rollback-to <GENERATION>
just clean                     # remove generations older than 7 days and GC
```

Review `flake.lock` and `just build` before switching. Agents use
[`flake-update-preview`](agents/permissions.md#flake-update-previews). Some
inputs have their own steps: [Rosetta image](programs/linux-builders.md#update-the-rosetta-image),
[Neovim nightly](programs/neovim.md#change-or-update-nightly) and
[Rex](programs/rex.md#update).

Nix never installs or prunes mise tools ([tool ownership](design/tool-ownership.md)).
Activation prints a reminder when mise inputs change:

```sh
mise -C ~ install
mise prune --dry-run           # review before running mise prune
```

## Homebrew app data

Activation uninstalls undeclared Homebrew packages but keeps their app data.
To delete it (back up first; zap can remove shared files):

```sh
brew uninstall --cask --zap --force CASK_NAME
```

## Backups and Spotlight

Time Machine excludes the Nix store, VM disks and rebuildable caches; check
with `tmutil isexcluded /nix`. Agent sessions are archived separately
([session history](agents/sessions.md#session-history)). Activation disables
Spotlight on the `/nix` volume; exclude other caches in System Settings →
Spotlight → Search Privacy.
