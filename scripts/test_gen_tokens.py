import copy
import json
import unittest

import gen_tokens as gen


def load():
    return json.loads(gen.TOKENS.read_text())


class Colours(unittest.TestCase):
    def test_parse(self):
        self.assertEqual((0x8AD0FF, 1.0), gen.parse_color("#8AD0FF", "x"))
        self.assertEqual((0xFFFFFF, 0.05), gen.parse_color("#FFFFFF@0.05", "x"))
        self.assertEqual((0, 0.5), gen.parse_color("#000000@.5", "x"))
        self.assertEqual((0, 1.0), gen.parse_color("#000000@1.0", "x"))

    def test_rejects_bad_colours(self):
        for bad in ["8AD0FF", "#8AD0F", "#8AD0FFAA", "#GGGGGG", "#FFFFFF@2", "#FFFFFF@-1", "red", None, 12]:
            with self.assertRaises(gen.TokenError, msg=str(bad)):
                gen.parse_color(bad, "x")

    def test_formats(self):
        self.assertEqual("RGBA(0x8AD0FF)", gen.swift_color("#8AD0FF", "x"))
        self.assertEqual("RGBA(0xFFFFFF, alpha: 0.05)", gen.swift_color("#FFFFFF@0.05", "x"))
        self.assertEqual("#8AD0FF", gen.css_color("#8AD0FF", "x"))
        self.assertEqual("rgba(255, 255, 255, 0.05)", gen.css_color("#FFFFFF@0.05", "x"))
        self.assertEqual("0.3", gen.number(0.30))
        self.assertEqual("24", gen.number(24.0))
        self.assertEqual("on-accent", gen.kebab("onAccent"))


class Resolution(unittest.TestCase):
    def test_extends_merges_one_level_deep_per_section(self):
        tokens = load()
        resolved = gen.resolve_theme(tokens, "dark-hc")
        self.assertEqual("#D6DBE3", resolved["text"]["secondary"])
        self.assertEqual("#F5F7FA", resolved["text"]["primary"], "untouched keys come from the parent")
        self.assertEqual(tokens["themes"]["dark"]["data"], resolved["data"])
        self.assertEqual("Graphite (increased contrast)", resolved["label"])

    def test_cycles_are_rejected(self):
        tokens = load()
        tokens["themes"]["dark"]["extends"] = "dark-hc"
        with self.assertRaises(gen.TokenError):
            gen.resolve_theme(tokens, "dark-hc")


class Validation(unittest.TestCase):
    def test_shipped_tokens_are_valid(self):
        gen.validate(load())

    def expect_error(self, edit):
        tokens = load()
        edit(tokens)
        with self.assertRaises(gen.TokenError):
            gen.validate(tokens)

    def test_catches_mistakes(self):
        self.expect_error(lambda t: t["themes"]["dark"]["text"].pop("secondary"))
        self.expect_error(lambda t: t["themes"]["dark"]["data"].update(fat="purple"))
        self.expect_error(lambda t: t["themes"]["light"]["glass"].update(base="#FFFFFF@0.9"))
        self.expect_error(lambda t: t["themes"]["light"].update(glows=[]))
        self.expect_error(lambda t: t["themes"].pop("light-hc"))
        self.expect_error(lambda t: t["chartGroups"]["macros"].update(members=["protein", "carbs", "sugar"]))
        self.expect_error(lambda t: t["type"]["hero"].update(style="fixed24"))
        self.expect_error(lambda t: t["type"]["hero"].update(weight="heavy"))
        self.expect_error(lambda t: t["themes"]["dark"]["shadow"].update(radius="big"))


class Generation(unittest.TestCase):
    def test_output_is_deterministic(self):
        tokens = load()
        self.assertEqual(gen.outputs(tokens), gen.outputs(copy.deepcopy(tokens)))

    def test_swift_output_shape(self):
        swift = gen.generate_swift(load())
        for name in ["dark", "light", "darkHighContrast", "lightHighContrast"]:
            self.assertIn(f"public static let {name} = HeliosPalette(", swift)
        self.assertIn("case hero", swift)
        self.assertIn("HeliosChartGroup(name: \"macros\"", swift)
        self.assertNotIn("size:", swift.replace("fontsize", ""), "no point sizes may reach the Swift side")

    def test_css_output_shape(self):
        css = gen.generate_css(load())
        for selector in ['[data-theme="dark"]', '[data-theme="light"]',
                         '[data-theme="dark"][data-contrast="more"]', '[data-theme="light"][data-contrast="more"]']:
            self.assertIn(selector + " {", css)
        self.assertIn("--glass-base: rgba(255, 255, 255, 0.05);", css)
        self.assertIn("--text-on-accent: #06131F;", css)
        self.assertIn("--data-protein: #31AA9A;", css)

    def test_committed_files_are_up_to_date(self):
        for path, text in gen.outputs(load()).items():
            self.assertEqual(text, path.read_text(), f"{path} is stale; run python3 scripts/gen_tokens.py")


if __name__ == "__main__":
    unittest.main()
