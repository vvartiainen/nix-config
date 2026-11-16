"""Fixed Git maintenance operations inside a fresh, non-networked Seatbelt.

The caller's environment and Git executable are never trusted. Only the Nix
launcher supplies the executable; no arbitrary git arguments pass through.
"""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import socket
import threading
from contextlib import contextmanager


def repository(cwd):
    for root in (cwd, *cwd.parents):
        dot = root / ".git"
        if dot.is_dir():
            common = dot.resolve()
            break
        if dot.is_file():
            pointer = dot.read_text().strip()
            if not pointer.startswith("gitdir: "):
                raise ValueError("invalid worktree pointer")
            metadata = (root / pointer[8:]).resolve()
            common = (metadata / (metadata / "commondir").read_text().strip()).resolve()
            break
    else:
        raise ValueError("run inside a Git working tree")
    # Only conventional non-bare repositories; no arbitrary metadata targets.
    if common.name != ".git" or not (common / "config").is_file():
        raise ValueError("expected a main checkout's .git directory")
    return root, common


def name(value):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}", value):
        raise ValueError("worktree names use letters, digits, _ and - (max 80)")
    return value


def ref(value):
    if (not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_./-]{0,199}", value)
            or ".." in value or "//" in value or value.endswith(("/", ".", ".lock"))):
        raise ValueError("expected a plain branch or remote-tracking ref")
    return value


def operation(args, common, check_paths=True):
    # A dedicated namespace excludes T3, Claude and Codex managed worktrees.
    managed = common.parent / ".agent-worktrees"
    if check_paths and managed.is_symlink():
        raise ValueError("managed directory must not be a symlink")
    if len(args) == 4 and args[:2] == ["worktree", "add"]:
        target = managed / name(args[2])
        if check_paths and (target.exists() or target.is_symlink()):
            raise ValueError("worktree already exists")
        return ["worktree", "add", "--no-track", "-b", "agent/" + args[2], str(target), ref(args[3])]
    if len(args) == 3 and args[:2] == ["worktree", "remove"]:
        target = managed / name(args[2])
        if check_paths and (target.is_symlink() or not target.is_dir()):
            raise ValueError("expected an existing managed worktree")
        # Git itself refuses dirty/locked worktrees; never pass --force.
        return ["worktree", "remove", str(target)]
    if len(args) == 4 and args[:2] == ["worktree", "move"]:
        source, target = (managed / name(value) for value in args[2:])
        if check_paths and (source.is_symlink() or target.exists() or target.is_symlink()):
            raise ValueError("expected a managed source and unused destination")
        return ["worktree", "move", str(source), str(target)]
    if len(args) == 3 and args[:2] == ["branch", "-d"]:
        return ["branch", "-d", ref(args[2])]
    if len(args) == 4 and args[:2] == ["branch", "-m"]:
        return ["branch", "-m", ref(args[2]), ref(args[3])]
    if len(args) == 4 and args[:2] == ["branch", "--set-upstream-to"]:
        return ["branch", "--set-upstream-to=" + ref(args[2]), ref(args[3])]
    if len(args) == 3 and args[:2] == ["branch", "--unset-upstream"]:
        return ["branch", "--unset-upstream", ref(args[2])]
    raise ValueError("use: worktree add NAME START | worktree remove NAME | worktree move OLD NEW | "
                     "branch -d BRANCH | branch -m OLD NEW | "
                     "branch --set-upstream-to REMOTE/BRANCH BRANCH | branch --unset-upstream BRANCH")


def profile(common, git, config_write=False, root=None):
    def path(value):
        return json.dumps(str(value))

    # Git can read repository config, but cannot launch configured commands,
    # reach the network, touch user files, or write hooks. Only its own binary
    # may exec (worktree add re-execs git). Config updates are fixed builtins.
    reads = [common.parent, Path(git).resolve().parent.parent, "/nix/store", "/usr/lib",
             "/System", "/usr/share", "/private/var/db/dyld", "/Library/Apple", "/dev/null", "/dev/urandom"]
    if root is not None:
        reads.append(root)
    return "\n".join([
        "(version 1)", "(allow default)", "(deny network*)",
        # Branch builtins do not need children. Even a configured command that
        # names Git itself cannot exploit the brief config-write permission.
        *(["(deny process-fork)"] if config_write else []),
        "(deny process-exec (require-all "
        f"(require-not (literal {path(Path(git).resolve())})) "
        f"(require-not (literal {path(Path(git).resolve().parent.parent / 'libexec/git-core/git')}))))",
        '(deny file-read-data (require-all (require-not (literal "/")) '
        + " ".join(f"(require-not (subpath {path(p)}))" for p in reads) + "))",
        f"(deny file-write* (require-all (require-not (subpath {path(common)})) "
        f"(require-not (subpath {path(common.parent / '.agent-worktrees')})) "
        '(require-not (literal "/dev/null"))))',
        # Config.worktree and hooks stay protected even in this inner sandbox.
        '(deny file-write* (regex #"/(hooks|config\\.worktree)(/|$)"))',
        r'(deny file-write* (regex #"/worktrees/[^/]+/config(\.lock)?$"))',
        r'(deny file-read* (regex #"/(\.ssh|\.aws|\.gnupg)(/|$)|/\.env(\.[^/]*)?$|/[^/]+\.(pem|key)$"))',
        *([] if config_write else [
            f"(deny file-write* (literal {path(common / 'config')}) "
            f"(literal {path(common / 'config.lock')}))",
        ]),
    ])


def run(git, args, cwd, capture=False, expected_common=None):
    root, common = repository(cwd.resolve())
    if expected_common is not None and common != expected_common:
        raise ValueError("launch repository changed")
    argv = operation(args, common)
    env = {"PATH": str(Path(git).parent), "HOME": "/var/empty", "LC_ALL": "C",
           "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
           "GIT_TERMINAL_PROMPT": "0"}
    return subprocess.run([
        "/usr/bin/sandbox-exec", "-p", profile(common, git, config_write=argv[0] == "branch", root=root), git,
        "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false",
        "-c", "core.untrackedCache=false", "-c", "protocol.allow=never",
        "--no-pager", "-c", "core.pager=cat", "-C", str(root), *argv,
    ], env=env, check=False, capture_output=capture, text=True, timeout=60)


@contextmanager
def broker(git, cwd, directory):
    """Pi's launcher owns this server outside Safehouse for one session only.

    Clients supply just the fixed operation's arguments, never a cwd, binary,
    environment, sandbox profile or destination path. Bind to the launch repo.
    """
    _, common = repository(cwd.resolve())
    endpoint = str(Path(directory) / "git.sock")
    server = socket.socket(socket.AF_UNIX)
    server.bind(endpoint)
    os.chmod(endpoint, 0o600)
    server.listen(4)
    server.settimeout(0.2)
    stopped = threading.Event()

    def serve():
        while not stopped.is_set():
            try:
                connection, _ = server.accept()
            except socket.timeout:
                continue
            with connection:
                connection.settimeout(2)
                try:
                    payload = connection.makefile("rb").readline(8193)
                    if len(payload) > 8192:
                        raise ValueError("request too large")
                    args = json.loads(payload)
                    if not isinstance(args, list) or not all(isinstance(arg, str) for arg in args):
                        raise ValueError("expected argument list")
                    result = run(git, args, cwd, capture=True, expected_common=common)
                    response = [result.returncode, result.stdout, result.stderr]
                except (ValueError, OSError, subprocess.SubprocessError) as error:
                    response = [1, "", f"agent-git: {error}\n"]
                try:
                    connection.sendall(json.dumps(response).encode() + b"\n")
                except OSError:
                    pass

    worker = threading.Thread(target=serve, daemon=True)
    worker.start()
    try:
        yield endpoint
    finally:
        stopped.set()
        worker.join(timeout=65)
        server.close()


def client(endpoint, args):
    # Even an unsandboxed caller cannot turn the socket client into a general
    # host-service client using a forged environment variable.
    if (not re.fullmatch(r"/private/tmp/pi-safehouse-[A-Za-z0-9_-]+/git\.sock", endpoint)
            or str(Path(endpoint).resolve()) != endpoint):
        raise ValueError("expected a Pi session's maintenance socket")
    operation(args, Path("/synthetic/.git"), check_paths=False)
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(65)
        connection.connect(endpoint)
        connection.sendall(json.dumps(args).encode() + b"\n")
        code, stdout, stderr = json.loads(connection.makefile("rb").readline())
    print(stdout, end="")
    print(stderr, end="", file=sys.stderr)
    return code


if __name__ == "__main__":
    try:
        if os.environ.get("AGENT_GIT_SOCKET"):
            sys.exit(client(os.environ["AGENT_GIT_SOCKET"], sys.argv[2:]))
        sys.exit(run(sys.argv[1], sys.argv[2:], Path.cwd()).returncode)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        sys.exit(f"agent-git: {error}")
