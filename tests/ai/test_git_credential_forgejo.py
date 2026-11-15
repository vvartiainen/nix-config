"""Check the git credential helper sandboxes use for the restricted forge token."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[2] / "nix/modules/home/programs/ai/shared/git-credential-forgejo.sh"


class ForgejoCredentialTests(unittest.TestCase):
    def setUp(self):
        if shutil.which("jq") is None:
            self.skipTest("jq is required to run the credential helper")
        self.scratch = tempfile.TemporaryDirectory(prefix="git-credential-forgejo-")
        self.addCleanup(self.scratch.cleanup)
        self.keystore = Path(self.scratch.name) / "keys.json"
        self.keystore.write_text(json.dumps({
            "hosts": {"forge.example": {"type": "Application", "token": "synthetic-token"}},
            "aliases": {},
            "default_ssh": [],
        }))

    def run_helper(self, operation, host, keystore=None):
        env = dict(os.environ)
        env.pop("FORGE_KEYSTORE", None)
        if keystore is not False:
            env["FORGE_KEYSTORE"] = str(keystore or self.keystore)
        request = f"protocol=https\nhost={host}\n\n" if host is not None else ""
        return subprocess.run(
            ["/bin/bash", str(HELPER), operation],
            input=request, env=env, text=True, capture_output=True,
        )

    def test_answers_the_stored_token_for_its_host(self):
        result = self.run_helper("get", "forge.example")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "username=forge-token\npassword=synthetic-token\n")

    def test_stays_silent_for_other_hosts_and_missing_state(self):
        cases = {
            "unknown host": (self.keystore, "other.example"),
            "no host in request": (self.keystore, None),
        }
        for name, (keystore, host) in cases.items():
            with self.subTest(name):
                result = self.run_helper("get", host, keystore)
                self.assertEqual((result.returncode, result.stdout), (0, ""))
        result = self.run_helper("get", "forge.example", keystore=False)
        self.assertEqual((result.returncode, result.stdout), (0, ""))
        result = self.run_helper("get", "forge.example", keystore=Path(self.scratch.name) / "absent.json")
        self.assertEqual((result.returncode, result.stdout), (0, ""))

    def test_malformed_state_and_other_operations_never_fail_a_git_command(self):
        self.keystore.write_text("not json")
        result = self.run_helper("get", "forge.example")
        self.assertEqual((result.returncode, result.stdout), (0, ""))
        for operation in ("store", "erase"):
            with self.subTest(operation):
                result = self.run_helper(operation, "forge.example")
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
        # The helper cannot be asked to persist or delete credentials.
        self.keystore.write_text(json.dumps({"hosts": {}, "aliases": {}, "default_ssh": []}))
        result = self.run_helper("store", "forge.example")
        self.assertEqual(json.loads(self.keystore.read_text())["hosts"], {})
        self.assertEqual(self.run_helper("unknown", "forge.example").returncode, 2)


if __name__ == "__main__":
    unittest.main()
