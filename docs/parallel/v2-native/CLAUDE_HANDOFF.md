# Claude Opus 5.5 — V2 native surfaces handoff

Branch: `claude/v2-native-surfaces`, from the published seed `a07ceb9`, in a
separate clean clone. Nothing outside the README ownership row was edited and
no other branch was merged. No model, service, calculation, storage, token,
package, project, root navigation, Settings, provider or feature-flag change.

## Files changed
| File | Change |
| --- | --- |
| `Views/Foundation/TodayFoundationView.swift` | V2 Today (details below); `MacroRings`, `Sparkline`, `NumberFreeHomeView` and the dose tile logic unchanged |
| `Views/Progress/WeightTrendChart.swift` | Chart height 104 → 160 (still `@ScaledMetric`); "Show weigh-ins" text table |
| `Views/Progress/ProgressDashboardView.swift` | Cards on an opaque surface (`progressCardRow()`, private) instead of `caliberCardRow()` |
| `Views/Progress/ProgressTimelineRow.swift` | Opaque card; full notes (removed `lineLimit(3)`); "+N" photo badge uses Helios type |
| `Views/Train/TrainHomeView.swift` | Resume row in Helios type with the workout name; history rows wrap; summary volume in the display unit |
| `Views/Train/ActiveWorkoutView.swift` | System `.font`/`.secondary` replaced by Helios type and palette (AX completed set, AX unit label, exercise picker) |
| `Stack/StackHomeView.swift` | "x of y logged today" line, one grouped Supply card ("As you recorded it"), opaque cards and focus tile, "Taken" without a blank time |
| `Caliber (DEV)UITests/ProgressUITests.swift` | New `testWeightChartListsWeighInsAsText` |

All paths are below `Caliber (DEV)/` unless shown.

## What changed, per surface
**Today.** The four concentric rings became one centered energy ring (reused
`MacroRings` with a single ring). The centre shows kcal left, or eaten in Eaten
mode; **above the goal, Left shows "N over"** instead of 0. Under the ring:
eaten and goal figures (eaten only, "no goal set", without a goal). Protein,
carbs and fat sit in three columns with "of N g" and a meter, and become one
column at accessibility sizes or when they do not fit. Title is now
"Energy today". The empty day keeps "No food logged today" and adds an
**Open Fuel** button (`todayOpenFuel`, existing `selectCaliberTab(.fuel)`).
The training card is titled "Continue workout" while a session is open and
shows "x of y sets logged" with a meter: done = `completedSets`, total = all
sets added to that session. Every Today card uses an opaque surface.
Goals come only from the saved profile, as before (invalid/zero = no goal).

**Progress.** Range picker, chart source, timeline grouping, swipe edit/delete,
sheets and IDs unchanged. "Show weigh-ins" (`weightTrendReadings`, a plain
button with value Shown/Hidden, not a DisclosureGroup, so a list-row tap
cannot fire it) lists every recorded weigh-in in the range, newest first, with
date (incl. year) and value in the chosen unit.

**Train.** Logging, rest, undo/reopen, drafts, swipe delete, Finish/Add
Exercise and IDs unchanged. One behaviour-visible fix: the finished-workout
summary showed volume in hard-coded kg; it now uses the display mass unit, the
same as the history row that opens it.

**Stack.** `StackLockGate`, opt-in, `StackRuntime.isLocked`, Log/Skip, editors
and the existing STK-10 estimate card (still gated by `showsEstimate`) are
unchanged. The new counts are from `StackPlanner.today` / `isTaken`, which the
screen already computed. No amounts were added anywhere new.

## Opaque surfaces
Each owned file has a private `v2Surface()` (or `progressCardRow()`): it draws
the existing `GlassBackground` with `reduceTransparency = true` set on that
background only, i.e. the audited `palette.opaque[level]` tone with the same
edge, Increase Contrast stroke and shadow. Text colours are unchanged, so they
are the stock text-on-opaque pairs (`check_tokens.py`: minimum 5.94:1). The
Stack focus tile is opaque `raised` on opaque `base`, avoiding the known nested
glass-on-glass contrast gap. If Codex prefers one shared modifier, promote it;
I kept it private per the contract. No new motion or glass is adopted.

## Dose tile "Locked"
Not reproduced in code: the tile already uses `StackRuntime.isLocked`
(`requiresUnlock && !isUnlocked`), so it shows "Locked" only while the lock is
on and not unlocked this session; unlocking calls `stack.open()` via
`.task(id: stack.isLocked)`. Left unchanged. Still no UI test for
`todayNextDose` after unlock; worth one on device.

## Not built (no data route; recorded instead of faked)
- Today's daily timeline (V2 board): needs a cross-domain read of diary,
  workouts, weigh-ins and Stack, which the contract excludes.
- Stack seven-day log dots: needs a new per-day adherence read.
- Train "last time vs today" column header rename and stepper controls: kept
  the existing text fields and "Previous" header (tests depend on the grid).

## Checks run here (cloud, Linux, no Xcode/Swift)
- `python3 scripts/lint_dynamic_type.py`: 223 files, 0 errors, 0 warnings.
- `python3 scripts/check_tokens.py`: PASS (54 pairs, minimum 5.94:1).
- `python3 scripts/gen_tokens.py --check`: up to date.
- `python3 -m unittest discover -s scripts -p 'test_*.py'`: 130 tests OK.
- Diff greps: no `minimumScaleFactor`, no new `lineLimit`, no fixed font sizes;
  new main controls ≥ 48 pt (Fuel chips 42 pt + 3 pt padding each side = 48).
- `python3 scripts/lint_foundation.py`: **cannot run** (needs `xcrun swift-format`).
  Code is hand-formatted to 2-space/100 columns; long string literals as existing.

## UNTESTED (Codex to verify)
Build, swift-format lint, unit tests and all UI tests, including
`ProgressUITests.testWeightChartListsWeighInsAsText` (the button may need a
scroll on small simulators) and the existing `FoundationUITests` ("No food
logged today"), `StackUITests`, `LookbookPolishUITests`, `ThemeIntegrationUITests`.
Native Graphite/Frost, default and AX5 text, 320-point width, Increase
Contrast, Reduce Transparency/OLED, VoiceOver order for the energy ring
("N kcal left/over/eaten today") and macro cells, and number-free (Today is not
shown then; `NumberFreeHomeView` unchanged).

## Correction batch (review findings 3, 4, 6, 7)

Same branch, after 17298c9. Only `Views/Foundation/TodayFoundationView.swift`,
`Stack/StackHomeView.swift` and this file changed. Train fit, unit preference,
Skip undo, weigh-in table performance and the Progress legend clipping are not
part of this batch: Train fit is in the next responsive batch, and Codex owns the
rest.

- **3. Below one unit over the goal.** `TodayFuelCard.figure` still compares the raw
  `goal - eaten < 0`. No stored or compared value is rounded. A positive overage
  below 1 shows "<1" (the 1 is formatted for the locale) with the caption
  "[unit] over". VoiceOver says "less than 1 [unit] over today's goal". Overages of
  1 or more, and the Left and Eaten modes, are unchanged.
- **4. Localization.** `Figure.caption` and `Figure.spoken`, and the energy-context
  captions ("[unit] eaten / goal / eaten · no goal set"), are `LocalizedStringKey`
  again. Only the formatted numbers are `Text(verbatim:)`.
- **6. Today tiles.** When text is not accessibility-sized, `ViewThatFits` pairs the
  weight and dose tiles only while each can have `tileWidth`. That is a 136-point
  `@ScaledMetric` relative to body, padding included, passed as each tile's
  `idealWidth`. Otherwise the tiles stack. At accessibility sizes they always stack,
  as before. Expected from arithmetic: paired at 320 points with default text,
  stacked at 320 points from xLarge, and stacked at 390 points from xxxLarge. When
  Stack is off, the dose tile renders nothing and the weight tile takes the full row.
- **7. Stack rows.** `StackDoseRow` and `StackCompoundRow` use a private
  `StackRowLayout`. It is `VStackLayout(alignment: .leading)` from `.xxxLarge` up and
  the old `HStackLayout` below that, so the status badge or the Log button moves
  under the name. Names and details now wrap rather than truncate. The buttons,
  actions, accessibility labels, IDs, the lock and opt-out gates, dates and units
  are unchanged.

Checks run in the cloud: `lint_dynamic_type.py` 0 errors and 0 warnings,
`check_tokens.py` PASS, `gen_tokens.py --check` up to date, and 130 script unit
tests OK. `lint_foundation.py` cannot run here because it needs `xcrun`. Every
native check is **UNTESTED**: build, swift-format, unit and UI tests, and the
layout at 320 and 375 points with default, xxxLarge and AX5 text.

## Correction batch 2 (review finding 1: Train set grid fit)

Same branch, after 224db4a. Only `Views/Train/ActiveWorkoutView.swift` and this file
changed.

- **One decision, one owner.** `ActiveWorkoutView.stacksSets` is true at accessibility
  sizes, as before, and also when the measured content width of an exercise header
  row, minus 4, is narrower than `setGridWidth`. The 4 points are the header's 16 + 12
  inset compared with the set row's 16 + 16. `setGridWidth` is a 302-point
  `@ScaledMetric` relative to body: 24 + 64 + 76 + 58 + 48 + 4 × 8 at default text,
  growing with text size. The width comes from a background `GeometryReader` on the
  header row, using `onAppear`/`onChange`. That row's width never depends on the
  decision, so measuring it can't loop. No `UIScreen` is used. Before the first
  measurement the width is 0, so the grid shows, matching the old behavior.
- **Header and rows switch together.** `columnHeader` and every `TrainingSetRow` read
  the same flag, passed as `stacked`. It replaces the row's own `isAccessibilitySize`
  checks, so the completed grid row, the stacked completed row, the open row, the
  warm-up/RPE row and the field widths all follow it.
- **Stacked labels.** With no header in the stacked layout, open rows now show
  "Previous 80 × 8" (only when there is one) and captions above the fields:
  "Weight · [unit]" and "Reps". These replace the old unit text after the weight
  field. Stacked completed rows add a "Previous …" line. The captions are hidden from
  VoiceOver, because the fields keep their "Weight" and "Reps" labels.
- **Preserved.** The parent `setDrafts` still owns drafts, and the `TextField` views
  and focus keys are the same in both layouts (`AnyLayout` keeps identity), so typed
  fractional values and focus survive a switch. Completion, undo/reopen, swipe delete,
  expand/collapse, the keyboard Done button, Add Set, Set options and every ID are
  unchanged. Fonts are not capped and names are not truncated.
- **Expected from arithmetic, not measured:** stacked at 320 points even with default
  text. Grid at 390 points with default text (about 318 points against 302 needed).
  At 375 points it is borderline (about 303 points against 302), depending on the
  list's margin. Stacked from about xLarge at 390 points.
- **Tests.** I didn't add a focused test. XCUITest can't see which layout was chosen
  without new layout IDs, and the stacked captions are hidden from accessibility.
  Codex's native check: at 320 points and at 390 points with xxxLarge text, every
  grid value and label is visible and switching layouts keeps a typed draft. The
  existing `LookbookPolishUITests` set-row predicates still match at 390 points with
  default text.

Checks run in the cloud: `lint_dynamic_type.py` 0 errors and 0 warnings,
`check_tokens.py` PASS, and 130 script unit tests OK. `lint_foundation.py` and every
native build, swift-format and test check are **UNTESTED**: there is no Xcode here.
