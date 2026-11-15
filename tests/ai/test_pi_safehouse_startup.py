"""Check launch-path validation without credentials or a nested OS sandbox."""

import importlib.util
import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch


module_spec = importlib.util.spec_from_file_location(
    "pi_safehouse", Path(__file__).resolve().parents[2] / "nix/modules/home/programs/ai/clients/pi/pi-safehouse.py"
)
launcher = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(launcher)


class StartupTests(unittest.TestCase):
    def test_generated_policy_expressions_are_balanced(self):
        spec = {"agentDir": "/tmp/agent", "writable": [], "denied": [], "protected": []}
        for sockets in ((), ('/tmp/SSH agent (fixture)/agent.sock',)):
            for service in (None, 12345):
                with self.subTest(sockets=sockets, service=service):
                    profile = launcher.make_profile(
                        spec, "/tmp/project", "/tmp", service, sockets,
                    )
                    # Ignore quoted strings (including regexes): paths may
                    # contain parentheses and escaped quotes.
                    depth = 0
                    for token in re.findall(r'"(?:\\.|[^"\\])*"|[()]', profile):
                        if token == "(":
                            depth += 1
                        elif token == ")":
                            depth -= 1
                            self.assertGreaterEqual(depth, 0, profile)
                    self.assertEqual(depth, 0, profile)

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

    def test_only_the_t3_mcp_port_is_reachable_on_the_host(self):
        # T3 Code serves its injected tools on a loopback port it advertises in
        # T3_MCP_URL. Nothing else on the host, including the Nix daemon and
        # Rex, may become reachable from the sandbox.
        cases = [
            ("http://127.0.0.1:3773/mcp", 3773),
            ("http://localhost:4100/mcp", 4100),
            ("http://[::1]:3773/mcp", 3773),
            ("https://example.com:443/mcp", None),
            ("http://192.168.1.5:3773/mcp", None),
            ("http://127.0.0.1/mcp", None),
            ("", None),
        ]
        for url, expected in cases:
            with self.subTest(url=url):
                self.assertEqual(launcher.loopback_service(url), expected)

        spec = {
            "agentDir": "/state", "readable": [], "writable": [], "denied": [],
            "protected": [], "env": {},
        }
        host_services = r'(deny network-outbound (remote ip "localhost:*"))'
        profile = launcher.make_profile(spec, "/work", "/tmp")
        self.assertIn(host_services, profile)
        self.assertNotIn('allow network-outbound (remote ip "localhost:', profile)
        profile = launcher.make_profile(spec, "/work", "/tmp", 3773)
        self.assertIn(host_services, profile)
        # The allow must follow the deny: Seatbelt is last-match-wins, and the
        # earlier require-not form parsed without exempting the port at runtime.
        self.assertIn('(allow network-outbound (remote ip "localhost:3773"))', profile)
        self.assertLess(
            profile.index(host_services),
            profile.index('(allow network-outbound (remote ip "localhost:3773"))'),
        )
        # The UNIX socket and LAN denies stay in place with the port exclusion.
        self.assertIn('(remote unix-socket)', profile)
        self.assertNotIn('localhost:3774', profile)

    def test_existing_git_metadata_stays_read_only_but_new_repositories_work(self):
        # `git init` and `git clone` are ordinary sandboxed work, so the blanket
        # `.git/config` and `.git/hooks` deny is gone. The git directories of
        # repositories that already exist stay protected, and a linked
        # worktree's pointer file cannot be repointed.
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            repo = root / "repo"
            repo.mkdir()
            pointer = repo / ".git"
            pointer.write_text("gitdir: /elsewhere/worktrees/topic\n")
            git_dir = root / "elsewhere" / "worktrees" / "topic"
            (git_dir / "hooks").mkdir(parents=True)
            (git_dir / "config").write_text("[core]\n")
            spec = root / "spec.json"
            spec.write_text(json.dumps({
                "agentDir": str(root / "state"), "readable": [],
                "writable": [str(root / "state"), str(root / "cache")], "denied": [],
                "protected": [], "env": {},
            }))
            captured = {}

            def capture(command, env):
                path = next(arg for arg in command if arg.startswith("--append-profile="))
                captured["profile"] = Path(path.split("=", 1)[1]).read_text()
                return 0

            with (
                patch.object(launcher.sys, "argv", ["launcher", str(spec), "safehouse", "pi"]),
                patch.object(launcher.Path, "cwd", return_value=repo),
                patch.object(launcher, "worktree_git_dirs", return_value=[str(git_dir)]),
                patch.dict(os.environ, {"HOME": str(root / "home"), "TMPDIR": str(root)}),
                patch.object(launcher.subprocess, "call", side_effect=capture),
            ):
                self.assertEqual(launcher.main(), 0)
            profile = captured["profile"]
        for protected in (git_dir / "config", git_dir / "hooks", pointer):
            self.assertIn(f'(deny file-write* (subpath "{protected}"))', profile)
        self.assertNotIn(r'(regex #"/\.git/(config$|hooks(/|$))")', profile)

    def test_only_the_ssh_agent_socket_is_reachable_among_host_sockets(self):
        # The agent signs with a key the sandbox never reads, so only the socket
        # the host exports is reachable; the socket deny still covers the rest.
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            socket_path = root / "agent" / "Listeners"
            socket_path.parent.mkdir()
            socket_path.write_text("")
            spec = root / "spec.json"
            spec.write_text(json.dumps({
                "agentDir": str(root / "state"), "readable": [],
                "writable": [str(root / "state"), str(root / "cache")], "denied": [],
                "protected": [], "env": {},
            }))
            captured = {}

            def capture(command, env):
                path = next(arg for arg in command if arg.startswith("--append-profile="))
                captured["profile"] = Path(path.split("=", 1)[1]).read_text()
                captured["passed"] = next(
                    arg for arg in command if arg.startswith("--env-pass=")
                ).split("=", 1)[1].split(",")
                return 0

            with (
                patch.object(launcher.sys, "argv", ["launcher", str(spec), "safehouse", "pi"]),
                patch.object(launcher.Path, "cwd", return_value=root),
                patch.dict(os.environ, {
                    "HOME": str(root / "home"),
                    "TMPDIR": str(root),
                    "SSH_AUTH_SOCK": str(socket_path),
                }),
                patch.object(launcher.subprocess, "call", side_effect=capture),
            ):
                self.assertEqual(launcher.main(), 0)
            profile = captured["profile"]
            passed = captured["passed"]
        self.assertIn(f'(allow file-read* (literal "{socket_path}"))', profile)
        self.assertIn(
            f'(allow network-outbound (remote unix-socket (path-literal "{socket_path}")))',
            profile,
        )
        self.assertIn(f'(require-not (literal "{socket_path}"))', profile)
        # Traversal to the socket is granted, without reading its directory.
        self.assertIn(f'(literal "{socket_path.parent}")', profile)
        self.assertIn("SSH_AUTH_SOCK", passed)

    def test_sandbox_only_commands_go_first_on_path(self):
        # A host app can prepend commands that must not exist outside the
        # sandbox, such as a wrapper pointing a CLI at the sandbox's own
        # credential store.
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch).resolve()
            wrapper = root / "wrapper" / "bin"
            wrapper.mkdir(parents=True)
            host_bin = root / "host-bin"
            host_bin.mkdir()
            agent = root / "state"
            cache = root / "cache"
            spec = root / "spec.json"
            spec.write_text(json.dumps({
                "agentDir": str(agent), "readable": [],
                "writable": [str(agent), str(cache)], "denied": [],
                "protected": [], "env": {}, "pathPrepend": [str(wrapper)],
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
                    "PATH": f"{host_bin}:{wrapper}",
                }),
                patch.object(launcher.subprocess, "call", side_effect=capture),
            ):
                self.assertEqual(launcher.main(), 0)
        self.assertEqual(captured["path"], f"{wrapper}:{host_bin}")


if __name__ == "__main__":
    unittest.main()
