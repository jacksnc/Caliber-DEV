# Offline barcode collection — step 1

2026-10-15. Incremental Fuel work; full P0/release gates remain open.

## Plan

1. Pin a permitted public Branded release and record exclusions.
2. Produce a bounded, separate read-only catalog with exact GTIN identities.
3. Preserve 100 g versus 100 mL and explicit source servings.
4. Load off the UI thread and use local lookup before optional online lookup.
5. Review/edit independent personal portions before logging.
6. Verify importer, reader, cancellation, math and real bundled product UI.
7. Review changes and save phase source/evidence.

## File tree and complete files

```text
Caliber (DEV)/
  App/BarcodeLookupCoordinator.swift
  Services/{BundledBarcodeService,BarcodeNutritionProduct}.swift
  Resources/{PackagedFoodDatabase.sqlite,PackagedFoodDatabaseManifest.json,ThirdPartyNotices.txt}
  Views/Diary/{BarcodeFoodLookupView,FoodNutritionReviewView}.swift
Caliber (DEV)Tests/PackagedBarcodeTests.swift
Caliber (DEV)UITests/FoodExperienceUITests.swift
Packages/CaliberFoundation/{Sources/CaliberDatabase/PackagedFoodCatalog.swift,Tests/CaliberDatabaseTests/PackagedFoodCatalogTests.swift}
scripts/{build_packaged_database,test_build_packaged_database,lint_foundation}.py
docs/adr/014-offline-packaged-foods.md
docs/evidence/packaged-food/
```

Complete implementation files are saved in the project; PACKAGED_FOOD_FILES.txt is the phase manifest. No placeholder product data or API keys were added.

## Result and migrations

50,000 USDA Branded products: 42,401 with a gram basis and 7,599 with a milliliter basis. The pinned April 2026 source includes labels published in 2019–2026; present-day package comparison remains necessary. This is an initial US-market subset, not complete barcode coverage. The manifest records the exact archive/database hashes, chosen brands, preparation/version rules and exclusions. No ingredients, package images or logos are included.

No SwiftData/private schema, existing logs, normalized rehearsal target, hosted configuration or online provider activation changes. New public SQLite tables are packaged_metadata, packaged_sources and packaged_products; application_id=1128352848, user_version=1. The reader opens immutable data with no sidecar writes. Local hits need no online permission. Local misses require configured/current online permission; cancellation/generation is checked before provider transmission.

A source serving scales reported nutrients by quantity/100. A 28 g serving at 393 kcal/100 g yields 110.04 kcal; 56 g yields 220.08 kcal. A 250 mL serving at 44 kcal/100 mL yields 110 kcal; two servings yield 220 kcal without an inferred gram weight. Personal macro overrides and source records remain independent.

## Tests and verification report

| Acceptance criterion | Result / evidence |
| --- | --- |
| Pinned reproducible source with no guessed nutrients/units | PASS — 24 importer tests and full pinned-archive exact reproduction; manifest records selection/exclusions. |
| Strict read-only reader, integrity/GTIN/version validation | PASS — package suite: 92 declared functions, two optional actual-resource checks skipped in ordinary run; new reader cases include 42 malformed datasets and eight invalid lookups. Actual 50,000-product resource check ran separately and passed. |
| Correct mass/volume mapping and local-first permission boundary | PASS — nine new app test functions, including real bundled mass/volume records, stale local miss cancellation and no unauthorized provider calls. |
| Build and existing app logic | PASS — 155 Swift Testing functions and 10 XCTest cases in the final Xcode run. |
| Real product reviews and existing portion edits | PASS — three isolated simulator UI cases: offline 28→56 g cereal, offline 1→2 volume servings with no grams, existing ounces/source portions/personal macro edits. Old online-fixture consent route also passed in the previous app run. |
| Strict format and diff whitespace | PASS — evidence/lint.log and diff-review.log. Full affected diff read for source, persistence and privacy regressions. |
| Physical camera, minimum OS, complete accessibility/device budgets | OPEN — iPhone 17 / iOS 27 simulator, Xcode 27; target remains iOS 17. Existing keyboard invalid-frame and AppIntents warnings remain. |

Mac Debug observation: full resource open/validation about 650 ms; 100 indexed lookups about 8.5 ms. Full validation runs off the app's main actor. These are observations, not physical-device budget certification. No new chart or health estimate is introduced. Earlier numeric editing failures were corrected by selecting the current amount on focus; final affected UI cases pass. Logs in docs/evidence/packaged-food contain final outcomes; observed-checks.json distinguishes recorded observations from raw logs.

## Run and verify

```sh
python3 -m unittest discover -s scripts -p 'test_build_packaged_database.py' -v
python3 scripts/build_packaged_database.py --archive /path/to/FoodData_Central_branded_food_csv_2026-04-30.zip --check
python3 scripts/lint_foundation.py
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-packaged-package
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,name=Caliber Account QA' \
  -parallel-testing-enabled NO '-only-testing:Caliber (DEV)Tests' \
  '-only-testing:Caliber (DEV)UITests/FoodExperienceUITests' \
  '-only-testing:Caliber (DEV)UITests/FoodShortcutsUITests' CODE_SIGNING_ALLOWED=NO
```

Importer byte reproduction requires the manifest's SQLite 3.54.0 writer. An optional actual-resource package test accepts CALIBER_PACKAGED_CATALOG_PATH and CALIBER_PACKAGED_CATALOG_SHA256. Pick an available simulator if the QA device is absent.

In Xcode: open Caliber (DEV).xcodeproj, choose Caliber (DEV), select an iPhone simulator and press ⌘R. Open Food Library → Scan Barcode. Enter 016000482685, tap Done then Look Up Barcode. Review the source/label and change grams before Add to Diary. For 000020072353, review the explicit 250 mL source serving; quantity multiplies servings without a gram conversion. These pinned source examples are math checks, not current physical label checks.

## Next step

Prepare restaurant imports from approved sources, leaving new real menu coverage pending source permission. Then add recipe ingredient snapshots, measured batch yield and reusable logging. Email/provider setup remains deferred.
