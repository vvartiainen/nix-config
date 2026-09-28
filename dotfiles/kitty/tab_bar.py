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


def _git_commondir(root):
    """Handles worktrees and submodules, where .git is a file pointing elsewhere."""
    dotgit = os.path.join(root, ".git")
    if os.path.isdir(dotgit):
        return dotgit
    with open(dotgit) as f:
        gitdir = os.path.normpath(os.path.join(root, f.read().split("gitdir:", 1)[1].strip()))
    commondir_file = os.path.join(gitdir, "commondir")
    if os.path.exists(commondir_file):
        with open(commondir_file) as f:
            return os.path.normpath(os.path.join(gitdir, f.read().strip()))
    return gitdir


@lru_cache(maxsize=256)
def _repo_name(root):
    try:
        with open(os.path.join(_git_commondir(root), "config")) as f:
            for line in f:
                key, _, value = line.partition("=")
                if key.strip() == "url":
                    name = value.strip().rstrip("/").rsplit("/", 1)[-1].rsplit(":", 1)[-1]
                    return name.removesuffix(".git")
    except (OSError, IndexError):
        pass
    return os.path.basename(root)


def draw_title(data):
    try:
        tab = get_boss().tab_for_id(data["tab_id"])
        if tab and tab.name:
            return tab.name
        # The shell's directory, so programs like yazi changing their own cwd don't affect it
        wd = data["tab"].active_oldest_wd or ""
        if not wd:
            return data["title"]
        root = _git_root(wd)
        if root:
            return _repo_name(root)
        return "~" if wd == HOME else os.path.basename(wd) or "/"
    except Exception:
        return data["title"]
