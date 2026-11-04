"""Verify hook coexistence and status delivery without a controlling terminal."""

import importlib.util
import io
import json
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("terminal-status.py")
spec = importlib.util.spec_from_file_location("terminal_status", SCRIPT)
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


class TerminalStatusTests(unittest.TestCase):
    def test_install_preserves_other_handlers_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.json"
            target = Path(directory) / "settings.json"
            vendor = {"type": "command", "command": "vendor-hook"}
            old = {"type": "command", "command": "/old" + status.MARKER + "claude done none"}
            new = {"type": "command", "command": "/new" + status.MARKER + "claude done none"}
            target.write_text(json.dumps({"model": "fixture", "hooks": {
                "Stop": [{"hooks": [vendor, old]}],
                "SessionStart": [{"hooks": [vendor]}],
            }}))
            source.write_text(json.dumps({"hooks": {"Stop": [{"hooks": [new]}]}}))
            status.install(source, target)
            first = target.read_text()
            status.install(source, target)
            self.assertEqual(target.read_text(), first)
            data = json.loads(first)
            self.assertEqual(data["model"], "fixture")
            self.assertEqual(data["hooks"]["Stop"], [{"hooks": [vendor]}, {"hooks": [new]}])
            self.assertEqual(data["hooks"]["SessionStart"], [{"hooks": [vendor]}])

    def run_report(self, payload, terminal, state="blocked", kind="permission"):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "report", "claude", state, kind],
            input=json.dumps(payload), text=True, capture_output=True,
            start_new_session=True,
            env={**os.environ, "NIX_CONFIG_AGENT_TTY": terminal},
        )
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))

    def test_hook_writes_osc_to_captured_terminal(self):
        master, slave = pty.openpty()
        try:
            # Some macOS sessions cannot resolve newly allocated PTY names
            # (ttyname returns ERANGE). Use the open slave descriptor while
            # exercising real terminal writes and captured hook streams.
            with patch.dict(os.environ, {"NIX_CONFIG_AGENT_TTY": "/dev/tty-fixture"}), \
                    patch.object(status.os, "open", return_value=os.dup(slave)), \
                    patch.object(status.sys, "stdin", io.StringIO("{}")):
                status.report("claude", "blocked", "permission")
            self.assertTrue(select.select([master], [], [], 1)[0])
            self.assertEqual(os.read(master, 1024),
                             b"\x1b]7501;state=blocked:app=claude:kind=permission\x1b\\")
            with patch.dict(os.environ, {"NIX_CONFIG_AGENT_TTY": "/dev/tty-fixture"}), \
                    patch.object(status.os, "open", return_value=os.dup(slave)), \
                    patch.object(status.sys, "stdin", io.StringIO("{}")):
                status.report("claude", "working", "none")
            self.assertTrue(select.select([master], [], [], 1)[0])
            self.assertEqual(os.read(master, 1024), b"\x1b]7501;state=working:app=claude\x1b\\")
        finally:
            os.close(master)
            os.close(slave)

    def test_subagents_do_not_overwrite_parent_status(self):
        master, slave = pty.openpty()
        try:
            for payload in ({"agent_id": "child"}, {"agentId": "child"}):
                with patch.dict(os.environ, {"NIX_CONFIG_AGENT_TTY": "/dev/tty-fixture"}), \
                        patch.object(status.sys, "stdin", io.StringIO(json.dumps(payload))), \
                        patch.object(status.os, "open") as open_terminal:
                    status.report("claude", "done", "none")
                    open_terminal.assert_not_called()
        finally:
            os.close(master)
            os.close(slave)

    def test_absent_or_closed_terminal_is_a_successful_noop(self):
        self.run_report({}, "")
        self.run_report({}, "/dev/tty-nix-config-missing")


if __name__ == "__main__":
    unittest.main()
