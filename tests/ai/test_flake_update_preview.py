"""Test scratch lock isolation with a fake Nix executable; no daemon/network."""

import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "preview", ROOT / "nix/modules/home/programs/ai/shared/flake-update-preview.py"
)
preview = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preview)


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.repo = self.root / "repo with spaces"
        self.repo.mkdir()
        (self.repo / "flake.nix").write_text("{}")
        (self.repo / "flake.lock").write_text("tracked")
        fixture = self.repo / "nix/fixtures/host"
        fixture.mkdir(parents=True)
        (fixture / "default.nix").write_text("{}")
        self.embedded = self.root / "embedded"
        self.embedded.mkdir()
        (self.embedded / "flake.nix").write_text("{ trusted = true; }")
        self.original = {"root": "root", "nodes": {
            "root": {"inputs": {"host": "host"}},
            "host": {"locked": {"path": "./nix/host-unset", "type": "path"}, "original": {"path": "./nix/host-unset", "type": "path"}}
        }}
        (self.embedded / "flake.lock").write_text(json.dumps(self.original))
        for directory in ["host-unset", "fixture"]:
            (self.embedded / directory).mkdir()
            (self.embedded / directory / "default.nix").write_text(directory)
        self.sources = [self.embedded / name for name in ["flake.nix", "flake.lock", "host-unset", "fixture"]]
        self.output = self.root / "output"
        self.addCleanup(os.chdir, Path.cwd())
        os.chdir(self.repo)
        self.patch = patch.object(preview, "OUTPUT", self.output)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def fake_nix(self, argv, **kwargs):
        self.argv = argv
        flake = Path(argv[argv.index("--flake") + 1].removeprefix("path:"))
        self.assertEqual(stat.S_IMODE(flake.parent.stat().st_mode), 0o700)
        self.assertEqual((flake / "flake.nix").read_text(), (self.embedded / "flake.nix").read_text())
        self.assertEqual(json.loads((flake / "flake.lock").read_text()), self.original)
        self.assertEqual((flake / "nix/host-unset/default.nix").read_text(), "host-unset")
        self.assertEqual((flake / "nix/fixtures/host/default.nix").read_text(), "fixture")
        self.assertFalse((flake / ".git").exists())
        self.assertEqual(argv, ["/fixed/nix", "flake", "update", *self.inputs, "--flake", f"path:{flake}",
                               "--output-lock-file", str(flake.parent / "flake.lock.new"),
                               "--override-input", "host", f"path:{flake}/nix/fixtures/host"])
        resolved = json.loads(json.dumps(self.original))
        resolved["nodes"]["host"]["locked"]["path"] = str(flake / "nix/fixtures/host")
        Path(argv[argv.index("--output-lock-file") + 1]).write_text(json.dumps(resolved))

    def test_fixed_argv_and_atomic_output(self):
        self.output.mkdir(mode=0o700)
        victim = self.root / "victim"
        victim.write_text("untouched")
        (self.output / "flake.lock.new").symlink_to(victim)
        self.inputs = ["nixpkgs", "home-manager"]
        with patch.object(preview.subprocess, "run", side_effect=self.fake_nix):
            preview.preview("/fixed/nix", self.sources, ["nixpkgs", "home-manager"])
        self.assertEqual((self.repo / "flake.lock").read_text(), "tracked")
        self.assertEqual(victim.read_text(), "untouched")
        self.assertEqual(json.loads((self.output / "flake.lock.new").read_text()), self.original)
        self.assertFalse((self.output / "flake.lock.new").is_symlink())

    def test_reject_arguments_before_nix(self):
        for name in ["--override-input", "../elsewhere", "a/b", "x;y", "host", "", "nixpkgs\n"]:
            with self.subTest(name=name), patch.object(preview.subprocess, "run") as run:
                with self.assertRaises(ValueError):
                    preview.preview("/fixed/nix", self.sources, [name])
                run.assert_not_called()

    def test_reject_output_directory_symlink_or_public_mode(self):
        self.output.symlink_to(self.repo, target_is_directory=True)
        with self.assertRaises(ValueError):
            preview.preview("/fixed/nix", self.sources, [])
        self.output.unlink()
        self.output.mkdir(mode=0o755)
        with self.assertRaises(ValueError):
            preview.preview("/fixed/nix", self.sources, [])

    def test_failed_nix_preserves_previous_preview(self):
        self.output.mkdir(mode=0o700)
        lock = self.output / "flake.lock.new"
        lock.write_text("old")
        with patch.object(preview.subprocess, "run", side_effect=OSError("failed")):
            with self.assertRaises(OSError):
                preview.preview("/fixed/nix", self.sources, [])
        self.assertEqual(lock.read_text(), "old")
        self.assertEqual(list(self.output.iterdir()), [lock])

    def test_cwd_flake_lock_and_fixture_symlinks_are_ignored(self):
        malicious = self.root / "malicious"
        malicious.write_text('{ inputs.secret.url = "path:/private/secret"; }')
        for target in [self.repo / "flake.nix", self.repo / "flake.lock", self.repo / "nix/fixtures/host/default.nix"]:
            target.unlink()
            target.symlink_to(malicious)
        self.inputs = []
        with patch.object(preview.subprocess, "run", side_effect=self.fake_nix):
            preview.preview("/fixed/nix", self.sources, [])
        self.assertEqual(malicious.read_text(), '{ inputs.secret.url = "path:/private/secret"; }')
        self.assertEqual(json.loads((self.output / "flake.lock.new").read_text()), self.original)

    def test_embedded_symlinks_rejected_before_nix(self):
        (self.embedded / "fixture/default.nix").unlink()
        (self.embedded / "fixture/default.nix").symlink_to(self.repo / "flake.nix")
        with patch.object(preview.subprocess, "run") as run:
            with self.assertRaises(ValueError):
                preview.preview("/fixed/nix", self.sources, [])
            run.assert_not_called()

    def test_invalid_result_preserves_previous_output(self):
        self.output.mkdir(mode=0o700)
        lock = self.output / "flake.lock.new"
        lock.write_text("old")
        def invalid(argv, **kwargs):
            Path(argv[argv.index("--output-lock-file") + 1]).write_text("invalid")
        with patch.object(preview.subprocess, "run", side_effect=invalid):
            with self.assertRaises(ValueError):
                preview.preview("/fixed/nix", self.sources, [])
        self.assertEqual(lock.read_text(), "old")
