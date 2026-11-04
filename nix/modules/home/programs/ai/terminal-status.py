"""Report agent lifecycle events to the launching Kitty terminal."""

import json
import os
from pathlib import Path
import stat
import sys
import tempfile


MARKER = "/bin/nix-config-terminal-status report "


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
    if not terminal.startswith("/dev/tty"):
        return
    # Ignore subagent hook events; they must not replace the main pane status.
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        payload = {}
    if payload.get("agent_id") or payload.get("agentId"):
        return
    if app not in {"codex", "claude", "copilot"}:
        return
    if state not in {"idle", "working", "done", "blocked", "error", "clear"}:
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
