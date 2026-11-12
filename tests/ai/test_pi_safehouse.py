"""macOS integration checks using a synthetic home; never uses real credentials.

Run with SAFEHOUSE pointing to the pinned safehouse executable and
PI_SANDBOX_TEST_ROOT pointing to a writable cache directory outside /tmp.
"""

import json
import os
from pathlib import Path
import subprocess
import socket
import sys
import tempfile
import unittest


class SafehouseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(
            prefix="pi-safehouse-test-", dir=os.environ["PI_SANDBOX_TEST_ROOT"]
        )
        cls.root = Path(cls.scratch.name).resolve()
        cls.home = cls.root / "home"
        cls.work = cls.home / "project"
        cls.agent = cls.home / ".pi/agent"
        cls.cache = cls.home / ".cache/npm-agent"
        cls.config_env = {
            "XDG_CONFIG_HOME": str(cls.home / ".config"),
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
        }
        # Preparation and sandboxed Git must not load host config or overrides.
        cls.env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        cls.env.update(cls.config_env, HOME=str(cls.home))
        for path in [cls.work, cls.agent, cls.cache, cls.home / ".aws", cls.home / ".npm"]:
            path.mkdir(parents=True)
        cls.policy = cls.agent / "extensions/pi-permission-system/config.json"
        cls.logs = cls.agent / "extensions/pi-permission-system/logs"
        cls.policy.parent.mkdir(parents=True)
        cls.logs.mkdir()
        cls.policy.write_text("{}")
        (cls.home / ".aws/synthetic").write_text("synthetic")
        (cls.home / "unrelated-read").write_text("synthetic")
        (cls.work / ".env").write_text("SYNTHETIC=1")
        (cls.work / ".env.example").write_text("SYNTHETIC=")
        (cls.work / ".git/hooks").mkdir(parents=True)
        (cls.work / ".git/config").write_text("[core]\n")
        cls.spec = cls.root / "spec.json"
        cls.spec.write_text(json.dumps({
            "agentDir": str(cls.agent),
            "readable": [str(Path(sys.executable).resolve().parent.parent)],
            "writable": [str(cls.agent), str(cls.cache)],
            "denied": [str(cls.home / ".aws")],
            "protected": [str(cls.policy)],
            "env": {"npm_config_cache": str(cls.cache), **cls.config_env},
        }))

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def run_probe(self, source, workdir=None):
        env = dict(self.env, SYNTHETIC_HOST_SECRET="must-not-pass")
        return subprocess.run([
            sys.executable, str(Path(__file__).resolve().parents[2] / "nix/modules/home/programs/ai/clients/pi/pi-safehouse.py"),
            str(self.spec), os.environ["SAFEHOUSE"], sys.executable, "-c", source,
        ], cwd=workdir or self.work, env=env, text=True, capture_output=True)

    def test_linked_worktree_can_commit_without_writing_main_sources_or_hooks(self):
        repo = self.root / "main-repo"
        worktree = self.root / "linked-worktree"
        repo.mkdir()
        def git(*args):
            return subprocess.check_output(
                ["/usr/bin/git", "-c", "core.hooksPath=/dev/null", "-C", str(repo), *args],
                stderr=subprocess.PIPE, text=True, env=self.env,
            ).removesuffix("\n")
        git("init", "-q")
        git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
            "commit", "--allow-empty", "-qm", "fixture")
        git("worktree", "add", "--detach", str(worktree))
        metadata = subprocess.check_output([
            "/usr/bin/git", "-C", str(worktree), "rev-parse", "--path-format=absolute", "--git-dir",
        ], text=True, env=self.env).removesuffix("\n")
        source = (
            "from pathlib import Path; import subprocess\n"
            "Path('change').write_text('fixture')\n"
            "subprocess.run(['/usr/bin/git', 'add', 'change'], check=True)\n"
            "subprocess.run(['/usr/bin/git', '-c', 'user.name=Fixture', '-c', "
            "'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], check=True)\n"
            f"for name in {[str(repo / 'source'), str(repo / '.git/config'), str(repo / '.git/hooks/pre-commit'), str(Path(metadata) / 'config.worktree')]!r}:\n"
            " try: Path(name).write_text('must fail')\n"
            " except PermissionError: pass\n"
            " else: raise AssertionError(name)\n"
        )
        result = self.run_probe(source, workdir=worktree)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_project_state_cache_and_environment(self):
        result = self.run_probe(
            "from pathlib import Path; import os; "
            "Path('output').write_text('ok'); "
            "Path(os.environ['PI_CODING_AGENT_DIR'], 'session').write_text('ok'); "
            "Path(os.environ['npm_config_cache'], 'cache').write_text('ok'); "
            "assert 'SYNTHETIC_HOST_SECRET' not in os.environ; "
            "assert Path('.env.example').read_text() == 'SYNTHETIC='"
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_denials_also_apply_to_child_processes(self):
        targets = [
            self.home / "unrelated", self.home / ".npm/output", self.policy,
            self.agent / "extensions/evil.ts",
            self.work / ".env", self.work / ".pi/settings.json",
            self.work / ".git/config", self.work / ".git/hooks/pre-commit",
        ]
        child = (
            "from pathlib import Path\n"
            f"targets = {list(map(str, targets))!r}\n"
            "for target in targets:\n"
            " try:\n"
            "  Path(target).parent.mkdir(parents=True, exist_ok=True)\n"
            "  Path(target).write_text('should fail')\n"
            " except PermissionError: pass\n"
            " else: raise AssertionError(target)\n"
            f"for target in {[str(self.home / '.aws/synthetic'), str(self.work / '.env'), str(self.home / 'unrelated-read')]!r}:\n"
            " try: Path(target).read_text()\n"
            " except PermissionError: pass\n"
            " else: raise AssertionError(target)\n"
            f"Path({str(self.logs / 'review.jsonl')!r}).write_text('ok')\n"
        )
        result = self.run_probe(
            "import subprocess, sys; "
            f"subprocess.run([sys.executable, '-c', {child!r}], check=True)"
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_host_unix_socket_is_blocked(self):
        path = str(self.work / "host-service.sock")
        with socket.socket(socket.AF_UNIX) as server:
            server.bind(path)
            server.listen(1)
            result = self.run_probe(
                "import socket\n"
                "with socket.socket(socket.AF_UNIX) as client:\n"
                f" try: client.connect({path!r})\n"
                " except PermissionError: pass\n"
                " else: raise AssertionError('host socket was reachable')\n"
            )
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
