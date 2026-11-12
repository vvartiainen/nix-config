"""Conservative approval hook for clients without native ask exceptions.

This classifies simple shell commands, never executes them. OS sandboxes remain
the security boundary; scripts and interpreters are deliberately opaque.
"""

import fnmatch
import json
from pathlib import PurePosixPath
import re
import shlex
import sys


def prefix(argv, prefixes):
    return any(argv[:len(rule)] == rule for rule in prefixes)


def unit_decision(argv, policy):
    argv = list(argv)
    argv[0] = PurePosixPath(argv[0]).name
    text = " ".join(argv)
    if prefix(argv, policy["denied"]) or any(
        fnmatch.fnmatchcase(text, pattern) for pattern in policy["deniedPatterns"]
    ):
        return "deny"
    # Catch combined short flags, reordered options and --force=... forms.
    if argv[:2] == ["git", "push"] and any(
        arg.startswith("--force") or (arg.startswith("-") and not arg.startswith("--") and "f" in arg[1:])
        for arg in argv[2:]
    ):
        return "deny"
    if argv[:2] == ["git", "clean"] and any(
        arg == "--force" or (arg.startswith("-") and not arg.startswith("--") and "f" in arg[1:])
        for arg in argv[2:]
    ):
        return "deny"
    if prefix(argv, policy["review"]):
        return "ask"
    if argv in policy["hostExact"] or prefix(argv, policy["hostInspection"]):
        return "allow"
    if argv[0] in {PurePosixPath(exe).name for exe in policy["hostExecutables"]}:
        return "ask"
    # Do not mistake opaque wrappers or option-bearing Git invocations for a
    # reviewed inner command. Leave ordinary scripts to the sandbox.
    if argv[0] in {
        "sh", "bash", "zsh", "dash", "ksh", "eval", "env", "command",
        "builtin", "xargs", "time", "timeout", "nohup", "nice", "parallel",
        "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done",
        "case", "esac", "function", "{", "}",
    } or (argv[0] == "git" and len(argv) > 1 and argv[1].startswith("-")):
        return "ask"
    return "allow"


def decide(command, policy):
    if not isinstance(command, str) or not command.strip():
        return "ask"
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|<>()\n")
        lexer.whitespace = " \t\r"
        tokens = list(lexer)
    except ValueError:
        return "ask"
    units, current = [], []
    uncertain = bool(re.search(r"[$`<>]|[()]", command))
    for token in tokens:
        if token and all(char in ";&|\n" for char in token):
            if current:
                units.append(current)
                current = []
        else:
            current.append(token)
    if current:
        units.append(current)
    elif tokens and tokens[-1] in ("&&", "||", "|", "|&"):
        uncertain = True
    if not units:
        return "ask"
    decisions = [unit_decision(unit, policy) for unit in units if unit]
    if "deny" in decisions:
        return "deny"
    if uncertain or "ask" in decisions or any(
        re.match(r"[A-Za-z_][A-Za-z_0-9]*=", unit[0]) for unit in units
    ):
        return "ask"
    return "allow"


def main():
    client, policy_file = sys.argv[1:]
    try:
        with open(policy_file) as source:
            policy = json.load(source)
        request = json.load(sys.stdin)
        command = request.get("command") if client == "cursor" else request.get("tool_input", {}).get("command")
        decision = decide(command, policy)
        # Missing sandbox metadata must not authorize an unrestricted retry.
        if client == "cursor" and request.get("sandbox") is not True and decision == "allow":
            argv = shlex.split(command)
            if argv not in policy["hostExact"] and not prefix(argv, policy["hostInspection"]):
                decision = "ask"
    except Exception:
        # Cursor treats most nonzero hook exits as fail-open. Return a valid
        # denial instead, without echoing potentially sensitive command text.
        decision = "deny"
    reason = "Shared AI policy: review host/remote operations; protect credentials and destructive actions."
    if client == "cursor":
        response = {"permission": decision}
        if decision != "allow":
            response["user_message"] = reason
    elif decision == "allow":
        # Defer to Claude's normal permission/sandbox flow; never grant an
        # unsandboxed retry from a hook.
        response = {}
    else:
        response = {"hookSpecificOutput": {
            "hookEventName": "PreToolUse", "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }}
    print(json.dumps(response))


if __name__ == "__main__":
    main()
