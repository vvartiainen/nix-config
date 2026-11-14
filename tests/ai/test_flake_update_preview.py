"""Test scratch lock isolation with a fake Nix executable; no daemon/network."""

import importlib.util
import os
from pathlib import Path
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
        self.output = self.root / "output"
        self.addCleanup(os.chdir, Path.cwd())
        os.chdir(self.repo)
        self.patch = patch.object(preview, "OUTPUT", self.output)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def fake_nix(self, argv, **kwargs):
        self.argv = argv
        Path(argv[argv.index("--output-lock-file") + 1]).write_text("preview")

    def test_fixed_argv_and_atomic_output(self):
        self.output.mkdir(mode=0o700)
        victim = self.root / "victim"
        victim.write_text("untouched")
        (self.output / "flake.lock.new").symlink_to(victim)
        with patch.object(preview.subprocess, "run", side_effect=self.fake_nix):
            preview.preview("/fixed/nix", ["nixpkgs", "home-manager"])
        self.assertEqual(self.argv[:7], ["/fixed/nix", "flake", "update", "nixpkgs", "home-manager", "--flake", str(self.repo)])
        self.assertEqual(self.argv[-3:], ["--override-input", "host", f"path:{self.repo}/nix/fixtures/host"])
        self.assertEqual((self.repo / "flake.lock").read_text(), "tracked")
        self.assertEqual(victim.read_text(), "untouched")
        self.assertEqual((self.output / "flake.lock.new").read_text(), "preview")
        self.assertFalse((self.output / "flake.lock.new").is_symlink())

    def test_reject_arguments_before_nix(self):
        for name in ["--override-input", "../elsewhere", "a/b", "x;y", "host", "", "nixpkgs\n"]:
            with self.subTest(name=name), patch.object(preview.subprocess, "run") as run:
                with self.assertRaises(ValueError):
                    preview.preview("/fixed/nix", [name])
                run.assert_not_called()

    def test_reject_output_directory_symlink_or_public_mode(self):
        self.output.symlink_to(self.repo, target_is_directory=True)
        with self.assertRaises(ValueError):
            preview.preview("/fixed/nix", [])
        self.output.unlink()
        self.output.mkdir(mode=0o755)
        with self.assertRaises(ValueError):
            preview.preview("/fixed/nix", [])

    def test_failed_nix_preserves_previous_preview(self):
        self.output.mkdir(mode=0o700)
        lock = self.output / "flake.lock.new"
        lock.write_text("old")
        with patch.object(preview.subprocess, "run", side_effect=OSError("failed")):
            with self.assertRaises(OSError):
                preview.preview("/fixed/nix", [])
        self.assertEqual(lock.read_text(), "old")
        self.assertEqual(list(self.output.iterdir()), [lock])

    def test_requires_fixture(self):
        (self.repo / "nix/fixtures/host/default.nix").unlink()
        with self.assertRaises(ValueError):
            preview.preview("/fixed/nix", [])
