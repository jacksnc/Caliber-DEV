# Integrated iPhone verification — 2026-11-01

Branch `codex/integrated-iphone-qa`, baseline e5aaa04. Worktree:
`/Users/jcrock/Documents/Codex/Caliber-integrated-iphone-qa`.

## Plan completed

1. Inspect current history and prior model handoffs without duplicating merges.
2. Prepare separate bounded Claude/Gemini tasks; record native-access limitation.
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
| Existing app logic and persistence regressions | PASS | 238 Swift Testing cases in 26 suites, plus 16 XCTest app cases |
| Focused widget/Health/date package regressions | PASS | 21 tests in /tmp/caliber-integrated-core.log |
| Native app and embedded WidgetKit extension build | PASS | Native test builds succeed on Compact QA; no signing/team changes |
| Formatting, Dynamic Type and diff review | PASS | Strict Foundation formatter; 241 files, zero Dynamic Type errors/warnings; clean diff whitespace; coordinator reread and independent source review |
| Original local preview and personal simulator preserved | PASS | Local-preview stays 84edf55 with its three original modified paths; only dedicated QA UUID used |
| External native Claude/Gemini tasks actually started | PENDING | Mac control reports locked; owner chose continued code work. Briefs prepared, not sent/acknowledged |
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

No native test job remains at this checkpoint. Next: inspect/unlock the existing
native model chats and send the prepared Claude/Gemini tasks once, using this
published integration HEAD. Continue separate physical widget/Health QA without
claiming those checks are satisfied by this batch. No release-readiness claim.
