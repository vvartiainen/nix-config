"""Test the agent betterleaks wrapper with a fake betterleaks; no real scan."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "nix/modules/home/programs/ai/shared/agent-betterleaks.sh"


class AgentBetterleaksTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.out = self.root / "out"
        fake = self.bin / "betterleaks"
        fake.write_text(
            "#!/bin/sh\n"
            f'printf "%s\\n" "$HOME" "$XDG_CONFIG_HOME" "$*" > "{self.out}"\n'
            "touch \"$HOME/cache\"\n"
            "exit 3\n"
        )
        fake.chmod(0o755)
        self.user_home = self.root / "user"
        self.user_home.mkdir()
        self.tmp = self.root / "tmp"
        self.tmp.mkdir()

    def run_wrapper(self, **extra):
        env = {
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "HOME": str(self.user_home),
            "TMPDIR": str(self.tmp),
            **extra,
        }
        return subprocess.run(
            ["bash", "-euo", "pipefail", str(SCRIPT), "dir", "a b"],
            env=env, capture_output=True, text=True,
        )

    def test_runs_with_a_throwaway_home_and_keeps_exit_status(self):
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 3, result.stderr)
        home, config, args = self.out.read_text().splitlines()
        self.assertTrue(home.startswith(f"{self.tmp}/agent-betterleaks."))
        self.assertEqual(config, f"{self.user_home}/.config")
        self.assertEqual(args, "dir a b")
        self.assertFalse(os.path.exists(home))
        self.assertEqual(list(self.tmp.iterdir()), [])

    def test_keeps_an_existing_config_home(self):
        self.run_wrapper(XDG_CONFIG_HOME="/synthetic/config")
        self.assertEqual(self.out.read_text().splitlines()[1], "/synthetic/config")


if __name__ == "__main__":
    unittest.main()
