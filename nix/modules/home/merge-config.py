"""Merge Nix settings into a JSON or TOML config file the app also writes.

The settings applied last time are kept in a state file, so keys removed
from Nix are removed from the config too, like `kubectl apply`. Keys the
app added are kept. Tables merge recursively; other values, including
arrays, are replaced whole.
"""

import argparse
import json
import os
import sys
import tempfile

import tomli_w
from agent_config_validation import parse, validate


def prune(current, old, new):
    """Drop keys that were in the old settings but are not in the new."""
    if not (isinstance(current, dict) and isinstance(old, dict)):
        return current
    result = dict(current)
    for key, old_value in old.items():
        if not isinstance(new, dict) or key not in new:
            result.pop(key, None)
        elif key in result:
            result[key] = prune(result[key], old_value, new[key])
    return result


def merge(current, new):
    """Recursively apply the new settings on top of the current config."""
    if not (isinstance(current, dict) and isinstance(new, dict)):
        return new
    result = dict(current)
    for key, value in new.items():
        result[key] = merge(result.get(key), value)
    return result


def load(path, fmt, default):
    """Read a config file; a missing or empty file gives the default."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        return default
    if not data.strip():
        return default
    return parse(data.decode(), fmt, path)


def dump(value, fmt):
    if fmt == "toml":
        return tomli_w.dumps(value)
    text = json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False)
    return text + "\n"


def write(path, text, mode):
    """Replace the file atomically, keeping its permissions."""
    directory = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(prefix=".merge-config-", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("config", help="config file to update")
    parser.add_argument("--settings", required=True, help="Nix settings")
    parser.add_argument("--state", required=True, help="last applied")
    parser.add_argument(
        "--format", choices=["json", "jsonc", "toml"], default="json"
    )
    parser.add_argument("--schema", help="bundled schema name")
    parser.add_argument(
        "--initial",
        default="{}",
        help="JSON config to start from when the file does not exist",
    )
    args = parser.parse_args()

    path = args.config
    # Keep the file's permissions, but not those of a read-only store link.
    mode = 0o600
    if os.path.isfile(path) and not os.path.islink(path):
        mode = os.stat(path).st_mode & 0o777 | 0o200
    os.makedirs(os.path.dirname(path), exist_ok=True)

    try:
        current = load(path, args.format, json.loads(args.initial))
    except ValueError as e:
        sys.exit(f"merge-config: could not parse {path}: {e}")
    if not isinstance(current, dict):
        sys.exit(f"merge-config: expected an object in {path}")
    new = load(args.settings, "json", {})
    old = load(args.state, "json", {})

    merged = merge(prune(current, old, new), new)
    try:
        validate(merged, args.schema, path)
    except ValueError as error:
        sys.exit(f"merge-config: {error}")
    # A link from an older Home Manager generation is replaced with a
    # regular file instead of being written through into the Nix store.
    write(path, dump(merged, args.format), mode)

    os.makedirs(os.path.dirname(args.state), exist_ok=True)
    write(args.state, dump(new, "json"), 0o644)


if __name__ == "__main__":
    main()
