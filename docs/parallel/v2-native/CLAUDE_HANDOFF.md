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
