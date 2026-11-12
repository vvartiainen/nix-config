"""Exercise approvals against fixture-generated policy, without running commands.

Set AI_PERMISSION_FIXTURE to the JSON from permission-fixture.nix.
"""

import importlib.util
import json
import os
import re
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "nix/modules/home/programs/ai/shared/shell-review.py"
spec = importlib.util.spec_from_file_location("shell_review", SCRIPT)
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)


@unittest.skipUnless(os.environ.get("AI_PERMISSION_FIXTURE"), "requires generated fixture policy")
class ShellReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads(Path(os.environ["AI_PERMISSION_FIXTURE"]).read_text())
        cls.policy = cls.fixture["commands"]

    def test_decision_matrix(self):
        cases = {
            "git status && rg -n TODO .": "allow",
            "git status\n": "allow",
            "python3 -m unittest discover": "allow",
            "go test ./...": "allow",
            "rm -rf /tmp/disposable-workspace-output": "allow",
            "rex ls --json": "allow",
            "rex --help": "allow",
            "kitty --version": "allow",
            "incus list": "allow",
            "git status && npm publish": "ask",
            "git status\nrex send-key enter": "ask",
            "rex capture --trim": "ask",
            "rex -S other-host run -- id": "ask",
            "/Applications/Rex.app/Contents/Helpers/Rex\\ Server.rex/Contents/MacOS/rex run -- id": "ask",
            "/opt/homebrew/bin/kitty @ send-text payload": "ask",
            "kitten @ launch sh": "ask",
            "incus exec guest -- id": "ask",
            "incus launch images:alpine guest": "ask",
            "sudo launchctl list": "ask",
            "darwin-rebuild switch": "ask",
            "just switch fixture": "ask",
            "npm install": "ask",
            "npm i": "ask",
            "uv sync": "ask",
            "mise install node": "ask",
            "git push origin main": "ask",
            "nix build .#system": "ask",
            "gh api repos/example/project": "ask",
            "sh -c 'rex run -- id'": "ask",
            "env NAME=value rex run -- id": "ask",
            "echo $(rex ls)": "ask",
            "if true; then rex run -- id; fi": "ask",
            "git -C elsewhere push": "ask",
            "git status &&": "ask",
            "unterminated '": "ask",
            "gh auth token": "deny",
            "gh auth status --hostname github.com --show-token": "deny",
            "security export -t privKeys": "deny",
            "op read op://synthetic/item": "deny",
            "git status && git push origin main --force": "deny",
            "git push origin -f main": "deny",
            "git push --force-with-lease=refs/heads/main origin main": "deny",
            "git clean -xfd": "deny",
            "git reset HEAD --hard": "deny",
            "diskutil eraseDisk APFS test /dev/synthetic": "deny",
            "dd if=/dev/zero of=/dev/synthetic": "deny",
            "rm -rf /": "deny",
        }
        for command, expected in cases.items():
            with self.subTest(command=command):
                self.assertEqual(review.decide(command, self.policy), expected)

    def test_lenient_decision_matrix(self):
        # Claude mode: "allow" defers to native rules and the sandbox.
        cases = {
            "ls 2>/dev/null": "allow",
            "make test 2>&1 | tail -20": "allow",
            "grep -n TODO . > /tmp/out.txt": "allow",
            "echo $HOME ${PATH}": "allow",
            "NAME=value make test": "allow",
            "timeout 60 python3 -m unittest": "allow",
            "for f in *.nix; do statix check $f; done": "allow",
            "git -C elsewhere status": "allow",
            "bash -c 'git status'": "allow",
            "git status &&": "allow",
            "unterminated '": "allow",
            "rex --help": "allow",
            "git status 2>&1 && npm publish": "ask",
            "echo $(rex run -- id)": "ask",
            "echo `rex capture`": "ask",
            "cat <(rex capture)": "ask",
            "env NAME=value rex run -- id": "ask",
            "timeout 5 git push origin main": "ask",
            "sh -c 'rex run -- id'": "ask",
            "bash -lc 'nix build .#system'": "ask",
            "eval git push": "ask",
            "if true; then rex run -- id; fi": "ask",
            "git -C elsewhere push": "ask",
            "git -c core.pager=cat push": "ask",
            "find . -exec rex run -- id ;": "ask",
            "FOO=1 git push origin main 2>/dev/null": "ask",
            "git -C elsewhere push --force": "deny",
            "xargs git clean -xfd": "deny",
            "bash -c 'gh auth token'": "deny",
            "ls && rm -rf /": "deny",
        }
        for command, expected in cases.items():
            with self.subTest(command=command):
                self.assertEqual(review.decide(command, self.policy, strict=False), expected)

    def run_hook(self, client, request):
        with tempfile.TemporaryDirectory() as scratch:
            policy = Path(scratch) / "policy.json"
            policy.write_text(json.dumps(self.policy))
            result = subprocess.run(
                [sys.executable, str(SCRIPT), client, str(policy)],
                input=json.dumps(request), text=True, capture_output=True, check=True,
            )
        return json.loads(result.stdout)

    def test_hook_outputs_and_unsandboxed_retries(self):
        for sandbox, expected in [(True, "allow"), (False, "ask"), (None, "ask")]:
            response = self.run_hook("cursor", {"command": "cat README.md", "sandbox": sandbox})
            self.assertEqual(response["permission"], expected)
        self.assertEqual(self.run_hook("cursor", {"command": "rex --help"})["permission"], "allow")
        self.assertEqual(self.run_hook("cursor", {"command": "npm publish", "sandbox": True})["permission"], "ask")
        self.assertEqual(self.run_hook("cursor", {"command": 123})["permission"], "ask")
        self.assertEqual(self.run_hook("cursor", ["malformed"])["permission"], "deny")
        self.assertEqual(self.run_hook("claude", {"tool_input": {"command": "cat README.md"}}), {})
        self.assertEqual(self.run_hook("claude", {"tool_input": {"command": "ls 2>/dev/null | head"}}), {})
        self.assertEqual(self.run_hook("cursor", {"command": "ls 2>/dev/null | head", "sandbox": True})["permission"], "ask")
        response = self.run_hook("claude", {"tool_input": {"command": "rex send-key enter"}})
        self.assertEqual(response["hookSpecificOutput"]["permissionDecision"], "ask")

    @unittest.skipUnless(shutil.which("codex"), "requires Codex's native rule evaluator")
    def test_codex_native_rules(self):
        # Build the fixture first so writeText outputs referenced by activation
        # exist. No command under test is executed by execpolicy check.
        rules = re.search(r"install -m 0644 (/nix/store/[^ ]+)", self.fixture["codex"]).group(1)
        self.assertTrue(Path(rules).exists(), "build the fixture system before native policy tests")
        for argv, expected in [
            (["git", "status"], None),
            (["npm", "i"], "prompt"),
            (["sudo", "id"], "prompt"),
            (["rex", "run", "--", "id"], "prompt"),
            (["rex", "--help"], "prompt"),
            (["kitty", "@", "send-text", "payload"], "prompt"),
            (["incus", "exec", "guest", "--", "id"], "prompt"),
            (["git", "push", "origin", "main"], "prompt"),
            (["gh", "auth", "token"], "forbidden"),
            (["gh", "auth", "status", "--show-token"], "forbidden"),
            (["git", "reset", "--hard"], "forbidden"),
            (["git", "push", "--force", "origin", "main"], "forbidden"),
            # Native prefix limitation: a trailing flag is still reviewed.
            (["git", "push", "origin", "main", "--force"], "prompt"),
            (["rm", "-rf", "/"], "forbidden"),
        ]:
            with self.subTest(argv=argv):
                result = subprocess.run(
                    ["codex", "execpolicy", "check", "--rules", rules, "--", *argv],
                    text=True, capture_output=True, check=True,
                )
                self.assertEqual(json.loads(result.stdout).get("decision"), expected)

    def test_generated_adapter_boundaries(self):
        rules = self.fixture["opencode"]
        self.assertIn({"action": "shell", "resource": "*", "effect": "ask"}, rules)
        for action in ["read", "edit", "external_directory"]:
            self.assertIn({"action": action, "resource": "/Users/agent/.ssh/*", "effect": "deny"}, rules)
        for command in ["just", "npm run", "rg", "find", "awk", "rm"]:
            self.assertNotIn({"action": "shell", "resource": command + " *", "effect": "allow"}, rules)
        launch = self.fixture["launch"]
        self.assertIn("--sandbox", launch)
        self.assertIn("shell(cargo test:*)", launch)
        self.assertNotIn("shell(just:*)", launch)
        self.assertIn("read(**/.env)", launch)
        self.assertIn("read(/Users/agent/.ssh/**)", launch)
        self.assertIn("beforeShellExecution", self.fixture["hooks"]["cursor"])
        self.assertIn("PreToolUse", self.fixture["hooks"]["claude"])


if __name__ == "__main__":
    unittest.main()
