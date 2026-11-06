"""Read-only checks for changed repository files, also used by agent stop hooks."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time


VENDORED = ("dotfiles/yazi/flavors/", "dotfiles/yazi/plugins/")


def git(root, *args):
    return subprocess.check_output(
        ["git", "--literal-pathspecs", "-C", str(root), *args],
        stderr=subprocess.PIPE,
        timeout=5,
    )


def repository(cwd):
    return Path(os.fsdecode(git(cwd, "rev-parse", "--show-toplevel")).strip())


def selected_files(root, base=None, all_files=False):
    names = git(root, "ls-files", "--others", "--exclude-standard", "-z")
    if all_files:
        names += git(root, "ls-files", "--cached", "-z")
    else:
        names += git(root, "diff", "--name-only", "-z", base or "HEAD", "--")
        names += git(root, "diff", "--cached", "--name-only", "-z", base or "HEAD", "--")
    selected = []
    for name in sorted(set(os.fsdecode(names).split("\0")) - {""}):
        path = root / name
        if name.startswith(VENDORED) or path.suffix in {".key", ".pem"}:
            continue
        if path.name == ".env" or path.name.startswith(".env."):
            continue
        if not path.is_file() or any(p.is_symlink() for p in (path, *path.parents)):
            continue
        selected.append("./" + name)
    return selected


def shell_kind(path):
    with path.open("rb") as source:
        first_line = source.readline(512).decode(errors="replace")
    directive = re.match(r"# shellcheck shell=(bash|zsh|dash|ksh|sh)\b", first_line)
    if directive:
        return directive[1]
    if first_line.startswith("#!"):
        match = re.search(r"\b(bash|zsh|dash|ksh|sh)\b", first_line)
        if match:
            return match[1]
    return {".sh": "sh", ".bash": "bash", ".zsh": "zsh"}.get(path.suffix)


def commands(root, files, formatting=False, base=None):
    if files:
        yield ["git", "diff", "--check", base or "HEAD", "--", *files]
        yield ["git", "diff", "--cached", "--check", base or "HEAD", "--", *files]
    untracked = set(
        os.fsdecode(git(root, "ls-files", "--others", "--exclude-standard", "-z")).split("\0")
    )
    for path in files:
        if path[2:] in untracked:
            yield ["git", "diff", "--no-index", "--check", "--", "/dev/null", path]
    nix = [f for f in files if f.endswith(".nix")]
    for path in nix:
        yield ["statix", "check", path]
    if nix:
        yield ["deadnix", "--fail", *nix]
        if formatting:
            yield ["nixfmt", "--check", *nix]
    python = [f for f in files if f.endswith(".py")]
    if python:
        yield ["ruff", "check", "--no-cache", "--no-fix", *python]
        if formatting:
            yield ["ruff", "format", "--no-cache", "--check", *python]
    lua = [f for f in files if f.endswith(".lua")]
    if lua and formatting:
        yield ["stylua", "--check", "--search-parent-directories", *lua]
    for path in files:
        kind = shell_kind(root / path)
        if kind == "zsh":
            yield ["zsh", "-dfn", path]
        elif kind:
            yield [kind, "-n", path]
            yield ["shellcheck", path]
            if formatting:
                yield ["shfmt", "-i", "2", "-d", path]


def check(root, *, base=None, all_files=False, formatting=False):
    files = selected_files(root, base, all_files)
    failures = []
    deadline = time.monotonic() + 45
    for command in commands(root, files, formatting, base):
        try:
            result = subprocess.run(
                command,
                cwd=root,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                timeout=max(0.01, min(10, deadline - time.monotonic())),
                check=False,
            )
            # Git's no-index mode can return 1 for a clean added file simply
            # because /dev/null differs. Whitespace errors include diagnostics.
            clean_addition = (
                command[:4] == ["git", "diff", "--no-index", "--check"]
                and result.returncode == 1
                and not result.stdout
            )
            if result.returncode and not clean_addition:
                failures.append(" ".join(command) + "\n" + result.stdout)
        except (OSError, subprocess.TimeoutExpired) as error:
            failures.append(" ".join(command) + "\n" + str(error))
        if time.monotonic() >= deadline:
            failures.append("Validation exceeded 45 seconds; run checks manually.")
            break
    return "\n".join(failures)


def hook_state(root, session):
    directory = Path(tempfile.gettempdir()) / f"nix-config-check-{os.getuid()}"
    directory.mkdir(mode=0o700, exist_ok=True)
    info = directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise OSError("validation state directory must be private and owned by this user")
    key = hashlib.sha256(f"{root}\0{session}".encode()).hexdigest()
    return directory / key


def hook(event, configured_repository):
    payload = json.load(sys.stdin)
    if not isinstance(payload, dict) or payload.get("agent_id") or payload.get("agentId"):
        return {}
    if payload.get("stop_hook_active"):
        return {}
    cwd = payload.get("cwd")
    if not isinstance(cwd, str) or not cwd:
        return {}
    try:
        root = repository(cwd)
        actual = git(root, "rev-parse", "--path-format=absolute", "--git-common-dir")
        expected = git(
            configured_repository, "rev-parse", "--path-format=absolute", "--git-common-dir"
        )
    except (OSError, subprocess.SubprocessError):
        return {}  # Other repositories and non-repository sessions are unaffected.
    if actual != expected:
        return {}
    session = payload.get("session_id") or payload.get("sessionId")
    if not isinstance(session, str) or not session:
        return {}
    state = hook_state(root, session)
    if event == "end":
        state.unlink(missing_ok=True)
        return {}
    if event == "prompt":
        # Remember HEAD so a commit made before Stop cannot hide changed files.
        state.write_bytes(git(root, "rev-parse", "HEAD"))
        return {}
    base = state.read_text().strip() if state.exists() else None
    failure = check(root, base=base)
    if failure:
        return {
            "decision": "block",
            "reason": (
                "Repository checks failed. Fix issues caused by your changes and rerun "
                f"just lint --base {base or 'HEAD'}. Report pre-existing or unavailable checks without modifying "
                "unrelated files. Do not apply the system or run builds from this hook.\n"
                + failure[:12000]
            ),
        }
    return {}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("--all", action="store_true", help="check all owned files")
    scope.add_argument("--base", help="include changes since this Git revision")
    parser.add_argument(
        "--format", action="store_true", help="also check formatting; never write files"
    )
    parser.add_argument("--hook", choices=["prompt", "stop", "end"])
    parser.add_argument(
        "--repository", type=Path, help="restrict hooks to this repository and its worktrees"
    )
    args = parser.parse_args()
    if args.hook:
        if args.repository is None:
            parser.error("--hook requires --repository")
        try:
            output = hook(args.hook, args.repository)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            output = {"decision": "block", "reason": f"Repository validation unavailable: {error}"}
            if args.hook != "stop":
                print(output["reason"], file=sys.stderr)
                return 1
        print(json.dumps(output))
        return 0
    try:
        failure = check(
            repository(Path.cwd()), base=args.base, all_files=args.all, formatting=args.format
        )
    except (OSError, subprocess.SubprocessError) as error:
        failure = str(error)
    if failure:
        print(failure, file=sys.stderr)
        return 1
    print("Repository checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
