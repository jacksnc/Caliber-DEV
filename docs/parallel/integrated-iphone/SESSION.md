# Integrated iPhone checkpoint — 2026-11-01

Coordinator: `/Users/jcrock/Documents/Codex/Caliber-integrated-iphone-qa`,
`codex/integrated-iphone-qa`, from e5aaa04. Recent reviewed features already form
one ancestor chain; no duplicate branch merge was needed. Owner local preview
and its three original dirty files remain separate and unchanged.

## Coordination

- Native control reports the Mac locked. Owner explicitly chose "Continue code
  work for now". No bypass or security-setting change was attempted.
- Claude/Gemini task briefs are prepared, not dispatched or acknowledged. Claude
  gets the larger energy-display consistency implementation; Gemini gets a
  smaller read-only Frost/large-text measurement review. Inspect actual chat,
  model, job and branch state before sending. No usage balance was independently
  verified. Gemini remains on the owner's Mac.
- Prior published cards/widgets tips are Claude 5af0a69 and Gemini b01514e.
  Gemini's dedicated local cards/widgets checkout is clean. These source checks
  do not establish current native chat state.
- An available Codex agent performed three read-only source reviews. It made no
  edits or native runs and did not impersonate either external model. It found
  the retained Diary date/path issue, a malformed stale preview fixture near
  midnight, a missing deferred-route retry and unreported check-in editor holds.
  Latest source review found no blocking issue; its minor standalone-preview
  registration finding was also corrected with a shared destination view.

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
