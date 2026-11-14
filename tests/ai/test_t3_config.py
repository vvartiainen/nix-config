"""Exercise the JSON activation merge without schema or TOML dependencies."""

import importlib.util
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[2] / "nix/modules/home/merge-config.py"
spec = importlib.util.spec_from_file_location("t3_merge_config", SCRIPT)
merge_config = importlib.util.module_from_spec(spec)
# T3 uses schema-free JSON. Full schema/TOML checks live in the full suite.
with patch.dict("sys.modules", {
    "tomli_w": SimpleNamespace(),
    "agent_config_validation": SimpleNamespace(
        parse=lambda data, fmt, path: json.loads(data), validate=lambda *args: None,
    ),
}):
    spec.loader.exec_module(merge_config)


class T3ConfigTests(unittest.TestCase):
    def test_provider_cache_override_survives_reapply_and_keeps_other_settings(self):
        providers = ("codex", "claudeAgent", "opencode", "pi")
        environment = [{
            "name": "XDG_CACHE_HOME", "value": "/Users/agent/.cache/xdg-agent",
            "sensitive": False,
        }]
        managed = {"providerInstances": {
            name: {"environment": environment}
            for name in providers
        }}
        # Also run against the realized fixture's t3-code.json after a build.
        if settings := os.environ.get("T3_CONFIG_SETTINGS"):
            managed = json.loads(Path(settings).read_text())
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            destination = root / "settings.json"
            source = root / "managed.json"
            state = root / "state.json"
            source.write_text(json.dumps(managed))
            destination.write_text(json.dumps({
                "providerInstances": {
                    "codex": {
                        "displayName": "Keep this name",
                        "environment": [{"name": "XDG_CACHE_HOME", "value": "/old"}],
                    },
                    "custom": {"driver": "codex", "environment": [{
                        "name": "CUSTOM", "value": "keep", "sensitive": False,
                    }]},
                },
                "unmanaged": True,
            }))
            args = [str(SCRIPT), str(destination), "--settings", str(source),
                    "--state", str(state)]
            for _ in range(2):
                with patch("sys.argv", args):
                    merge_config.main()
                result = json.loads(destination.read_text())
                for name in providers:
                    self.assertEqual(result["providerInstances"][name]["environment"], environment)
                self.assertEqual(result["providerInstances"]["codex"]["displayName"], "Keep this name")
                self.assertEqual(result["providerInstances"]["custom"]["environment"][0]["value"], "keep")
                self.assertTrue(result["unmanaged"])


if __name__ == "__main__":
    unittest.main()
