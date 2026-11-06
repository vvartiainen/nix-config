"""Exercise file selection and hook behavior using temporary Git repositories."""

import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "check-repository.py"
spec = importlib.util.spec_from_file_location("checks", SCRIPT)
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


class RepositoryChecksTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve() / "repo"
        self.root.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.write("tracked.py", "print('before')\n")
        self.write("deleted.sh", "#!/bin/sh\ntrue\n")
        self.write("renamed.py", "print('rename')\n")
        self.write(".gitignore", "ignored.py\n")
        self.commit()
        self.state = self.root.parent / "state"
        self.state_patch = patch.object(checks, "hook_state", return_value=self.state)
        self.state_patch.start()
        self.addCleanup(self.state_patch.stop)

    def git(self, *args):
        return subprocess.check_output(
            ["git", "-c", "core.hooksPath=/dev/null", "-C", str(self.root), *args],
            stderr=subprocess.PIPE,
            text=True,
        ).strip()

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")

    def hook(self, event, **payload):
        data = {"cwd": str(self.root), "session_id": "fixture", **payload}
        with patch.object(checks.sys, "stdin", io.StringIO(json.dumps(data))):
            return checks.hook(event, self.root)

    def test_staged_unstaged_untracked_renamed_and_deleted_files(self):
        self.write("tracked.py", "print('after')\n")
        self.write("staged.nix", "{}\n")
        self.git("add", "staged.nix")
        self.write("space and\nnewline.sh", "#!/bin/sh\ntrue\n")
        self.git("mv", "renamed.py", "new-name.py")
        (self.root / "deleted.sh").unlink()
        self.assertEqual(
            checks.selected_files(self.root),
            ["./new-name.py", "./space and\nnewline.sh", "./staged.nix", "./tracked.py"],
        )

    def test_ignored_vendored_secret_and_symlink_files_are_skipped(self):
        for name in (
            "ignored.py",
            "dotfiles/yazi/plugins/vendor.lua",
            "dotfiles/yazi/flavors/vendor.lua",
            ".env",
            ".env.local",
            "private.key",
            "private.pem",
        ):
            self.write(name, "unreadable input\n")
        (self.root / "linked.py").symlink_to(self.root / "tracked.py")
        outside = self.root.parent / "outside"
        outside.mkdir()
        (outside / "external.py").write_text("external\n")
        (self.root / "linked").symlink_to(outside, target_is_directory=True)
        self.assertEqual(checks.selected_files(self.root), [])

    def test_all_includes_unchanged_owned_files(self):
        self.assertIn("./tracked.py", checks.selected_files(self.root, all_files=True))
        self.assertEqual(checks.selected_files(self.root), [])

    def test_staged_change_is_checked_when_worktree_matches_head(self):
        before = (self.root / "tracked.py").read_text()
        self.write("tracked.py", "print('staged') \n")
        self.git("add", "tracked.py")
        self.write("tracked.py", before)
        self.assertEqual(checks.selected_files(self.root), ["./tracked.py"])
        self.assertIn("trailing whitespace", checks.check(self.root))

    def test_commands_detect_shebangs_and_keep_formatting_opt_in(self):
        files = ["./tool", "./shell.zsh", "./module.nix", "./helper.py", "./config.lua"]
        self.write("tool", "#!/usr/bin/env bash\ntrue\n")
        self.write("shell.zsh", "#!/bin/zsh\nprint ok\n")
        embedded = self.write("embedded.sh", "# shellcheck shell=bash\nread -r x <<<ok\n")
        self.assertEqual(checks.shell_kind(embedded), "bash")
        for path in files[2:]:
            self.write(path, "\n")
        commands = list(checks.commands(self.root, files))
        self.assertIn(["bash", "-n", "./tool"], commands)
        self.assertIn(["shellcheck", "./tool"], commands)
        self.assertIn(["zsh", "-dfn", "./shell.zsh"], commands)
        self.assertNotIn(["shellcheck", "./shell.zsh"], commands)
        self.assertIn(["statix", "check", "./module.nix"], commands)
        self.assertIn(["deadnix", "--fail", "./module.nix"], commands)
        self.assertFalse(any(c[0] in {"nixfmt", "shfmt", "stylua"} for c in commands))
        formatted = list(checks.commands(self.root, files, formatting=True))
        for tool in ("nixfmt", "shfmt", "stylua"):
            self.assertTrue(any(c[0] == tool for c in formatted))
        self.assertIn(["ruff", "format", "--no-cache", "--check", "./helper.py"], formatted)

    def test_hook_checks_commits_since_prompt_and_cleans_up(self):
        before = self.git("rev-parse", "HEAD")
        self.assertEqual(self.hook("prompt"), {})
        self.write("tracked.py", "print('committed during turn')\n")
        self.commit()
        with patch.object(checks, "check", return_value="") as check:
            self.assertEqual(self.hook("stop"), {})
            check.assert_called_once_with(self.root, base=before)
        self.assertEqual(checks.selected_files(self.root, base=before), ["./tracked.py"])
        self.hook("end")
        self.assertFalse(self.state.exists())

    def test_failure_blocks_once_and_subagents_do_not_run_checks(self):
        with patch.object(checks, "check", return_value="lint failure") as check:
            result = self.hook("stop")
            self.assertEqual(result["decision"], "block")
            self.assertIn("lint failure", result["reason"])
            check.reset_mock()
            for payload in (
                {"stop_hook_active": True},
                {"agent_id": "child"},
                {"agentId": "child"},
            ):
                self.assertEqual(self.hook("stop", **payload), {})
            check.assert_not_called()

    def test_copilot_session_and_unrelated_repository(self):
        self.assertEqual(self.hook("prompt", session_id=None, sessionId="copilot"), {})
        self.assertTrue(self.state.exists())
        other = self.root.parent / "other"
        other.mkdir()
        subprocess.run(["git", "init", "-q", str(other)], check=True)
        with patch.object(checks, "check") as check:
            self.assertEqual(self.hook("stop", cwd=str(other)), {})
            check.assert_not_called()

    def test_worktree_uses_same_repository_and_separate_root(self):
        worktree = self.root.parent / "worktree"
        self.git("worktree", "add", "--detach", str(worktree))
        self.assertEqual(self.hook("prompt", cwd=str(worktree)), {})
        with patch.object(checks, "check", return_value="") as check:
            self.hook("stop", cwd=str(worktree))
            self.assertEqual(check.call_args.args[0], worktree)

    def test_missing_tools_are_reported_and_other_checks_still_run(self):
        self.write("helper.py", "broken\n")
        success = subprocess.CompletedProcess([], 0, stdout="")
        with (
            patch.object(checks, "selected_files", return_value=["./helper.py"]),
            patch.object(checks.subprocess, "check_output", return_value=b"helper.py\0"),
            patch.object(
                checks.subprocess,
                "run",
                side_effect=[FileNotFoundError("git"), success, success, success],
            ) as run,
        ):
            failure = checks.check(self.root)
        self.assertIn("git", failure)
        self.assertEqual(run.call_count, 4)

    def test_untracked_whitespace_errors_are_reported(self):
        self.write("new.md", "trailing space \n")
        failure = checks.check(self.root)
        self.assertIn("trailing whitespace", failure)

    def test_check_is_read_only_and_reports_real_shell_syntax_error(self):
        path = self.write("broken.zsh", "if then\n")
        before = path.read_bytes()
        failure = checks.check(self.root)
        self.assertIn("zsh -dfn", failure)
        self.assertEqual(path.read_bytes(), before)

    @unittest.skipUnless(
        all(shutil.which(tool) for tool in ("nixfmt", "ruff", "shfmt", "stylua", "deadnix")),
        "formatting tools must be installed",
    )
    def test_formatting_checks_use_real_tools_and_never_rewrite_files(self):
        files = {
            "module.nix": "{foo=1;}\n",
            "helper.py": "value= 1\n",
            "config.lua": "local x={}\nreturn x\n",
            "tool.sh": "#!/bin/bash\nif true;then echo ok;fi\n",
        }
        for name, text in files.items():
            self.write(name, text)
        failure = checks.check(self.root, formatting=True)
        for tool in ("nixfmt --check", "ruff format", "shfmt -i", "stylua --check"):
            self.assertIn(tool, failure)
        for name, text in files.items():
            self.assertEqual((self.root / name).read_text(), text)


if __name__ == "__main__":
    unittest.main()
