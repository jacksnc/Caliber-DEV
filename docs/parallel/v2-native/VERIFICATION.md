# Native V2 verification

This is a separate QA build, not the owner's installed preview. Native seed:
a07ceb9. QA: Caliber Lookbook QA, 60A77BA7-5A23-4A5B-8405-B089F66D6B9F,
iPhone 17 / iOS 27.0. Derived data: /tmp/caliber-v2-native-derived.

## Diary slice - 2026-10-30

| Acceptance | Result | Evidence |
| --- | --- | --- |
| App compiles and existing calculation/storage tests pass | PASS | 242 unit cases, 317 runs, no failures; diary-unit-summary.json |
| Reported calories remain independent; missing/invalid goals and overflow safe | PASS | Five DiaryNutritionMetricTests, including 640 reported versus 634 macro calories |
| Centered Graphite/Frost native summary | PASS | DiaryV2UITests, reviewed default captures |
| Largest accessibility text reflows, no fixed ring constraining text | PASS | AX5 test, dynamic-type/text-clipping audits and reviewed capture |
| Meal action keeps Breakfast destination | PASS | Default themes and AX5 route assertions |
| Calendar arrows show next empty day and restore original total | PASS | Next-day test, 1462 → 0 → 1462 |
| Copy/repeat preserve completed preview and single add | PASS | Both existing FoodShortcuts cases, fixed hidden-navbar-aware helper |
| Format/static scaling lint | PASS | lint_foundation.py, strict Dynamic Type audit: 224 files, 0 errors/warnings |
| Models, health formulas, providers, privacy gates, personal store unchanged | PASS | Source diff and independent read-only review |
| Combined peer surfaces and food flow | PENDING | Integrate reviewed peer changes and test native build |
| Small-phone/iPad/resizing and independent Frost beta | PENDING | After combined iPhone checkpoint |

Machine summaries live in docs/evidence/v2-native/diary-{unit,ui}-summary.json.
Reviewed screenshots live in output/screenshots/v2-native/diary. Full local
results: /tmp/caliber-v2-diary-unit.xcresult and
/tmp/caliber-v2-diary-ui-fixed.xcresult. No runtime warnings in either summary;
legacy compile-time concurrency warnings elsewhere remain.

## Run

```sh
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict 'Caliber (DEV)' Packages/CaliberFoundation/Sources
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' -destination 'platform=iOS Simulator,id=60A77BA7-5A23-4A5B-8405-B089F66D6B9F' -derivedDataPath /tmp/caliber-v2-native-derived -parallel-testing-enabled NO '-only-testing:Caliber (DEV)Tests'
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' -destination 'platform=iOS Simulator,id=60A77BA7-5A23-4A5B-8405-B089F66D6B9F' -derivedDataPath /tmp/caliber-v2-native-derived -parallel-testing-enabled NO '-only-testing:Caliber (DEV)UITests/DiaryV2UITests' '-only-testing:Caliber (DEV)UITests/FoodShortcutsUITests/testCopyYesterdayLetsYouChooseFoodsAndAddsOnlyOnce' '-only-testing:Caliber (DEV)UITests/FoodShortcutsUITests/testSameDayMealRepeatKeepsItsCompletedPreviewStable'
```

Do not use the auto-selecting test_ios.py during parallel QA. No migration.


## Reviewed food integration and base surfaces - 2026-10-31 02:42 UTC

Combined native build/unit:243 cases PASS. HeliosDesign:48 XCTest cases PASS.
Full strict scaling lint224files0issues; foundation format lint PASS.
Four food functional cases PASS (selected meal/date, macro/source independence,
reuse/cancel/edit and single save) in combined-food-initial result. The AX audit
needed harness corrections; its final run now PASSES all hub/manual/quick-review
screens in BOTH Graphite and Frost at default and AX5 sizes, with48pt checks.

The 11-case base integration run passed8 cases: number-free privacy, all3Lookbook
cases, Progress text-table, Stack logging/lock, active workout and full AX5 theme
walkthrough. It failed the food audit plus default Graphite/Frost on a repeated
Progress "Smoothed trend" clipping issue. The targeted correction run now passes
all3 affected cases. No failures were suppressed; original summaries are kept.
Progress legend fitting/wrapping was corrected. AX surfaces use fresh fixtures
so prior audits/row remeasurement do not supply the next route's scroll state.
Normal functional save/cancel paths remain separately exercised.

Evidence: native-surfaces-initial-summary.json, combined-food-initial-summary.json,
layout-corrections-summary.json, combined-unit-summary.json and helios-tests.log.
Selected native captures: output/screenshots/v2-native/food. Full28 captures:
/tmp/caliber-v2-corrections-readable. Frost Progress and AX review were visually
inspected. Keyboard invalid-frame warnings remain; the unchanged a07ceb9 app
reproduces them (baseline-keyboard-summary.json + exact probe source). This is
not a warning-free claim. Earlier baseline full-case attempt was aborted.

Pending: review/merge peer handoff corrections and Claude224db4a presentation
fixes, native rebuild/scoped revalidation, then iPhone checkpoint. Known inherited
Train-width and Progress-unit-preference risks are in BACKLOG; no claim that all
P0 app/release requirements are complete. No owner preview/device/store changes.


## Native iPhone checkpoint - 2026-10-31 03:16 UTC

Latest full food suite PASS7/7 (footer-review-summary.json), including selected
meal/date, source overrides/reset, recent-food reuse/cancel, single save, exact
2350.25calorie total and <1kcalover display. Existing system audits still pass for
all hub/manual/quick-review initial surfaces in Graphite/Frost/default/AX5.

Deep review uses a separate measured check: default→AX calorie and macro row
heights grow by >30%, exact100.25calories/Fat2.5625g remain accessible, Fat's entire
bounds stay inside the viewport above the footer, no horizontal overflow, primary
action≥48pt. Both default/AX captures were visually inspected: correct Frost
palette, no internal value truncation, clear full-width actions. Their neighboring
rows scroll naturally under the native bar. Captures: output/screenshots/v2-native/
final-review. No system-audit certification is inferred from these measurements.

The additional deep-scroll system audit remains INCONCLUSIVE: its element is
evicted during font-size queries (three identity retries); generic nil-element
reports are retained in final-layout-diagnostic-summary.json. Original audits
were not disabled or filtered. The initially added deep-row diagnostic was
replaced by the focused growth/bounds test with independent source-review
agreement, not described as a passing system audit. See decisions V206/V207.

Claude224db4a is merged. Native compiler call-syntax correction in two Stack
layouts is verified by243unit tests (final-unit-summary.json). Latest themed
Frost and full AX5 pass; Graphite's Doses today heading required explicit wrapping
and passes the subsequent targeted full-screen run. Stack opt-in/logging/lock
passes. Prior number-free/Profile/workout/Progress text-table cases remain green.
48Helios tests and strict224file scaling/format lint pass. No health engine,
model, dataset, provider, entitlement or user-store changes. Legacy keyboard
warning remains, reproduced on baseline. No physical-owner installation.

This is a native presentation checkpoint with the stated audit limitation and
inherited issues in BACKLOG, not an all-P0/release-complete claim. Next: native
compact/landscape and tablet/resizing checks, then independent Frost beta.


## Pushed-route follow-up - 2026-10-31 03:38 UTC

A final legacy pushed-review check found a real overlap after footer introduction:
Save hit the global Today tab. The first outer safeAreaInset experiment failed
and was reverted. A transient UI footer-presence bridge now hides floating
navigation while a review footer is visible; disappearing releases its UUID.
No persistent navigation/model/health state is involved.

Modal reuse/cancel passes with the bridge. The pushed-route now saves correctly,
prevents repeat save, restores navigation after Back, retains favorite/frequent
state and verifies200.5exact diary calories. Its old assumption that tapping the
already active custom tab pops its stack was corrected to the actual2Back route;
app tab behavior was preserved. Test also asserts the navigation bar is absent
while the footer owns actions, and the capture was inspected. Confirmed result:
pushed-review-confirmed-summary.json; capture final-review/pushed-review-clear-
action.png. Earlier failed results are retained. Main source/format/scaling lint
passes. No owner checkout installation or stored-data change.


Compact Train: reviewed e9d41cb compiles and passes the two existing draft/options
and Graphite workout cases on375pt iPhoneSE3 QA (compact-train-summary.json).
This verifies current default portrait behavior, not every text size/rotation;
those are next in responsive QA. No health calculations/storage changed.
