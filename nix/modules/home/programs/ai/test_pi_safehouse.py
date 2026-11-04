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
        for path in [cls.work, cls.agent, cls.cache, cls.home / ".aws", cls.home / ".npm"]:
            path.mkdir(parents=True)
        cls.policy = cls.agent / "extensions/pi-permission-system/config.json"
        cls.policy.parent.mkdir(parents=True)
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
            "env": {"npm_config_cache": str(cls.cache)},
        }))

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def run_probe(self, source):
        env = dict(os.environ, HOME=str(self.home), SYNTHETIC_HOST_SECRET="must-not-pass")
        return subprocess.run([
            sys.executable, str(Path(__file__).with_name("pi-safehouse.py")),
            str(self.spec), os.environ["SAFEHOUSE"], sys.executable, "-c", source,
        ], cwd=self.work, env=env, text=True, capture_output=True)

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
