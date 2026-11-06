"""Run with kitty +runpy 'import runpy; runpy.run_path("...", run_name="__main__")'."""

import tempfile
import unittest
from pathlib import Path

from kitty.config import load_config
from kitty.fast_data_types import set_options
from kitty.open_actions import actions_for_url_from_list, load_actions_from_path

CONFIG = Path(__file__).resolve().parents[4] / "dotfiles/kitty"


class OpenActionsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        set_options(load_config(str(CONFIG / "kitty.conf")))

    def actions(self, name, path):
        return list(
            actions_for_url_from_list(path.as_uri(), load_actions_from_path(str(CONFIG / name)))
        )

    def test_editor_paths_are_arguments_not_shell_code(self):
        for config in ("open-actions.conf", "launch-actions.conf"):
            for extension in ("md", "json", "nix", "sh", "ts"):
                path = Path(f"/tmp/a b'\"$(touch unwanted);.{extension}")
                with self.subTest(config=config, extension=extension):
                    (action,) = self.actions(config, path)
                    self.assertEqual(action.func, "launch")
                    self.assertEqual(
                        action.args[-5:],
                        ('exec "$@"', "kitty-open", "/opt/homebrew/bin/nvim", "--", str(path)),
                    )

    def test_directories_open_yazi(self):
        with tempfile.TemporaryDirectory(prefix="kitty directory '") as directory:
            for config in ("open-actions.conf", "launch-actions.conf"):
                with self.subTest(config=config):
                    (action,) = self.actions(config, Path(directory))
                    self.assertEqual(
                        action.args[-3:],
                        ('exec yazi -- "$@"', "kitty-open", directory),
                    )

    def test_other_documents_use_system_defaults_from_links(self):
        for extension in ("pdf", "zip", "docx", "xlsx"):
            with self.subTest(extension=extension):
                self.assertEqual(
                    self.actions("open-actions.conf", Path(f"/tmp/document.{extension}")), []
                )

    def test_html_links_use_the_system_browser(self):
        for extension in ("html", "htm", "xhtml", "xht"):
            path = Path(f"/tmp/web page.{extension}")
            with self.subTest(extension=extension):
                (action,) = self.actions("open-actions.conf", path)
                self.assertEqual(action.func, "launch")
                self.assertEqual(
                    action.args, ("--type=background", "/usr/bin/open", "--", str(path))
                )


if __name__ == "__main__":
    unittest.main()
