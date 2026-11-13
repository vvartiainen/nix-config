"""Check launch-path validation without credentials or a nested OS sandbox."""

import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


module_spec = importlib.util.spec_from_file_location(
    "pi_safehouse", Path(__file__).resolve().parents[2] / "nix/modules/home/programs/ai/clients/pi/pi-safehouse.py"
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

    def test_home_and_root_do_not_grant_the_working_directory(self):
        # Host apps probe the CLI from $HOME; that must start, but must not make
        # the home directory (or /) the writable workspace.
        for name in ("home", "root"):
            with self.subTest(name), tempfile.TemporaryDirectory() as scratch:
                root = Path(scratch).resolve()
                home = root / "home"
                home.mkdir()
                agent = root / "state"
                cache = root / "cache"
                spec = root / "spec.json"
                spec.write_text(json.dumps({
                    "agentDir": str(agent), "readable": [],
                    "writable": [str(agent), str(cache)], "denied": [],
                    "protected": [], "env": {},
                }))
                cwd = home if name == "home" else Path("/")

                def capture(command, env):
                    grants = []
                    for arg in command:
                        if arg.startswith(("--add-dirs=", "--add-dirs-ro=")):
                            grants.extend(arg.split("=", 1)[1].split(":"))
                    self.assertNotIn(str(home), grants)
                    self.assertNotIn("/", grants)
                    workdir = next(a for a in command if a.startswith("--workdir="))
                    self.assertNotIn(str(home), workdir)
                    self.assertNotEqual(workdir, "--workdir=/")
                    return 0

                with (
                    patch.object(launcher.sys, "argv", ["launcher", str(spec), "safehouse", "pi", "--version"]),
                    patch.object(launcher.Path, "cwd", return_value=cwd),
                    patch.dict(os.environ, {"HOME": str(home), "TMPDIR": str(root)}),
                    patch.object(launcher.subprocess, "call", side_effect=capture) as run,
                ):
                    self.assertEqual(launcher.main(), 0)
                    run.assert_called_once()

    def test_t3_session_variables_reach_the_sandboxed_process(self):
        # T3 Code hands its MCP endpoint, runtime mode and injected extension to
        # Pi through T3_* variables; unrelated host variables stay withheld.
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            agent = root / "state"
            cache = root / "cache"
            spec = root / "spec.json"
            spec.write_text(json.dumps({
                "agentDir": str(agent), "readable": [],
                "writable": [str(agent), str(cache)], "denied": [],
                "protected": [], "env": {},
            }))
            passed = []

            def capture(command, env):
                value = next(a for a in command if a.startswith("--env-pass="))
                passed.extend(value.split("=", 1)[1].split(","))
                return 0

            with (
                patch.object(launcher.sys, "argv", ["launcher", str(spec), "safehouse", "pi"]),
                patch.object(launcher.Path, "cwd", return_value=root),
                patch.dict(os.environ, {
                    "HOME": str(root / "home"),
                    "TMPDIR": str(root),
                    "T3_PI_RUNTIME_MODE": "approval-required",
                    "T3_MCP_URL": "http://127.0.0.1:3773/mcp",
                    "SYNTHETIC_HOST_SECRET": "must-not-pass",
                }),
                patch.object(launcher.subprocess, "call", side_effect=capture),
            ):
                self.assertEqual(launcher.main(), 0)
        self.assertIn("T3_PI_RUNTIME_MODE", passed)
        self.assertIn("T3_MCP_URL", passed)
        self.assertNotIn("SYNTHETIC_HOST_SECRET", passed)

    def test_path_entries_resolve_away_from_profile_symlinks(self):
        # Safehouse grants the store, not the profile symlinks PATH names, so a
        # lookup of `mcp-nixos` under ~/.nix-profile/bin fails with EPERM.
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            store_bin = root / "store" / "profile" / "bin"
            store_bin.mkdir(parents=True)
            profile = root / ".nix-profile"
            profile.symlink_to(root / "store" / "profile")
            plain = root / "bin"
            plain.mkdir()
            agent = root / "state"
            cache = root / "cache"
            spec = root / "spec.json"
            spec.write_text(json.dumps({
                "agentDir": str(agent), "readable": [],
                "writable": [str(agent), str(cache)], "denied": [],
                "protected": [], "env": {},
            }))
            captured = {}

            def capture(command, env):
                captured["path"] = env["PATH"]
                return 0

            with (
                patch.object(launcher.sys, "argv", ["launcher", str(spec), "safehouse", "pi"]),
                patch.object(launcher.Path, "cwd", return_value=root),
                patch.dict(os.environ, {
                    "HOME": str(root / "home"),
                    "TMPDIR": str(root),
                    "PATH": f"{profile / 'bin'}:{plain}:{root / 'absent'}:{plain}",
                }),
                patch.object(launcher.subprocess, "call", side_effect=capture),
            ):
                self.assertEqual(launcher.main(), 0)
        self.assertEqual(captured["path"], f"{store_bin}:{plain}")


if __name__ == "__main__":
    unittest.main()
