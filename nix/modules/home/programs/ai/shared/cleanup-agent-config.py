"""Reset global MCP registrations; preserve user-managed skills and plugins."""

import argparse
import copy
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

import json5
import tomlkit
from agent_config_validation import config_files, validate


def clear_keys(data, keys):
    for key in keys:
        data.pop(key, None)


def codex_tools(data):
    clear_keys(data, ["mcp_servers"])
    for profile in data.get("profiles", {}).values():
        codex_tools(profile)


def opencode_tools(data):
    clear_keys(data, ["mcp"])


class Cleanup:
    def __init__(self, home, config_home, state_home, dry_run=False):
        self.home = home
        self.config_home = config_home
        self.state_home = state_home
        self.dry_run = dry_run
        self.backup = None

    def backup_path(self, path):
        if self.backup is None:
            # Keep only the latest run that changed something.
            self.backup = self.state_home / "nix-config/agent-config-backup"
            if self.backup.exists():
                shutil.rmtree(self.backup)
            self.backup.mkdir(parents=True, mode=0o700)
        # Paths may live outside HOME through XDG. Mirror their absolute
        # location to avoid collisions without following directory symlinks.
        target = self.backup / str(path).lstrip("/")
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        return target

    def edit(self, path, transform, check_only=False):
        if not path.exists():
            return
        text = path.read_text()
        is_toml = path.suffix == ".toml"
        data = tomlkit.parse(text) if is_toml else json5.loads(text)
        if not isinstance(data, dict):
            raise ValueError(f"expected an object in {path}")
        before = copy.deepcopy(data)
        transform(data)
        schema = next((schema for file, _, schema in
                       config_files(self.home, self.config_home)
                       if file == path), None)
        validate(data, schema, path)
        if check_only or data == before:
            return
        print(f"{'would clean' if self.dry_run else 'cleaning'} {path}")
        if self.dry_run:
            return
        backup = self.backup_path(path)
        # Back up the contents, including those of a former Nix store link.
        shutil.copyfile(path, backup)
        backup.chmod(0o600)
        output = tomlkit.dumps(data) if is_toml else (
            json.dumps(data, indent=2, ensure_ascii=False) + "\n"
        )
        mode = 0o600 if path.is_symlink() else path.stat().st_mode & 0o777
        fd, tmp = tempfile.mkstemp(prefix=".agent-config-", dir=path.parent)
        try:
            with os.fdopen(fd, "w") as handle:
                handle.write(output)
            os.chmod(tmp, mode)
            os.replace(tmp, path)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

    def run(self):
        home, xdg = self.home, self.config_home
        edits = [
            (home / ".codex/config.toml", codex_tools),
            (home / ".claude.json", lambda d: clear_keys(d, ["mcpServers"])),
            (home / ".claude/.claude.json",
             lambda d: clear_keys(d, ["mcpServers"])),
            (xdg / "opencode/opencode.json", opencode_tools),
            (xdg / "opencode/opencode.jsonc", opencode_tools),
        ]
        for path in [
            home / ".pi/agent/mcp.json",
            home / ".copilot/mcp-config.json",
            xdg / "cursor/mcp.json",
            home / ".cursor/mcp.json",
        ]:
            edits.append((path, lambda d: clear_keys(d, ["mcpServers"])))
        # Parse and validate every file before making any changes. A malformed
        # config must never be replaced by defaults or silently ignored.
        for path, transform in edits:
            self.edit(path, transform, check_only=True)
        for path, transform in edits:
            self.edit(path, transform)

        if self.backup:
            print(f"Backups: {self.backup}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run", action="store_true", help="show changes only"
    )
    args = parser.parse_args()
    home = Path.home()
    cleanup = Cleanup(
        home,
        Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")),
        Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")),
        args.dry_run,
    )
    try:
        cleanup.run()
    except (OSError, ValueError, TypeError, AttributeError) as error:
        sys.exit(f"cleanup-agent-config: {error}")


if __name__ == "__main__":
    main()
