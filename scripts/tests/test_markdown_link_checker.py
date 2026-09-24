import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "analysis" / "check_markdown_links.py"
SPEC = importlib.util.spec_from_file_location("check_markdown_links", MODULE_PATH)
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class MarkdownLinkCheckerTests(unittest.TestCase):
    def test_extracts_relative_links_and_reference_definitions(self):
        text = """A [file](../README.md) and ![image](<images/my image.png>).
[ref]: https://example.invalid/page
```md
[example](not-a-real-file.md)
```
"""
        found = list(checker.markdown_targets(text))
        self.assertEqual(
            [(line, target) for line, target in found],
            [(1, "../README.md"), (1, "images/my image.png"), (2, "https://example.invalid/page")],
        )

    def test_ignores_external_and_anchor_only_targets(self):
        self.assertIsNone(checker.normalized_local_path("docs/page.md", "https://example.invalid"))
        self.assertIsNone(checker.normalized_local_path("docs/page.md", "#section"))

    def test_ignores_windows_absolute_paths_with_or_without_angle_brackets(self):
        self.assertIsNone(
            checker.normalized_local_path("docs/page.md", "C:/Users/research/file.md")
        )
        self.assertIsNone(
            checker.normalized_local_path("docs/page.md", "<C:/Users/research/file.md>")
        )
        self.assertIsNone(
            checker.normalized_local_path("docs/page.md", r"C:\\Users\\research\\file.md")
        )

    def test_resolves_relative_paths_case_sensitively(self):
        self.assertEqual(checker.normalized_local_path("docs/page.md", "../README.md"), "README.md")
        paths = {"README.md", "docs/page.md"}
        self.assertTrue(checker.path_exists_case_sensitive("README.md", paths))
        self.assertFalse(checker.path_exists_case_sensitive("readme.md", paths))

    def test_identifies_vendored_markdown_in_current_and_frozen_sources(self):
        self.assertTrue(checker.is_vendored_markdown("vendor/upstream/README.md"))
        self.assertTrue(
            checker.is_vendored_markdown(
                "artifacts/milestones/step1/source/vendor/upstream/README.md"
            )
        )
        self.assertFalse(checker.is_vendored_markdown("experiments/step1/REPORT.md"))


if __name__ == "__main__":
    unittest.main()
