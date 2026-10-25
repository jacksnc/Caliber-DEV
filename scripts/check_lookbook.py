#!/usr/bin/env python3
"""Keep the look book honest: it may only use tokens that exist, and the numbers it prints must be the real ones.

    python3 scripts/check_lookbook.py

Checks (standard library only):
  1. every var(--name) in design/lookbook/look.css is defined in design/tokens.css or inside look.css itself
  2. look.css hard-codes no colours outside the camera simulation (a camera feed is not themed)
  3. every page links ../tokens.css and look.css, has balanced tags, and is listed in index.html
  4. every hex colour printed on a palette sheet belongs to that sheet's theme in design/tokens.json, and every
     contrast ratio printed beside one matches a recomputation (worst case over every backdrop the glass can meet)
"""
import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gen_tokens as gen  # noqa: E402

ROOT = HERE.parent
LOOKBOOK = ROOT / "design" / "lookbook"
SHEETS = {"graphite.html": "dark", "frost.html": "light"}
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}


# ---------- CSS ----------

def strip_comments(css):
    return re.sub(r"/\*.*?\*/", "", css, flags=re.S)


def undefined_variables(look_css, tokens_css):
    defined = set(re.findall(r"(--[a-z0-9-]+)\s*:", tokens_css)) | set(re.findall(r"(--[a-z0-9-]+)\s*:", strip_comments(look_css)))
    used = set(re.findall(r"var\((--[a-z0-9-]+)", strip_comments(look_css)))
    return sorted(used - defined)


def stray_colours(look_css):
    """Hex colours outside the camera section. #000 is allowed: it is only ever a mask, never a visible colour."""
    parts = re.split(r"(/\* -{5,} .*? -{5,} \*/)", look_css)
    found = []
    section = "(top)"
    for part in parts:
        if re.match(r"/\* -{5,} ", part):
            section = part
            continue
        if "camera" in section:
            continue
        for match in re.findall(r"#[0-9a-fA-F]{3,8}\b", strip_comments(part)):
            if match.lower() not in ("#000", "#000000"):
                found.append((section.strip("/* -"), match))
    return found


# ---------- HTML ----------

class Balance(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack = []
        self.errors = []

    def handle_starttag(self, tag, attrs):
        if tag not in VOID:
            self.stack.append((tag, self.getpos()[0]))

    def handle_startendtag(self, tag, attrs):
        pass

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        if not self.stack:
            self.errors.append(f"line {self.getpos()[0]}: </{tag}> has no opening tag")
        elif self.stack[-1][0] != tag:
            self.errors.append(f"line {self.getpos()[0]}: </{tag}> closes <{self.stack[-1][0]}> from line {self.stack[-1][1]}")
            while self.stack and self.stack[-1][0] != tag:
                self.stack.pop()
            if self.stack:
                self.stack.pop()
        else:
            self.stack.pop()


def unbalanced(html):
    parser = Balance()
    parser.feed(html)
    parser.close()
    return parser.errors + [f"line {line}: <{tag}> is never closed" for tag, line in parser.stack]


# ---------- palette sheets ----------

def srgb(hex_color):
    value = int(hex_color.lstrip("#"), 16)
    return tuple(((value >> shift) & 255) / 255 for shift in (16, 8, 0))


def luminance(rgb):
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(a, b):
    high, low = sorted((luminance(a), luminance(b)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def over(foreground, alpha, background):
    return tuple(f * alpha + b * (1 - alpha) for f, b in zip(foreground, background))


def colour(spec):
    value, alpha = gen.parse_color(spec, "colour")
    return srgb("#%06X" % value), alpha


def glass_surfaces(theme):
    """Every glass level composited over every backdrop it can meet: canvas ends, each glow, all glows stacked."""
    top, _ = colour(theme["canvas"]["top"])
    bottom, _ = colour(theme["canvas"]["bottom"])
    backdrops = [top, bottom]
    for glow in theme["glows"]:
        tint, _ = colour(glow["color"])
        height = tuple(a * (1 - glow["y"]) + b * glow["y"] for a, b in zip(top, bottom))
        backdrops += [over(tint, glow["opacity"], height), over(tint, glow["opacity"], top), over(tint, glow["opacity"], bottom)]
    for start in (top, bottom):
        stacked = start
        for glow in theme["glows"]:
            stacked = over(colour(glow["color"])[0], glow["opacity"], stacked)
        backdrops.append(stacked)
    surfaces = []
    for backdrop in backdrops:
        for level in ("base", "raised", "overlay"):
            tint, alpha = colour(theme["glass"][level])
            surfaces.append(over(tint, alpha, backdrop))
    return surfaces


def theme_hexes(theme):
    """Every opaque colour a theme defines, as upper-case #RRGGBB."""
    found = set()

    def walk(node):
        if isinstance(node, dict):
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)
        elif isinstance(node, str) and re.match(r"#[0-9A-Fa-f]{6}(@[0-9.]+)?$", node):
            found.add(node[:7].upper())

    walk(theme)
    return found


def palette_problems(html, theme):
    problems = []
    allowed = theme_hexes(theme)
    printed = set(h.upper() for h in re.findall(r"#[0-9A-Fa-f]{6}\b", html))
    for hex_color in sorted(printed - allowed):
        problems.append(f"{hex_color} is printed but is not a colour of this theme")

    surfaces = glass_surfaces(theme)
    on_accent = colour(theme["text"]["onAccent"])[0]
    accent = colour(theme["accent"]["base"])[0]
    pattern = re.compile(r"(#[0-9A-Fa-f]{6})(?:</span><span[^>]*>|\s*·\s*)(\d+\.\d)(?:\s*:\s*1)?")
    for hex_color, ratio in pattern.findall(html):
        hex_color = hex_color.upper()
        if hex_color == theme["text"]["onAccent"].upper():
            actual = contrast(on_accent, accent)
        else:
            actual = min(contrast(srgb(hex_color), surface) for surface in surfaces)
        if abs(actual - float(ratio)) > 0.06:
            problems.append(f"{hex_color} is printed with {ratio} : 1 but measures {actual:.2f} : 1")
    return problems


# ---------- driver ----------

def check(root=ROOT):
    lookbook = root / "design" / "lookbook"
    tokens_css = (root / "design" / "tokens.css").read_text()
    look_css = (lookbook / "look.css").read_text()
    tokens = json.loads((root / "design" / "tokens.json").read_text())
    problems = []

    for name in undefined_variables(look_css, tokens_css):
        problems.append(f"look.css uses {name}, which no token or rule defines")
    for section, value in stray_colours(look_css):
        problems.append(f"look.css hard-codes {value} in '{section}'; use a token")

    index = (lookbook / "index.html").read_text()
    for page in sorted(lookbook.glob("*.html")):
        text = page.read_text()
        if page.name != "index.html":
            for link in ('href="../tokens.css"', 'href="look.css"'):
                if link not in text:
                    problems.append(f"{page.name} does not link {link}")
            if f'src="{page.name}' not in index:
                problems.append(f"{page.name} is not shown in index.html")
        for error in unbalanced(text):
            problems.append(f"{page.name}: {error}")

    for name, theme_name in SHEETS.items():
        theme = gen.resolve_theme(tokens, theme_name)
        for problem in palette_problems((lookbook / name).read_text(), theme):
            problems.append(f"{name}: {problem}")
    return problems


def main():
    problems = check()
    for problem in problems:
        print(f"look book: {problem}")
    print(f"look book: {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
