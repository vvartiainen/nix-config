"""Check hook upgrades, coexistence and preservation of unrelated settings."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("agent-hooks.py")
spec = importlib.util.spec_from_file_location("agent_hooks", SCRIPT)
hooks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hooks)

STATUS = "/bin/nix-config-terminal-status report "
CHECK = "/bin/nix-config-check --hook "


class AgentHooksTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.source = Path(self.scratch.name) / "hooks.json"
        self.target = Path(self.scratch.name) / "settings.json"

    def test_upgrade_both_consumers_preserves_vendor_hooks_and_other_settings(self):
        vendor = {"type": "command", "command": "vendor-hook"}
        prompt = {"type": "prompt", "prompt": "Review the result"}
        old_status = {"type": "command", "command": "/old" + STATUS + "claude done none"}
        old_check = {"type": "command", "command": "/old" + CHECK + "stop"}
        new_status = {"type": "command", "command": "/new" + STATUS + "claude done none"}
        new_check = {"type": "command", "command": "/new" + CHECK + "stop"}
        self.target.write_text(
            json.dumps(
                {
                    "model": "fixture",
                    "hooks": {
                        "Stop": [{"hooks": [vendor, old_status]}, {"hooks": [old_check, prompt]}],
                        "SessionStart": [{"hooks": [vendor]}],
                    },
                }
            )
        )
        self.source.write_text(
            json.dumps(
                {
                    "hooks": {
                        "Stop": [{"hooks": [new_status]}, {"hooks": [new_check]}],
                    }
                }
            )
        )
        hooks.install(self.source, self.target, STATUS, CHECK)
        first = self.target.read_text()
        hooks.install(self.source, self.target, STATUS, CHECK)
        self.assertEqual(self.target.read_text(), first)
        data = json.loads(first)
        self.assertEqual(data["model"], "fixture")
        self.assertEqual(data["hooks"]["SessionStart"], [{"hooks": [vendor]}])
        self.assertEqual(
            data["hooks"]["Stop"],
            [
                {"hooks": [vendor]},
                {"hooks": [prompt]},
                {"hooks": [new_status]},
                {"hooks": [new_check]},
            ],
        )

    def test_removed_event_handlers_are_cleaned_up(self):
        self.target.write_text(
            json.dumps(
                {
                    "hooks": {
                        "Stop": [
                            {
                                "hooks": [
                                    {"type": "command", "command": "/old" + CHECK + "stop"},
                                ]
                            }
                        ]
                    }
                }
            )
        )
        self.source.write_text('{"hooks": {}}')
        hooks.install(self.source, self.target, CHECK)
        self.assertEqual(json.loads(self.target.read_text()), {"hooks": {"Stop": []}})

    def test_install_creates_missing_parent_and_preserves_flat_foreign_handlers(self):
        self.target = self.target.parent / "nested/settings.json"
        self.source.write_text('{"hooks": {"Stop": [{"hooks": []}]}}')
        hooks.install(self.source, self.target, CHECK)
        foreign = {"type": "command", "command": "foreign-flat-handler"}
        self.target.write_text(json.dumps({"hooks": {"Stop": [foreign]}}))
        hooks.install(self.source, self.target, CHECK)
        self.assertEqual(json.loads(self.target.read_text())["hooks"]["Stop"][0], foreign)

    def test_invalid_source_or_empty_marker_does_not_overwrite_config(self):
        self.target.write_text('{"model": "fixture"}')
        self.source.write_text("invalid JSON")
        for markers, error in (((CHECK,), ValueError), ((), ValueError), (("",), ValueError)):
            with self.assertRaises(error):
                hooks.install(self.source, self.target, *markers)
            self.assertEqual(self.target.read_text(), '{"model": "fixture"}')


if __name__ == "__main__":
    unittest.main()
