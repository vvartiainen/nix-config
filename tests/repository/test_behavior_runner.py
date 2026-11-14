"""Check suite selection and failure propagation without launching applications."""

import importlib.util
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[2] / "nix/validation/test-repository.py"
spec = importlib.util.spec_from_file_location("behavior_runner", SCRIPT)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class BehaviorRunnerTests(unittest.TestCase):
    def test_fast_mode_does_not_run_runtime_or_schema_suites(self):
        with (
            patch.object(runner.sys, "argv", [str(SCRIPT)]),
            patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run,
        ):
            self.assertEqual(runner.main(), 0)
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(len(commands), 7)
        self.assertTrue(all("unittest" in command for command in commands))
        self.assertFalse(any("test_pi_safehouse.py" in command for command in commands))

    def test_failure_is_nonzero_and_remaining_suites_still_run(self):
        with (
            patch.object(runner.sys, "argv", [str(SCRIPT)]),
            patch.object(runner.subprocess, "run", side_effect=[
                subprocess.CompletedProcess([], 1),
                *[subprocess.CompletedProcess([], 0) for _ in range(6)],
            ]) as run,
        ):
            self.assertEqual(runner.main(), 1)
            self.assertEqual(run.call_count, 7)

    def test_full_mode_without_fixture_fails_instead_of_skipping_policy(self):
        with (
            patch.object(runner.sys, "argv", [str(SCRIPT), "--full"]),
            patch.dict(os.environ, {}, clear=True),
            patch.object(runner.subprocess, "run") as run,
            self.assertRaises(SystemExit) as error,
        ):
            runner.main()
        self.assertEqual(error.exception.code, 2)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
