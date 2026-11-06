import os
import re
from functools import lru_cache
from urllib.parse import urlparse

from kittens.ssh.utils import get_connection_data
from kitty.fast_data_types import get_boss, wcswidth
from kitty.utils import get_hostname, path_from_osc7_url

HOME = os.path.expanduser("~")


def _git_root(path):
    while path and path != "/":
        if os.path.exists(os.path.join(path, ".git")):
            return path
        path = os.path.dirname(path)
    return None


def _git_dirs(root):
    """Return the Git directory and shared directory for worktrees/submodules."""
    dotgit = os.path.join(root, ".git")
    if os.path.isdir(dotgit):
        return dotgit, dotgit
    with open(dotgit) as f:
        gitdir = os.path.normpath(os.path.join(root, f.read().split("gitdir:", 1)[1].strip()))
    commondir_file = os.path.join(gitdir, "commondir")
    if os.path.exists(commondir_file):
        with open(commondir_file) as f:
            return gitdir, os.path.normpath(os.path.join(gitdir, f.read().strip()))
    return gitdir, gitdir


@lru_cache(maxsize=256)
def _repo_title(root):
    name = os.path.basename(root)
    worktree = False
    try:
        gitdir, commondir = _git_dirs(root)
        worktree = os.path.isfile(os.path.join(gitdir, "commondir"))
        if worktree:
            name = (
                os.path.basename(os.path.dirname(commondir))
                if os.path.basename(commondir) == ".git"
                else os.path.basename(commondir).removesuffix(".git")
            )
        with open(os.path.join(commondir, "config")) as f:
            for line in f:
                key, _, value = line.partition("=")
                if key.strip() == "url":
                    name = value.strip().rstrip("/").rsplit("/", 1)[-1].rsplit(":", 1)[-1]
                    name = name.removesuffix(".git")
                    break
    except (OSError, IndexError):
        pass
    # A .git file alone also occurs in submodules; commondir marks a worktree.
    if worktree:
        return f"{name}:{os.path.basename(root)}"
    return name


SHELLS = frozenset({"zsh", "bash", "sh", "fish"})
ACCENT = "#CBA6F7"
DIM = "#6C7086"
ACTIVITY = "#F9E2AF"
BELL = "#F38BA8"
SSH = "#94E2D5"
SSH_ICON = "󰒋"  # Nerd Font server icon
# Visible cells per line; matches tab_title_max_length in kitty.conf.
LINE_WIDTH = 20


def _name(tab, data):
    if tab and tab.name:
        return tab.name
    # The oldest foreground process, rather than a short-lived child command.
    wd = data["tab"].active_oldest_wd or ""
    if not wd:
        return data["title"]
    root = _git_root(wd)
    if root:
        return _repo_title(root)
    return "~" if wd == HOME else os.path.basename(wd) or "/"


def _ssh(tab):
    """Return (host, remote directory) when the active window runs ssh or kitten ssh."""
    w = tab.active_window if tab else None
    if w is None:
        return None
    cmd = w.ssh_kitten_cmdline()
    if not cmd:
        for p in w.child.foreground_processes:
            q = list(p["cmdline"] or ())
            if q and os.path.basename(q[0]).lower() == "ssh":
                cmd = q
                break
    conn = get_connection_data(cmd) if cmd else None
    if conn is None:
        return None
    # The alias as typed, which names hosts from ~/.ssh/config better than FQDNs.
    host = conn.hostname.rpartition("@")[2]
    cwd = ""
    # Shell integration on the remote reports its directory with its hostname;
    # a local URL is the directory from before ssh started.
    reported = w.screen.last_reported_cwd or ""
    if isinstance(reported, bytes):
        reported = reported.decode("utf-8", "replace")
    netloc = urlparse(reported).netloc.partition(":")[0]
    if netloc and netloc not in (get_hostname(), "localhost"):
        path = path_from_osc7_url(reported)
        if re.fullmatch(r"/(home/[^/]+|Users/[^/]+|root)/?", path):
            cwd = "~"
        else:
            cwd = os.path.basename(path.rstrip("/")) or "/"
    return host, cwd


def _fit(text, width):
    if width <= 0:
        return ""
    if wcswidth(text) <= width:
        return text
    while text and wcswidth(text) > width - 1:
        text = text[:-1]
    return text + "…"


def _is_active(tab):
    tm = tab.tab_manager_ref() if tab else None
    return tm is not None and tm.active_tab is tab


def draw_title(data):
    """Two-line vertical tab: index, name and markers, then the foreground program.

    SSH tabs show the host instead, then the remote directory.

    Every line starts with the same gutter, which holds the accent bar of the
    active tab, so both lines stay aligned.
    """
    try:
        tab = get_boss().tab_for_id(data["tab_id"])
        fmt = data["fmt"]
        fg = fmt.fg
        gutter = f"{getattr(fg, '_' + ACCENT[1:])}▎{fg.tab}" if _is_active(tab) else " "
        dim = getattr(fg, "_" + DIM[1:])

        suffix = ""
        if data["num_windows"] > 1 and data["layout_name"] == "stack":
            suffix += f":{data['num_windows']}"
        status = data["tab"].program_status
        if status:
            suffix += f" {status}"
        markers = [
            f"{getattr(fg, '_' + color[1:])} ●{fg.tab}"
            for color, symbol in ((ACTIVITY, data["activity_symbol"]), (BELL, data["bell_symbol"]))
            if symbol
        ]

        # Gutter, space, index, space; line 2 aligns with the name.
        index = str(data["index"])
        name_col = len(index) + 3
        width = LINE_WIDTH - name_col - wcswidth(suffix) - 2 * len(markers)

        try:
            ssh = None if tab is None or tab.name else _ssh(tab)
        except Exception:
            ssh = None
        if ssh:
            # SSH tabs: host on line 1, the remote directory (if reported) on line 2.
            host, detail = ssh
            name = f"{getattr(fg, '_' + SSH[1:])}{SSH_ICON} {_fit(host, width - 2)}{fg.tab}"
        else:
            name = _fit(_name(tab, data), width)
            detail = data["tab"].active_exe.lstrip("-")
            if detail in SHELLS:
                detail = ""
        line1 = f"{gutter} {dim}{index}{fg.tab} {name}{suffix}{''.join(markers)}"
        if not detail:
            return line1
        detail = _fit(detail, LINE_WIDTH - name_col)
        line2 = f"{gutter}{' ' * (name_col - 1)}{fmt.nobold}{dim}{detail}{fg.tab}"
        return f"{line1}\n{line2}"
    except Exception:
        return data["title"]
