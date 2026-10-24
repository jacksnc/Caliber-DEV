#!/usr/bin/env python3
"""Find Swift text that does not scale with Dynamic Type.

    python3 scripts/lint_dynamic_type.py [paths...]      # default: Packages and App, if present
    python3 scripts/lint_dynamic_type.py --strict ...    # warnings fail too

Xcode's accessibility audit reports "Dynamic Type font sizes are partially unsupported" when text is drawn with a
fixed point size. In SwiftUI that means `.font(.system(size: 17))`, `Font.custom("X", fixedSize: 17)`, or a UIFont built
from `systemFont(ofSize:)` without `UIFontMetrics`. Use a text style instead (`.font(.body)` or
`heliosFont(.body)`); for a size that must follow the text size but is not a font, use `@ScaledMetric`.

Escape hatch, on the offending line or the line above:

    // helios-lint: allow(fixed-system-font) reason it is safe

Standard library only.
"""
import argparse
import re
import sys
from pathlib import Path

ERROR, WARNING = "error", "warning"

RULES = {
    "fixed-system-font": (ERROR, re.compile(r"\.system\(\s*size\s*:"),
                          "fixed point size; use a text style such as .font(.body) or heliosFont(.body)"),
    "fixed-custom-font": (ERROR, re.compile(r"\.custom\(\s*\"[^\"]*\"\s*,\s*fixedSize\s*:"),
                          "Font.custom(fixedSize:) never scales; use Font.custom(_:size:relativeTo:)"),
    "uikit-fixed-font": (ERROR, re.compile(r"\b(?:UIFont|NSFont)\s*\.\s*(?:systemFont|boldSystemFont|italicSystemFont|monospacedSystemFont|monospacedDigitSystemFont)\s*\(\s*ofSize\s*:"),
                         "UIFont with a fixed size; wrap it with UIFontMetrics(forTextStyle:).scaledFont(for:) or use preferredFont(forTextStyle:)"),
    "dynamic-type-cap": (WARNING, re.compile(r"\.dynamicTypeSize\s*\("),
                         "limits Dynamic Type; people who need the largest sizes will not get them. Review at the largest accessibility size"),
    "minimum-scale-factor": (WARNING, re.compile(r"\.minimumScaleFactor\s*\("),
                             "shrinks text instead of letting it wrap or grow; fine for a number in a fixed ring, not for body text"),
    "line-limit-one": (WARNING, re.compile(r"\.lineLimit\s*\(\s*1\s*\)"),
                       "single-line text truncates at large sizes; allow wrapping or provide the full text another way"),
}

ALLOW = re.compile(r"helios-lint:\s*allow\(([a-z0-9,\- ]+)\)")
UIFONT_GUARDS = ("UIFontMetrics", "scaledFont(for:")
EXCLUDED_PARTS = {".build", "DerivedData", ".swiftpm", "Tests", "SourcePackages", "checkouts"}


def blank_comments(text):
    """Replace comment text with spaces, keeping every newline so line numbers stay valid."""
    out = []
    i, n = 0, len(text)
    while i < n:
        if text.startswith("//", i):
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
        elif text.startswith("/*", i):
            depth = 0
            while i < n:
                if text.startswith("/*", i):
                    depth += 1
                    out.append("  ")
                    i += 2
                elif text.startswith("*/", i):
                    depth -= 1
                    out.append("  ")
                    i += 2
                    if depth == 0:
                        break
                else:
                    out.append("\n" if text[i] == "\n" else " ")
                    i += 1
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def allowed(lines, index, rule):
    for probe in (index, index - 1):
        if 0 <= probe < len(lines):
            match = ALLOW.search(lines[probe])
            if match and rule in [part.strip() for part in match.group(1).split(",")]:
                return True
    return False


def lint_text(text, name="<memory>"):
    """Returns a list of (line, severity, rule, message) for one file's text."""
    original_lines = text.splitlines()
    stripped = blank_comments(text)
    findings = []
    for rule, (severity, pattern, message) in RULES.items():
        for match in pattern.finditer(stripped):
            line_index = stripped.count("\n", 0, match.start())
            if allowed(original_lines, line_index, rule):
                continue
            if rule == "uikit-fixed-font":
                window = "\n".join(original_lines[line_index:line_index + 3])
                if any(guard in window for guard in UIFONT_GUARDS):
                    continue
            findings.append((line_index + 1, severity, rule, message))
    findings.sort()
    return findings


def swift_files(paths):
    for raw in paths:
        path = Path(raw)
        if path.is_file() and path.suffix == ".swift":
            yield path
        elif path.is_dir():
            for candidate in sorted(path.rglob("*.swift")):
                if not EXCLUDED_PARTS.intersection(candidate.parts):
                    yield candidate


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("paths", nargs="*")
    parser.add_argument("--strict", action="store_true", help="treat warnings as errors")
    args = parser.parse_args(argv)

    root = Path(__file__).resolve().parent.parent
    paths = args.paths or [str(root / name) for name in ("Packages", "App") if (root / name).exists()]
    errors = warnings = files = 0
    in_actions = bool(__import__("os").environ.get("GITHUB_ACTIONS"))
    for path in swift_files(paths):
        files += 1
        for line, severity, rule, message in lint_text(path.read_text(encoding="utf-8", errors="replace"), str(path)):
            shown = path.relative_to(root) if root in path.resolve().parents else path
            if in_actions:
                print(f"::{severity} file={shown},line={line}::[{rule}] {message}")
            else:
                print(f"{shown}:{line}: {severity}: [{rule}] {message}")
            if severity == ERROR or args.strict:
                errors += 1
            else:
                warnings += 1
    print(f"dynamic type lint: {files} files, {errors} errors, {warnings} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
