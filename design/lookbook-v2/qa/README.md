# Lookbook V2 Responsive & Food-Flow QA

Reproducible design verification for `design/lookbook-v2/responsive.css`, `food-entry.html`, and `food-review.html` using only Python 3 standard library modules and existing macOS `/Applications/Google Chrome.app` (no third-party packages, network fetches, simulator edits, or system-setting changes).

## Commands

Run fast unit tests + static contract checks (`< 0.1s`):

```bash
python3 -m unittest discover -s design/lookbook-v2/qa -v
python3 design/lookbook-v2/qa/check_v2_responsive.py --static-only
```

Run full static + isolated headless-Chromium rendered DOM audit across 116 owned-board viewport/theme/scale/state combinations and refresh PNG screenshots:

```bash
python3 design/lookbook-v2/qa/check_v2_responsive.py \
  --capture-screenshots \
  --json-out design/lookbook-v2/qa/latest-report.json
```

Run cross-branch integration rehearsal in memory (reads peer `diary.html`, `base.css`, `components.css`, and sibling boards via `git show` without merging or modifying peer files — 382 rendered combinations across all 7 V2 boards):

```bash
python3 design/lookbook-v2/qa/check_v2_responsive.py \
  --peer-ref origin/codex/lookbook-v2 \
  --claude-ref origin/claude/lookbook-v2-design \
  --json-out design/lookbook-v2/qa/peer-integration-report.json
```

## Isolation Guarantees

- Ephemeral loopback HTTP server binds `127.0.0.1:0` (explicitly skipping `8768` so Codex preview sessions are untouched).
- Headless Chrome uses a disposable `--user-data-dir` and `--remote-debugging-port=0`, never attaching to or resizing any open browser window.

## What Is Verified vs. UNTESTED

| Check | Status | Scope / Method |
| --- | --- | --- |
| Token & CSS hygiene | Tested | Every `var(--...)` defined in `design/tokens.css` or locally; zero hardcoded colors; zero `text-overflow: ellipsis` truncation; WCAG AA `>= 4.5:1` token pairs in Graphite & Frost |
| Frozen board HTML contract | Tested | Stylesheet/script load order, balanced tags, zero external URLs/imports, sequential headings (`h1 -> h2 -> h3`), `<label for>` associations, `button[type="button"]`, `data-board-link` |
| Responsive width & landscape sweep | Tested | `320x693`, `375x812`, `390x844`, `430x932`, `480x854`, `667x375` (short landscape), `568x320` (ultra-short landscape) |
| 200% & 300% HTML text stress | Tested | `scale=1` (`16px`), `scale=2` (`32px`), `scale=3` (`48px`) with verified unshrunk body font (`17px / 34px / 51px`), `docScrollWidth <= innerWidth`, zero clipped elements |
| Touch target geometry | Tested | Every visible interactive `button`, `a[href]`, `input` shell, `select`, and `label.v2-check` measured `>= 48x48` CSS px |
| Themes & accessibility query modes | Tested | `theme=dark` (Graphite), `theme=light` (Frost), `glass=reduced`, `contrast=more`, `state=populated`, `long-name`, `empty`, `number-free` (plus `no-goals` on `diary.html`, `locked`/`opted-out` on `stack.html`) |
| Native SwiftUI Dynamic Type | **UNTESTED** | HTML `root.style.fontSize` scaling does **not** establish SwiftUI `@Environment(\.dynamicTypeSize)` layout |
| Native iOS VoiceOver / Switch Control | **UNTESTED** | DOM label/focus audit does **not** replace physical iOS VoiceOver rotor, announcement, and focus-order testing |
| Native Swift/Xcode build & simulator | **UNTESTED** | Intentional design-first checkpoint; zero runtime Swift files altered |
