import tempfile
import unittest
from pathlib import Path

import lint_dynamic_type as lint


def rules(text):
    return [(line, rule) for line, _severity, rule, _message in lint.lint_text(text)]


class FixedFonts(unittest.TestCase):
    def test_fixed_system_size_is_an_error(self):
        findings = lint.lint_text('Text("x").font(.system(size: 17))\n')
        self.assertEqual([(1, "error", "fixed-system-font")], [(l, s, r) for l, s, r, _ in findings])

    def test_text_styles_are_fine(self):
        for source in [
            'Text("x").font(.body)',
            'Text("x").font(.system(.title, design: .rounded, weight: .semibold))',
            'Text("x").font(.system(.caption).monospacedDigit())',
            'Text("x").font(.custom("Avenir", size: 17, relativeTo: .body))',
            'Text("x").font(.custom("Avenir", size: 17))',
            'Text("x").heliosFont(.metricValue)',
        ]:
            self.assertEqual([], rules(source + "\n"), source)

    def test_multiline_system_size_is_found_on_the_right_line(self):
        source = 'Text("x")\n    .font(\n        .system(\n            size: 12,\n            weight: .bold)\n    )\n'
        self.assertEqual([(3, "fixed-system-font")], rules(source))

    def test_font_system_size_without_leading_font_modifier(self):
        self.assertEqual([(1, "fixed-system-font")], rules("let f = Font.system(size: 14, weight: .bold)\n"))

    def test_custom_fixed_size(self):
        self.assertEqual([(1, "fixed-custom-font")], rules('.font(.custom("Avenir", fixedSize: 17))\n'))

    def test_uikit_fixed_fonts(self):
        for source in ["UIFont.systemFont(ofSize: 15)", "UIFont.boldSystemFont(ofSize: 15)",
                       "UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)", "NSFont.systemFont(ofSize: 13)"]:
            self.assertEqual([(1, "uikit-fixed-font")], rules(source + "\n"), source)

    def test_uikit_font_scaled_with_metrics_is_fine(self):
        self.assertEqual([], rules("let f = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.systemFont(ofSize: 17))\n"))
        self.assertEqual([], rules("let base = UIFont.systemFont(ofSize: 17)\nlet f = UIFontMetrics.default.scaledFont(for: base)\n"))


class Warnings(unittest.TestCase):
    def test_warnings(self):
        source = '.dynamicTypeSize(...DynamicTypeSize.xxxLarge)\n.minimumScaleFactor(0.5)\n.lineLimit(1)\n.lineLimit(2)\n'
        findings = lint.lint_text(source)
        self.assertEqual([(1, "warning", "dynamic-type-cap"), (2, "warning", "minimum-scale-factor"), (3, "warning", "line-limit-one")],
                         [(l, s, r) for l, s, r, _ in findings])


class Suppression(unittest.TestCase):
    def test_comments_are_ignored(self):
        self.assertEqual([], rules('// .font(.system(size: 17))\n/* .font(.system(size: 17)) */\nlet x = 1 // .system(size: 3)\n'))

    def test_block_comment_keeps_line_numbers(self):
        source = '/* a\n b\n c */\n.font(.system(size: 9))\n'
        self.assertEqual([(4, "fixed-system-font")], rules(source))

    def test_allow_comment_same_line_and_previous_line(self):
        self.assertEqual([], rules('.font(.system(size: 9)) // helios-lint: allow(fixed-system-font) decorative glyph\n'))
        self.assertEqual([], rules('// helios-lint: allow(fixed-system-font) app icon badge\n.font(.system(size: 9))\n'))

    def test_allow_comment_is_rule_specific(self):
        self.assertEqual([(1, "fixed-system-font")], rules('.font(.system(size: 9)) // helios-lint: allow(line-limit-one)\n'))
        self.assertEqual([], rules('.font(.system(size: 9)).lineLimit(1) // helios-lint: allow(fixed-system-font, line-limit-one)\n'))

    def test_allow_does_not_leak_two_lines_down(self):
        self.assertEqual([(3, "fixed-system-font")], rules('// helios-lint: allow(fixed-system-font)\nlet a = 1\n.font(.system(size: 9))\n'))


class FileDiscovery(unittest.TestCase):
    def test_walks_directories_and_skips_build_output_and_tests(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Sources").mkdir()
            (root / "Sources" / "Good.swift").write_text('Text("x").font(.body)\n')
            (root / "Sources" / "Bad.swift").write_text('Text("x").font(.system(size: 17))\n')
            (root / ".build").mkdir()
            (root / ".build" / "Skipped.swift").write_text('Text("x").font(.system(size: 17))\n')
            (root / "Tests").mkdir()
            (root / "Tests" / "AlsoSkipped.swift").write_text('Text("x").font(.system(size: 17))\n')
            (root / "notes.txt").write_text(".system(size: 3)\n")
            names = sorted(path.name for path in lint.swift_files([str(root)]))
            self.assertEqual(["Bad.swift", "Good.swift"], names)

    def test_exit_status(self):
        with tempfile.TemporaryDirectory() as directory:
            good = Path(directory) / "Good.swift"
            good.write_text('Text("x").font(.body).lineLimit(1)\n')
            self.assertEqual(0, lint.main([str(good)]))
            self.assertEqual(1, lint.main(["--strict", str(good)]))
            bad = Path(directory) / "Bad.swift"
            bad.write_text('Text("x").font(.system(size: 17))\n')
            self.assertEqual(1, lint.main([str(bad)]))


class Repository(unittest.TestCase):
    def test_the_repository_itself_is_clean(self):
        root = Path(__file__).resolve().parent.parent
        self.assertEqual(0, lint.main([str(root / "Packages")]))


if __name__ == "__main__":
    unittest.main()
