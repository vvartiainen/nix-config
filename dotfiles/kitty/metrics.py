"""Persistent quick-access quota view, run with Kitty's bundled Python."""

import os
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import termios
import textwrap
import time
import tty


COMMAND = [
    "/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI",
    "cards", "--provider", "both", "--source", "oauth", "--no-color",
]
REFRESH_INTERVAL = 300
FETCH_TIMEOUT = 30


class Quotas:
    """Keep the last good report while a separate process fetches the next one."""

    def __init__(self, command=COMMAND, interval=REFRESH_INTERVAL, timeout=FETCH_TIMEOUT):
        self.command = command
        self.interval = interval
        self.timeout = timeout
        self.text = ""
        self.updated_at = None
        self.error = ""
        self.partial_text = ""
        self.next_refresh = 0
        self.process = None
        self.started_at = 0
        self.stdout = None
        self.stderr = None

    def refresh(self, columns):
        if self.process is not None:
            return
        self.next_refresh = time.monotonic() + self.interval
        self.stdout = tempfile.TemporaryFile(mode="w+t", encoding="utf-8", errors="replace")
        self.stderr = tempfile.TemporaryFile(mode="w+t", encoding="utf-8", errors="replace")
        try:
            self.process = subprocess.Popen(
                self.command,
                stdin=subprocess.DEVNULL,
                stdout=self.stdout,
                stderr=self.stderr,
                env={**os.environ, "COLUMNS": str(columns)},
                start_new_session=True,
            )
            self.started_at = time.monotonic()
        except OSError as exc:
            self.error = f"Could not start CodexBar: {exc}"
            self.close()

    def poll(self):
        if self.process is None:
            return
        code = self.process.poll()
        timed_out = time.monotonic() - self.started_at >= self.timeout
        if code is None and not timed_out:
            return
        if code is None:
            self.stop_process()
            self.error = f"Refresh timed out after {self.timeout:g}s. Press R to retry."
        else:
            self.stdout.seek(0)
            output = self.stdout.read(1024 * 1024).strip()
            self.stderr.seek(0)
            error = self.stderr.read(4096).strip()
            if code == 0 and output:
                self.text = output
                self.updated_at = time.time()
                self.error = ""
                self.partial_text = ""
            else:
                # Cards can contain usable quotas plus a failure footer while
                # exiting nonzero. Keep that evidence without replacing good data.
                self.partial_text = output
                footer = "\n".join(output.splitlines()[-6:])
                self.error = error or footer or f"CodexBar returned no complete report (exit {code}). Press R to retry."
        self.close()
        self.next_refresh = time.monotonic() + self.interval

    def stop_process(self):
        if self.process is not None and self.process.poll() is None:
            try:
                os.killpg(self.process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            self.process.wait()

    def close(self):
        self.stop_process()
        self.process = None
        for stream in (self.stdout, self.stderr):
            if stream is not None:
                stream.close()
        self.stdout = self.stderr = None


def report_lines(quotas, now=None, columns=100):
    now = time.time() if now is None else now
    status = "Fetching first report…"
    if quotas.updated_at is not None:
        age = max(0, int(now - quotas.updated_at))
        stamp = time.strftime("%H:%M:%S", time.localtime(quotas.updated_at))
        status = f"Updated {stamp} · {age // 60}m {age % 60}s ago"
        if age >= quotas.interval:
            status += " · stale"
        if quotas.process is not None:
            status += " · refreshing…"
    elif quotas.error and quotas.process is None:
        status = "No successful report yet."
    lines = ["METRICS · Codex / Claude", "Esc / Q hide · R refresh · Ctrl+D stop", status, ""]
    if quotas.error:
        message = "Refresh failed: " + " ".join(quotas.error.split())
        lines += textwrap.wrap(message, width=max(1, columns - 1)) + [""]
    if quotas.text:
        if quotas.error:
            lines += ["Last successful report:"]
        lines += quotas.text.splitlines()
    elif quotas.partial_text:
        lines += ["Latest attempt (incomplete):"] + quotas.partial_text.splitlines()
    return lines


def draw(quotas, size):
    lines = report_lines(quotas, columns=size.columns)
    visible = lines[:size.lines]
    if len(lines) > size.lines:
        visible[-1] = "… Resize the dashboard to see the full report."
    # Erase individual lines and the unused area, avoiding a full-screen flash.
    sys.stdout.write("\x1b[H" + "\r\n".join(line[:max(1, size.columns - 1)] + "\x1b[K" for line in visible) + "\x1b[J")
    sys.stdout.flush()


def main(command=COMMAND, interval=REFRESH_INTERVAL, timeout=FETCH_TIMEOUT):
    quotas = Quotas(command, interval, timeout)
    fd = sys.stdin.fileno()
    previous = termios.tcgetattr(fd)
    previous_sigterm = signal.getsignal(signal.SIGTERM)

    def stop(_signum, _frame):
        raise KeyboardInterrupt

    try:
        signal.signal(signal.SIGTERM, stop)
        tty.setcbreak(fd)
        sys.stdout.write("\x1b]2;Metrics\x07\x1b[?1049h\x1b[?25l")
        next_draw = 0
        while True:
            quotas.poll()
            size = shutil.get_terminal_size((100, 28))
            if quotas.process is None and time.monotonic() >= quotas.next_refresh:
                quotas.refresh(size.columns)
            if time.monotonic() >= next_draw:
                draw(quotas, size)
                next_draw = time.monotonic() + 1
            readable, _, _ = select.select([fd], [], [], 0.2)
            if readable:
                keys = os.read(fd, 64)
                if not keys or b"\x04" in keys:
                    break
                if b"r" in keys.lower():
                    quotas.refresh(size.columns)
                    next_draw = 0
    except KeyboardInterrupt:
        pass
    finally:
        quotas.close()
        termios.tcsetattr(fd, termios.TCSADRAIN, previous)
        signal.signal(signal.SIGTERM, previous_sigterm)
        sys.stdout.write("\x1b[?25h\x1b[?1049l")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
