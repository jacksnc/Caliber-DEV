# Recipe and reusable-meal verification

Date: 2026-10-24
Branch: `codex/phase1-foundation`

## Scope

Step 3 adds a reusable recipe/meal editor using offline USDA foods, saved My
Foods, or manually entered portions. Nutrition is summed from entered/source
values, divided by batch servings, and optionally apportioned by measured cooked
batch weight. Logging supports servings or cooked grams when that weight is
known. A diary macro override is stored as a personal entry. Saved recipes and
diary rows keep value snapshots independent of editable source foods.

## Verification

| Criterion | Result | Evidence |
|---|---|---|
| Recipe batch and portion math, including measured yield and invalid inputs | PASS | Native SwiftPM recipe harness passed the golden vectors, bounds, overflow, and underflow cases. |
| Draft edits, persistence, retry after failed save/delete, diary snapshots, and macro overrides | PASS | Native SwiftData recipe harness passed 20 test functions, including failure-recovery and persistence/archive cases. |
| Legacy archive compatibility and normalized projection rehearsal | PASS | Foundation compatibility tests passed; all 15 original types/IDs/fields and photo bytes remained identical, v1 archive bytes were unchanged, and the v2 archive plus typed projection round-tripped. The v4 rehearsal digest was unchanged and no migration outbox was created. |
| iOS app compiles for Simulator | PASS | `xcodebuild build -quiet` for scheme `Caliber (DEV)` completed successfully after the recipe retry fix. |
| Repository formatting/lint rules | PASS | `python3 scripts/lint_foundation.py` completed successfully after formatting changed Swift files. |
| Focused recipe create-and-log UI flow | PASS | `RecipeBuilderUITests.testCreateMeasuredRecipeAndLogOneCookedPortion` passed 1/1 on the iPhone 17 Simulator (iOS 27.0). It created a manual chicken batch, checked 200 batch calories, 100 per serving, 0.8 raw-to-cooked factor, selected Cooked grams, logged 200 g, and observed “Added to Lunch.” |

The native harness lives outside the app checkout at
`/Users/jcrock/Documents/Codex/2026-10-07/are-x20/work/recipe-logic-2026-10-24/tests`.
It compiles copied app source and focused tests on macOS; it is useful evidence
for SwiftData/math behavior, but it does not replace the iOS UI test or an iOS 17
physical-device check. One initial Xcode unit-test selector attempt discovered
zero tests; the harness above is the successful unit/persistence result.

## Commands

```sh
python3 scripts/lint_foundation.py
xcodebuild build -quiet -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/caliber-recipe-ios
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,id=384D80B9-60DE-4538-B135-00D31BB69D2E' \
  -only-testing:'Caliber (DEV)UITests/RecipeBuilderUITests'
swift test --package-path /Users/jcrock/Documents/Codex/2026-10-07/are-x20/work/recipe-logic-2026-10-24/tests -j 4
```

The UI test passed on the booted iPhone 17 simulator (iOS 27.0). Xcode emitted
its existing destination metadata warnings and a SwiftUI runtime warning,
“Invalid frame dimension (negative or non-finite),” during launch; the UI flow
still completed successfully, and that warning's source was not isolated here.

## Limits

- This completes the requested recipe-builder step, not all of FUEL-04.
- Restaurant import remains disabled until current menu-data rights and coverage
  are reviewed. Existing sample menu entries are not official coverage.
- iOS 17 runtime, physical camera/device, largest Dynamic Type, VoiceOver, and
  performance checks have not been established by this recipe verification.
