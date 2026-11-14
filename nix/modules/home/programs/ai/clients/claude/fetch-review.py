"""Review Claude's unsandboxed fetches; never execute the requested command.

Only a literal standalone invocation with known options can defer to existing
permissions. Unknown syntax/options ask rather than guessing Git's grammar.
"""

import json
import re
import shlex
import subprocess
import sys


FLAGS = set("""--all --append --atomic --dry-run --force --keep --multiple
--prefetch --prune --prune-tags --no-prune --no-prune-tags --tags --no-tags
--quiet --verbose --progress --no-progress --update-head-ok --update-shallow
--unshallow --no-recurse-submodules --recurse-submodules --no-write-fetch-head
--write-fetch-head --no-auto-maintenance --auto-maintenance --no-auto-gc
--auto-gc --no-write-commit-graph --write-commit-graph --no-show-forced-updates
--show-forced-updates --ipv4 --ipv6 --negotiate-only --no-keep""".split())
VALUES = set("""--depth --deepen --shallow-since --shallow-exclude --jobs
--negotiation-tip --refmap --filter --server-option --submodule-prefix""".split())
OPTIONAL_VALUES = {"--recurse-submodules": {"yes", "on-demand", "no"}}


def needs_review(command, cwd, git="git"):
    if not isinstance(command, str):
        return True
    try:
        argv = shlex.split(command)
    except ValueError:
        return True
    # Leave unrelated Bash commands to the existing shell-review hook. Any
    # fetch-containing wrapper/compound command must be reviewed as a whole.
    if "fetch" not in argv and not re.search(r"\bfetch\b", command):
        return False
    if argv[:2] != ["git", "fetch"]:
        return True
    # shlex is a tokenizer, not a shell parser. Reject expansions, operators,
    # comments, globs and escapes even inside quotes (conservative by design).
    if re.search(r"[\n\r\x00$`;&|<>(){}*?\[\]#!\\]", command):
        return True
    if any(arg.startswith("--upload-pack") or arg.startswith("-u") for arg in argv[2:]):
        return True
    operands = []
    multiple = all_remotes = end_options = False
    args = iter(argv[2:])
    for arg in args:
        if not end_options and arg == "--":
            end_options = True
        elif not end_options and arg.startswith("--"):
            option, equal, value = arg.partition("=")
            if option in VALUES:
                if not equal:
                    value = next(args, None)
                if not value or value.startswith("-"):
                    return True
            elif equal:
                if value not in OPTIONAL_VALUES.get(option, set()):
                    return True
            elif option not in FLAGS:
                return True
            multiple |= option in {"--multiple", "--prefetch"}
            all_remotes |= option == "--all"
        elif not end_options and arg.startswith("-"):
            # -u is --upload-pack; unknown/argument-taking short options ask.
            if len(arg) == 1 or any(flag not in "afkptqvn46" for flag in arg[1:]):
                return True
        else:
            operands.append(arg)
    if not isinstance(cwd, str) or not cwd:
        return True
    try:
        result = subprocess.run(
            [git, "remote"], cwd=cwd, check=True, capture_output=True,
            text=True, timeout=5,
        )
    except (OSError, subprocess.SubprocessError, UnicodeError):
        return True
    remotes = set(result.stdout.splitlines())
    if all_remotes:
        return bool(operands)
    repositories = operands if multiple else operands[:1]
    return any(repository not in remotes for repository in repositories)


def main():
    try:
        request = json.load(sys.stdin)
        review = needs_review(
            request.get("tool_input", {}).get("command"), request.get("cwd"),
            sys.argv[1] if len(sys.argv) > 1 else "git",
        )
    except Exception:
        review = True
    response = {}
    if review:
        response = {"hookSpecificOutput": {
            "hookEventName": "PreToolUse", "permissionDecision": "ask",
            "permissionDecisionReason": "Fetch requires review: use a standalone command with configured remote names and known options.",
        }}
    print(json.dumps(response))


if __name__ == "__main__":
    main()
