"""Resolve the current flake to a fixed scratch lock, never its tracked lock."""

import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile


OUTPUT = Path("/private/tmp/flake-update-review")


def preview(nix, inputs):
    if any(not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", name) or name == "host" for name in inputs):
        raise ValueError("expected plain input names other than host; no flags or paths")
    repo = Path.cwd().resolve()
    fixture = repo / "nix/fixtures/host"
    if not (repo / "flake.nix").is_file() or not (fixture / "default.nix").is_file():
        raise ValueError("run from the repository root with nix/fixtures/host/default.nix")
    # Never hand Nix a caller-controlled output symlink. A private directory
    # prevents other users replacing entries between validation and rename.
    OUTPUT.mkdir(mode=0o700, exist_ok=True)
    info = OUTPUT.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError(f"{OUTPUT} must be an owned directory with mode 0700 (no symlink)")
    with tempfile.TemporaryDirectory(prefix="resolve-", dir=OUTPUT) as scratch:
        lock = Path(scratch) / "flake.lock.new"
        subprocess.run(
            [nix, "flake", "update", *inputs, "--flake", str(repo),
             "--output-lock-file", str(lock), "--override-input", "host", f"path:{fixture}"],
            check=True,
        )
        # Atomic replacement also replaces a stale output symlink itself.
        os.replace(lock, OUTPUT / "flake.lock.new")
    print(OUTPUT / "flake.lock.new")


def main():
    try:
        preview(sys.argv[1], sys.argv[2:])
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"flake-update-preview: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
