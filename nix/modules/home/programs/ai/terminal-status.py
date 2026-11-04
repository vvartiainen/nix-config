"""Report agent lifecycle events independently to Kitty and SketchyBar."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile


MARKER = "/bin/nix-config-terminal-status report "


def state_directory():
    # Shared by sandboxed hooks and SketchyBar, with no home-directory grants.
    directory = Path(f"/tmp/nix-config-agent-status-{os.getuid()}")
    directory.mkdir(mode=0o700, exist_ok=True)
    info = directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise OSError("agent status directory must be private and owned by this user")
    return directory


def state_path(directory, launch):
    return directory / (hashlib.sha256(launch.encode()).hexdigest() + ".json")


def run_quietly(arguments):
    try:
        subprocess.run(arguments, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=0.5, check=False)
    except (OSError, subprocess.TimeoutExpired):
        pass


def bar_command(*arguments):
    executable = os.environ.get("NIX_CONFIG_SKETCHYBAR", "")
    if executable:
        run_quietly([executable, *arguments])


def clear(launch):
    try:
        state_path(state_directory(), launch).unlink()
    except OSError:
        return
    bar_command("--trigger", "agent_status_update")


def publish(app, state, kind, payload, terminal):
    launch = os.environ.get("NIX_CONFIG_AGENT_LAUNCH", "")
    if not launch:
        return
    if state != "blocked":
        clear(launch)
        return
    try:
        directory = state_directory()
        record = {
            "app": app, "kind": kind,
            "cwd": str(payload.get("cwd") or os.getcwd()),
            "pid": int(os.environ["NIX_CONFIG_AGENT_PID"]),
            "socket": os.environ.get("KITTY_LISTEN_ON", "") if terminal else "",
            "window": os.environ.get("KITTY_WINDOW_ID", "") if terminal else "",
        }
        fd, temporary = tempfile.mkstemp(dir=directory, prefix=".status-")
        try:
            with os.fdopen(fd, "w") as out:
                json.dump(record, out)
            os.replace(temporary, state_path(directory, launch))
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    except (OSError, KeyError, ValueError):
        return
    bar_command("--trigger", "agent_status_update")


def waiting_records(directory):
    records = []
    for path in sorted(directory.glob("*.json")):
        try:
            record = json.loads(path.read_text())
            pid = record["pid"]
            if not isinstance(pid, int) or pid <= 0:
                raise ValueError("invalid process id")
            os.kill(pid, 0)
            records.append(record)
        except (OSError, ValueError, KeyError, TypeError):
            path.unlink(missing_ok=True)
    return records


def render_bar(name, sender):
    try:
        directory = state_directory()
        # Serialize renderers so an older event cannot overwrite a newer label.
        with (directory / ".render.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            records = waiting_records(directory)
            if not records:
                bar_command("--set", name, "drawing=off")
                return
            first = records[0]
            if sender == "mouse.clicked":
                # The address was captured by the hook; never query Kitty.
                if first.get("socket", "").startswith("unix:") and str(first.get("window", "")).isdigit():
                    run_quietly(["/opt/homebrew/bin/kitten", "@", "--to", first["socket"],
                                 "focus-window", "--match", f"id:{first['window']}"])
                return
            action = {"permission": "approval", "question": "answer", "auth": "sign in"}.get(first["kind"], "input")
            project = Path(first["cwd"]).name or "/"
            label = f"{first['app']}: {action} · {project}"
            if len(records) > 1:
                label += f" (+{len(records) - 1})"
            bar_command("--set", name, "drawing=on", f"label={label}")
    except (OSError, ValueError, KeyError, TypeError):
        pass


def install(source, destination):
    path = Path(destination)
    current = json.loads(path.read_text()) if path.exists() else {}
    hooks = current.setdefault("hooks", {})
    # Store paths change on upgrades; recognize our executable's stable name.
    for event, groups in hooks.items():
        kept = []
        for group in groups:
            if "hooks" in group:
                group["hooks"] = [h for h in group["hooks"]
                                  if MARKER not in h.get("command", "")]
                if group["hooks"]:
                    kept.append(group)
            else:
                kept.append(group)
        hooks[event] = kept
    for event, groups in json.loads(Path(source).read_text())["hooks"].items():
        hooks.setdefault(event, []).extend(groups)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=".terminal-status-")
    try:
        with os.fdopen(fd, "w") as out:
            json.dump(current, out, indent=2)
            out.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def report(app, state, kind):
    terminal = os.environ.get("NIX_CONFIG_AGENT_TTY", "")
    # Ignore subagent hook events; they must not replace the main pane status.
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        payload = {}
    if not isinstance(payload, dict):
        return
    if payload.get("agent_id") or payload.get("agentId"):
        return
    if app not in {"codex", "claude", "copilot"}:
        return
    if state not in {"idle", "working", "done", "blocked", "error", "clear"}:
        return
    # SketchyBar delivery is independent of Kitty or terminal-device access.
    publish(app, state, kind, payload, terminal)
    if not terminal.startswith("/dev/tty"):
        return
    sequence = f"\033]7501;state={state}:app={app}"
    if kind in {"permission", "question", "auth"}:
        sequence += f":kind={kind}"
    sequence += "\033\\"
    try:
        fd = os.open(terminal, os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK)
        try:
            if stat.S_ISCHR(os.fstat(fd).st_mode) and os.isatty(fd):
                os.write(fd, sequence.encode())
        finally:
            os.close(fd)
    except OSError:
        pass  # Notification delivery must never fail an agent operation.


if __name__ == "__main__":
    if sys.argv[1] == "install":
        install(*sys.argv[2:])
    elif sys.argv[1] == "report":
        report(*sys.argv[2:])
    elif sys.argv[1] == "clear":
        clear(*sys.argv[2:])
    elif sys.argv[1] == "sketchybar":
        render_bar(*sys.argv[2:])
