"""Resolve the applied configuration’s flake to a fixed scratch lock, never its tracked lock."""

import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile


OUTPUT = Path("/private/tmp/flake-update-review")


def copy_source(source, target):
    # The build supplies immutable store sources. Reject links rather than
    # following anything outside those small source trees.
    source = Path(source)
    if source.is_symlink() or any(p.is_symlink() for p in source.rglob("*")):
        raise ValueError("embedded source must not contain symlinks")
    if source.is_dir():
        shutil.copytree(source, target)
    else:
        shutil.copyfile(source, target)


def preview(nix, sources, inputs):
    if any(not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", name) or name == "host" for name in inputs):
        raise ValueError("expected plain input names other than host; no flags or paths")
    # Never hand Nix a caller-controlled output symlink. A private directory
    # prevents other users replacing entries between validation and rename.
    OUTPUT.mkdir(mode=0o700, exist_ok=True)
    info = OUTPUT.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError(f"{OUTPUT} must be an owned directory with mode 0700 (no symlink)")
    with tempfile.TemporaryDirectory(prefix="resolve-", dir=OUTPUT) as scratch:
        flake = Path(scratch) / "flake"
        (flake / "nix").mkdir(parents=True)
        for source, target in zip(sources, ["flake.nix", "flake.lock", "nix/host-unset", "nix/fixtures/host"], strict=True):
            destination = flake / target
            destination.parent.mkdir(parents=True, exist_ok=True)
            copy_source(source, destination)
        original = json.loads((flake / "flake.lock").read_text())
        lock = Path(scratch) / "flake.lock.new"
        subprocess.run(
            [nix, "flake", "update", *inputs, "--flake", f"path:{flake}",
             "--output-lock-file", str(lock), "--override-input", "host", f"path:{flake}/nix/fixtures/host"],
            check=True,
        )
        # The fixture is only for resolution. Preserve the embedded lock's
        # relative host node so lock_diff does not report a synthetic update.
        resolved = json.loads(lock.read_text())
        host = resolved["nodes"][resolved["root"]]["inputs"]["host"]
        original_host = original["nodes"][original["root"]]["inputs"]["host"]
        resolved["nodes"][host] = original["nodes"][original_host]
        lock.write_text(json.dumps(resolved, indent=2) + "\n")
        # Atomic replacement also replaces a stale output symlink itself.
        os.replace(lock, OUTPUT / "flake.lock.new")
    print(OUTPUT / "flake.lock.new")


def main():
    try:
        preview(sys.argv[1], sys.argv[2:6], sys.argv[6:])
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"flake-update-preview: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
