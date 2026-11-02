"""Behavior checks with synthetic quota providers; never reads provider configs."""

import importlib.util
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import termios
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[4] / "dotfiles/kitty/metrics.py"
PYTHON = os.environ.get("METRICS_TEST_PYTHON", sys.executable)
spec = importlib.util.spec_from_file_location("metrics", SCRIPT)
metrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metrics)


class QuotaTests(unittest.TestCase):
    def setUp(self):
        self.quotas = metrics.Quotas(
            [PYTHON, "-c", "print('Codex: 75% left\\nClaude: 60% left')"],
            timeout=1,
        )
        self.addCleanup(self.quotas.close)

    def finish_refresh(self):
        deadline = time.monotonic() + 3
        while self.quotas.process is not None and time.monotonic() < deadline:
            self.quotas.poll()
            time.sleep(0.01)
        self.assertIsNone(self.quotas.process, "synthetic provider failed to finish")

    def get_success(self):
        self.quotas.refresh(100)
        self.finish_refresh()
        self.assertIn("75% left", self.quotas.text)
        self.assertIsNotNone(self.quotas.updated_at)
        return self.quotas.text, self.quotas.updated_at

    def test_failed_refresh_keeps_success_and_original_age(self):
        report, stamp = self.get_success()
        self.quotas.command = [PYTHON, "-c", "import sys; sys.exit('synthetic authentication failure')"]
        self.quotas.refresh(100)
        self.finish_refresh()
        self.assertEqual((self.quotas.text, self.quotas.updated_at), (report, stamp))
        self.assertIn("synthetic authentication failure", self.quotas.error)
        lines = "\n".join(metrics.report_lines(self.quotas, now=stamp + 301))
        self.assertIn("stale", lines)
        self.assertIn("5m 1s ago", lines)
        self.assertIn(report, lines)

    def test_timeout_keeps_success_and_allows_retry(self):
        report, stamp = self.get_success()
        self.quotas.timeout = 0.1
        self.quotas.command = [PYTHON, "-c", "import time; time.sleep(30)"]
        self.quotas.refresh(100)
        stalled = self.quotas.process
        self.finish_refresh()
        self.assertIsNotNone(stalled.returncode)
        self.assertEqual((self.quotas.text, self.quotas.updated_at), (report, stamp))
        self.assertIn("timed out", self.quotas.error)
        self.quotas.timeout = 1
        self.quotas.command = [PYTHON, "-c", "print('Recovered quota report')"]
        self.quotas.refresh(100)
        self.finish_refresh()
        self.assertEqual(self.quotas.text, "Recovered quota report")
        self.assertEqual(self.quotas.error, "")

    def test_empty_report_does_not_replace_good_data(self):
        report, stamp = self.get_success()
        self.quotas.command = [PYTHON, "-c", "pass"]
        self.quotas.refresh(100)
        self.finish_refresh()
        self.assertEqual((self.quotas.text, self.quotas.updated_at), (report, stamp))
        self.assertIn("no complete report", self.quotas.error)

    def test_first_partial_report_shows_quota_and_provider_failure(self):
        self.quotas.command = [
            PYTHON, "-c",
            "import sys; print('Codex: 75% left\\nFailed providers: Claude OAuth unavailable'); sys.exit(1)",
        ]
        self.quotas.refresh(100)
        self.finish_refresh()
        self.assertEqual(self.quotas.text, "")
        self.assertIsNone(self.quotas.updated_at)
        lines = "\n".join(metrics.report_lines(self.quotas))
        self.assertIn("Latest attempt (incomplete)", lines)
        self.assertIn("75% left", lines)
        self.assertIn("Claude OAuth unavailable", lines)

    def test_partial_failure_exposes_footer_but_preserves_last_good_report(self):
        report, stamp = self.get_success()
        self.quotas.command = [
            PYTHON, "-c",
            "import sys; print('Codex: 50% left\\nFailed providers: Claude OAuth unavailable'); sys.exit(1)",
        ]
        self.quotas.refresh(100)
        self.finish_refresh()
        self.assertEqual((self.quotas.text, self.quotas.updated_at), (report, stamp))
        lines = "\n".join(metrics.report_lines(self.quotas))
        self.assertIn("Claude OAuth unavailable", lines)
        self.assertIn("Last successful report", lines)
        self.assertIn(report, lines)

    def test_long_error_wraps_instead_of_hiding_its_cause(self):
        self.quotas.error = "Synthetic provider failure " * 10 + "expired OAuth session"
        lines = metrics.report_lines(self.quotas, columns=40)
        self.assertIn("expired OAuth session", " ".join(lines))
        self.assertTrue(all(len(line) < 40 for line in lines[4:]))

    def test_missing_cli_reports_error_without_crashing(self):
        self.quotas.command = ["/nonexistent-synthetic-codexbar"]
        self.quotas.refresh(100)
        self.assertIsNone(self.quotas.process)
        self.assertIn("Could not start", self.quotas.error)
        self.assertIn("No successful report", "\n".join(metrics.report_lines(self.quotas)))

    def test_refresh_while_busy_does_not_replace_running_fetch(self):
        self.quotas.command = [PYTHON, "-c", "import time; time.sleep(30)"]
        self.quotas.refresh(100)
        running = self.quotas.process
        self.quotas.refresh(100)
        self.assertIs(self.quotas.process, running)

    def test_output_larger_than_a_pipe_does_not_block_fetch(self):
        self.quotas.command = [PYTHON, "-c", "print('x' * 100000)"]
        self.quotas.refresh(100)
        self.finish_refresh()
        self.assertEqual(len(self.quotas.text), 100000)
        self.assertEqual(self.quotas.error, "")

    def test_input_stays_responsive_during_fetch_and_terminal_is_restored(self):
        master, slave = pty.openpty()
        self.addCleanup(os.close, master)
        self.addCleanup(os.close, slave)
        previous = termios.tcgetattr(slave)
        program = (
            f"import runpy; ns = runpy.run_path({str(SCRIPT)!r}); "
            f"ns['main'](command={[PYTHON, '-c', 'import time; time.sleep(30)']!r})"
        )
        child = subprocess.Popen(
            [PYTHON, "-c", program], stdin=slave, stdout=slave, stderr=slave,
        )

        def cleanup():
            if child.poll() is None:
                child.terminate()
                child.wait(timeout=3)

        self.addCleanup(cleanup)
        output = b""
        deadline = time.monotonic() + 3
        while b"Fetching first report" not in output and time.monotonic() < deadline:
            readable, _, _ = select.select([master], [], [], 0.1)
            if readable:
                output += os.read(master, 8192)
        self.assertIn(b"Fetching first report", output)
        os.write(master, b"\x04")
        self.assertEqual(child.wait(timeout=2), 0)
        restored = termios.tcgetattr(slave)
        # macOS may set PENDIN when restoring buffered input; it is kernel
        # bookkeeping rather than a change to canonical input or echo settings.
        pending = getattr(termios, "PENDIN", 0)
        restored[3] &= ~pending
        previous[3] &= ~pending
        self.assertEqual(restored, previous)


if __name__ == "__main__":
    unittest.main(argv=[__file__])
