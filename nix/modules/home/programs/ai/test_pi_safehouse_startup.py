"""Check launch-path validation without credentials or a nested OS sandbox."""

import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


module_spec = importlib.util.spec_from_file_location(
    "pi_safehouse", Path(__file__).with_name("pi-safehouse.py")
)
launcher = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(launcher)


class StartupTests(unittest.TestCase):
    def test_optional_paths_and_first_launch_directories(self):
        for include_existing in (True, False):
            with self.subTest(include_existing=include_existing), tempfile.TemporaryDirectory() as scratch:
                root = Path(scratch).resolve()
                existing = root / "existing"
                existing.mkdir()
                missing = root / ".gitconfig"
                broken = root / "broken-profile"
                broken.symlink_to(root / "absent-target")
                agent = root / "state"
                cache = root / "cache"
                readable = [str(missing), str(broken)]
                if include_existing:
                    readable.append(str(existing))
                spec = root / "spec.json"
                spec.write_text(json.dumps({
                    "agentDir": str(agent), "readable": readable,
                    "writable": [str(agent), str(cache)], "denied": [],
                    "protected": [], "env": {},
                }))

                def strict_safehouse(command, env):
                    self.assertIn("--enable=clipboard", command)
                    grants = []
                    for arg in command:
                        if arg.startswith(("--add-dirs=", "--add-dirs-ro=")):
                            paths = arg.split("=", 1)[1].split(":")
                            self.assertTrue(all(path and Path(path).exists() for path in paths))
                            if arg.startswith("--add-dirs-ro="):
                                grants.extend(paths)
                    self.assertEqual(grants, [str(existing)] if include_existing else [])
                    self.assertTrue(agent.is_dir())
                    self.assertTrue(cache.is_dir())
                    self.assertFalse(missing.exists())
                    self.assertEqual(command[-2:], ["pi", "--version"])
                    return 0

                with (
                    patch.object(launcher.sys, "argv", ["launcher", str(spec), "safehouse", "pi", "--version"]),
                    patch.object(launcher.Path, "cwd", return_value=root),
                    patch.dict(os.environ, {"HOME": str(root / "home"), "TMPDIR": str(root)}),
                    patch.object(launcher.subprocess, "call", side_effect=strict_safehouse) as run,
                ):
                    self.assertEqual(launcher.main(), 0)
                    run.assert_called_once()


if __name__ == "__main__":
    unittest.main()
