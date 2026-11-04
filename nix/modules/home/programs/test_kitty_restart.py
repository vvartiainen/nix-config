"""Run with Kitty's Python; never closes or launches a real Kitty instance."""

import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from kittens.runner import import_kitten_main_module


SCRIPT = Path(__file__).resolve().parents[4] / "dotfiles/kitty/restart.py"
spec = importlib.util.spec_from_file_location("kitty_restart", SCRIPT)
restart = importlib.util.module_from_spec(spec)
spec.loader.exec_module(restart)


class RestartTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.home = Path(scratch.name)
        self.boss = Mock()
        self.boss.serialize_state_as_session.return_value = iter(["layout stack", "launch"])
        self.popen = Mock()
        for target, value in (
            ("config_dir", str(SCRIPT.parent)),
            ("get_options", Mock(return_value=SimpleNamespace(
                config_paths=("/tmp/custom kitty.conf",), config_overrides=("font_size=16",),
            ))),
            ("kitty_exe", Mock(return_value="/kitty")),
            ("current_application_quit_request", Mock(return_value=restart.IMPERATIVE_CLOSE_REQUESTED)),
        ):
            patcher = patch.object(restart, target, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        for patcher in (
            patch.object(restart.subprocess, "Popen", self.popen),
            patch.object(restart.Path, "home", return_value=self.home),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_cancel_does_not_save_quit_or_spawn(self):
        restart.restart(False, self.boss)
        self.boss.serialize_state_as_session.assert_not_called()
        self.boss.handle_quit_confirmation.assert_not_called()
        self.popen.assert_not_called()

    def test_save_failure_leaves_kitty_running(self):
        self.boss.serialize_state_as_session.side_effect = OSError("disk full")
        restart.restart(True, self.boss)
        self.boss.handle_quit_confirmation.assert_not_called()
        self.popen.assert_not_called()
        self.boss.show_error.assert_called_once()

    def test_spawn_failure_leaves_kitty_running(self):
        self.popen.side_effect = OSError("cannot spawn")
        restart.restart(True, self.boss)
        self.boss.handle_quit_confirmation.assert_not_called()
        self.boss.show_error.assert_called_once()

    def test_snapshot_exists_before_quit_and_waiter_is_detached(self):
        def quit_kitty(confirmed):
            self.assertTrue(confirmed)
            self.popen.assert_called_once()
            command = self.popen.call_args.args[0]
            snapshot = Path(command[4])
            self.assertEqual(snapshot.read_text(), "layout stack\nlaunch")
            self.assertEqual(snapshot.stat().st_mode & 0o777, 0o600)

        self.boss.handle_quit_confirmation.side_effect = quit_kitty
        restart.restart(True, self.boss)
        self.boss.show_error.assert_not_called()
        opts = self.boss.serialize_state_as_session.call_args.args[1]
        self.assertTrue(opts.os_window_geometry)
        self.assertFalse(opts.use_foreground_process)
        self.assertTrue(self.popen.call_args.kwargs["start_new_session"])
        self.assertEqual(self.popen.call_args.args[0][5:], [
            "--config", "/tmp/custom kitty.conf", "--override", "font_size=16",
        ])

    def test_quit_veto_stops_waiter(self):
        restart.current_application_quit_request.return_value = 0
        restart.restart(True, self.boss)
        self.popen.return_value.terminate.assert_called_once()

    def test_native_kitten_loader_can_prepare_restart_without_file_global(self):
        kitten = import_kitten_main_module(str(SCRIPT.parent), SCRIPT.name)
        namespace = kitten["start"].__globals__
        self.assertNotIn("__file__", namespace)
        with patch.dict(namespace, {
            "config_dir": str(SCRIPT.parent),
            "get_options": restart.get_options,
            "kitty_exe": restart.kitty_exe,
            "current_application_quit_request": restart.current_application_quit_request,
        }):
            namespace["restart"](True, self.boss)
        self.boss.show_error.assert_not_called()
        self.boss.handle_quit_confirmation.assert_called_once_with(True)
        self.assertEqual(self.popen.call_args.args[0][1], str(SCRIPT.with_name("restart.sh")))


class WaiterTests(unittest.TestCase):
    def test_reopens_only_after_old_process_exits_and_preserves_arguments(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            output = root / "arguments"
            fake_kitty = root / "fake kitty"
            fake_kitty.write_text(
                '#!/bin/sh\nkill -0 "$RESTART_TEST_PID" 2>/dev/null && exit 99\n'
                'printf "%s\\n" "$@" > "$RESTART_TEST_OUTPUT"\n'
            )
            fake_kitty.chmod(0o700)
            old = subprocess.Popen(["/bin/sleep", "0.3"])
            waiter = subprocess.Popen([
                "/bin/sh", str(SCRIPT.with_name("restart.sh")), str(old.pid),
                str(fake_kitty), str(root / "snapshot with spaces"),
                "--config", "/tmp/custom config",
            ], env={**os.environ, "RESTART_TEST_OUTPUT": str(output), "RESTART_TEST_PID": str(old.pid)})
            try:
                self.assertFalse(output.exists())
                self.assertIsNone(waiter.poll())
                old.wait(timeout=3)
                self.assertEqual(waiter.wait(timeout=3), 0)
                self.assertEqual(output.read_text().splitlines(), [
                    "--detach", "--config", "/tmp/custom config", "--session",
                    str(root / "snapshot with spaces"),
                ])
            finally:
                for process in (old, waiter):
                    if process.poll() is None:
                        process.terminate()
                    process.wait()


if __name__ == "__main__":
    unittest.main()
