#!/usr/bin/env python3
"""Generate the Swift and CSS design tokens from design/tokens.json.

    python3 scripts/gen_tokens.py            # (re)write the generated files
    python3 scripts/gen_tokens.py --check    # exit 1 if a generated file is stale (used by CI)

Standard library only, so it runs anywhere a CI runner has python3.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design" / "tokens.json"
SWIFT_OUT = ROOT / "Packages" / "HeliosDesign" / "Sources" / "HeliosDesign" / "GeneratedTokens.swift"
CSS_OUT = ROOT / "design" / "tokens.css"

THEME_PROPERTY = {"dark": "dark", "light": "light", "dark-hc": "darkHighContrast", "light-hc": "lightHighContrast"}
THEME_ORDER = ["dark", "light", "dark-hc", "light-hc"]
TEXT_STYLES = ["largeTitle", "title", "title2", "title3", "headline", "body", "callout", "subheadline", "footnote", "caption", "caption2"]
DESIGNS = ["default", "rounded"]
WEIGHTS = ["regular", "medium", "semibold", "bold"]

COLOR_PATTERN = re.compile(r"^#([0-9A-Fa-f]{6})(?:@(0|1|0?\.\d+|1\.0+))?$")

REQUIRED = {
    "label": str,
    "canvas": ["top", "bottom"],
    "glass": ["base", "raised", "overlay"],
    "opaque": ["base", "raised", "overlay"],
    "border": ["highlight", "lowlight", "hairline", "strong"],
    "shadow": ["color", "radius", "y"],
    "text": ["primary", "secondary", "tertiary", "onAccent"],
    "accent": ["base", "pressed", "subtle", "focus", "tint"],
    "data": ["energy", "protein", "carbs", "fat", "training", "peptide", "weight", "reference"],
    "status": ["success", "warning", "danger"],
}


class TokenError(Exception):
    pass


def parse_color(text, where):
    match = COLOR_PATTERN.match(text) if isinstance(text, str) else None
    if not match:
        raise TokenError(f"{where}: '{text}' is not #RRGGBB or #RRGGBB@alpha")
    alpha = float(match.group(2)) if match.group(2) is not None else 1.0
    if not 0.0 <= alpha <= 1.0:
        raise TokenError(f"{where}: alpha {alpha} outside 0...1")
    return int(match.group(1), 16), alpha


def merge(base, override):
    result = json.loads(json.dumps(base))
    for key, value in override.items():
        if key == "extends":
            continue
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result


def resolve_theme(tokens, name, seen=()):
    if name in seen:
        raise TokenError(f"theme '{name}' extends itself")
    try:
        theme = tokens["themes"][name]
    except KeyError:
        raise TokenError(f"unknown theme '{name}'")
    if "extends" in theme:
        return merge(resolve_theme(tokens, theme["extends"], seen + (name,)), theme)
    return json.loads(json.dumps(theme))


def validate(tokens):
    for name in THEME_ORDER:
        if name not in tokens.get("themes", {}):
            raise TokenError(f"missing theme '{name}'")
    for name in THEME_ORDER:
        theme = resolve_theme(tokens, name)
        for section, spec in REQUIRED.items():
            if section not in theme:
                raise TokenError(f"{name}: missing '{section}'")
            if spec is str:
                continue
            for key in spec:
                if key not in theme[section]:
                    raise TokenError(f"{name}.{section}: missing '{key}'")
                value = theme[section][key]
                if section == "shadow" and key in ("radius", "y"):
                    if not isinstance(value, (int, float)):
                        raise TokenError(f"{name}.shadow.{key} must be a number")
                else:
                    parse_color(value, f"{name}.{section}.{key}")
        if not theme.get("glows"):
            raise TokenError(f"{name}: needs at least one glow")
        for i, glow in enumerate(theme["glows"]):
            parse_color(glow["color"], f"{name}.glows[{i}].color")
            for key in ("opacity", "x", "y", "radius"):
                if not isinstance(glow.get(key), (int, float)) or not 0 <= glow[key] <= 1.5:
                    raise TokenError(f"{name}.glows[{i}].{key} must be a number in 0...1.5")
        alphas = [parse_color(theme["glass"][k], f"{name}.glass.{k}")[1] for k in ("base", "raised", "overlay")]
        if not alphas[0] <= alphas[1] <= alphas[2]:
            raise TokenError(f"{name}.glass: levels must not get less opaque as they rise")
    data_names = set(resolve_theme(tokens, "dark")["data"])
    for group, spec in tokens["chartGroups"].items():
        if group.startswith("$"):
            continue
        for member in spec["members"]:
            if member not in data_names:
                raise TokenError(f"chartGroups.{group}: unknown data colour '{member}'")
    for role, spec in tokens["type"].items():
        if spec["style"] not in TEXT_STYLES:
            raise TokenError(f"type.{role}: '{spec['style']}' is not a Dynamic Type text style")
        if spec["design"] not in DESIGNS or spec["weight"] not in WEIGHTS:
            raise TokenError(f"type.{role}: bad design or weight")
        if not isinstance(spec.get("monospacedDigit"), bool):
            raise TokenError(f"type.{role}: monospacedDigit must be a boolean")


# --------------------------------------------------------------------------------------------- formatting

def number(value):
    if isinstance(value, bool):
        raise TokenError("boolean where a number was expected")
    if isinstance(value, int) or float(value).is_integer():
        return str(int(value))
    return repr(float(value))


def swift_color(text, where):
    rgb, alpha = parse_color(text, where)
    return f"RGBA(0x{rgb:06X})" if alpha == 1.0 else f"RGBA(0x{rgb:06X}, alpha: {number(alpha)})"


def css_color(text, where):
    rgb, alpha = parse_color(text, where)
    if alpha == 1.0:
        return f"#{rgb:06X}"
    return f"rgba({(rgb >> 16) & 255}, {(rgb >> 8) & 255}, {rgb & 255}, {number(alpha)})"


def kebab(name):
    return re.sub(r"(?<!^)(?=[A-Z])", "-", name).lower()


def swift_palette(name, theme):
    c = lambda section, key: swift_color(theme[section][key], f"{name}.{section}.{key}")
    glows = ",\n".join(
        f"            HeliosGlow(color: {swift_color(g['color'], f'{name}.glows')}, opacity: {number(g['opacity'])}, "
        f"x: {number(g['x'])}, y: {number(g['y'])}, radius: {number(g['radius'])})"
        for g in theme["glows"]
    )
    group = lambda section, keys, ctor: f"{ctor}(" + ", ".join(f"{k}: {c(section, k)}" for k in keys) + ")"
    prop = THEME_PROPERTY[name]
    return f"""    public static let {prop} = HeliosPalette(
        id: "{name}", label: "{theme['label']}", isDark: {str(name.startswith('dark')).lower()}, isHighContrast: {str(name.endswith('-hc')).lower()},
        canvasTop: {c('canvas', 'top')}, canvasBottom: {c('canvas', 'bottom')},
        glows: [
{glows},
        ],
        glass: {group('glass', ['base', 'raised', 'overlay'], 'GlassLevels')},
        opaque: {group('opaque', ['base', 'raised', 'overlay'], 'GlassLevels')},
        border: {group('border', ['highlight', 'lowlight', 'hairline', 'strong'], 'BorderTokens')},
        shadow: ShadowToken(color: {c('shadow', 'color')}, radius: {number(theme['shadow']['radius'])}, y: {number(theme['shadow']['y'])}),
        text: {group('text', ['primary', 'secondary', 'tertiary', 'onAccent'], 'TextColors')},
        accent: {group('accent', ['base', 'pressed', 'subtle', 'focus', 'tint'], 'AccentColors')},
        data: {group('data', ['energy', 'protein', 'carbs', 'fat', 'training', 'peptide', 'weight', 'reference'], 'DataColors')},
        status: {group('status', ['success', 'warning', 'danger'], 'StatusColors')}
    )"""


def generate_swift(tokens):
    palettes = "\n\n".join(swift_palette(n, resolve_theme(tokens, n)) for n in THEME_ORDER)
    radius = tokens["radius"]
    motion = tokens["motion"]
    groups = ",\n".join(
        f'        HeliosChartGroup(name: "{name}", members: {json.dumps(spec["members"])}, minDeltaE: {number(spec["minDeltaE"])})'
        for name, spec in tokens["chartGroups"].items() if not name.startswith("$")
    )
    roles = list(tokens["type"].items())
    cases = "\n".join(f"    case {name}" for name, _ in roles)
    specs = "\n".join(
        f"        case .{name}: return HeliosTypeSpec(style: .{spec['style']}, design: .{spec['design']}, "
        f"weight: .{spec['weight']}, monospacedDigit: {str(spec['monospacedDigit']).lower()})"
        for name, spec in roles
    )
    return f"""// GENERATED by scripts/gen_tokens.py from design/tokens.json. Do not edit by hand:
// change the JSON and run `python3 scripts/gen_tokens.py`. CI fails if this file is stale.

import Foundation

extension HeliosPalette {{
{palettes}
}}

public enum HeliosTokens {{
    public static let version = {tokens['version']}
    public static let radius = HeliosRadius(chip: {number(radius['chip'])}, button: {number(radius['button'])}, tile: {number(radius['tile'])}, card: {number(radius['card'])}, sheet: {number(radius['sheet'])})
    public static let spacing: [Double] = [{', '.join(number(v) for v in tokens['spacing'])}]
    public static let minimumTapTarget: Double = {number(tokens['minTarget'])}
    public static let glass = HeliosGlassSpec(blur: {number(tokens['glass']['blur'])}, saturation: {number(tokens['glass']['saturation'])})
    public static let motion = HeliosMotion(fast: {number(motion['fast'])}, base: {number(motion['base'])}, slow: {number(motion['slow'])}, springResponse: {number(motion['springResponse'])}, springDamping: {number(motion['springDamping'])})
    public static let chartGroups: [HeliosChartGroup] = [
{groups},
    ]
}}

public enum HeliosTypeRole: String, CaseIterable, Sendable {{
{cases}

    public var spec: HeliosTypeSpec {{
        switch self {{
{specs}
        }}
    }}
}}
"""


def css_block(selector, name, theme):
    lines = [f"{selector} {{"]
    add = lambda var, value: lines.append(f"  --{var}: {value};")
    add("theme-label", json.dumps(theme["label"]))
    add("canvas-top", css_color(theme["canvas"]["top"], name))
    add("canvas-bottom", css_color(theme["canvas"]["bottom"], name))
    for i, glow in enumerate(theme["glows"], start=1):
        add(f"glow-{i}-color", css_color(glow["color"], name))
        add(f"glow-{i}-opacity", number(glow["opacity"]))
        add(f"glow-{i}-x", f"{number(glow['x'] * 100)}%")
        add(f"glow-{i}-y", f"{number(glow['y'] * 100)}%")
        add(f"glow-{i}-radius", f"{number(glow['radius'] * 100)}%")
    for section, keys in (("glass", ["base", "raised", "overlay"]), ("opaque", ["base", "raised", "overlay"]),
                          ("border", ["highlight", "lowlight", "hairline", "strong"]),
                          ("text", ["primary", "secondary", "tertiary", "onAccent"]),
                          ("data", ["energy", "protein", "carbs", "fat", "training", "peptide", "weight", "reference"]),
                          ("status", ["success", "warning", "danger"])):
        for key in keys:
            add(f"{kebab(section)}-{kebab(key)}", css_color(theme[section][key], f"{name}.{section}.{key}"))
    for key in ("base", "pressed", "subtle", "focus", "tint"):
        add("accent" if key == "base" else f"accent-{key}", css_color(theme["accent"][key], f"{name}.accent.{key}"))
    add("shadow-color", css_color(theme["shadow"]["color"], name))
    add("shadow-radius", f"{number(theme['shadow']['radius'])}px")
    add("shadow-y", f"{number(theme['shadow']['y'])}px")
    lines.append("}")
    return "\n".join(lines)


def generate_css(tokens):
    blocks = []
    selectors = {
        "dark": ':root[data-theme="dark"]',
        "light": ':root[data-theme="light"]',
        "dark-hc": ':root[data-theme="dark"][data-contrast="more"]',
        "light-hc": ':root[data-theme="light"][data-contrast="more"]',
    }
    for name in THEME_ORDER:
        blocks.append(css_block(selectors[name], name, resolve_theme(tokens, name)))
    radius = tokens["radius"]
    shared = [":root {"]
    shared += [f"  --radius-{kebab(k)}: {number(v)}px;" for k, v in radius.items()]
    shared += [f"  --space-{i}: {number(v)}px;" for i, v in enumerate(tokens["spacing"], start=1)]
    shared += [f"  --min-target: {number(tokens['minTarget'])}px;",
               f"  --glass-blur: {number(tokens['glass']['blur'])}px;",
               f"  --glass-saturate: {number(tokens['glass']['saturation'])};",
               f"  --motion-fast: {number(tokens['motion']['fast'])}s;",
               f"  --motion-base: {number(tokens['motion']['base'])}s;",
               f"  --motion-slow: {number(tokens['motion']['slow'])}s;"]
    for role, spec in tokens["type"].items():
        shared.append(f"  --type-{kebab(role)}-size: {number(spec['cssSize'])}px;")
        shared.append(f"  --type-{kebab(role)}-weight: {({'regular': 400, 'medium': 500, 'semibold': 600, 'bold': 700})[spec['weight']]};")
    shared.append("}")
    header = "/* GENERATED by scripts/gen_tokens.py from design/tokens.json. Do not edit by hand. */\n"
    return header + "\n".join(shared) + "\n\n" + "\n\n".join(blocks) + "\n"


def outputs(tokens):
    return {SWIFT_OUT: generate_swift(tokens), CSS_OUT: generate_css(tokens)}


def main(argv):
    check = "--check" in argv
    try:
        tokens = json.loads(TOKENS.read_text())
        validate(tokens)
        generated = outputs(tokens)
    except (TokenError, KeyError, json.JSONDecodeError) as error:
        print(f"tokens: {error}", file=sys.stderr)
        return 2
    stale = []
    for path, text in generated.items():
        current = path.read_text() if path.exists() else None
        if current != text:
            stale.append(path)
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
    if check:
        if stale:
            for path in stale:
                print(f"stale: {path.relative_to(ROOT)} (run python3 scripts/gen_tokens.py)", file=sys.stderr)
            return 1
        print("design tokens are up to date")
        return 0
    print("wrote: " + (", ".join(str(p.relative_to(ROOT)) for p in stale) if stale else "nothing to change"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
