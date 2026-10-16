# Restaurant import preparation — step 2

2026-10-15. FUEL-13 infrastructure prepared; new real menu coverage remains pending.

## Plan

1. Keep real data pending a permitted source; retain honest sample labels.
2. Define strict source, license declaration, restaurant, category and serving values.
3. Build a bounded offline importer with deterministic preview/staged output.
4. Read immutable source values without a private-store source migration.
5. Open ordinary portion/macro review and retain personal menu Edit/Delete actions.
6. Gate production coverage and fictional fixtures separately.
7. Check malformed data, source math, diary snapshots and simulator routes.

## File tree and complete source

```text
Caliber (DEV)/
  Resources/RestaurantMenuCatalog.json
  Services/{BundledRestaurantMenuService,FoodNutritionReference}.swift
  Views/Restaurants/{RestaurantListView,ImportedRestaurantMenuView}.swift
  Views/Diary/FoodNutritionReviewView.swift
Caliber (DEV)Tests/ImportedRestaurantMenuTests.swift
Caliber (DEV)UITests/FoodExperienceUITests.swift
Packages/CaliberFoundation/{Sources/CaliberDatabase/RestaurantMenuCatalog.swift,Tests/CaliberDatabaseTests/RestaurantMenuCatalogTests.swift}
scripts/{import_restaurant_menus,test_import_restaurant_menus,lint_foundation}.py
docs/examples/restaurant-menu-{input,empty}.json
docs/adr/015-permitted-restaurant-imports.md
```

Complete files are saved in the project; RESTAURANT_IMPORT_FILES.txt is the phase manifest. No new real source dataset was supplied or copied. Permission status/reference are maintainer declarations that require an actual completed rights review; software cannot grant rights.

## Result and migrations

The importer accepts an exact schemaVersion 1 input, preserving explicit per-serving kcal/protein/total carbohydrate/fat and optional source grams. It validates unique source/restaurant/global item IDs, references, HTTPS source metadata, dates, complete finite numbers and supported app categories. Unknown/duplicate JSON fields and oversized/deep/ambiguous input fail. Normalized output carries the true raw-input SHA256; deterministic ordering and --check expose changes. Output replacement is atomic and failed writes retain prior output.

Production contains zero imported sources/items. Existing menus remain samples. FUEL-13 remains default off even if a maintainer adds nonempty approved output; a separate release readiness change is required. Fictional fixtures remain explicitly marked and require --fixture for the CLI and allowFictional for the reader. The app's fixture path exists only in DEBUG and additionally requires its isolated-memory testing flag.

Imported menus browse categories and source retrieval dates. Review uses an explicit known serving weight or only the stated serving count; no inferred density/side inclusion or macro estimate. Adding a diary entry creates an independent personal FoodItem with restaurant source type and source identity/date, never a source MenuItem graph. Personal custom items keep their existing edit/delete flow. Starting the first custom item creates a personal restaurant identity; canceling the item draft may leave that empty identity for reuse.

No SwiftData/hosted migration, provider setup, network fetch or account change in this phase. Only a new bundled public JSON resource/schema is added. Existing Chipotle protein-doubling/sample behavior remains intact. The separate recipe phase adds its own private metadata migration and is documented independently.

## Verification report

| Acceptance criterion | Result / evidence |
| --- | --- |
| Deterministic permission/source-aware import | PASS — 23 Python tests, real CLI fixture output/--check and empty production reproduction. Missing nutrients never become zero. |
| Strict immutable reader | PASS — 11 package test functions, including 44 malformed-data cases, duplicate/escaped keys, URL/date/license/source and size/count/nesting boundaries. |
| Correct serving math and independent source/private boundary | PASS — three new app functions: honest empty production, known-gram review/personal override with zero inserted source rows, unknown mass refusing grams. |
| Imported categories/review and existing custom actions | PASS — fictional menu category→100 g review→single log, plus both existing Chipotle eligibility and custom edit/delete UI cases in restaurant-import-01. |
| Final build/app tests/default-off gate | PASS — final restaurant-import-02 Xcode build/test: 158 Swift Testing functions + 10 XCTest cases and the imported-menu UI case; initial run also passed both existing custom menu UI cases. |
| Formatting and whitespace | PASS — strict affected app/reader formatting and clean diff check. |
| Real current-menu coverage / release clearance | OPEN — requires actual permitted dataset, real-serving comparisons and explicit FUEL-13 release readiness. No actual coverage is claimed. |
| Physical iPhone, minimum OS, full accessibility/budgets | OPEN — available tests use iPhone 17 / iOS 27 simulator; deployment remains iOS 17. |

No chart or new health estimate is introduced. Evidence is saved in docs/evidence/restaurant-import. Runtime keyboard/AppIntents/SwiftData simulator diagnostics are not certified warning-free. Release, provider/contact/email and full P0 completion remain open.

## Run and verify

```sh
python3 -m unittest discover -s scripts -p 'test_import_restaurant_menus.py' -v
python3 scripts/import_restaurant_menus.py --input docs/examples/restaurant-menu-input.json --fixture --preview
python3 scripts/import_restaurant_menus.py --input docs/examples/restaurant-menu-empty.json --output 'Caliber (DEV)/Resources/RestaurantMenuCatalog.json' --check
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-menu-package --filter restaurantMenu
python3 scripts/lint_foundation.py
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,name=Caliber Account QA' \
  -parallel-testing-enabled NO '-only-testing:Caliber (DEV)Tests' \
  '-only-testing:Caliber (DEV)UITests/FoodExperienceUITests/testImportedFictionalMenuUsesCategoriesAndPersonalReview' \
  '-only-testing:Caliber (DEV)UITests/RestaurantCustomizationUITests' CODE_SIGNING_ALLOWED=NO
```

Choose an available simulator when the named QA device is absent. To inspect the ordinary app, open Caliber (DEV).xcodeproj, choose Caliber (DEV) + an iPhone simulator, press ⌘R, then Food Library → Restaurants. New imported coverage correctly says pending; samples and your custom items remain usable. Fixture menu UI is only for isolated automated tests.

## Next step

Build recipe/reusable-meal creation with ingredient snapshots, serving counts and explicit measured raw/cooked weights, while preserving existing archives and completed migration rehearsals. Obtain a permitted restaurant source separately; do not relabel the fictional example as real.
