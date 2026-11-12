"""Verify status delivery without a controlling terminal."""

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


SCRIPT = Path(__file__).resolve().parents[2] / "nix/modules/home/programs/ai/terminal-status.py"
spec = importlib.util.spec_from_file_location("terminal_status", SCRIPT)
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


class TerminalStatusTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.directory = Path(scratch.name)
        directory = patch.object(status, "state_directory", return_value=self.directory)
        self.addCleanup(directory.stop)
        directory.start()
        bar = patch.object(status, "bar_command")
        self.addCleanup(bar.stop)
        self.bar = bar.start()
        environment = patch.dict(os.environ, {"NIX_CONFIG_AGENT_LAUNCH": ""})
        self.addCleanup(environment.stop)
        environment.start()

    def send(self, launch, state="blocked", terminal="", kind="permission",
             app="claude", payload=None, pid=None):
        with patch.dict(os.environ, {
            "NIX_CONFIG_AGENT_LAUNCH": launch,
            "NIX_CONFIG_AGENT_PID": str(os.getpid() if pid is None else pid),
            "NIX_CONFIG_AGENT_TTY": terminal,
            "KITTY_LISTEN_ON": "unix:/tmp/kitty-fixture",
            "KITTY_WINDOW_ID": "7",
        }), patch.object(status.os, "getppid", return_value=os.getpid()), \
                patch.object(status.sys, "stdin", io.StringIO(json.dumps(
            {"cwd": "/fixture/project", "session_id": launch, **(payload or {})}
        ))):
            status.report(app, state, kind)

    def test_codex_sessions_share_a_daemon_without_sharing_status(self):
        # Every daemon hook sees the same stale environment from its first
        # launcher. Neither that launch ID, PID nor terminal identifies a thread.
        with patch.object(status.os, "open", wraps=os.open) as open_file:
            self.send("stale-launch", app="codex", terminal="/dev/tty-stale", pid=999999999, payload={
                "session_id": "first",
            })
            self.send("stale-launch", app="codex", terminal="/dev/tty-stale", kind="question", pid=999999999,
                      payload={"session_id": "second"})
            self.assertFalse(any(call.args[0] == "/dev/tty-stale" for call in open_file.call_args_list))
        records = status.active_records(self.directory)
        self.assertEqual(len(records), 2)
        self.assertEqual({record["kind"] for record in records}, {"permission", "question"})
        self.assertTrue(all(record["pid"] == os.getpid() for record in records))
        self.assertTrue(all("socket" not in record and "window" not in record for record in records))
        status.clear("stale-launch")  # A launcher exiting cannot erase daemon state.
        self.assertEqual(len(status.active_records(self.directory)), 2)
        self.send("stale-launch", app="codex", state="working", payload={"session_id": "first"})
        self.assertEqual(sorted(record["state"] for record in status.active_records(self.directory)),
                         ["blocked", "working"])
        self.send("stale-launch", app="codex", state="done", payload={"session_id": "first"})
        self.send("stale-launch", app="codex", state="clear", payload={"session_id": "second"})
        self.assertEqual(status.active_records(self.directory), [])

    def test_codex_does_not_require_a_zsh_wrapper(self):
        with patch.dict(os.environ, {"NIX_CONFIG_AGENT_LAUNCH": "", "NIX_CONFIG_AGENT_PID": ""}), \
                patch.object(status.os, "getppid", return_value=os.getpid()), \
                patch.object(status.sys, "stdin", io.StringIO(json.dumps({"session_id": "thread"}))):
            status.report("codex", "blocked", "permission")
        self.assertEqual(len(status.active_records(self.directory)), 1)
        self.bar.assert_called_with("--trigger", "agent_status_update")
        with patch.object(status.os, "kill", side_effect=ProcessLookupError):
            self.assertEqual(status.active_records(self.directory), [])

    def test_codex_ignores_missing_session_ids_and_subagents(self):
        for payload in ({}, {"session_id": ""}, {"session_id": 7},
                        {"session_id": "parent", "agent_id": "child"}):
            with patch.object(status.sys, "stdin", io.StringIO(json.dumps(payload))):
                status.report("codex", "blocked", "permission")
        self.assertEqual(list(self.directory.glob("*.json")), [])
        self.bar.assert_not_called()

    def test_exec_hook_records_its_persistent_parent(self):
        # Exercise both shell replacements used by installed Codex hooks:
        # hook shell -> reporter shell -> Python. The owner must outlive them.
        code = '''import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location("reporter", sys.argv[1])
reporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reporter)
reporter.state_directory = lambda: pathlib.Path(sys.argv[2])
reporter.report("codex", "blocked", "permission")
'''
        result = subprocess.run(
            ["/bin/sh", "-c", 'exec /bin/sh -c \'exec "$@"\' reporter "$@"', "hook",
             sys.executable, "-B", "-c", code, str(SCRIPT), str(self.directory)],
            input=json.dumps({"session_id": "thread", "cwd": "/fixture/project"}),
            text=True, capture_output=True, start_new_session=True,
            env={**os.environ, "NIX_CONFIG_AGENT_LAUNCH": "", "NIX_CONFIG_SKETCHYBAR": ""},
        )
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
        records = status.active_records(self.directory)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["pid"], os.getpid())

    def test_async_question_completion_preserves_waiting_until_work_resumes(self):
        self.send("first", app="codex", kind="question")
        self.send("first", app="codex", state="working", payload={
            "hook_event_name": "PostToolUse",
            "tool_name": "request_user_input_async",
        })
        self.assertEqual([record["kind"] for record in status.active_records(self.directory)],
                         ["question"])
        self.send("first", app="codex", state="working", payload={
            "hook_event_name": "PostToolUse", "tool_name": "Bash",
        })
        self.assertEqual([record["state"] for record in status.active_records(self.directory)], ["working"])

    def test_sketchybar_receives_hooks_without_kitty_or_a_terminal(self):
        self.send("first")
        self.bar.assert_called_with("--trigger", "agent_status_update")
        with patch.object(status, "run_quietly") as external:
            status.render_bar("agent_status", "agent_status_update")
            external.assert_not_called()  # No Kitty query or other process.
        arguments = self.bar.call_args.args
        self.assertEqual(arguments[:4], ("--set", "agent_status", "drawing=on", "label=1"))
        self.assertIn("label=claude: approval · /fixture/project", arguments)

    def test_kitty_delivery_failure_does_not_prevent_sketchybar(self):
        self.send("first", terminal="/dev/tty-nix-config-missing")
        self.assertEqual(len(status.active_records(self.directory)), 1)
        self.bar.assert_called_with("--trigger", "agent_status_update")

    def test_sessions_clear_independently_and_wrapper_cleanup_is_idempotent(self):
        self.send("first")
        self.send("second", kind="question")
        status.render_bar("agent_status", "agent_status_update")
        self.assertEqual(self.bar.call_args.args[3], "label=2")
        self.send("first", state="working")
        records = status.active_records(self.directory)
        self.assertEqual(sorted(record["state"] for record in records), ["blocked", "working"])
        self.send("first", state="done")
        status.clear("second")
        status.clear("second")
        status.render_bar("agent_status", "agent_status_update")
        self.assertEqual(self.bar.call_args.args[:4],
                         ("--set", "agent_status", "drawing=off", "popup.drawing=off"))

    def test_dead_launch_shell_is_removed(self):
        self.send("first")
        with patch.object(status.os, "kill", side_effect=ProcessLookupError):
            self.assertEqual(status.active_records(self.directory), [])
        self.assertFalse(list(self.directory.glob("*.json")))

    def test_click_toggles_read_only_details_without_terminal_commands(self):
        self.send("first", terminal="/dev/tty-nix-config-missing")
        with patch.object(status, "run_quietly") as external:
            status.render_bar("agent_status", "mouse.clicked")
            external.assert_not_called()
        self.assertIn("popup.drawing=toggle", self.bar.call_args.args)
        self.assertIn("label=claude: approval · /fixture/project", self.bar.call_args.args)
        status.render_bar("agent_status", "mouse.exited.global")
        self.assertIn("popup.drawing=off", self.bar.call_args.args)

    def test_running_and_blocked_counts_are_separate(self):
        self.send("running", state="working", kind="none", app="codex")
        self.send("approval")
        self.send("question", kind="question", app="copilot")
        status.render_bar("agent_status.running", "agent_status_update")
        self.assertEqual(self.bar.call_args.args[:4],
                         ("--set", "agent_status.running", "drawing=on", "label=1"))
        self.assertIn("label=codex: running · /fixture/project", self.bar.call_args.args)
        status.render_bar("agent_status", "agent_status_update")
        self.assertEqual(self.bar.call_args.args[3], "label=2")
        self.assertIn("label=copilot: answer · /fixture/project", self.bar.call_args.args)
        for launch in ("running", "approval", "question"):
            self.send(launch, state="done", app="codex" if launch == "running" else "claude")
        for name in ("agent_status", "agent_status.running"):
            status.render_bar(name, "agent_status_update")
            self.assertEqual(self.bar.call_args.args[:4],
                             ("--set", name, "drawing=off", "popup.drawing=off"))

    def test_old_blocked_records_survive_upgrade(self):
        self.send("first")
        path = next(self.directory.glob("*.json"))
        record = json.loads(path.read_text())
        del record["state"]
        path.write_text(json.dumps(record))
        status.render_bar("agent_status", "agent_status_update")
        self.assertEqual(self.bar.call_args.args[3], "label=1")

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
