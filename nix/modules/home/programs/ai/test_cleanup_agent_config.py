"""Run with the cleanup package's Python interpreter."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import sys

import tomlkit

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "cleanup", Path(__file__).with_name("cleanup-agent-config.py")
)
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)


class CleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "user"
        self.xdg = self.root / "config"
        self.state = self.root / "state"

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def run_cleanup(self, dry_run=False):
        job = cleanup.Cleanup(self.home, self.xdg, self.state, dry_run)
        with contextlib.redirect_stdout(io.StringIO()):
            job.run()
        return job

    def test_global_tools_and_unrelated_state(self):
        codex = self.write(self.home / ".codex/config.toml", '''# keep comment
model = "test"
[projects."/project"]
trust_level = "trusted"
[[skills.config]]
path = "/user/.codex/skills/.system/skill-creator/SKILL.md"
enabled = true
[[skills.config]]
path = "/project/.agents/skills/project/SKILL.md"
enabled = true
[mcp_servers.global]
command = "test"
[plugins."extra@market"]
enabled = true
[profiles.work.mcp_servers.other]
command = "other"
[profiles.work.plugins."extra@market"]
enabled = true
''')
        claude = self.write(self.home / ".claude/settings.json", json.dumps({
            "enabledPlugins": {"extra@market": True}, "model": "keep",
        }))
        copilot = self.write(self.home / ".copilot/config.json", json.dumps({
            "installedPlugins": [{"name": "extra", "enabled": True}],
            "loggedInUsers": ["keep"], "trustedFolders": ["keep"],
        }))
        opencode = self.write(self.xdg / "opencode/opencode.jsonc", '''{
// comment accepted
"mcp": {"global": {}}, "plugin": ["extra"],
"skills": {"paths": ["/extra"]}, "model": "keep",
}''')
        mcp_files = [
            self.home / ".claude.json", self.home / ".pi/agent/mcp.json",
            self.home / ".copilot/mcp-config.json",
            self.xdg / "cursor/mcp.json", self.home / ".cursor/mcp.json",
        ]
        for path in mcp_files:
            self.write(path, '{"mcpServers":{"global":{}},"keep":true}')
        project = self.write(self.home / "repo/.codex/config.toml", "keep")
        auth = self.write(self.home / ".codex/auth.json", "keep")
        history = self.write(self.home / ".codex/history.jsonl", "keep")
        skill = self.write(self.home / ".agents/skills/tool/SKILL.md", "keep")
        system = self.write(
            self.home / ".codex/skills/.system/tool/SKILL.md", "keep"
        )
        original = codex.read_text()
        self.run_cleanup(dry_run=True)
        self.assertEqual(codex.read_text(), original)
        self.assertTrue(skill.exists())
        self.assertFalse(self.state.exists())

        job = self.run_cleanup()
        data = tomlkit.parse(codex.read_text())
        self.assertNotIn("mcp_servers", data)
        self.assertEqual(len(data["skills"]["config"]), 1)
        self.assertFalse(data["skills"]["config"][0]["enabled"])
        self.assertNotIn("mcp_servers", data["profiles"]["work"])
        self.assertFalse(data["plugins"]["extra@market"]["enabled"])
        self.assertFalse(
            data["profiles"]["work"]["plugins"]["extra@market"]["enabled"]
        )
        self.assertEqual(data["projects"]["/project"]["trust_level"], "trusted")
        self.assertIn("# keep comment", codex.read_text())
        self.assertFalse(json.loads(claude.read_text())["enabledPlugins"][
            "extra@market"
        ])
        data = json.loads(copilot.read_text())
        self.assertEqual(data["installedPlugins"], [])
        self.assertEqual(data["loggedInUsers"], ["keep"])
        self.assertEqual(data["trustedFolders"], ["keep"])
        self.assertEqual(json.loads(opencode.read_text()), {"model": "keep"})
        for path in mcp_files:
            self.assertEqual(json.loads(path.read_text()), {"keep": True})
        for path in [project, auth, history, system]:
            self.assertEqual(path.read_text(), "keep")
        self.assertFalse(skill.exists())
        backup = job.backup / str(codex).lstrip("/")
        self.assertEqual(backup.read_text(), original)
        self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
        self.assertIsNone(self.run_cleanup().backup)

    def test_invalid_config_stops_before_writes(self):
        first = self.write(self.home / ".codex/config.toml", "mcp_servers={}")
        self.write(self.xdg / "opencode/opencode.jsonc", "broken {")
        with self.assertRaises(ValueError):
            self.run_cleanup()
        self.assertEqual(first.read_text(), "mcp_servers={}")
        self.assertFalse(self.state.exists())

    def test_symlinks_preserve_targets(self):
        target = self.write(self.root / "source/config.toml", "mcp_servers={}")
        link = self.home / ".codex/config.toml"
        link.parent.mkdir(parents=True)
        link.symlink_to(target)
        skill = self.write(self.root / "source/skills/tool/SKILL.md", "keep")
        skill_link = self.home / ".agents/skills"
        skill_link.parent.mkdir(parents=True)
        skill_link.symlink_to(skill.parent.parent)
        job = self.run_cleanup()
        self.assertFalse(link.is_symlink())
        self.assertEqual(target.read_text(), "mcp_servers={}")
        self.assertEqual(skill.read_text(), "keep")
        self.assertFalse(skill_link.exists())
        self.assertTrue((job.backup / str(skill_link).lstrip("/")).is_symlink())


if __name__ == "__main__":
    unittest.main()
