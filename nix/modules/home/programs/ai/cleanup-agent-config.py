"""Reset global agent tools; projects opt into tools through ct agents."""

import argparse
import copy
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

import json5
import tomlkit


def clear_keys(data, keys):
    for key in keys:
        data.pop(key, None)


def disable_plugins(data, key):
    for name, value in data.get(key, {}).items():
        if isinstance(value, bool):
            data[key][name] = False
        elif isinstance(value, dict):
            value["enabled"] = False


def codex_tools(data):
    clear_keys(data, ["mcp_servers"])
    disable_plugins(data, "plugins")
    # Reset /skills toggles too. Keep disabled entries (including the paths
    # declared by Nix); remove global enable overrides for project skills.
    skills = data.get("skills", {})
    if "config" in skills:
        entries = []
        for entry in skills["config"]:
            path = Path(entry.get("path", ""))
            if ".system" in path.parts:
                entry["enabled"] = False
            if entry.get("enabled") is False:
                entries.append(entry)
        skills["config"] = entries
    for profile in data.get("profiles", {}).values():
        codex_tools(profile)


def claude_tools(data):
    disable_plugins(data, "enabledPlugins")


def copilot_tools(data):
    if "installedPlugins" in data:
        data["installedPlugins"] = []


def opencode_tools(data):
    clear_keys(data, ["mcp", "plugin", "skills"])


class Cleanup:
    def __init__(self, home, config_home, state_home, dry_run=False):
        self.home = home
        self.config_home = config_home
        self.state_home = state_home
        self.dry_run = dry_run
        self.backup = None

    def backup_path(self, path):
        if self.backup is None:
            root = self.state_home / "nix-config/agent-config-backups"
            root.mkdir(parents=True, exist_ok=True, mode=0o700)
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S-")
            self.backup = Path(tempfile.mkdtemp(prefix=stamp, dir=root))
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

    def archive_skills(self, path, keep_system=False):
        if not path.exists() and not path.is_symlink():
            return
        # Move the link itself; never change its target (possibly a project).
        entries = [path] if path.is_symlink() else sorted(path.iterdir())
        for entry in entries:
            if keep_system and entry.name == ".system":
                continue
            action = "would archive" if self.dry_run else "archiving"
            print(f"{action} {entry}")
            if not self.dry_run:
                shutil.move(str(entry), self.backup_path(entry))

    def run(self):
        home, xdg = self.home, self.config_home
        edits = [
            (home / ".codex/config.toml", codex_tools),
            (home / ".claude.json", lambda d: clear_keys(d, ["mcpServers"])),
            (home / ".claude/settings.json", claude_tools),
            (home / ".copilot/settings.json", claude_tools),
            (home / ".copilot/config.json", copilot_tools),
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

        for relative in [
            ".agents/skills", ".claude/skills", ".claude/commands",
            ".copilot/skills", ".cursor/skills", ".pi/agent/skills",
            ".pi/agent/extensions",
        ]:
            self.archive_skills(home / relative)
        self.archive_skills(xdg / "opencode/skills")
        self.archive_skills(xdg / "opencode/plugins")
        self.archive_skills(home / ".codex/skills", keep_system=True)
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
