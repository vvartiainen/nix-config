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
            "flake-update-preview": "allow",
            "flake-update-preview nixpkgs": "allow",
            "nix flake update": "ask",
            "git status\n": "allow",
            "python3 -m unittest discover": "allow",
            "go test ./...": "allow",
            "agent-betterleaks git .": "allow",
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
            "fj-edit-body pr 1 /tmp/body.md": "ask",
            "fj pr search -r forge.example/owner/repo": "allow",
            "fj issue search -r forge.example/owner/repo": "allow",
            "fj pr view 'forge.example/owner/repo#13'": "allow",
            "fj pr status 'forge.example/owner/repo#13'": "allow",
            "fj issue view 'forge.example/owner/repo#13'": "allow",
            "fj repo view forge.example/owner/repo": "allow",
            "fj pr create -r forge.example/owner/repo --body-file /tmp/body.md title": "ask",
            "fj issue create -r forge.example/owner/repo --body-file /tmp/body.md title": "ask",
            "op-item-from-secret --vault Synthetic --title Example /tmp/secret": "ask",
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
            "flake-update-preview": "allow",
            "flake-update-preview nixpkgs": "allow",
            "nix flake update": "ask",
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
            "GIT_EDITOR=true git rebase --continue": "allow",
            "git reset --soft HEAD~1": "allow",
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

    def test_claude_literal_heredocs(self):
        # Python open() in both reported edit-and-check calls is data, not
        # the macOS host command. Include text that shlex cannot parse as shell.
        for checks in [
            "gofmt -l cmd internal; go build ./... && go vet ./internal/provision ./internal/service ./cmd/...",
            "gofmt -l internal cmd; go vet ./internal/provision && go test ./internal/provision/ 2>&1 | tail -30",
        ]:
            command = """cd /tmp/agents-work/wt/example && python3 - <<'EOF'
p='internal/service/example.go'
s=open(p).read()
s=s.replace("old", "new")
open(p,'w').write(s)
# Don't interpret rex run, git push, or unmatched ' as shell here.
EOF
""" + checks
            with self.subTest(checks=checks):
                self.assertEqual(self.run_hook("claude", {"tool_input": {"command": command}}), {})
                # Cursor still asks for syntax it cannot inspect.
                self.assertEqual(review.decide(command, self.policy), "ask")

        cases = {
            'cat <<"END"\nopen(file)\nEND\n': "allow",
            "cat <<\\END\nopen(file)\nEND\n": "allow",
            "cat <<-'END'\n\topen(file)\n\tEND\n": "allow",
            "cat <<'A' <<'B'\nopen(file)\nA\nrex run\nB\ngo test ./...": "allow",
            "cat <<'A' <<B\nopen(file)\nA\n$(rex run -- id)\nB\n": "ask",
            "cat <<'END'\n$(rex run -- id)\nEND\n": "allow",
            "cat <<'END'\ntext\nEND\nrex run -- id": "ask",
            "cat <<'END'; git push\ntext\nEND\n": "ask",
            "rex run <<'END'\ntext\nEND\n": "ask",
            "cat <<END\n$(rex run -- id)\nEND\n": "ask",
            "cat <<'END'\ntext\nEND\ncat <<END\n$(git push --force)\nEND\n": "deny",
            "echo \"<<'END'\"\nrex run\nEND\n": "ask",
            "echo hi;# <<'END'\nrex run\nEND\n": "ask",
            "cat <<'END'\nrex run\n": "ask",
        }
        for command, expected in cases.items():
            with self.subTest(command=command):
                self.assertEqual(review.decide(command, self.policy, strict=False), expected)

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
            (["flake-update-preview"], "allow"),
            (["flake-update-preview", "nixpkgs"], "allow"),
            (["nix", "flake", "update"], "prompt"),
            (["git", "status"], None),
            (["git", "rebase", "main"], None),
            (["git", "reset", "--soft", "HEAD~1"], None),
            (["git", "clean", "--dry-run"], None),
            (["npm", "i"], "prompt"),
            (["sudo", "id"], "prompt"),
            (["rex", "run", "--", "id"], "prompt"),
            (["rex", "--help"], "prompt"),
            (["kitty", "@", "send-text", "payload"], "prompt"),
            (["incus", "exec", "guest", "--", "id"], "prompt"),
            (["git", "push", "origin", "main"], "prompt"),
            (["git", "fetch", "origin"], "prompt"),
            (["fj", "pr", "view", "13"], "allow"),
            (["fj", "pr", "search", "-r", "forge.example/owner/repo"], "allow"),
            (["fj", "issue", "search", "-r", "forge.example/owner/repo"], "allow"),
            (["fj", "pr", "view", "forge.example/owner/repo#13"], "allow"),
            (["fj", "pr", "status", "forge.example/owner/repo#13"], "allow"),
            (["fj", "issue", "view", "forge.example/owner/repo#13"], "allow"),
            (["fj", "repo", "view", "forge.example/owner/repo"], "allow"),
            (["fj", "pr", "create", "-r", "forge.example/owner/repo"], "prompt"),
            (["fj", "issue", "create", "-r", "forge.example/owner/repo"], "prompt"),
            (["gh", "pr", "checks", "13"], "allow"),
            (["gh", "pr", "create"], "prompt"),
            (["gh", "auth", "status", "-t"], None),
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

    def test_codex_network_enforcement(self):
        settings = re.search(
            r"--settings (/nix/store/[^ ]+)", self.fixture["codex"]
        ).group(1)
        self.assertTrue(Path(settings).exists(), "build the fixture system before settings tests")
        config = json.loads(Path(settings).read_text())
        # UI feature settings must not replace the network enforcement flag.
        self.assertTrue(config["features"]["network_proxy"])
        self.assertFalse(config["features"]["apps"])
        self.assertFalse(config["features"]["mentions_v2"])
        network = config["permissions"]["workspace-only"]["network"]
        self.assertEqual(network["domains"], {"*": "allow"})
        self.assertEqual(config["approval_policy"], "on-request")
        self.assertEqual(config["approvals_reviewer"], "user")
        self.assertFalse(network["dangerously_allow_all_unix_sockets"])
        self.assertEqual(
            network["unix_sockets"],
            {
                self.fixture["paths"]["nixDaemonSocket"]: "allow",
                **{path: "allow" for path in self.fixture["socketDirs"]},
            },
        )

    def test_codex_protects_worktree_configuration(self):
        settings = re.search(r"--settings (/nix/store/[^ ]+)", self.fixture["codex"]).group(1)
        config = json.loads(Path(settings).read_text())
        filesystem = config["permissions"]["workspace-only"]["filesystem"]
        workspace = filesystem[":workspace_roots"]
        for path in (".git/config", ".git/config.worktree", ".git/hooks", ".git/worktrees"):
            self.assertEqual(workspace[path], "read")
        shared_configs = [path for path in filesystem if path.endswith("/.git/config")]
        self.assertTrue(shared_configs)
        for path in shared_configs:
            self.assertEqual(filesystem[path + ".worktree"], "read")
            self.assertEqual(filesystem[path.removesuffix("config") + "worktrees"], "read")
        # Terminal launches grant shared metadata dynamically; these must keep
        # per-worktree config protected when granting the index and refs.
        for path in ("$c/config.worktree", "$c/worktrees", "$g/config.worktree", "$g/config", "$g/hooks"):
            self.assertIn(path, self.fixture["launch"])

    def test_git_maintenance_has_a_narrow_unsandboxed_entry(self):
        self.assertEqual(self.policy["gitMaintenance"], [["agent-git"]])
        rules = Path(re.search(r"install -m 0644 (/nix/store/[^ ]+)", self.fixture["codex"]).group(1)).read_text()
        self.assertIn('pattern = ["agent-git"], decision = "allow"', rules)
        claude = self.settings_file("claude", "claude-code-settings")
        self.assertIn("agent-git *", claude["sandbox"]["excludedCommands"])
        self.assertIn("Bash(agent-git:*)", claude["permissions"]["allow"])

    def settings_file(self, client, name):
        path = Path(re.search(rf"--settings (/nix/store/[^ ]+-{name}[^ ]*\.json)", self.fixture[client]).group(1))
        self.assertTrue(path.exists(), "build the fixture system before settings tests")
        return json.loads(path.read_text())

    def test_claude_generated_rules_do_not_mix_globs_and_prefix_syntax(self):
        permissions = self.settings_file("claude", "claude-code-settings")["permissions"]
        for action in ("allow", "ask", "deny"):
            for rule in permissions[action]:
                with self.subTest(action=action, rule=rule):
                    self.assertIsNone(re.search(r"\*.*:\*\)$", rule))

    def test_sandbox_sockets_match_codex(self):
        # Only the Nix daemon socket and the agent plugin socket directory are
        # reachable; Rex and localhost stay out.
        socket = self.fixture["paths"]["nixDaemonSocket"]
        socket_dirs = self.fixture["socketDirs"]
        self.assertTrue(socket_dirs)
        self.assertTrue(all(path.endswith("-agent") for path in socket_dirs))
        claude = self.settings_file("claude", "claude-code-settings")
        self.assertTrue(claude["sandbox"]["enabled"])
        self.assertIn("fj *", claude["sandbox"]["excludedCommands"])
        for command in ("pr search", "pr view", "pr status", "issue search", "issue view", "repo view"):
            self.assertIn(f"Bash(fj {command}:*)", claude["permissions"]["allow"])
        for command in ("pr create", "issue create"):
            self.assertIn(f"Bash(fj {command}:*)", claude["permissions"]["ask"])
            self.assertNotIn(f"Bash(fj {command}:*)", claude["permissions"]["allow"])
        self.assertFalse(claude["sandbox"]["network"]["allowAllUnixSockets"])
        self.assertEqual(claude["sandbox"]["network"]["allowUnixSockets"], [socket, *socket_dirs])
        self.assertFalse(claude["sandbox"]["network"]["allowLocalBinding"])
        for path in (
            "**/.git/config", "**/.git/config.worktree", "**/.git/hooks",
            "**/.git/worktrees/*/config", "**/.git/worktrees/*/config.worktree",
            "**/.git/worktrees/*/hooks",
        ):
            self.assertIn(path, claude["sandbox"]["filesystem"]["denyWrite"])
        self.assertEqual(claude["env"]["PLUGIN_UNIX_SOCKET_DIR"], socket_dirs[0])
        for wrapper in ["fj-edit-body", "op-item-from-secret"]:
            self.assertIn(f"{wrapper} *", claude["sandbox"]["excludedCommands"])
            self.assertIn(f"Bash({wrapper}:*)", claude["permissions"]["ask"])
        self.assertEqual(claude["permissions"]["defaultMode"], "acceptEdits")
        self.assertIn("Bash(npm publish:*)", claude["permissions"]["ask"])
        for executable in self.fixture["commands"]["rexExecutables"]:
            self.assertIn(f"{executable} *", claude["sandbox"]["excludedCommands"])
            self.assertIn(f"Bash({executable} *)", claude["permissions"]["ask"])
        self.assertFalse([rule for rule in claude["permissions"]["allow"] if rule.startswith("Bash(rex")])
        # Configured-remote fetches leave the sandbox unprompted; other
        # repositories and --upload-pack still ask. Local history edits stay
        # sandboxed.
        self.assertIn("Bash(git fetch:*)", claude["permissions"]["allow"])
        self.assertNotIn("Bash(git fetch:*)", claude["permissions"]["ask"])
        for pattern in self.fixture["commands"]["fetchReviewPatterns"]:
            self.assertIn(f"Bash({pattern})", claude["permissions"]["ask"])
        self.assertIn("git fetch *", claude["sandbox"]["excludedCommands"])
        # SSH pushes leave the sandbox but still ask; force pushes stay denied.
        self.assertIn("git push *", claude["sandbox"]["excludedCommands"])
        self.assertIn("Bash(git push:*)", claude["permissions"]["ask"])
        self.assertNotIn("Bash(git push:*)", claude["permissions"]["allow"])
        self.assertIn("Bash(git push --force:*)", claude["permissions"]["deny"])
        self.assertNotIn("Bash(git rebase:*)", claude["permissions"]["ask"])
        self.assertEqual(claude["env"]["GIT_CONFIG_KEY_0"], "branch.autoSetupMerge")
        xdg_cache = claude["env"]["XDG_CACHE_HOME"]
        self.assertTrue(xdg_cache.endswith("/.cache/xdg-agent"))
        self.assertIn(xdg_cache, claude["sandbox"]["filesystem"]["allowWrite"])
        self.assertIn("flake-update-preview", claude["sandbox"]["excludedCommands"])
        self.assertIn("flake-update-preview *", claude["sandbox"]["excludedCommands"])
        self.assertIn("Bash(flake-update-preview)", claude["permissions"]["allow"])
        self.assertIn("Bash(flake-update-preview:*)", claude["permissions"]["allow"])
        self.assertNotIn("Bash(flake-update-preview:*)", claude["permissions"]["ask"])
        hosts = claude["sandbox"]["network"]["allowedDomains"]
        self.assertIn("wthziax2yejsqc4k.public.blob.vercel-storage.com", hosts)
        for host in ["api.github.com", "raw.githubusercontent.com"]:
            self.assertIn(host, hosts)
            self.assertIn(f"WebFetch(domain:{host})", claude["permissions"]["allow"])
        for host in [
            "github.com", "codeload.github.com", "*.github.com",
            "*.githubusercontent.com", "*.vercel-storage.com", "*",
        ]:
            self.assertNotIn(host, hosts)
        cursor = self.settings_file("cursor", "cursor-cli-config")
        self.assertEqual(cursor["sandbox"]["networkAllowlist"], hosts)
        copilot = self.settings_file("copilot", "github-copilot-cli-settings")
        policy = copilot["sandbox"]["userPolicy"]
        self.assertTrue(copilot["sandbox"]["enabled"])
        self.assertEqual(policy["network"]["allowedHosts"], hosts)
        self.assertFalse(policy["network"]["allowLocalNetwork"])
        self.assertFalse([p for p in policy["filesystem"]["readwritePaths"] if "rex" in p.lower()])
        self.assertIn(socket, policy["filesystem"]["readwritePaths"])
        launch = self.fixture["launch"]
        self.assertIn("shell(rex ls:*)", launch)
        self.assertNotIn("shell(rex:*)", launch)
        self.assertNotIn("shell(rex run", launch)

    def test_t3_private_settings_and_credentials_stay_denied(self):
        paths = self.fixture["paths"]
        for name in ("settings.json", "client-settings.json", "secrets"):
            path = f"/Users/agent/.t3/userdata/{name}"
            with self.subTest(name=name):
                self.assertIn(path, paths["denied"])
                self.assertFalse(any(
                    path == readable or path.startswith(readable + "/")
                    for readable in paths["readable"]
                ))

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
        bash_hooks = [handler for group in self.fixture["hooks"]["claude"]["PreToolUse"]
                      if group.get("matcher") == "Bash" for handler in group["hooks"]]
        fetch_hooks = [handler for handler in bash_hooks
                       if "nix-config-fetch-review-claude" in handler["command"]]
        self.assertEqual(len(fetch_hooks), 1)
        self.assertEqual(fetch_hooks[0]["type"], "command")
        self.assertEqual(fetch_hooks[0]["onFailure"], "block")
        self.assertTrue(all("onFailure" not in handler for handler in bash_hooks
                            if handler not in fetch_hooks))
        self.assertIn("nix-config-fetch-review-claude", self.fixture["hooks"]["commandMarkers"])

    def test_repository_stop_hooks_use_only_fast_checker(self):
        for client, event in (("codex", "Stop"), ("claude", "Stop"), ("copilot", "agentStop")):
            groups = self.fixture["hooks"][client][event]
            handlers = [handler for group in groups for handler in group.get("hooks", [group])]
            checks = [handler for handler in handlers if "/bin/nix-config-check --hook stop "
                      in handler.get("command", "")]
            self.assertEqual(len(checks), 1, client)
            self.assertNotIn("--full", checks[0]["command"])
            self.assertNotIn("nix build", checks[0]["command"])


if __name__ == "__main__":
    unittest.main()
