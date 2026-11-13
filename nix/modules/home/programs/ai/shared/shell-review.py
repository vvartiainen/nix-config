"""Shell approval hook shared by Cursor and Claude.

This classifies shell commands, never executes them. OS sandboxes remain the
security boundary. Strict mode (Cursor, no native ask exceptions) asks for any
syntax or wrapper it cannot see through. Lenient mode (Claude, which has native
ask rules) asks only when a command part matches a review, deny or host rule
and otherwise defers to the client's own permission and sandbox flow.
"""

import fnmatch
import json
from pathlib import PurePosixPath
import re
import shlex
import sys


def prefix(argv, prefixes):
    return any(argv[:len(rule)] == rule for rule in prefixes)


SHELLS = {"sh", "bash", "zsh", "dash", "ksh"}
WRAPPERS = {
    "env", "command", "builtin", "exec", "xargs", "time", "timeout", "nohup",
    "nice", "parallel",
}
KEYWORDS = {
    "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done",
    "case", "esac", "function", "{", "}", "!",
}
PUNCTUATION = ";&|<>()\n"
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z_0-9]*=")
RANK = {"allow": 0, "ask": 1, "deny": 2}
MAX_DEPTH = 4


def mask_literal_heredocs(command):
    """Hide quoted heredoc data from shell rules, preserving executable headers.

    Unquoted bodies can expand shell commands, so keep scanning those. Fall
    back to the original input for headers we cannot parse or missing endings.
    This is only for Claude's lenient scan, never a grant of permission.
    """
    lines = iter(command.splitlines(keepends=True))
    output = []
    word = re.compile(r"(?:'[^'\n]*'|\"[^\"$`\\\n]*\"|\\[^\n]|[A-Za-z0-9_])+")
    for line in lines:
        pending, pieces = [], []
        i = start = 0
        while i < len(line):
            char = line[i]
            if char == "#" and (i == 0 or line[i - 1] in " \t\r\n;&|()<>"):
                break
            if char == "`" or line.startswith("$(", i):
                return command
            if char == "\\":
                i += 2
                continue
            if char in "'\"":
                quote = char
                i += 1
                while i < len(line) and line[i] != quote:
                    if quote == '"' and (line[i] == "`" or line.startswith("$(", i)):
                        return command
                    i += 2 if quote == '"' and line[i] == "\\" else 1
                if i == len(line):
                    return command
                i += 1
                continue
            if line.startswith("<<<", i):
                i += 3
                continue
            if not line.startswith("<<", i):
                i += 1
                continue
            operator = i
            i += 2
            tabs = line[i:i + 1] == "-"
            i += tabs
            while i < len(line) and line[i] in " \t":
                i += 1
            match = word.match(line, i)
            if not match or (match.end() < len(line) and line[match.end()] not in " \t\r\n;&|)"):
                return command
            raw = match.group()
            delimiter = shlex.split(raw)[0]
            literal = any(c in raw for c in "'\"\\")
            pending.append((delimiter, tabs, literal))
            i = match.end()
            if literal:
                pieces.append(line[start:operator])
                start = i
        output.append("".join(pieces) + line[start:])
        for delimiter, tabs, literal in pending:
            for body in lines:
                text = body.lstrip("\t") if tabs else body
                if text.rstrip("\n") == delimiter:
                    if not literal:
                        output.append(body)
                    break
                if not literal:
                    output.append(body)
            else:
                return command
    return "".join(output)


def rule_decision(argv, policy):
    """Match the policy lists; None when no rule applies."""
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
    return None


def unit_decision(argv, policy):
    decision = rule_decision(argv, policy)
    if decision:
        return decision
    # Do not mistake opaque wrappers or option-bearing Git invocations for a
    # reviewed inner command. Leave ordinary scripts to the sandbox.
    name = PurePosixPath(argv[0]).name
    if name in SHELLS | WRAPPERS | KEYWORDS | {"eval"} or (
        name == "git" and len(argv) > 1 and argv[1].startswith("-")
    ):
        return "ask"
    return "allow"


def strip_git_options(argv):
    i = 1
    while i < len(argv) and argv[i].startswith("-"):
        i += 2 if argv[i] in ("-C", "-c") else 1
    return [argv[0], *argv[i:]]


def lenient_decision(argv, policy, depth, scan=True):
    """Look through wrappers for a matching rule; unmatched parts are allowed."""
    if depth > MAX_DEPTH:
        return "ask"
    while argv and (argv[0] in KEYWORDS or ASSIGNMENT.match(argv[0])):
        argv = argv[1:]
    if not argv:
        return "allow"
    decision = rule_decision(argv, policy)
    if decision:
        return decision
    name = PurePosixPath(argv[0]).name
    if name == "git" and len(argv) > 1 and argv[1].startswith("-"):
        return lenient_decision(strip_git_options(argv), policy, depth + 1)
    if name == "eval":
        return decide(" ".join(argv[1:]), policy, strict=False, depth=depth + 1)
    if name in SHELLS:
        for i, arg in enumerate(argv[1:-1], start=1):
            if re.fullmatch(r"-[A-Za-z]*c[A-Za-z]*", arg):
                return decide(argv[i + 1], policy, strict=False, depth=depth + 1)
        return "allow"
    if (name in WRAPPERS or name == "find") and scan:
        # Wrapper options vary; check every possible inner command start,
        # including find -exec.
        decisions = [
            lenient_decision(argv[i:], policy, depth + 1, scan=False)
            for i in range(1, len(argv))
        ]
        return max(decisions, key=RANK.get, default="allow")
    return "allow"


def decide(command, policy, strict=True, depth=0):
    # In lenient mode "allow" means no hook opinion, not an approval.
    unknown = "ask" if strict else "allow"
    if not isinstance(command, str) or not command.strip():
        return unknown
    if not strict:
        command = mask_literal_heredocs(command)
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=PUNCTUATION)
        lexer.whitespace = " \t\r"
        tokens = list(lexer)
    except ValueError:
        return unknown
    if not strict:
        # Split at operators, redirects, substitutions and expansions so that
        # inner commands are checked on their own.
        units, current = [], []
        for token in tokens:
            if token in ("$", "`") or (token and all(char in PUNCTUATION for char in token)):
                if current:
                    units.append(current)
                    current = []
            else:
                current.append(token)
        if current:
            units.append(current)
        decisions = [lenient_decision(unit, policy, depth) for unit in units]
        return max(decisions, key=RANK.get, default="allow")
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
        decision = decide(command, policy, strict=client != "claude")
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
