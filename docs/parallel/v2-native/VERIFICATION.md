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
