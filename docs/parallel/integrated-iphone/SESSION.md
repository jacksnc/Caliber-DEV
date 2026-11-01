# Integrated iPhone checkpoint — 2026-11-01

## Latest follow-up — Diary energy units and model review

The Mac is unlocked and both existing native model chats were inspected before
work. Claude Opus 5.5 Medium implemented display-only saved-unit formatting in
Diary, food search and copy previews. Commit `29ad331` was reviewed and
cherry-picked locally as `26cd3dc`. Gemini 4 Argon was attempted, returned its
existing quota error, and was not upgraded; Gemini 3.8 Flash Medium completed
the separate read-only Frost/large-text task in branch
`gemini/integrated-frost-review`, commit `06d365f`. Claude Opus 5.5 Medium then
independently reviewed those findings in chat without editing files.

Codex corrections after review: the new views explicitly import `CaliberCore`;
Settings now has a stable energy-picker ID and says where the preference
applies; the UI test scrolls lazy Settings rows and checks the fixture's recent
food row in search. The broader run caught a threshold-format bug; the fix now
formats the `<0.1 kJ` threshold directly in the display unit. Food Search
favorite swipe uses the active Helios accent. The latest focused run passes all
6 energy unit tests and the kcal→kJ→kcal Diary/search/copy UI flow. Strict lints
pass. Focused reruns now pass all three FoodShortcuts tests and the Dinner/oats
review path after correcting lazy-list scrolling, picker timing, and route/AX
test assumptions. All 244 app unit tests pass. The historical broad UI result
is still partial and the full UI batch has not been rerun; details are in
`VERIFICATION.md`.

`MODEL_REVIEW.md` records the five findings and their evidence. A stale Diary
AX5 clipping claim was closed; the logo background is confirmed, while disabled
Save and translucent navigation need follow-up QA before code changes. The
previous statements below that external tasks were “not sent” describe the
earlier checkpoint only and are superseded by this follow-up.

Native verification used only Compact QA and fictional showcase data. The
latest corrected result is `/tmp/caliber-energyunit-final3.xcresult` with three
visually reviewed captures in
`output/screenshots/integrated-iphone/energy-unit-final-2026-11-01/`. The wider
`/tmp/caliber-energy-regression.xcresult` remains a historical partial result:
its energy-unit source predates the threshold fix, its UI assertion searched
for an Oikos row outside that route, and three FoodShortcuts tests had stale
lazy-list/route assumptions. The focused corrective rerun passes all three;
the related Dinner/oats review path and all 244 app unit tests also pass. The
full 22-case UI batch was not rerun after the fixes.

Coordinator: `/Users/jcrock/Documents/Codex/Caliber-integrated-iphone-qa`,
`codex/integrated-iphone-qa`, from e5aaa04. Recent reviewed features already form
one ancestor chain; no duplicate branch merge was needed. Owner local preview
and its three original dirty files remain separate and unchanged.

## Coordination

- Claude Opus 5.5 Medium completed the energy-display implementation; it was
  reviewed and cherry-picked as `26cd3dc`. Gemini 4 Argon hit its existing
  quota, so the read-only task was completed by Gemini 3.8 Flash Medium on the
  owner's Mac in a separate checkout; its report is `GEMINI_HANDOFF.md` and
  commit `06d365f`. Claude independently reviewed the report without edits.
- No model usage balance was claimed and no purchase or plan change was made.
  Prior cards/widgets commits `5af0a69` and `b01514e` were not duplicated.
- The earlier Codex read-only widget routing/privacy review and integration
  tests are complete; details and retained test artifacts remain below.

## Implementation and written reason for navigation change

The actual iOS URL handler originally only selected Fuel. A native baseline test
confirmed that tapping the widget's Fuel URL leaves Food Library open. Diary also
retained its prior selected date. The fix sends an ephemeral, consumable request
to Diary, resets the date to now only when safe, and uses one type-erased Fuel
navigation path for Library branches. This replaces conflicting nested navigation
paths, not the persistent tab or its stores. Normal food routes remain available.

Food-add links open the existing editable search, not a log insertion. Repeated
Add keeps current search/review input. Diary edit/copy/repeat/add sheets defer
requests until dismissal. A pushed Library branch must return to its root before
it can be popped. Profile, Quick Log and shared check-in forms hold external
navigation until finished. Privacy/Demo transitions clear pending requests.
Requests are not persisted across launch. No guarantee is made for every editor
in the app; only the explicitly covered routes have evidence in this batch.

The stale widget preview now uses the real daily constructor for its historical
generation date, including that day's midnight expiry. This changes Debug-only
fictional preview data; the production snapshot schema and privacy rules stay
intact. No health formula, record or database migration.

## Test progression

- `/tmp/caliber-widget-routing-baseline.xcresult`: Add URL passes; Fuel URL fails
  to return from Library, confirming the original behavior.
- `/tmp/caliber-integrated-routing.xcresult`: 238 Swift Testing app cases and 16
  XCTest app cases pass. Four of seven routing cases pass. Two Library cases
  catch a real regression in the first fix: SwiftUI reports
  AnyNavigationPath.Error.comparisonTypeMismatch. The single-stack correction
  removes that design. The day-reset case also catches a test-fixture assumption:
  yesterday has 2,100 fictional calories; the known-empty future day is now used.
- `/tmp/caliber-integrated-routing-corrected.xcresult`: seven of eight routing
  cases pass, including Library return, date reset and unsaved check-in notes.
  The remaining failure is a test tapping a search Cancel button that iOS hides
  after URL activation; cancellation is now conditional before the Back action.
- `/tmp/caliber-integrated-core.log`: 21 focused widget/Health/date-policy tests
  pass. No engine changed.
- Final native result/checklist: VERIFICATION.md. Intermediate failures remain
  recorded here rather than being described as successful runs.

Final source runs: `/tmp/caliber-integrated-iphone-final.xcresult` passes 254 app
tests, all three food-flow UI cases and seven routing cases. The remaining
Library-search case preserves input correctly but taps iOS's search Close before
Back; a test-only bounded Close/Back correction passes in
`/tmp/caliber-integrated-library-return.xcresult`. All 11 unique UI cases are now
covered by passing results. No production source changed after the main final
run. No native test job remains. Read VERIFICATION.md for exact limits/commands.

All native commands target Compact QA 2998CE67-7D71-460B-AD69-76DAA4D014F6,
DerivedData `/tmp/caliber-integrated-qa-derived`, one test runner at a time and
`-collect-test-diagnostics never`. No personal simulator or source store used.
