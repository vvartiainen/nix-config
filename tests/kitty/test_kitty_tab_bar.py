"""Exercise Kitty tab labels against isolated Git repositories and worktrees."""

import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


SCRIPT = Path(__file__).resolve().parents[2] / "dotfiles/kitty/tab_bar.py"
spec = importlib.util.spec_from_file_location("tab_bar", SCRIPT)
tab_bar = importlib.util.module_from_spec(spec)
with patch.dict(sys.modules, {"kitty": Mock(), "kitty.fast_data_types": Mock()}):
    spec.loader.exec_module(tab_bar)


class TabTitleTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        self.repo = self.root / "checkout"
        self.git("init", "-q", str(self.repo))
        self.git("-C", str(self.repo), "-c", "user.name=Fixture",
                 "-c", "user.email=fixture@example.invalid", "commit", "-q",
                 "--allow-empty", "-m", "fixture")
        tab_bar._repo_title.cache_clear()

    def git(self, *args):
        return subprocess.run(
            ["git", "-c", "core.hooksPath=/dev/null", *args], check=True,
            capture_output=True, text=True,
            env={**os.environ, "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"},
        )

    def title(self, cwd, name=""):
        tab = SimpleNamespace(name=name)
        data = {"tab_id": 1, "title": "agent title", "tab": SimpleNamespace(active_oldest_wd=str(cwd))}
        return tab_bar._name(tab, data)

    def worktree(self):
        path = self.root / "task 42"
        self.git("-C", str(self.repo), "worktree", "add", "--detach", str(path), "HEAD")
        return path

    def test_main_checkout_keeps_remote_repository_name(self):
        self.git("-C", str(self.repo), "remote", "add", "origin", "git@example.invalid:team/project.git")
        self.assertEqual(self.title(self.repo), "project")

    def test_detached_worktree_and_subdirectory_include_directory_name(self):
        self.git("-C", str(self.repo), "remote", "add", "origin", "https://example.invalid/team/project.git")
        worktree = self.worktree()
        nested = worktree / "src" / "nested"
        nested.mkdir(parents=True)
        self.assertEqual(self.title(worktree), "project:task 42")
        self.assertEqual(self.title(nested), "project:task 42")

    def test_no_remote_uses_main_checkout_name(self):
        self.assertEqual(self.title(self.repo), "checkout")
        self.assertEqual(self.title(self.worktree()), "checkout:task 42")

    def test_submodule_git_file_does_not_add_worktree_suffix(self):
        # Submodules have a .git file but no commondir marker.
        gitdir = self.root / "module-metadata"
        (self.repo / ".git").rename(gitdir)
        (self.repo / ".git").write_text("gitdir: ../module-metadata\n")
        self.assertEqual(self.title(self.repo), "checkout")

    def test_explicit_tab_name_takes_precedence(self):
        self.assertEqual(self.title(self.worktree(), name="Pinned"), "Pinned")

    def test_non_repository_and_missing_directory_fallbacks(self):
        self.assertEqual(self.title(self.root), self.root.name)
        self.assertEqual(self.title(tab_bar.HOME), "~")
        self.assertEqual(self.title("/"), "/")
        self.assertEqual(self.title(""), "agent title")

    def test_malformed_git_file_falls_back_to_directory_name(self):
        path = self.root / "broken"
        path.mkdir()
        (path / ".git").write_text("invalid metadata\n")
        self.assertEqual(self.title(path), "broken")


if __name__ == "__main__":
    unittest.main()
