import json
import unittest

import check_lookbook as check
import gen_tokens as gen


def theme(name):
    return gen.resolve_theme(json.loads(gen.TOKENS.read_text()), name)


class Repository(unittest.TestCase):
    def test_the_look_book_is_consistent(self):
        self.assertEqual([], check.check())


class Css(unittest.TestCase):
    def test_finds_variables_nothing_defines(self):
        self.assertEqual(["--nope"], check.undefined_variables("a { color: var(--nope); b: var(--yes) }", ":root { --yes: 1 }"))

    def test_variables_defined_in_the_stylesheet_itself_count(self):
        self.assertEqual([], check.undefined_variables(".a { --tint: red; color: var(--tint) }", ""))

    def test_comments_are_ignored(self):
        self.assertEqual([], check.undefined_variables("/* var(--nope) */ a { color: red }", ""))

    def test_hard_coded_colours_are_flagged_outside_the_camera(self):
        css = "/* ---------- glass ---------- */\na { color: #abcdef; mask: #000 }\n/* ---------- camera ---------- */\nb { color: #fff }\n"
        self.assertEqual([("glass", "#abcdef")], check.stray_colours(css))


class Html(unittest.TestCase):
    def test_balanced_markup_passes(self):
        self.assertEqual([], check.unbalanced('<div><input value="1"><span>a</span><svg><circle></circle></svg></div>'))

    def test_misnested_tags_are_reported(self):
        self.assertTrue(check.unbalanced("<div><span></div>"))

    def test_unclosed_tags_are_reported(self):
        self.assertEqual(["line 1: <section> is never closed"], check.unbalanced("<section><p>x</p>"))


class Sheets(unittest.TestCase):
    def test_a_correct_row_passes(self):
        html = '<span class="t-callout num">#F5F7FA</span><span class="t-foot c-2 num">9.4 : 1</span> #8AD0FF · 6.1 : 1'
        self.assertEqual([], check.palette_problems(html, theme("dark")))

    def test_a_wrong_ratio_is_caught(self):
        problems = check.palette_problems("#8AD0FF · 9.9 : 1", theme("dark"))
        self.assertEqual(1, len(problems))
        self.assertIn("measures 6.06", problems[0])

    def test_a_colour_from_another_theme_is_caught(self):
        problems = check.palette_problems("#0868B8 · 4.9 : 1", theme("dark"))
        self.assertTrue(any("not a colour of this theme" in p for p in problems))

    def test_text_on_accent_is_measured_against_the_accent(self):
        self.assertEqual([], check.palette_problems("#06131F</span><span>11.2 : 1", theme("dark")))

    def test_contrast_helper_matches_wcag_extremes(self):
        self.assertAlmostEqual(21.0, check.contrast((0, 0, 0), (1, 1, 1)), places=6)
        self.assertAlmostEqual(1.0, check.contrast((0.4, 0.4, 0.4), (0.4, 0.4, 0.4)), places=6)


if __name__ == "__main__":
    unittest.main()
