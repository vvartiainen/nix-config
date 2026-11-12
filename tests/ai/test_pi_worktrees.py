"""Verify Pi grants only the Git metadata needed by linked worktrees."""

import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[2] / "nix/modules/home/programs/ai/pi-safehouse.py"
spec = importlib.util.spec_from_file_location("pi_safehouse", SCRIPT)
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class PiWorktreeTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name).resolve()
        self.repo = self.root / "main repo"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "--allow-empty",
            "-qm",
            "fixture",
        )
        self.worktree = self.root / "linked worktree"
        self.git("worktree", "add", "--detach", str(self.worktree))

    def git(self, *args):
        return subprocess.check_output(
            ["git", "-c", "core.hooksPath=/dev/null", "-C", str(self.repo), *args],
            stderr=subprocess.PIPE,
            text=True,
        ).removesuffix("\n")

    def test_main_checkout_and_non_repository_need_no_extra_grants(self):
        self.assertEqual(launcher.worktree_git_dirs(self.repo), [])
        self.assertEqual(launcher.worktree_git_dirs(self.root), [])

    def test_linked_worktree_grants_only_shared_and_per_worktree_git_dirs(self):
        common, current = launcher.worktree_git_dirs(self.worktree)
        self.assertEqual(common, str(self.repo / ".git"))
        self.assertEqual(Path(current).parent, self.repo / ".git/worktrees")
        self.assertNotIn(str(self.repo), (common, current))

    def test_launcher_passes_grants_and_keeps_hooks_and_configs_protected(self):
        spec_path = self.root / "spec.json"
        agent = self.root / "agent"
        spec_path.write_text(
            json.dumps(
                {
                    "agentDir": str(agent),
                    "readable": [],
                    "writable": [str(agent)],
                    "denied": [],
                    "protected": [],
                    "env": {},
                }
            )
        )
        captured = {}

        def launch(command, **kwargs):
            captured["command"] = command
            overlay = next(
                arg.split("=", 1)[1] for arg in command if arg.startswith("--append-profile=")
            )
            captured["profile"] = Path(overlay).read_text()
            return 0

        with (
            patch.object(launcher.sys, "argv", [str(SCRIPT), str(spec_path), "safehouse", "pi"]),
            patch.object(launcher.Path, "cwd", return_value=self.worktree),
            patch.object(launcher.subprocess, "call", side_effect=launch),
        ):
            self.assertEqual(launcher.main(), 0)
        grants = next(arg for arg in captured["command"] if arg.startswith("--add-dirs="))
        for directory in launcher.worktree_git_dirs(self.worktree):
            self.assertIn(directory, grants)
            for name in ("hooks", "config", "config.worktree"):
                self.assertIn(
                    f"(deny file-write* {launcher.subpath(Path(directory) / name)})",
                    captured["profile"],
                )
        self.assertNotIn(launcher.subpath(self.repo) + ")", captured["profile"])


if __name__ == "__main__":
    unittest.main()
