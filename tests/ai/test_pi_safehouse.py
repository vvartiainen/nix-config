"""macOS integration checks using a synthetic home; never uses real credentials.

Run with SAFEHOUSE pointing to the pinned safehouse executable and
PI_SANDBOX_TEST_ROOT pointing to a writable cache directory outside /tmp.
"""

import errno
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
        cls.env.pop("SSH_AUTH_SOCK", None)
        cls.env.update(cls.config_env, HOME=str(cls.home))
        for path in [cls.work, cls.agent, cls.cache, cls.home / ".aws", cls.home / ".npm", cls.home / ".ssh"]:
            path.mkdir(parents=True)
        cls.policy = cls.agent / "extensions/pi-permission-system/config.json"
        cls.logs = cls.agent / "extensions/pi-permission-system/logs"
        cls.policy.parent.mkdir(parents=True)
        cls.logs.mkdir()
        cls.policy.write_text("{}")
        (cls.home / ".aws/synthetic").write_text("synthetic")
        (cls.home / ".ssh/id_ed25519").write_text("synthetic, not a private key")
        (cls.home / "unrelated-read").write_text("synthetic")
        (cls.work / ".env").write_text("SYNTHETIC=1")
        (cls.work / ".env.example").write_text("SYNTHETIC=")
        subprocess.run(
            ["/usr/bin/git", "-c", "core.hooksPath=/dev/null", "init", "-q", str(cls.work)],
            env=cls.env, check=True, capture_output=True,
        )
        (cls.work / ".git/config.worktree").write_text("[core]\n")
        cls.spec = cls.root / "spec.json"
        cls.spec.write_text(json.dumps({
            "agentDir": str(cls.agent),
            # Match the production read-only toolchain grant. A Nix Python
            # environment wraps an interpreter whose dylibs live in other
            # store paths, so granting only its bin parent is insufficient.
            "readable": ["/nix/store", str(Path(sys.executable).resolve().parent.parent)],
            "writable": [str(cls.agent), str(cls.cache)],
            "denied": [str(cls.home / ".aws")],
            "protected": [str(cls.policy)],
            "env": {"npm_config_cache": str(cls.cache), **cls.config_env},
        }))

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def run_probe(self, source, workdir=None, ssh_socket=None):
        env = dict(
            self.env,
            SYNTHETIC_HOST_SECRET="must-not-pass",
            T3_PI_RUNTIME_MODE="approval-required",
        )
        if ssh_socket is not None:
            env["SSH_AUTH_SOCK"] = str(ssh_socket)
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
            "assert os.environ['T3_PI_RUNTIME_MODE'] == 'approval-required'; "
            "assert Path('.env.example').read_text() == 'SYNTHETIC='"
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_system_ssh_configuration_and_nix_includes_are_readable(self):
        # -G parses configuration without connecting. An explicit system
        # config avoids reading the real user's ~/.ssh/config; the system's
        # includes still exercise nix-darwin's /etc/static symlink traversal.
        result = self.run_probe(
            "import subprocess\n"
            "result = subprocess.run(['/usr/bin/ssh', '-G', '-F', "
            "'/etc/ssh/ssh_config', 'fixture.invalid'], capture_output=True, text=True)\n"
            "assert result.returncode == 0, result.stderr\n"
            "assert 'hostname fixture.invalid' in result.stdout\n"
            # The metadata traversal grant must not expose private-key paths.
            f"from pathlib import Path\nkey = Path({str(self.home / '.ssh/id_ed25519')!r})\n"
            "try: key.read_text()\n"
            "except PermissionError: pass\n"
            "else: raise AssertionError('synthetic private-key path was readable')\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_main_checkout_can_commit_and_create_repositories(self):
        result = self.run_probe(
            "from pathlib import Path; import subprocess\n"
            "def git(*args):\n"
            " subprocess.run(['/usr/bin/git', '-c', 'core.hooksPath=/dev/null', "
            "'-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', "
            "*args], check=True)\n"
            "Path('change').write_text('fixture')\n"
            "git('add', 'change')\n"
            "git('commit', '-qm', 'fixture')\n"
            "git('init', '-q', 'new-repo')\n"
            "git('clone', '-q', '--no-local', '.', 'clone')\n"
            "assert Path('new-repo/.git/config').is_file()\n"
            "assert Path('clone/change').read_text() == 'fixture'\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_denials_also_apply_to_child_processes(self):
        targets = [
            self.home / "unrelated", self.home / ".npm/output", self.policy,
            self.agent / "extensions/evil.ts",
            self.work / ".env", self.work / ".pi/settings.json",
            self.work / ".git/config", self.work / ".git/hooks/pre-commit",
            self.work / ".git/config.worktree",
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
        # macOS limits Unix socket paths to roughly 100 bytes; worktree paths
        # can exceed that before the socket name. File access to /tmp is
        # intentionally allowed, while the Unix socket network denial applies.
        with tempfile.TemporaryDirectory(prefix="pi-socket-", dir="/tmp") as scratch, \
                socket.socket(socket.AF_UNIX) as server:
            path = str(Path(scratch) / "service.sock")
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

    def test_injected_ssh_socket_connects_but_other_host_socket_is_blocked(self):
        with tempfile.TemporaryDirectory(prefix="pi-ssh-", dir="/tmp") as scratch, \
                socket.socket(socket.AF_UNIX) as agent, \
                socket.socket(socket.AF_UNIX) as other:
            root = Path(scratch)
            agent_path = str(root / "agent.sock")
            other_path = str(root / "other.sock")
            agent.bind(agent_path)
            agent.listen(1)
            other.bind(other_path)
            other.listen(1)
            result = self.run_probe(
                "import os, socket\n"
                f"assert os.environ['SSH_AUTH_SOCK'] == {agent_path!r}\n"
                "with socket.socket(socket.AF_UNIX) as client:\n"
                " client.settimeout(2)\n"
                " client.connect(os.environ['SSH_AUTH_SOCK'])\n"
                "with socket.socket(socket.AF_UNIX) as client:\n"
                " client.settimeout(2)\n"
                f" try: client.connect({other_path!r})\n"
                " except PermissionError: pass\n"
                " else: raise AssertionError('unrelated host socket was reachable')\n",
                ssh_socket=agent_path,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_configured_ssh_agent_overrides_host_app_socket(self):
        with tempfile.TemporaryDirectory(prefix="pi-agent-", dir="/tmp") as scratch, \
                socket.socket(socket.AF_UNIX) as configured, \
                socket.socket(socket.AF_UNIX) as inherited:
            root = Path(scratch)
            configured_path = str(root / "configured.sock")
            inherited_path = str(root / "inherited.sock")
            configured.bind(configured_path)
            configured.listen(1)
            inherited.bind(inherited_path)
            inherited.listen(1)
            original = self.spec.read_text()
            spec = json.loads(original)
            spec["env"]["SSH_AUTH_SOCK"] = configured_path
            self.spec.write_text(json.dumps(spec))
            try:
                result = self.run_probe(
                    "import os, socket\n"
                    f"assert os.environ['SSH_AUTH_SOCK'] == {configured_path!r}\n"
                    "with socket.socket(socket.AF_UNIX) as client:\n"
                    " client.settimeout(2)\n"
                    " client.connect(os.environ['SSH_AUTH_SOCK'])\n"
                    "with socket.socket(socket.AF_UNIX) as client:\n"
                    f" try: client.connect({inherited_path!r})\n"
                    " except PermissionError: pass\n"
                    " else: raise AssertionError('unselected agent was reachable')\n",
                    ssh_socket=inherited_path,
                )
            finally:
                self.spec.write_text(original)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_host_ip_services_are_blocked(self):
        # Exercise IPv4/IPv6, TCP/UDP and a non-default loopback address. The
        # server is outside Safehouse; the client runs in a child process.
        for family, host in [
            (socket.AF_INET, "127.0.0.1"),
            (socket.AF_INET, "127.0.0.2"),
            (socket.AF_INET6, "::1"),
            (socket.AF_INET6, "::ffff:127.0.0.1"),
        ]:
            for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
                with self.subTest(host=host, kind=kind), socket.socket(family, kind) as server:
                    # Probe an actual host listener. On macOS, an unassigned
                    # 127.0.0.2 can route off-host; a wildcard localhost rule
                    # does not classify it as a service on this machine.
                    try:
                        server.bind((host, 0))
                    except OSError as error:
                        if error.errno == errno.EADDRNOTAVAIL:
                            self.skipTest(f"{host} is not assigned on this host")
                        raise
                    if kind == socket.SOCK_STREAM:
                        server.listen(1)
                    address = (host, server.getsockname()[1])
                    child = (
                        "import socket\n"
                        f"with socket.socket({int(family)}, {int(kind)}) as client:\n"
                        " client.settimeout(2)\n"
                        f" try: client.connect({address!r}); client.send(b'probe')\n"
                        " except PermissionError: pass\n"
                        " else: raise AssertionError('host IP service was reachable')\n"
                    )
                    result = self.run_probe(
                        "import subprocess, sys; "
                        f"subprocess.run([sys.executable, '-c', {child!r}], check=True)"
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
