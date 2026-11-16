"""Validate the broker grammar; opt-in macOS runtime uses only synthetic repos."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "nix/modules/home/programs/ai/shared/agent-git.py"
spec = importlib.util.spec_from_file_location("agent_git", SCRIPT)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class GrammarTests(unittest.TestCase):
    def test_only_fixed_operations(self):
        common = Path("/synthetic/repo/.git")
        for args in (["config", "core.hooksPath", "/tmp/evil"],
                     ["branch", "-D", "main"], ["worktree", "remove", "../live"],
                     ["worktree", "add", "x", "--config=alias.x=!sh"],
                     ["branch", "--set-upstream-to", "file:///tmp/x", "main"],
                     ["worktree", "move", "x", "/tmp/y"],
                     ["branch", "-d", "x", "main"]):
            with self.subTest(args=args), self.assertRaises(ValueError):
                helper.operation(args, common)
        self.assertEqual(helper.operation(["branch", "-d", "feature/topic"], common),
                         ["branch", "-d", "feature/topic"])
        self.assertIn("/synthetic/repo/.agent-worktrees/topic",
                      helper.operation(["worktree", "add", "topic", "origin/main"], common))

    def test_symlink_destination_is_rejected(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            (root / ".agent-worktrees").symlink_to(root / "elsewhere")
            with self.assertRaises(ValueError):
                helper.operation(["worktree", "add", "x", "main"], root / ".git")


@unittest.skipUnless(os.environ.get("AGENT_GIT_RUNTIME"), "requires reviewed macOS runtime")
class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="pi-safehouse-agent-git-", dir="/private/tmp")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.git = str(Path(shutil.which("git")).resolve())
        self.env = {"PATH": str(Path(self.git).parent), "HOME": str(self.root),
                    "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"}
        self.command("init", "-q", "-b", "main")
        self.command("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                     "commit", "--allow-empty", "-qm", "fixture")

    def command(self, *args):
        return subprocess.check_output([self.git, "-C", str(self.repo), *args],
                                       env=self.env, text=True, stderr=subprocess.STDOUT).strip()

    def maintain(self, *args):
        result = helper.run(self.git, list(args), self.repo, capture=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("could not lock config", result.stderr)
        return result

    def test_worktrees_branch_cleanup_and_upstream(self):
        self.command("update-ref", "refs/remotes/origin/main", "HEAD")
        self.command("config", "remote.origin.url", "https://fixture.invalid/repo")
        self.command("config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*")
        self.maintain("worktree", "add", "topic", "main")
        target = self.repo / ".agent-worktrees/topic"
        self.assertTrue((target / ".git").is_file())
        # Same helper works when launched from a linked worktree, including T3's layout.
        result = helper.run(self.git, ["branch", "--set-upstream-to", "origin/main", "agent/topic"],
                            target, capture=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.maintain("branch", "-m", "agent/topic", "feature/renamed")
        self.assertEqual(subprocess.check_output([self.git, "-C", str(target), "branch", "--show-current"],
                                                env=self.env, text=True).strip(), "feature/renamed")
        self.maintain("branch", "-m", "feature/renamed", "agent/topic")
        self.maintain("branch", "--unset-upstream", "agent/topic")
        self.maintain("branch", "--set-upstream-to", "origin/main", "agent/topic")
        self.maintain("worktree", "move", "topic", "moved")
        moved = target.parent / "moved"
        (moved / "dirty").write_text("keep")
        refused = helper.run(self.git, ["worktree", "remove", "moved"], self.repo, capture=True)
        self.assertNotEqual(refused.returncode, 0)
        self.assertTrue((moved / "dirty").exists())
        (moved / "dirty").unlink()
        self.maintain("worktree", "remove", "moved")
        self.maintain("branch", "-d", "agent/topic")
        self.assertNotIn('[branch "agent/topic"]', (self.repo / ".git/config").read_text())
        self.assertFalse(target.exists())

    def test_launch_from_t3_style_external_worktree(self):
        target = self.root / "t3/worktrees/repo/thread"
        target.parent.mkdir(parents=True)
        self.command("worktree", "add", "--detach", str(target))
        result = helper.run(self.git, ["worktree", "add", "external", "main"], target, capture=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = helper.run(self.git, ["worktree", "remove", "external"], target, capture=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((target / ".git").exists())

    def test_injections_stay_blocked(self):
        config = self.repo / ".git/config"
        outer = '(version 1)(allow default)(deny file-write* (literal ' + json.dumps(str(config))
        outer += ') (literal ' + json.dumps(str(config) + '.lock') + '))'
        before = config.read_bytes()
        for key in ("core.hooksPath", "core.fsmonitor", "alias.injection"):
            result = subprocess.run(["/usr/bin/sandbox-exec", "-p", outer, self.git,
                                     "-C", str(self.repo), "config", key, "!touch /tmp/must-not-run"],
                                    env=self.env, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(config.read_bytes(), before)
            with self.assertRaises(ValueError):
                helper.run(self.git, ["config", key, "injected"], self.repo)
        # Existing command-bearing config must not execute outside the helper sandbox.
        marker = self.root / "injected"
        self.command("config", "core.fsmonitor", f"touch {marker}")
        self.command("config", "core.hooksPath", str(self.root / "hooks"))
        hooks = self.root / "hooks"
        hooks.mkdir()
        hook = hooks / "post-checkout"
        hook.write_text(f"#!/bin/sh\ntouch {marker}\n")
        hook.chmod(0o755)
        self.maintain("worktree", "add", "clean", "main")
        self.assertFalse(marker.exists())
        self.maintain("worktree", "remove", "clean")
        # A direct git filter (no shell metacharacters) could re-exec the
        # allowed Git binary. Worktree operations must still protect config.
        self.command("config", "filter.attack.smudge", f"{self.git} config core.hooksPath /tmp/injected")
        (self.repo / ".gitattributes").write_text("payload filter=attack\n")
        (self.repo / "payload").write_text("fixture\n")
        self.command("add", ".gitattributes", "payload")
        self.command("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                     "commit", "-qm", "filter fixture")
        result = helper.run(self.git, ["worktree", "add", "filtered", "main"], self.repo, capture=True)
        self.assertNotEqual(self.command("config", "core.hooksPath"), "/tmp/injected")

    def test_pi_broker_is_bound_to_repository_and_rejects_arbitrary_git(self):
        with helper.broker(self.git, self.repo, self.root) as endpoint:
            self.assertEqual(helper.client(endpoint, ["worktree", "add", "pi", "main"]), 0)
            self.assertEqual(helper.client(endpoint, ["worktree", "remove", "pi"]), 0)
            self.assertEqual(helper.client(endpoint, ["branch", "-d", "agent/pi"]), 0)
            with self.assertRaises(ValueError):
                helper.client(endpoint, ["config", "core.hooksPath", "/tmp"])


if __name__ == "__main__":
    unittest.main()
