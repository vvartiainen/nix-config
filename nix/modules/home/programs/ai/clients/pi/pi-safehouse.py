"""Launch all of Pi inside Safehouse with the repository's final-deny policy."""

import ipaddress
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit


def sb_string(value):
    # JSON string escaping also quotes Seatbelt path strings. Preserve Unicode.
    return json.dumps(str(value), ensure_ascii=False)


def subpath(path):
    return f"(subpath {sb_string(path)})"


def resolved_path(value):
    """Rewrite PATH entries to the real directories they link to.

    Safehouse grants the Nix store, not the profile symlinks that PATH names, so
    resolving `mcp-nixos` or `statix` through `~/.nix-profile/bin` or
    `/etc/profiles/per-user/<user>/bin` fails with EPERM. Resolving here, outside
    the sandbox, keeps tools reachable under the names projects configure.
    """
    entries = []
    for entry in value.split(":"):
        if not entry:
            continue
        try:
            directory = Path(entry).resolve()
        except OSError:
            continue
        if directory.is_dir() and str(directory) not in entries:
            entries.append(str(directory))
    return ":".join(entries)


def loopback_service(url):
    """The TCP port of a URL naming a loopback host, otherwise None.

    Only loopback URLs qualify: a host app that serves its tools on another
    address already reaches the sandbox through the ordinary network grant.
    """
    try:
        parts = urlsplit(url)
        host = parts.hostname
        port = parts.port
    except ValueError:
        return None
    if not host or port is None:
        return None
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        if host != "localhost":
            return None
    else:
        if not address.is_loopback:
            return None
    return port


def loopback_deny(service):
    """Deny host-local TCP, except the port an injected tool endpoint uses.

    T3 Code runs its MCP endpoint on the host loopback interface and hands Pi
    the URL in T3_MCP_URL. Excluding that one port keeps Pi's T3 tools usable
    while every other host service, including the Nix daemon and Rex, stays
    unreachable. The endpoint keeps its bearer token, and the exclusion applies
    to child commands too: they can reach that port but nothing else on the
    host.
    """
    deny = '(remote ip "localhost:*")'
    if service is None:
        return f"(deny network-outbound {deny})"
    return (
        "(deny network-outbound (require-all "
        f'{deny} (require-not (remote ip "localhost:{service}"))))'
    )


def worktree_git_dirs(workdir):
    try:
        common, current = [
            str(Path(subprocess.check_output(
                ["git", "rev-parse", "--path-format=absolute", flag],
                cwd=workdir, text=True, stderr=subprocess.DEVNULL, timeout=5,
            ).removesuffix("\n")).resolve())
            for flag in ("--git-common-dir", "--git-dir")
        ]
    except (OSError, subprocess.SubprocessError):
        return []
    return [common, current] if common != current else []


def make_profile(spec, workdir, tmpdir, t3_service=None):
    writable = [workdir, tmpdir, "/tmp", "/private/tmp", "/dev", *spec["writable"]]
    extensions = f'{spec["agentDir"]}/extensions'
    extension_logs = f"{extensions}/pi-permission-system/logs"
    # Safehouse's toolchain profiles permit normal user-cache writes. Narrow
    # those grants to our disposable caches, Pi state and this invocation's cwd.
    profile = [
        "(deny file-write* (require-all\n"
        + "\n".join(f"  (require-not {subpath(p)})" for p in writable)
        + "))",
    ]
    for path in spec["denied"]:
        profile.append(f"(deny file-read* file-write* {subpath(path)})")
    for path in spec["protected"]:
        profile.append(f"(deny file-write* {subpath(path)})")
    # These denials also apply when launching in a repository or home directory
    # that would otherwise grant access. Do not let project code rewrite policy
    # or Git hooks/config for a later unsandboxed invocation.
    profile.extend([
        r'(deny file-write* (require-all (regex #"/\.pi(/|$)") '
        f'(require-not {subpath(spec["agentDir"])})))',
        # Extension files are code that loads in later sessions. The permission
        # extension's review log is the only write this directory needs.
        "(deny file-write* (require-all "
        f"{subpath(extensions)} (require-not {subpath(extension_logs)})))",
        r'(deny file-write* (regex #"/\.git/(config$|hooks(/|$))"))',
        r'(deny file-read* file-write* (regex #"/[^/]+\.(pem|key)$"))',
        r'(deny file-read* file-write* (require-all '
        r'(regex #"/\.env($|\.)") (require-not (regex #"/\.env\.example$"))))',
        # Do not grant access to host daemons, including the Nix daemon and Rex,
        # through UNIX sockets. DNS uses Safehouse's separate resolver grant.
        '(deny network-outbound (require-all (remote unix-socket) '
        '(require-not (literal "/private/var/run/mDNSResponder"))))',
        # Seatbelt's localhost selector covers host addresses (IPv4 and IPv6),
        # not arbitrary LAN CIDRs. Keep host TCP/UDP services unreachable even
        # through bash or an extension, apart from the endpoint a host app
        # injects tools on; DNS still uses mDNSResponder above.
        loopback_deny(t3_service),
    ])
    return "\n".join(profile) + "\n"


def main():
    spec_path, safehouse, pi, *args = sys.argv[1:]
    spec = json.loads(Path(spec_path).read_text())
    cwd = Path.cwd().resolve()
    workdir = str(cwd)
    tmpdir = str(Path(os.environ.get("TMPDIR", "/tmp")).resolve())
    # Starting at / or $HOME would make the workspace grant unreasonably broad,
    # so keep those ungranted. Host apps probe the CLI from $HOME
    # (`pi --version`, provider status discovery) and have no project at hand,
    # so run with an empty workspace instead of refusing; Pi keeps its own cwd
    # and a real session still starts from a project directory.
    if workdir in ("/", str(Path.home().resolve())):
        workdir = tempfile.mkdtemp(prefix="pi-safehouse-workspace-", dir=tmpdir)
        if sys.stderr.isatty():
            print(
                "pi: started in %s, which the sandbox does not grant; "
                "run Pi in a project directory for file access" % cwd,
                file=sys.stderr,
            )
    # Linked worktrees share objects and refs with the original checkout.
    # Grant only their Git metadata, not the main checkout's source files.
    git_dirs = worktree_git_dirs(workdir)
    spec["writable"].extend(git_dirs)
    for directory in git_dirs:
        spec["protected"].extend(
            str(Path(directory) / name) for name in ("config", "config.worktree", "hooks")
        )
    # Safehouse requires every explicit grant to exist. Read grants include
    # optional probes such as ~/.gitconfig and profile links; skip absent or
    # broken links without widening access to their parent directories.
    readable = [path for path in spec["readable"] if Path(path).exists()]
    # These are the explicitly configured disposable caches and Pi state,
    # rather than optional read paths. Ensure first launch can write to them.
    for path in spec["writable"]:
        Path(path).mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="pi-safehouse-") as scratch:
        overlay = Path(scratch) / "policy.sb"
        t3_service = loopback_service(os.environ.get("T3_MCP_URL", ""))
        overlay.write_text(make_profile(spec, workdir, tmpdir, t3_service))
        # Safehouse sanitizes the inherited environment; pass only the selected
        # API key, our cache variables and T3's session variables. T3 Code drives
        # Pi over RPC and hands its MCP endpoint, runtime mode and injected
        # extension path to the process through T3_* names. Stored Pi credentials
        # also work.
        env = {
            key: value for key, value in os.environ.items()
            if not key.startswith("SAFEHOUSE_") and key not in ("BASH_ENV", "ENV")
        }
        env.update(spec["env"])
        env["PATH"] = resolved_path(env.get("PATH", ""))
        env["PI_CODING_AGENT_DIR"] = spec["agentDir"]
        t3_env = sorted(key for key in os.environ if key.startswith("T3_"))
        passed = ["DEEPSEEK_API_KEY", "PI_CODING_AGENT_DIR", *spec["env"], *t3_env]
        command = [
            safehouse,
            f"--workdir={workdir}",
            "--trust-workdir-config=false",
            # pbcopy/pbpaste and Pi's own copy/paste need the pasteboard mach
            # service, which Safehouse keeps behind this integration.
            "--enable=clipboard",
            f"--append-profile={overlay}",
            "--add-dirs=" + ":".join(spec["writable"]),
            *(["--add-dirs-ro=" + ":".join(readable)] if readable else []),
            "--env-pass=" + ",".join(passed),
            "--", pi, *args,
        ]
        try:
            return subprocess.call(command, env=env)
        except KeyboardInterrupt:
            return 130


if __name__ == "__main__":
    sys.exit(main())
