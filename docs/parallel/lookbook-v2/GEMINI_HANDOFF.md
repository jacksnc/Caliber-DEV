# Gemini Argon (Mac) — Lookbook V2 Responsive & Food-Flow Handoff

Date: 2026-10-30
Branch: `gemini/lookbook-v2-responsive`
Seed commit: `137e3bf` (`docs: establish lookbook v2 parallel design contract`)
Design & QA commit: `97c233f` (`97c233f8b96cf75d86f03a08acd26e4e50973341`)
Peer branches inspected read-only via `git show` (not merged or edited):
- `origin/codex/lookbook-v2` (`b250653` / `f59152b` — `diary.html`, additive `base.css` classes)
- `origin/claude/lookbook-v2-design` (`b4070ab` / `30ff32b` — `components.css`, `today.html`, `train.html`, `stack.html`, `progress.html`)

## 1. Owned Files Touched

Strictly confined to Gemini V2 role ownership (`docs/parallel/lookbook-v2/README.md`):

- `design/lookbook-v2/responsive.css`
- `design/lookbook-v2/food-entry.html`
- `design/lookbook-v2/food-review.html`
- `design/lookbook-v2/qa/README.md`
- `design/lookbook-v2/qa/check_v2_responsive.py`
- `design/lookbook-v2/qa/test_check_v2_responsive.py`
- `design/lookbook-v2/qa/latest-report.json`
- `design/lookbook-v2/qa/peer-integration-report.json`
- `design/lookbook-v2/qa/screenshots/food-entry-graphite-390.png`
- `design/lookbook-v2/qa/screenshots/food-entry-frost-390.png`
- `design/lookbook-v2/qa/screenshots/food-review-graphite-390.png`
- `design/lookbook-v2/qa/screenshots/food-review-frost-390.png`
- `design/lookbook-v2/qa/screenshots/food-entry-frost-320-scale3.png`
- `design/lookbook-v2/qa/screenshots/food-review-graphite-320-scale3.png`
- `docs/parallel/lookbook-v2/GEMINI_HANDOFF.md`

Runtime Swift, `design/tokens.json`, `design/tokens.css`, v1 `design/lookbook/`, CI, central docs, Codex worktrees, the owner local-preview checkout, the personal iPhone simulator, and loopback `127.0.0.1:8768` were left completely untouched.

## 2. What Was Built

### `design/lookbook-v2/food-entry.html` (`Add food` hub)
- **Destination & meal context**: `Fuel diary` back link (`>= 48px`) + destination chip (`Logging to Lunch · Fri, Oct 30` via `data-demo="shortDate"`) and destination card (`Lunch · Friday, October 30` via `data-demo="date"`) with 4 `>= 48px` meal switcher preview pills (`Breakfast`, `Lunch`, `Dinner`, `Snacks`).
- **Offline search & top match**: Labeled search shell (`#food-search-input`, query `bowl`) noting bundled offline provenance (`311 USDA Foundation + 7,793 SR Legacy foods`) and linking directly to `food-review.html` for `Demo chicken bowl` (`640 kcal`, `P 48 g`, `C 70 g`, `F 18 g`).
- **Capture & library routes (`Ways to add`)**: 2-column `.grid-2` of `>= 64px` tactile preview buttons with original inline vector icons for **Barcode scan** (GTIN-14 check & explicit `100 g`/`100 mL`/serving basis), **Nutrition label** (on-device read & macro discrepancy flag), **My Foods & Meals**, and **Manual entry** (requires all four explicit values; blank macros never default to `0 g`).
- **Photo estimate mock (`FUEL-10`)**: Original CSS/SVG viewfinder diagram (`var(--accent)`, `var(--border-strong)`, `var(--data-protein)`, `var(--data-carbs)`) illustrating `Proposed: Demo chicken bowl · est. 380 g`, stating explicitly that vision proposes food identity and gram mass only—never calories or macros—and requires user confirmation in Review.
- **Restaurant entry (`FUEL-13` off)**: Zero real branded restaurant chains or imports; shows fictional `Fictional Harbor Kitchen · Demo chicken bowl` (`1 stated entrée`) and personal CSV import preview without guessing missing mass, cooking yield, or side items.
- **Recent foods & state coverage**: Lists the four synthetic diary items (`Demo chicken bowl`, `Demo oats & berries`, `Demo salmon & potatoes`, `Demo yogurt & fruit`) bound to `window.CALIBER_DEMO` energies, plus full `state=long-name`, `state=empty`, and `state=number-free` variants.

### `design/lookbook-v2/food-review.html` (`Review food` editable portion & macros)
- **Food identity & favorite preview**: Reading-edge `Demo chicken bowl` title (plus `state=long-name` variant), `1 bowl (380 g)` basis note, and `>= 48x48px` favorite toggle preview button (`★`).
- **Centered log summary**: Centered `640` kcal (`data-demo="bowlEnergy"`) + 3-column `.macro-grid` (`Protein 48 g`, `Carbs 70 g`, `Fat 18 g`) and explicit method footnote explaining that reported `640 kcal` is preserved rather than overwritten by `4P + 4C + 9F` (`634 kcal`), plus `state=number-free` check-in fallback.
- **Meal/date context & serving amount**: Stacked `Meal slot` (`<select>`) and `Diary date` (`<input data-demo="shortDate">`) fields; adaptive `.portion-grid` (`1 bowl (380 g)`, `Grams (g)`, `Weight ounces (oz)`) + `Quantity` + 4 `>= 48px` portion presets (`0.5 bowl`, `1 bowl`, `1.5 bowls`, `380 g`) and unit-conversion vs. override-reset explanation.
- **Editable portion & macros**: Four labeled, tabular-numeral fields (`Calories (kcal)`, `Protein (g)`, `Carbs (g)`, `Fat (g)`) paired with semantic `--data-*` indicator dots, `Save personal snapshot to My Foods` checkbox row (`>= 48px`), and `Reset to source values preview` button.
- **Original source & Add preview**: `<dl>` provenance table (`Caliber synthetic V2 fixture · Demo chicken bowl`, immutable diary snapshot rule) and explicit `Add to Lunch · Fri, Oct 30 (Preview)` primary CTA (`min-height: 52px`) + `Return to Diary without saving` link. Clicking any preview button updates `#preview-status` (`… — design preview; nothing was saved.`).

### `design/lookbook-v2/responsive.css` (Shared V2 + Codex `b250653` Diary + Claude `30ff32b` Reflow)
- **Eliminates Codex `b250653` Diary `320px/scale=3/long-name/Frost` overflow (`docScrollWidth: 521 -> 320`)**:
  - Converts outer/card/button/chip/pill/nav paddings and gaps from `rem` to fixed `px` at narrow widths (`<= 389px`, `<= 359px`) and `[data-scale="2"]` / `[data-scale="3"]`, keeping 100% full text sizes (`17px` / `34px` / `51px` body; `32px` / `64px` / `96px` `h1`).
  - Reflows `.app-header` (wraps at `scale=2`, stacks vertically at `scale=3`, scales `.avatar` circle to `56px`/`68px` so `"C"` never clips).
  - Reflows `.diary-date` into a 2-column grid with `.diary-date-label` spanning `1 / -1` above the `‹` and `›` `>= 48px` buttons.
  - Removes the circular `.energy-orbit` decorative ring at `[data-scale="2"]` and `[data-scale="3"]` (and compacts orbit diameter in short landscape `max-height: 500px`), keeping `.energy-value` single-line via `min(3.75rem, 31vw)` / `min(3.2rem, 31vw)` (`scale=1` sizes unchanged).
  - Wraps `.remaining-pill` (`max-width: 100%; flex-wrap: wrap`), `.energy-context`, `.row`, and `.section-head`, while protecting `html :is(.primary, .secondary, .icon-button)` `48x48px` minimums against higher-specificity child `min-width: 0` rules.
  - Stacks `.macro-grid`, `.diary-actions`, `.grid-2`, `.grid-3`, `.portion-grid`, `.food-row` (with reading-edge inline `.food-amount`), `.meal-pills`, `.review-presets`, and adapts `.app-nav` (`2`-col / `1`-col horizontal icon+label rows at `scale=2/3`, horizontal compact bar in short landscape).
  - Never uses `overflow-x: hidden/clip` on `html`/`body` or `text-overflow: ellipsis` to mask overflow.

## 3. Reproducible Verification & Honest Tested vs. UNTESTED Status

### Commands Executed & Results
1. **QA unit tests**:
   `python3 -m unittest discover -s design/lookbook-v2/qa -v` -> **PASS (`Ran 6 tests in 0.005s`)**
2. **Owned-branch static + isolated headless Chromium DOM/layout audit + PNG capture**:
   `python3 design/lookbook-v2/qa/check_v2_responsive.py --capture-screenshots --json-out design/lookbook-v2/qa/latest-report.json`
   -> **PASS (`static=PASSED rendered=PASSED cases=116 problems=0`, `Chrome/156.0.8078.74`, ephemeral port `57714`)**
3. **Full 7-board cross-branch in-memory rehearsal (Codex `origin/codex/lookbook-v2` + Claude `origin/claude/lookbook-v2-design` + Gemini `responsive.css`)**:
   `python3 design/lookbook-v2/qa/check_v2_responsive.py --peer-ref origin/codex/lookbook-v2 --claude-ref origin/claude/lookbook-v2-design --json-out design/lookbook-v2/qa/peer-integration-report.json`
   -> **PASS (`static=PASSED rendered=PASSED cases=382 problems=0`, `diary.html @320px/scale=3/long-name/Frost docScrollWidth=320`, ephemeral port `58582`)**
4. **Repository token, v1 lookbook & Swift format lint guards**:
   - `python3 scripts/check_tokens.py` -> **PASS (`54 text/essential-mark contrast pairs; minimum 5.94:1`)**
   - `python3 scripts/check_lookbook.py` -> **PASS (`look book: 0 problems`)**
   - `python3 scripts/lint_foundation.py` -> **PASS (exit 0)**

### Verification Matrix & Limitations

| Verification Area | Status | Notes / Limitations |
| --- | --- | --- |
| Static HTML5, frozen head order, label/button semantics, zero external URLs | **TESTED (PASS)** | Enforced by `check_v2_responsive.py` & `test_check_v2_responsive.py` |
| Token-only CSS (`../tokens.css`), zero hardcoded colors, WCAG AA `>= 4.5:1` pairs | **TESTED (PASS)** | Verified across Graphite (`dark`) and Frost (`light`) opaque surfaces & accents |
| Responsive widths (`320, 375, 390, 430, 480px`) & short landscape (`667x375`, `568x320`) | **TESTED (PASS)** | Zero horizontal overflow (`docScrollWidth <= innerWidth`) across all 116 owned & 382 7-board cases |
| 200% (`scale=2`) & 300% (`scale=3`) HTML text stress | **TESTED (PASS)** | Full unshrunk body font (`17px / 34px / 51px`), zero ellipsis or clipped elements |
| Interactive touch targets `>= 48x48` CSS px, `--accent-focus`, `glass=reduced`, `contrast=more` | **TESTED (PASS)** | Live `getBoundingClientRect()` check on every visible button, link, input shell, select, and checkbox label |
| Native SwiftUI Dynamic Type (`@Environment(\.dynamicTypeSize)`) | **UNTESTED** | HTML `root.style.fontSize` scaling does **not** establish native SwiftUI Dynamic Type layout |
| Native iOS VoiceOver, Switch Control & Voice Control | **UNTESTED** | DOM accessible-name and focus checks do **not** replace physical/simulator iOS assistive-tech testing |
| Native Xcode build / simulator UI tests (`scripts/test_ios.py`) | **UNTESTED** | Design-only checkpoint; zero runtime Swift files modified |
| Safari / WebKit print-to-PDF pagination | **UNTESTED** | Rendered checks ran in local headless Chromium (`156.0.8078.74`); assembled PDF export belongs to Codex |

## 4. Fixture Observations & Cross-File Requests for Codex

1. **`fixture.js` canonical food metadata**: `window.CALIBER_DEMO` currently freezes `bowlEnergy` (`640`), `bowlProtein` (`48`), `bowlCarbs` (`70`), and `bowlFat` (`18`), while `diary.html`, `food-entry.html`, and `food-review.html` repeat text literals (`Demo chicken bowl`, long-name variant, `1 bowl (380 g)`, and per-meal item macros for oats/salmon/yogurt). Adding optional frozen keys (`bowlName`, `bowlLongName`, `bowlServing`, `bowlMeal`) in `fixture.js` would keep all three Fuel boards single-sourced via `data-demo`.
2. **`board.js` query-parameter persistence across board links**: `board.js` currently forwards only `?theme=...` on `.app-nav a` and `a[data-board-link]`. Forwarding active `scale`, `glass`, `contrast`, and compatible `state` (`long-name`, `number-free`, `empty`) across internal navigation links would preserve stress-test parameters during multi-screen clicks.
3. **`board.js` parent tab highlight for child Fuel boards**: When `body[data-screen]` is `food-entry` or `food-review`, marking the `diary` (`Fuel`) link active in `.app-nav` would reflect that both boards belong to the Fuel tab hierarchy.
4. **CSS cascade compatibility verified**: Claude's `components.css` (`30ff32b`) uses `html:is([data-scale="2"],[data-scale="3"]) .section-head > * { min-width: 0; }`; `responsive.css` loads after `components.css` and enforces `html :is(.primary, .secondary, .icon-button) { min-width: 48px; min-height: 48px; }`, confirmed clean across all 382 7-board cases.

## 5. Native SwiftUI Food-Flow Mapping (iPhone First, Then iPad & Resizing — No Android)

### Step 7a: iPhone Native Mapping (Post-Checkpoint)
- **`food-entry.html` -> `Caliber (DEV)/Views/Diary/FoodSearchView.swift` + `FoodEntryPass2HubCard` (`FoodEntryPass2Components.swift`) + `AddFoodView.swift`**:
  - Align `FoodEntryPass2HubCard` with V2's calmer card grouping: destination summary (`FoodEntryPass2ContextFormatter.summary`) + inline 4-meal pill selector (`minHeight: 48`), unified search field with offline USDA catalog count subtitle, 2x2 `Ways to add` capture/library grid (`typeSize.isAccessibilitySize ? 1 : 2` columns), and reading-edge `Recent foods` rows.
  - Bump `FoodEntryPass2QuickReviewButton` (`FoodEntryPass2Components.swift` line 523) from `minWidth: 44, minHeight: 48` to `minWidth: 48, minHeight: 48`, and `libraryTile` (line 501) from `minHeight: 44` to `minHeight: 48` to match V2's strict `>= 48pt` target floor.
- **`food-review.html` -> `Caliber (DEV)/Views/Diary/FoodNutritionReviewView.swift` + `SavedFoodDetailView.swift` + `Views/Components/MacroOverrideSection.swift` + `FoodEntryPass2QuickReviewSheet`**:
  - Promote `Nutrition for this log` to a centered Helios summary card above the form sections (`reported kcal` hero numeral + `FoodEntryPass2MacroSummaryRow`, which already uses `ViewThatFits` horizontal-to-vertical reflow, plus the conditional `reported kcal preserved` footnote when reported energy differs from `4P + 4C + 9F`).
  - Upgrade `MacroOverrideSection.swift` (lines 36–52) from trailing `LabeledContent` inputs to stacked reading-edge `VStack(alignment: .leading, spacing: 4)` fields with semantic `theme.palette.data` dots and `.frame(maxWidth: .infinity, minHeight: 48)`, matching `AddFoodView.swift` (lines 187–197).
  - Add `typeSize.isAccessibilitySize` bottom `.safeAreaInset` action stacking (`Add to <Meal>` / `Cancel`, each `minHeight: 48`) to `FoodNutritionReviewView.swift` so confirmation controls never truncate inside navigation-bar toolbar items at AX1–AX5, matching `AddFoodView.swift` (lines 83–117).
  - Keep all `FoodPortionMath`, `NutritionInput`, `ReferenceFoodLogger`, `FoodEntryPass2ManualLogger`, and `SwiftData` models unchanged.

### Step 7b: iPad & Dynamic Window Resizing Plan (After Approved Native iPhone)
- **Size-class & container-width driven (never `userInterfaceIdiom == .pad` checks)**: iPad Slide Over (`320pt`) and 1/3 Split View (`320–375pt`) must render the exact single-column compact layout verified at `320px` and `375px` in V2.
- **Compact width (`< 600pt`, or whenever `dynamicTypeSize.isAccessibilitySize` is active)**: Single-column Fuel diary -> sheet/pushed `FoodSearchView` -> `FoodEntryPass2QuickReviewSheet` (`.presentationDetents([.large])`), ensuring AX Dynamic Type never squeezes two panes side-by-side.
- **Medium regular width (`600pt–899pt`, iPad portrait, 1/2–2/3 Split View, resized Stage Manager window)**: Two-column adaptive Fuel Entry workspace (`320–350pt` leading `FoodSearchView` hub/results column + `>= 340pt` trailing inline `FoodNutritionReviewView` inspector pane) so tapping `Demo chicken bowl` or a recent food updates the editable portion/macro review inline without modal sheet stacking; collapses cleanly to single-column below `600pt` while preserving unsaved draft state (`@State` hoisted to workspace coordinator).
- **Wide regular width (`>= 900pt`, iPad landscape / full Stage Manager)**: System `TabViewStyle.sidebarAdaptable` navigation + capped readable content measure (`maxWidth: 720pt` per pane) so reading-edge food names and trailing tabular kcal amounts stay visually connected rather than stretched across `1000pt+` rows.
- **Pointer & hardware keyboard parity**: `>= 48pt` hit targets, `.hoverEffect(.highlight)` on shortcut tiles and food rows, `⌘F` to focus food search, `Escape` to dismiss uncommitted review without writing data, and `⌘Return` to confirm log when `final != nil`.

## 6. Prioritized Frost Beta Ideas (Separate Post-Checkpoint Proposals — Zero New Providers/Math/Data)

Ranked for the post-iPhone Frost beta (`docs/LOOKBOOK_V2.md` step 8):

1. **P1 — Frost Interactive Field & Pill Perimeter Contrast Standard (`border.strong` over `opaque.raised`)**:
   In Frost, `border.hairline` (`rgba(11, 22, 38, 0.08)`) keeps outer cards airy, but under bright kitchen or gym glare editable text fields, unselected meal pills, and portion presets benefit markedly from `border.strong` (`rgba(11, 22, 38, 0.45)`) on `opaque.raised` (`#F8FAFE`), as demonstrated in `food-entry.html` and `food-review.html`. Apply this distinction across SwiftUI Frost inputs without modifying generated token palettes.
2. **P2 — In-App Frost Daylight / Opaque / High-Contrast A/B Switcher in `AppearancePreviewPicker`**:
   Let Frost beta testers toggle standard Frost, Opaque Frost (reduced glass), and Increased-Contrast Frost side-by-side on real devices to gather structured legibility ratings in bright ambient light without collecting any personal health or diary data.
3. **P3 — Inline `"Why reported kcal differs from macros"` Disclosure in Frost Review**:
   Surface a one-tap disclosure popover next to the Frost energy summary explaining fiber, polyols, and package-label rounding (`docs/HOW_WE_CALCULATE.md` §Energy cross-check—zero calculation changes) so beta testers understand why Caliber preserves reported `640 kcal` instead of forcing `634 kcal`.
4. **P4 — Explicit Override-Reset Notice When Typing a New Quantity vs. Switching Units**:
   Pair Frost's `status.warning` (`#8A5A00`) badge with an inline confirmation cue when typing a new serving quantity is about to clear a manual macro override, distinguishing it clearly from unit switching (`bowl` <-> `g` <-> `oz`), which preserves exact mass and personal edits.
