"""Exercise activation error handling without changing macOS associations."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "nix/modules/darwin/set-default-application.sh"
APP = "net.kovidgoyal.kitty"


class DefaultApplicationTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.duti = Path(scratch.name) / "fake duti"
        self.set_log = Path(scratch.name) / "set-calls"
        self.duti.write_text(
            "#!/bin/bash\n"
            "if [[ $1 == -x || $1 == -d ]]; then\n"
            '  [[ $1 == -x && .$2 == "$EXPECTED_TYPE" || $1 == -d && $2 == "$EXPECTED_TYPE" ]] || exit 99\n'
            '  printf "%s" "$QUERY_OUTPUT"\n'
            '  exit "$QUERY_STATUS"\n'
            "fi\n"
            '[[ $1 == -s && $2 == "$EXPECTED_APP" && $3 == "$EXPECTED_TYPE" && $4 == all ]] || exit 99\n'
            'printf "set\\n" >> "$FILE_ASSOC_SET_LOG"\n'
            'printf "%s" "$DUTI_OUTPUT" >&2\n'
            'exit "$DUTI_STATUS"\n'
        )
        self.duti.chmod(0o700)

    def apply(self, file_type, output="", status=0, query_output="", query_status=1):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.duti), APP, file_type],
            env={
                **os.environ,
                "EXPECTED_APP": APP,
                "EXPECTED_TYPE": file_type,
                "DUTI_OUTPUT": output,
                "DUTI_STATUS": str(status),
                "QUERY_OUTPUT": query_output,
                "QUERY_STATUS": str(query_status),
                "FILE_ASSOC_SET_LOG": str(self.set_log),
            },
            capture_output=True,
            text=True,
            check=False,
        )

    def test_success(self):
        result = self.apply(".md")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertEqual(self.set_log.read_text(), "set\n")

    def test_browser_types_are_rejected_without_setting(self):
        for file_type in (
            ".html",
            ".htm",
            ".xhtml",
            ".xht",
            "public.html",
            "public.xhtml",
            "public.url",
            "text/html",
            "application/xhtml+xml",
            "http",
            "https",
        ):
            with self.subTest(file_type=file_type):
                result = self.apply(file_type)
                self.assertEqual(result.returncode, 2)
                self.assertIn("Refusing to change browser association", result.stderr)
                self.assertFalse(self.set_log.exists())

    def test_matching_extension_does_not_set_again(self):
        result = self.apply(
            ".md", query_output=f"kitty\n/Applications/kitty.app\n{APP}\n", query_status=0
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.set_log.exists())

    def test_matching_uti_does_not_set_again(self):
        result = self.apply("public.source-code", query_output=f"{APP}\n", query_status=0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.set_log.exists())

    def test_different_default_is_updated(self):
        result = self.apply(
            ".md",
            query_output="Xcode\n/Applications/Xcode.app\ncom.apple.dt.Xcode\n",
            query_status=0,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.set_log.read_text(), "set\n")

    def test_dynamic_extension_rejection_warns_and_continues(self):
        result = self.apply(
            ".conf",
            f"failed to set {APP} as handler for dyn.ah62d4qmxhk2x425tr3xa (error -50)\n",
            206,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("warning: skipping .conf", result.stderr)
        self.assertIn("Finder", result.stderr)

    def test_other_failures_propagate(self):
        for file_type, uti, error, status in (
            (".md", "net.daringfireball.markdown", -50, 206),
            (".conf", "dyn.example", -10814, 194),
            ("public.source-code", "dyn.example", -50, 206),
        ):
            with self.subTest(file_type=file_type, error=error):
                output = f"failed to set {APP} as handler for {uti} (error {error})"
                result = self.apply(file_type, output, status)
                self.assertEqual(result.returncode, status)
                self.assertIn(file_type, result.stderr)
                self.assertIn(output, result.stderr)


if __name__ == "__main__":
    unittest.main()
