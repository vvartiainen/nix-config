---
name: mac-disk-cleanup
description: Find and reclaim macOS disk space, including "System Data", on a nix-darwin Mac. Use when asked why the disk is full, what System Data contains, or to clean caches, simulators, VM disks, Apple Intelligence models, local snapshots or the Nix store.
---

# Mac disk cleanup

Read repository instructions first. Survey and plan before deleting anything:
show the user a table of findings with sizes and proposed commands, and wait
for approval. Deletions are hard to reverse; never delete outside the approved
list. Report sizes as measured and say whether they came from `du` (GB) or
`df` (GiB).

## Survey

Most system paths are hidden from the agent sandbox. Use read-only commands
with the sandbox disabled where needed, one command at a time.

```sh
df -h /System/Volumes/Data /nix
tmutil listlocalsnapshots /
du -sh ~/Library/Caches/* ~/.cache/* ~/.npm ~/Library/Application\ Support/* 2>/dev/null | sort -h | tail -30
du -sh /System/Library/AssetsV2/* 2>/dev/null | sort -h | tail -15
du -sh /Library/Developer/CoreSimulator ~/Library/Developer/CoreSimulator
du -sh ~/.local/share/containers/podman/machine/*/* 2>/dev/null
ls -la /var/lib/linux-builder/
```

Usual large items: Apple Intelligence models (`UAF_FM_GenerativeModels`,
`UAF_FM_CodeLM` in AssetsV2), simulator runtimes, VM disks (linux-builder,
podman), package caches, the Nix store, and local Time Machine snapshots.

## Known items

**Package caches.** The agent shell points npm, Go and pip at agent cache
directories and sets `XDG_CACHE_HOME`, so plain clean commands miss the user's
caches. Pass the real paths and verify with `du` afterwards:

```sh
npm_config_cache=~/.npm npm cache clean --force
PIP_CACHE_DIR=~/Library/Caches/pip pip cache purge
GOCACHE=~/Library/Caches/go-build go clean -cache
env -u XDG_CACHE_HOME pnpm store prune
brew cleanup --prune=all
uv cache clean
```

Leave browser and app caches, Playwright/Puppeteer browsers, runtime caches
and `~/.agent-sandbox/state/*/home.img` (sandbox home disks, not caches) unless
the user asks.

**Simulators.** `xcrun simctl` needs the sandbox disabled and may install or
upgrade the CoreSimulator service on first run; mention that side effect.

```sh
xcrun simctl runtime list
xcrun simctl shutdown all && xcrun simctl delete all
xcrun simctl runtime delete <id>        # one per runtime; deletion is async
```

Recheck `runtime list` until it shows 0 images. A leftover
`AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime/*.asset` can remain:
identify it with `plutil -p <asset>/Info.plist` (SimulatorVersion, Build) and
have the user remove it with `sudo rm -rf`.

**Podman.** Check `nix/modules/darwin/programs/podman.nix` first: activation
creates the declared machine and removes undeclared ones. A leftover
`podman/machine/qemu/*.qcow2` belongs to an old QEMU machine that current
podman cannot list or start, so its containers cannot be inspected. Connections
shown as `ReadWrite false` come from `~/.config/containers/containers.conf`,
which `podman system connection rm` cannot change; the user edits that file.

**linux-builder.** The disk at `/var/lib/linux-builder/nixos.qcow2` is a sparse
file created only when missing, with no TRIM: it grows to `diskSize` and never
shrinks. A smaller `diskSize` applies after the user switches, stops the
builder and deletes the file with `sudo rm`.

**Apple Intelligence.** macOS 27 has no off switch. Turning off Siri alone does
not remove the models. `nix/modules/darwin/apple-intelligence.nix` builds
`/etc/apple-intelligence.mobileconfig` (restrictions, locked Siri and privacy
preferences, and `DownloadServerBaseURLOverride-<asset type>` download blocks).
The user installs it with `open` and approves it in System Settings > General >
Device Management after each change. Verify it is enforced:

```sh
python3 - <<'EOF'
import ctypes, ctypes.util
cf = ctypes.CDLL(ctypes.util.find_library("CoreFoundation"))
cf.CFStringCreateWithCString.restype = ctypes.c_void_p
cf.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
cf.CFPreferencesAppValueIsForced.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
s = lambda x: cf.CFStringCreateWithCString(None, x.encode(), 0x08000100)
for d, k in [("com.apple.applicationaccess", "allowAssistant"),
             ("com.apple.MobileAsset", "DownloadServerBaseURLOverride-com.apple.MobileAsset.UAF.FM.GenerativeModels")]:
    print(d, k, bool(cf.CFPreferencesAppValueIsForced(s(k), s(d))))
EOF
```

`defaults read` shows the unmanaged value, not the forced one. Only after the
profile is enforced, remove the models through Apple's asset service with
[`uaf.m`](uaf.m), built into a scratch directory:

```sh
clang -fobjc-arc -framework Foundation -o <scratch>/uaf uaf.m
<scratch>/uaf status
<scratch>/uaf reset com.apple.modelcatalog com.apple.MobileAsset.UAF.FM.Visual \
  com.apple.MobileAsset.UAF.FM.CodeLM com.apple.MobileAsset.UAF.Photos.MagicCleanup \
  com.apple.MobileAsset.UAF.Photos.SpatialPhotosRelive
```

Run `status` first and stop if an asset type no longer matches. "Could not
eliminate as there are current locks" clears later or after a restart; retry.
The folders then hold only an empty `purpose_auto`.

**Local snapshots.** Deleted data stays allocated while an older APFS snapshot
references it, so `df` barely moves after a cleanup. After the user runs a Time
Machine backup (`tmutil status` shows `Running = 0`), they delete the older
snapshots and keep the newest one:

```sh
sudo tmutil deletelocalsnapshots <date>
```

**Nix store.** Check `nix.gc` before suggesting changes; the launchd job's
`runs` counter resets at boot. Generations share most paths, so deleting them
frees little. Find what holds space:

```sh
nix-store --gc --print-roots
nix path-info -Sh /run/current-system <other roots>
```

Stale `result` links are cheap to remove; `{censored}` roots belong to running
processes. VM images (for example agent-sandbox `result` links) are usually
the largest roots; ask before removing them.

## Permissions

- `sudo` commands and deletions under `~` that the auto-mode classifier blocks
  go to the user as `! <command>` lines. Do not retry them another way.
- The user's `rm` may be `rm -i`, which `!` cannot answer, and zsh aborts the
  whole command when a glob matches nothing. Check targets exist and give
  explicit paths.
- Do not read `~/.ssh` or credential files; tell the user which stale keys
  they can delete.
- Config changes follow repository validation and commit rules; the user
  applies them.

## Report

Finish with a table of what was removed and how much it freed, what will grow
back (caches, Nix store, VM disks up to their limits), and anything left for
the user.
