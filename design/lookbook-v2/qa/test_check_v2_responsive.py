import sys
import unittest
from pathlib import Path

QA_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(QA_DIR))
import check_v2_responsive as qa  # noqa: E402


class StaticContractTests(unittest.TestCase):
    def test_owned_v2_boards_and_responsive_css_pass_static_checks(self) -> None:
        self.assertEqual([], qa.run_static_checks(qa.ROOT))

    def test_undefined_css_variables_detected(self) -> None:
        undef = qa.undefined_css_variables(
            ".a { color: var(--missing-token); background: var(--defined-token); }",
            ":root { --defined-token: #000; }",
        )
        self.assertEqual(["--missing-token"], undef)

    def test_local_custom_property_definition_counts(self) -> None:
        undef = qa.undefined_css_variables(
            ".v2-field-group { --macro-color: var(--accent); color: var(--macro-color); }",
            ":root { --accent: #0868B8; }",
        )
        self.assertEqual([], undef)

    def test_hardcoded_colors_detected_outside_comments(self) -> None:
        css = "/* #FFFFFF allowed in comment */\n.card { color: #123456; border-color: rgba(0, 0, 0, 0.2); }"
        self.assertEqual(["#123456", "rgba(0, 0, 0, 0.2)"], qa.hardcoded_colors(css))

    def test_html_inspector_catches_unlabeled_input_and_missing_button_type(self) -> None:
        sample = (
            '<!doctype html><html lang="en" data-theme="dark"><head>'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '</head><body class="v2-app" data-screen="food-entry">'
            '<header class="app-header"></header>'
            '<main class="content" id="main">'
            '<input id="orphan" type="text">'
            '<button>Save</button>'
            '<a href="diary.html">Back</a>'
            '</main><nav class="app-nav"></nav></body></html>'
        )
        ins = qa.BoardHTMLInspector()
        ins.feed(sample)
        ins.close()
        self.assertEqual([("input", "orphan", False, 1)], ins.controls_needing_label)
        self.assertEqual([(None, "Save", 1)], ins.buttons)
        self.assertEqual([("diary.html", False, 1)], ins.links)

    def test_wcag_contrast_extremes(self) -> None:
        self.assertAlmostEqual(21.0, qa.wcag_contrast("#000000", "#FFFFFF"), places=5)
        self.assertAlmostEqual(1.0, qa.wcag_contrast("#41536B", "#41536B"), places=5)


if __name__ == "__main__":
    unittest.main()
