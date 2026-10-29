"""Run with the validator/cleanup package's Python interpreter."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import agent_config_validation as validation

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "cleanup", Path(__file__).with_name("cleanup-agent-config.py")
)
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)
MERGE = Path(os.environ.get(
    "MERGE_CONFIG", Path(__file__).parents[2] / "merge-config.py"
))


class ValidationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "user"
        self.xdg = self.root / "config"
        self.state = self.root / "state/merged.json"

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def merge(self, path, settings, fmt="json", schema="claude"):
        source = self.write(self.root / "new.json", json.dumps(settings))
        return subprocess.run([
            sys.executable, str(MERGE), str(path), "--format", fmt,
            "--schema", schema, "--settings", str(source),
            "--state", str(self.state),
        ], capture_output=True, text=True)

    def test_real_schemas_reject_wrong_values(self):
        for schema, data in [
            ("codex", {"model": 12}),
            ("claude", {"permissions": {"allow": "wrong"}}),
            ("opencode", {"model": 12}),
            ("opencode-cli", {"theme": {"mode": "wrong"}}),
            ("opencode-tui", {"theme": 12}),
            ("pi-settings", {"defaultThinkingLevel": "typo"}),
            ("pi-keybindings", {"app.model.select": 12}),
            ("pi-models", {"providers": []}),
            ("pi-theme", {"name": 12}),
        ]:
            with self.subTest(schema=schema), self.assertRaises(ValueError):
                validation.validate(data, schema)

    def test_invalid_merged_runtime_value_preserves_config_and_state(self):
        path = self.write(self.home / "settings.json", '{"model": 12}')
        self.write(self.state, '{"effortLevel": "low"}')
        result = self.merge(path, {"effortLevel": "medium"})
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn("['model']", result.stderr)
        self.assertEqual(path.read_text(), '{"model": 12}')
        self.assertEqual(self.state.read_text(), '{"effortLevel": "low"}')

    def test_merge_validates_after_pruning_and_applying_settings(self):
        path = self.write(self.home / "config.toml", 'model = 12\nweb_search = 12\n')
        self.write(self.state, '{"web_search": 12}')
        result = self.merge(path, {"model": "test"}, "toml", "codex")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(validation.load(path), {"model": "test"})
        self.assertEqual(json.loads(self.state.read_text()), {"model": "test"})

    def test_jsonc_merges_keep_unmanaged_values(self):
        path = self.write(self.home / "settings.json", '{/*comment*/"model":"keep",}')
        result = self.merge(path, {"effortLevel": "medium"}, "jsonc")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(path.read_text()), {
            "model": "keep", "effortLevel": "medium",
        })

    def test_invalid_candidate_does_not_replace_symlink(self):
        target = self.write(self.root / "target.json", '{"model":"keep"}')
        link = self.home / "settings.json"
        link.parent.mkdir(parents=True)
        link.symlink_to(target)
        result = self.merge(link, {"model": 12})
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(link.is_symlink())
        self.assertEqual(target.read_text(), '{"model":"keep"}')
        self.assertFalse(self.state.exists())

    def test_cleanup_preflights_schema_failures_before_any_writes(self):
        first = self.write(self.home / ".codex/config.toml", "mcp_servers={}")
        self.write(self.xdg / "opencode/opencode.jsonc", '{"model":12}')
        for dry_run in [False, True]:
            with self.subTest(dry_run=dry_run), self.assertRaises(ValueError):
                cleanup.Cleanup(self.home, self.xdg, self.state, dry_run).run()
        self.assertEqual(first.read_text(), "mcp_servers={}")
        self.assertFalse(self.state.exists())

    def test_scan_reports_coverage_missing_and_multiple_failures(self):
        self.write(self.home / ".codex/config.toml", 'model = 12')
        self.write(self.xdg / "cursor/sandbox.json", '{}')
        self.write(self.home / ".claude/settings.json", '{"model":12}')
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            failures = validation.check_files(self.home, self.xdg)
        self.assertEqual(len(failures), 2)
        self.assertIn("parse only; no schema", output.getvalue())
        self.assertIn("missing:", output.getvalue())
        self.assertFalse(self.state.exists())

    def test_opencode_layer_does_not_hide_invalid_user_file(self):
        self.write(self.xdg / "opencode/opencode.jsonc", '{"model":12}')
        self.write(self.xdg / "opencode/home-manager.json", '{"model":"test/model"}')
        with contextlib.redirect_stdout(io.StringIO()):
            failures = validation.check_files(self.home, self.xdg)
        self.assertEqual(len(failures), 1)
        self.assertIn("opencode.jsonc", failures[0])

    def test_schema_uri_cannot_trigger_network_and_errors_hide_values(self):
        validation.validate({"$schema": "https://invalid.example/schema"}, "claude")
        with self.assertRaises(ValueError) as error:
            validation.validate({"model": ["secret-token"]}, "claude")
        self.assertNotIn("secret-token", str(error.exception))
        path = self.write(self.root / "broken.jsonc", '{"secret-token" broken}')
        with self.assertRaises(ValueError) as error:
            validation.load(path, "jsonc")
        self.assertNotIn("secret-token", str(error.exception))

    def test_cli_is_read_only_and_exits_nonzero_for_invalid_settings(self):
        path = self.write(self.home / ".claude/settings.json", '{"model":12}')
        args = [sys.executable, "-c",
                "from agent_config_validation import main; main()",
                "--home", str(self.home), "--config-home", str(self.xdg)]
        result = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("expected type string", result.stderr)
        self.assertEqual(path.read_text(), '{"model":12}')
        self.assertFalse(self.state.exists())
        path.write_text('{"model":"keep"}')
        result = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ok (claude)", result.stdout)


if __name__ == "__main__":
    unittest.main()
