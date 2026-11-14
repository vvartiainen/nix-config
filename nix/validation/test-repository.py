"""Run behavior suites without reading real host configuration or credentials."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


FAST = {
    "repository": ["test_*.py"],
    "darwin": ["test_default_apps.py"],
    "kitty": ["test_kitty_metrics.py", "test_kitty_tab_bar.py"],
    "ai": ["test_agent_hooks.py", "test_pi_safehouse_startup.py", "test_pi_worktrees.py"],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--full", action="store_true", help="also test schemas, policy and Kitty runtime")
    mode.add_argument("--integration", action="store_true", help="run Safehouse and Neovim runtime tests")
    args = parser.parse_args()
    root = Path.cwd()
    if not (root / "tests/repository/test_repository_checks.py").is_file():
        parser.error("run from the repository root")
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", GIT_CONFIG_GLOBAL=os.devnull,
               GIT_CONFIG_NOSYSTEM="1")
    commands = []

    def suite(directory, pattern):
        commands.append([sys.executable, "-B", "-m", "unittest", "discover",
                         "-s", f"tests/{directory}", "-p", pattern, "-v"])

    if args.integration:
        for name in ("SAFEHOUSE", "PI_SANDBOX_TEST_ROOT", "NVIM_TEST_PLUGINS"):
            if not env.get(name) or not Path(env[name]).exists():
                parser.error(f"{name} must name an existing integration-test path (see docs/maintenance.md)")
        if sys.platform != "darwin":
            parser.error("Safehouse integration tests require macOS")
        suite("ai", "test_pi_safehouse.py")
        commands.append(["nvim", "--headless", "-u", "NONE", "-i", "NONE",
                         "-l", "tests/neovim/test-tools.lua"])
    else:
        if args.full:
            if not env.get("AI_PERMISSION_FIXTURE"):
                parser.error("full tests require the packaged runner; use just test")
            if not shutil.which("kitty"):
                parser.error("full tests require the configured Kitty installation on PATH")
        for directory, patterns in FAST.items():
            for pattern in patterns:
                suite(directory, pattern)
        if args.full:
            for pattern in ("test_agent_config_validation.py", "test_cleanup_agent_config.py",
                            "test_shell_review.py"):
                suite("ai", pattern)
            for name in ("test_kitty_open_actions.py", "test_kitty_restart.py"):
                commands.append(["kitty", "+runpy", "import runpy; "
                                 f"runpy.run_path('tests/kitty/{name}', run_name='__main__')"])
    failed = False
    for command in commands:
        print("+ " + " ".join(command), flush=True)
        try:
            result = subprocess.run(command, env=env, timeout=120 if args.integration else 30,
                                    stdin=subprocess.DEVNULL, check=False)
            failed |= result.returncode != 0
        except (OSError, subprocess.TimeoutExpired) as error:
            print(str(error), file=sys.stderr)
            failed = True
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
