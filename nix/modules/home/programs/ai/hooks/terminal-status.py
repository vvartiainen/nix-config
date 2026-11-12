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


def publish(app, state, kind, payload):
    if app == "codex":
        session = payload.get("session_id")
        if not isinstance(session, str) or not session:
            return
        launch = f"codex:{session}"
        # The hook shell execs this reporter, so its parent is Codex itself
        # (the shared daemon or the embedded CLI), not a short-lived shell.
        pid = os.getppid()
    else:
        launch = os.environ.get("NIX_CONFIG_AGENT_LAUNCH", "")
        pid = os.environ.get("NIX_CONFIG_AGENT_PID", "")
    if not launch:
        return
    if state not in {"working", "blocked"}:
        clear(launch)
        return
    try:
        directory = state_directory()
        record = {
            "app": app, "state": state, "kind": kind,
            "cwd": str(payload.get("cwd") or os.getcwd()),
            "pid": int(pid),
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


def active_records(directory):
    records = []
    for path in sorted(directory.glob("*.json")):
        try:
            record = json.loads(path.read_text())
            # Records from the previous reporter only represented blocked agents.
            record.setdefault("state", "blocked")
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
            state = "working" if name == "agent_status.running" else "blocked"
            records = [r for r in active_records(directory) if r["state"] == state]
            if not records:
                bar_command("--set", name, "drawing=off", "popup.drawing=off",
                            "--remove", f"/^{name.replace('.', '[.]')}[.]detail[.].*/")
                return
            arguments = ["--set", name, "drawing=on", f"label={len(records)}"]
            if sender == "mouse.clicked":
                other = "agent_status" if state == "working" else "agent_status.running"
                arguments += ["popup.drawing=toggle", "--set", other, "popup.drawing=off"]
            elif sender == "mouse.exited.global":
                arguments += ["popup.drawing=off"]
            arguments += ["--remove", f"/^{name.replace('.', '[.]')}[.]detail[.].*/"]
            for index, record in enumerate(records):
                action = "running" if state == "working" else {
                    "permission": "approval", "question": "answer", "auth": "sign in",
                }.get(record["kind"], "input")
                # Keep session text in one label argument, never a shell command.
                project = " ".join(str(record["cwd"]).split())
                label = f"{record['app']}: {action} · {project}"
                item = f"{name}.detail.{index}"
                arguments += ["--add", "item", item, f"popup.{name}", "--set", item,
                              "icon.drawing=off", "label.font=SF Pro:Regular:12.0",
                              "label.max_chars=90", "label.padding_left=10",
                              "label.padding_right=10", f"label={label}"]
            bar_command(*arguments)
    except (OSError, ValueError, KeyError, TypeError):
        pass


def report(app, state, kind):
    # Codex's TUI emits OSC 7501 itself, including with a shared daemon.
    # A daemon's inherited terminal/socket/window can belong to another client.
    terminal = "" if app == "codex" else os.environ.get("NIX_CONFIG_AGENT_TTY", "")
    # Ignore subagent hook events; they must not replace the main pane status.
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        payload = {}
    if not isinstance(payload, dict):
        return
    if payload.get("agent_id") or payload.get("agentId"):
        return
    # Async questions return before the user answers. That tool completion
    # must not immediately erase the waiting state set by PreToolUse.
    if (app == "codex" and state == "working"
            and payload.get("hook_event_name") == "PostToolUse"
            and payload.get("tool_name") == "request_user_input_async"):
        return
    if app not in {"codex", "claude", "copilot"}:
        return
    if state not in {"idle", "working", "done", "blocked", "error", "clear"}:
        return
    # SketchyBar delivery is independent of Kitty or terminal-device access.
    publish(app, state, kind, payload)
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
    if sys.argv[1] == "report":
        report(*sys.argv[2:])
    elif sys.argv[1] == "clear":
        clear(*sys.argv[2:])
    elif sys.argv[1] == "sketchybar":
        render_bar(*sys.argv[2:])
