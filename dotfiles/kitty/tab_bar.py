import os
from functools import lru_cache

from kitty.fast_data_types import get_boss

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


def draw_title(data):
    try:
        tab = get_boss().tab_for_id(data["tab_id"])
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
    except Exception:
        return data["title"]
