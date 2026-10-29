"""Offline validation of agent settings and their Home Manager layers."""

import argparse
from functools import lru_cache
import json
import os
from pathlib import Path
import sys
import tomllib

import json5
from jsonschema.validators import validator_for
from referencing import Registry
from referencing.exceptions import Unresolvable
from jsonschema.exceptions import SchemaError


def load(path, fmt=None):
    path = Path(path)
    fmt = fmt or ("toml" if path.suffix == ".toml" else "json")
    return parse(path.read_text(), fmt, path)


def parse(text, fmt, label):
    try:
        if fmt == "toml":
            return tomllib.loads(text)
        if fmt == "jsonc":
            return json5.loads(text)
        return json.loads(text)
    except ValueError:
        raise ValueError(f"{label}: invalid {fmt} syntax") from None


@lru_cache
def schema_validator(name):
    manifest = Path(__file__).with_name("agent-config-schemas.json")
    schemas = json.loads(manifest.read_text())
    schema = json.loads(Path(schemas[name]).read_text())
    cls = validator_for(schema)
    cls.check_schema(schema)
    # No network retrieval, including for external $refs. Schemas must be
    # self-contained; a config's own $schema never selects executable policy.
    return cls(schema, registry=Registry())


def validate(data, schema=None, label="config"):
    if not isinstance(data, dict):
        raise ValueError(f"{label}: expected an object")
    if schema is None:
        return
    try:
        errors = list(schema_validator(schema).iter_errors(data))
    except (OSError, KeyError, ValueError, SchemaError, Unresolvable) as error:
        raise ValueError(f"{label}: cannot use bundled schema {schema}: "
                         f"{type(error).__name__}") from None
    if errors:
        details = []
        for error in errors[:10]:
            location = "$" + "".join(f"[{part!r}]" for part in error.path)
            # Error.message can expose config values (tokens, env vars).
            constraint = f"fails {error.validator}"
            if error.validator == "type":
                constraint = f"expected type {error.validator_value}"
            details.append(f"{location}: {constraint}")
        raise ValueError(f"{label} ({schema}): " + "; ".join(details))


def config_files(home, xdg):
    """Default locations managed by this repository; never auth or history."""
    files = [
        (home / ".codex/config.toml", "toml", "codex"),
        (home / ".claude/settings.json", "json", "claude"),
        (home / ".claude.json", "json", None),
        (home / ".copilot/settings.json", "jsonc", None),
        (home / ".copilot/config.json", "jsonc", None),
        (home / ".copilot/lsp-config.json", "json", None),
        (home / ".copilot/permissions-config.json", "json", None),
        (xdg / "cursor/cli-config.json", "json", None),
        (xdg / "cursor/sandbox.json", "json", None),
        (home / "Library/Application Support/Claude/claude_desktop_config.json",
         "json", None),
    ]
    for base in [home / ".pi/agent", home / ".copilot", home / ".cursor",
                 xdg / "cursor"]:
        name = "mcp-config.json" if base.name == ".copilot" else "mcp.json"
        files.append((base / name, "json", None))
    for name in ["settings", "keybindings", "models"]:
        files.append((home / f".pi/agent/{name}.json", "json", f"pi-{name}"))
    files.append((home / ".pi/agent/themes/catppuccin-mocha.json",
                  "json", "pi-theme"))
    for name, schema in [("opencode", "opencode"), ("cli", "opencode-cli"),
                         ("tui", "opencode-tui")]:
        for suffix in ["json", "jsonc"]:
            files.append((xdg / f"opencode/{name}.{suffix}", "jsonc", schema))
        layer = "home-manager" if name == "opencode" else f"home-manager-{name}"
        files.append((xdg / f"opencode/{layer}.json", "json", schema))
    return files


def merge_layers(current, new):
    # Objects merge recursively; scalar values and arrays are replaced.
    # Key order matters for OpenCode permission rules.
    if not isinstance(current, dict) or not isinstance(new, dict):
        return new
    result = dict(current)
    for key, value in new.items():
        result[key] = merge_layers(result.get(key), value)
    return result


def check_files(home, xdg):
    failures = []
    for path, fmt, schema in config_files(home, xdg):
        if not path.exists() and not path.is_symlink():
            print(f"missing: {path}")
            continue
        try:
            validate(load(path, fmt), schema, path)
            print(f"ok ({schema or 'parse only; no schema'}): {path}")
        except (OSError, ValueError) as error:
            failures.append(str(error))
    # Validate the effective global OpenCode layers as well as their sources.
    # Project configs and process-specific inline overrides are out of scope.
    for name, schema in [("opencode", "opencode"), ("cli", "opencode-cli")]:
        root = xdg / "opencode"
        layer = "home-manager" if name == "opencode" else "home-manager-cli"
        paths = [root / f"{name}.json", root / f"{name}.jsonc",
                 root / f"{layer}.json"]
        try:
            data = {}
            present = False
            for path in paths:
                if path.exists():
                    data = merge_layers(data, load(path, "jsonc"))
                    present = True
            if present:
                validate(data, schema, f"effective OpenCode {name}")
                print(f"ok ({schema}): effective global OpenCode {name}")
        except (OSError, ValueError) as error:
            failures.append(str(error))
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--config-home", type=Path)
    args = parser.parse_args()
    xdg = args.config_home or Path(os.environ.get("XDG_CONFIG_HOME",
                                               args.home / ".config"))
    failures = check_files(args.home, xdg)
    if failures:
        for failure in failures:
            print(f"validate-agent-config: {failure}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
