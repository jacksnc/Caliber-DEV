# Integrated iPhone verification — 2026-11-01

Branch `codex/integrated-iphone-qa`, baseline e5aaa04. Worktree:
`/Users/jcrock/Documents/Codex/Caliber-integrated-iphone-qa`.

## Full UI rerun after harness corrections — latest

The serial iPhone SE (3rd generation), iOS 27.0, run completed in
`/tmp/caliber-ui-full-after-harness-2026-11-01.xcresult`. It executed all 91 UI
cases: **76 passed, 15 failed**. The run used fictional UI fixtures. No
production source changed during this rerun.

Test-only corrections now exercised by the full batch include restoring
portrait orientation in teardown, opening the restaurant search before tapping
a lazy restaurant row, scrolling Stack consent content before asserting the
controls, and returning from Restaurants to the Food Library root before
opening Barcode. The full run confirms the corrected Stack opt-in/logging flow
and `ThemeIntegrationUITests.testLargestTextScreens` pass. A separate focused
run also confirms the responsive-run teardown no longer contaminates following
portrait cases; the workout fractional-draft rotation case itself still fails.

The remaining failures are recorded without converting them into passing
claims. They span food fixture/action discovery, modal/draft expectations,
account fixture navigation, demo-chart targeting at the largest text size,
one invalid-focus interaction, two Progress save journeys and one workout
rotation journey:

| Failing UI case | Evidence / next review |
|---|---|
| `FoodEntryPass2UITests.testBackdatedMealCarriesThroughNoResultsManualEntryAndRecipesWithoutInventingZeroMacros` | Empty-state “Show All” expectation not found after switching Recent scope; review current empty-search behavior and fixture. |
| `FoodEntryPass2UITests.testFutureLoggingDateShowsFutureBadgeNeverPastDateAndRetainsSelectedMealAndDay` | Recent quick-review row not found in the selected future-date flow. |
| `FoodEntryPass2UITests.testRecentQuickActionPrefillsLastPortionCancelsCleanlyAndKeepsLoggedSnapshotEditable` | Recent quick-review row not found after opening Dinner. |
| `FoodEntryPass2UITests.testSubCalorieOverageUsesAnHonestBoundAndKeepsReportedTotal` | UI automation did not focus the Calories field before typing; this is an input/reveal failure, so its overage assertion was not reached. |
| `FoodExperienceUITests.testOfflineFoodPortionAndPersonalMacroEditCanBeLogged` | Expected offline banana catalog identifier `1105073` was absent from this search result. |
| `FoodShortcutsUITests.testRecentFavoriteAndFrequentFoodsReuseTheLatestPortion` | Recent fixture row was not discovered in the broad run; its three focused cases passed in `/tmp/caliber-foodshortcuts-final.xcresult`. |
| `FoundationUITests.testAccountSignInAndDeviceSignOutUseOnlyFixture` | Consent control appeared, but the expected Continue button was absent after toggling; account fixture flow needs isolated review. |
| `FoundationUITests.testDemoAndExitPreserveEmptyPersonalDiary` | Test could not tap the Body weight chart table action. |
| `FoundationUITests.testDemoAtLargestTextSizeHasUsableChartRoutes` | Method/info route control was not tappable after returning from the chart table at AX5; review layout and test reveal. |
| `FoundationUITests.testHostedDeletionKeepsLocalProgressNote` | Shared account fixture helper did not expose its Continue control. |
| `FoundationUITests.testRecoveryUsesCodeWithoutSigningIn` | Shared account fixture helper did not expose its Continue control. |
| `GoalSetupUITests.testInvalidAgeAndMissingEquationCannotAdvance` | Automation lost keyboard focus during replacement of the age value; validation assertion was not reached. |
| `ProgressUITests.testDailyCheckInEditsSameDayAndCanBeDeleted` | Save tap failed after entering the note; timeline/edit/delete assertions were not reached. |
| `ProgressUITests.testNotesOnlyCheckInDoesNotInventAWeight` | Save tap failed after entering notes; no-weight assertion was not reached. |
| `ResponsiveLayoutUITests.testWorkoutFractionalDraftSurvivesRotationAndCardCollapse` | Could not reveal the workout exercise row after rotation at accessibility text size; remains an open responsive-layout issue. |

The result bundle reports repeated SwiftUI runtime warnings for
`Invalid frame dimension (negative or non-finite)` during UI execution. This
batch does not isolate which view emitted them, so they remain an open runtime
warning rather than an asserted root cause.

The earlier “full broad UI regression — NOT RERUN” statements below describe
the state before this run and are superseded by this section.

## Latest follow-up: saved kcal/kJ display and Frost review

The saved energy preference now formats Diary totals/goals/balance, meal
headings, Diary food rows, Food Search rows and copy previews. Values continue to
store and calculate in kcal; the display conversion uses `1 kcal = 4.184 kJ`
after arithmetic. Food-entry editors, original nutrition-label values and the
confirmed Health activity allowance continue to use kcal. No schema or data
migration was needed.

| Check | Result | Evidence |
|---|---|---|
| kcal and kJ formatting, locale decimals, arithmetic and storage invariance | PASS | 6 tests in `CaliberEnergyDisplayTests` passed in `/tmp/caliber-energyunit-final3.xcresult` |
| Diary, meal row, copy preview and Food Search follow kJ, then return to kcal | PASS | 1 end-to-end UI test in `/tmp/caliber-energyunit-final3.xcresult`; fixtures only |
| Three rendered saved-unit states | PASS | Screenshots exported and visually reviewed in `output/screenshots/integrated-iphone/energy-unit-final-2026-11-01/` |
| Small positive kJ over-goal amounts do not appear as zero | PASS | Focused regression fixed `<0.1` threshold formatting; English/German locale cases are in the passing six-test suite |
| Foundation formatting lint | PASS | `python3 scripts/lint_foundation.py` exited 0 |
| Dynamic Type strict lint | PASS | 242 files, 0 errors and 0 warnings |
| Design-token accessibility lint | PASS | 54 contrast pairs; minimum text contrast 5.94:1; command `python3 scripts/check_tokens.py` exited 0 |
| Focused food and energy regressions | PASS | Energy display UI/unit tests pass; all 3 corrected `FoodShortcutsUITests` pass in `/tmp/caliber-foodshortcuts-final.xcresult`; the Dinner/oats review path passes in `/tmp/caliber-food-entry-oats-lazyfavorite.xcresult`. All 244 app unit tests pass in `/tmp/caliber-unit-final.xcresult`. |
| Full broad UI regression after harness corrections | FAIL (76/91) | `/tmp/caliber-ui-full-after-harness-2026-11-01.xcresult`; 76 pass and 15 are detailed above. The result does not establish that all failures are product defects; several stop at automation focus/route assertions. |
| Original widget routing batch and user data boundaries | PASS | Prior evidence below; only Compact QA simulator and fictional fixtures were used in this follow-up |
| Native model review | PASS | Claude Opus 5.5 Medium implemented and independently reviewed; Gemini 3.8 Flash Medium delivered read-only review after Gemini 4 Argon hit its existing quota. No overage enabled. |
| Physical iPhone, Health permission/source and Home Screen widget sizing | NOT VERIFIED | This follow-up used Compact QA only and did not request Health access or edit the personal device |

### Latest test runs

- `/tmp/caliber-energyunit-final3.xcresult`: latest source, 6 energy unit tests
  and the full energy-unit UI flow pass. The broad run initially found that the
  `<0.1 kJ` threshold had accidentally been converted as kcal; this was fixed
  and covered by the focused rerun.
- `/tmp/caliber-energy-regression.xcresult`: 244 Swift Testing cases had two
  assertions fail in that same now-corrected test; its old energy UI test also
  searched for a packaged Oikos result outside the route's recent-row section.
  The corrected focused energy run passes. The broad UI batch had three
  FoodShortcuts failures from lazy-list scrolling and a stale route assertion;
  all three now pass in `/tmp/caliber-foodshortcuts-final.xcresult`. The related
  Dinner/oats review test passes in `/tmp/caliber-food-entry-oats-lazyfavorite.xcresult`.
- `/tmp/caliber-unit-final.xcresult`: all 244 app unit tests pass after the
  threshold correction.
- The complete 91-case UI batch is now recorded above; it is not fully green.
- No production build was copied into the owner's local preview, and no
  personal simulator, real Health data, provider, credential or permission was
  touched.

## Plan completed

1. Inspect current history and prior model handoffs without duplicating merges.
2. Inspect the native chats and branches; dispatch bounded Claude/Gemini tasks.
3. Independently review widget navigation and reproduce its retained destination.
4. Preserve drafts while routing safe widget links to today's diary/search.
5. Run isolated app, package and native food/routing regressions.
6. Review the diff and native captures; publish the checkpoint separately.

## Files

```text
Caliber (DEV)/Views/
  RootTabView.swift
  Navigation/{CaliberWidgetNavigation,QuickLogSheet}.swift
  Diary/DiaryView.swift
  FoodLibrary/FoodLibraryView.swift
  Progress/ProgressEntryForm.swift
Caliber (DEV)UITests/WidgetRoutingUITests.swift
CaliberWidgets/WidgetPreviewFixtures.swift
docs/parallel/integrated-iphone/{README,SESSION,CLAUDE_TASK,GEMINI_TASK,VERIFICATION}.md
output/screenshots/integrated-iphone/*.png
```

Complete source files are committed in this checkout. No database, settings or
snapshot migration; navigation state is ephemeral. The existing health math,
source nutrition, consent, provider and Stack gates remain unchanged.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Recent reviewed features share one integrated history | PASS | Branch starts at e5aaa04, containing prior cards/widgets/Health and progress-unit commits |
| Original widget Fuel navigation defect reproduced | PASS | Baseline native URL test fails to return from Food Library; Add route passes |
| Fuel link returns to today and opens the diary root | PASS | Corrected native cases from a pushed Library and a known-empty non-today date |
| Add opens editable search without changing diary totals | PASS | Native URL case dismisses search and confirms the original 1,462 recorded calories |
| Repeated Add and queued Fuel preserve active search text | PASS | Native search retains oikos, then safely returns to unchanged diary totals |
| Pushed Library search survives external URL and drains its request after return | PASS | Final focused Library-return rerun, using actual iOS URL delivery and search/Back controls |
| Open Profile and an unsaved check-in note are preserved | PASS | Profile remains open until closed; typed note survives URL, Cancel then opens queued food search |
| Number-free mode cannot be left through either URL | PASS | Both URLs keep Numbers are hidden visible and expose neither Fuel tab nor search |
| Search, barcode lookup and custom restaurant flows survive navigation consolidation | PASS | Oikos name and GTIN reviews both show 150 g / 130 source calories; fictional local restaurant and custom item creation succeed |
| Existing app logic and persistence regressions | PASS for prior batch | 238 Swift Testing cases in 26 suites, plus 16 XCTest app cases in the original integration run; the latest follow-up separately passes 244 app unit tests and focused food-flow UI cases above |
| Focused widget/Health/date package regressions | PASS | 21 tests in /tmp/caliber-integrated-core.log |
| Native app and embedded WidgetKit extension build | PASS | Native test builds succeed on Compact QA; no signing/team changes |
| Formatting, Dynamic Type and diff review | PASS | Strict Foundation formatter; 241 files, zero Dynamic Type errors/warnings; clean diff whitespace; coordinator reread and independent source review |
| Original local preview and personal simulator preserved | PASS | Local-preview stays 84edf55 with its three original modified paths; only dedicated QA UUID used |
| External native Claude/Gemini tasks actually started | PASS | Claude and Gemini 3.8 Flash completed the bounded follow-up tasks; see `CLAUDE_HANDOFF.md`, `GEMINI_HANDOFF.md`, and `MODEL_REVIEW.md` |
| Physical widget/camera/Health and all-device performance | NOT VERIFIED | Simulator URL/fixture results are not Home Screen sizing/redaction, camera optics, real Health permission/source or hardware-performance evidence |

## Exact runs

- `/tmp/caliber-widget-routing-baseline.xcresult`: confirms the original retained
  Library behavior with no production fix applied.
- `/tmp/caliber-integrated-routing.xcresult`: app logic passes; first routing fix
  exposes a real mixed typed/nested NavigationPath crash. It is corrected before
  publication. See SESSION.md for the fixture-date assertion correction too.
- `/tmp/caliber-integrated-routing-corrected.xcresult`: 7/8 URL cases pass; the
  remaining test assumes a search Cancel button exists after URL activation.
- `/tmp/caliber-integrated-iphone-final.xcresult`: final production source;
  254 app tests and 3 food UI cases pass, plus 7/8 routing cases. The remaining
  test successfully preserves search text but taps the search Close control
  instead of the subsequent Back button, then fails to find Diary.
- `/tmp/caliber-integrated-library-return.xcresult`: the last routing case passes
  after bounded test-only Close/Back handling. No production source changed after
  the main final run. Combined coverage: all 11 targeted UI cases pass.
- `/tmp/caliber-integrated-core.log`: 21 focused package cases pass.
- `/tmp/caliber-integrated-final-lint.log`: strict Foundation formatting passes.
  Strict Dynamic Type lint reports 241 files / zero errors / zero warnings.

Four exported native PNGs in output/screenshots/integrated-iphone show Frost
Diary after the URL, the fictional preserved note, the reviewed Oikos serving
and the fictional custom restaurant. Diary and note captures were visually
inspected. All values/notes are isolated fixtures, not owner records.

## Reproduce

```sh
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict
swift test --package-path Packages/CaliberFoundation --filter 'widget|activity|seasonal'
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,id=2998CE67-7D71-460B-AD69-76DAA4D014F6' \
  -derivedDataPath /tmp/caliber-integrated-qa-derived \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  '-only-testing:Caliber (DEV)Tests' \
  '-only-testing:Caliber (DEV)UITests/WidgetRoutingUITests' \
  '-only-testing:Caliber (DEV)UITests/FoodExperienceUITests/testOikosProNameSearchUsesReviewedLabelServing' \
  '-only-testing:Caliber (DEV)UITests/FoodExperienceUITests/testOikosProBarcodeUsesSameReviewedLabel' \
  '-only-testing:Caliber (DEV)UITests/FoodExperienceUITests/testLocalRestaurantCanBeCreatedAndReceivesCustomMenu' \
  CODE_SIGNING_ALLOWED=NO
```

The full UI job has completed with the partial result above. Next: review the
remaining failures individually, especially the AX5 chart/workout layouts and
the catalog lookup, then re-run only corrected failing cases before another
broad batch. Native physical-device widget/Health checks remain separate and
unverified. No release-readiness claim.
