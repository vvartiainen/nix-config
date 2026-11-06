"""Merge registered agent hooks while preserving unrelated settings and handlers."""

import json
import os
from pathlib import Path
import sys
import tempfile


def install(source, destination, *markers):
    if not markers or any(not marker for marker in markers):
        raise ValueError("managed hook command markers are required")
    path = Path(destination)
    current = json.loads(path.read_text()) if path.exists() else {}
    hooks = current.setdefault("hooks", {})
    # Store paths change on upgrades; identify our commands by stable fragments.
    for event, groups in hooks.items():
        kept = []
        for group in groups:
            if "hooks" in group:
                group["hooks"] = [
                    hook
                    for hook in group["hooks"]
                    if not any(marker in hook.get("command", "") for marker in markers)
                ]
                if group["hooks"]:
                    kept.append(group)
            else:
                kept.append(group)
        hooks[event] = kept
    for event, groups in json.loads(Path(source).read_text())["hooks"].items():
        hooks.setdefault(event, []).extend(groups)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=".agent-hooks-")
    try:
        with os.fdopen(fd, "w") as out:
            json.dump(current, out, indent=2)
            out.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    install(*sys.argv[1:])
