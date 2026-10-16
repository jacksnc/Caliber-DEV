# Expanded offline food database

2026-10-15 · `codex/phase1-foundation` · Imports prepared October 14. Incremental FUEL-02/03 checkpoint; full Fuel P0 and Foundation release acceptance remain open.

## Plan

1. Retain existing food IDs, personal snapshots, source boundaries and service protocols.
2. Import pinned USDA Foundation and SR Legacy public releases with auditable exclusions.
3. Build a separate indexed SQLite reference catalog and verify its manifest/hash.
4. Read typed foods/servings through the existing GRDB package without a user-store migration.
5. Add source-defined household measures, visible source years and compatible favorites.
6. Validate the resource off the UI thread and keep manual entry available.
7. Check import, database, nutrition and simulator interactions; review the full diff.
8. Save the phase commit, verification evidence and complete source archive.

## File tree and complete source

```text
Caliber (DEV)/
  App/FoodLibraryPreferences.swift
  Services/{BundledFoodSearchService,FoodCatalogTypes,FoodNutritionReference}.swift
  Resources/{FoodDatabase.sqlite,FoodDatabaseManifest.json,ThirdPartyNotices.txt}
  Views/Diary/{FoodSearchView,FoodNutritionReviewView}.swift
  Views/FoodLibrary/FoodLibraryView.swift
Caliber (DEV)Tests/{FoodCatalogTests,ExpandedFoodDatabaseTests}.swift
Caliber (DEV)UITests/FoodShortcutsUITests.swift
Packages/CaliberFoundation/
  Sources/CaliberDatabase/ReferenceFoodCatalog.swift
  Tests/CaliberDatabaseTests/ReferenceFoodCatalogTests.swift
scripts/{build_food_database,test_build_food_database,lint_foundation}.py
docs/{DECISIONS,BACKLOG,CHANGELOG,HOW_WE_CALCULATE,MIGRATIONS,LICENSES,SECURITY}.md
docs/adr/013-public-food-database.md
```

The delivery ZIP contains complete source/resources/tests, not snippets. Xcode's folder synchronization includes the new app files and bundled resource; existing CaliberDatabase package boundaries/dependencies are reused. `FOOD_DATABASE_FILES.txt` lists the exact phase files. The original Foundation JSON and importer remain unchanged as reproduction/compatibility fixtures.

## Result

The app now searches **8,104 complete foods** and **14,792 source-defined portions** entirely offline. Production lookup uses an immutable SQLite/FTS5 catalog instead of rescanning the small JSON fixture. Its size is **7,000,064 bytes**; SHA256 is `3ff4994f61ddb212fda6323cf623ca1eb5a2728ff1323e197083ef461a7a0968`.

| Source | Imported foods | Imported portions | Exclusions |
| --- | ---: | ---: | --- |
| Foundation, April 2026 | 311 | 361 | 32 null + 52 incomplete food records |
| SR Legacy, April 2018 | 7,793 | 14,431 | 18 portions with invalid amount/weight |
| Total | 8,104 | 14,792 | Missing nutrients/weights are never fabricated |

Exact source URLs and archive/JSON/output hashes are in FoodDatabaseManifest.json and LICENSES.md. [USDA's official downloads](https://fdc.nal.usda.gov/download-datasets/) distinguish the releases; [its data documentation](https://fdc.nal.usda.gov/data-documentation/) identifies SR as historical reference. The UI shows source years and historical context. It never labels these records current restaurant menus or barcode products. Names retain raw/cooked/preparation qualifiers, distinct FDC identities stay distinct, and Foundation wins equivalent-relevance ties.

Household choices appear only where the source supplies gram mass. For FDC168878, 1 cup of the specified cooked rice is 158 g; 2 cups log 316 g and 410.8 kcal. FDC172470's 2 tbsp peanut-butter serving is already 32 g and is not doubled again. Unit-only changes retain exact mass/personal macro edits; a typed amount change resets an override. Saved food text records resolved grams plus the entered measure/count. A full-width numeric field keeps long converted values editable. Source records remain immutable and each diary addition remains an independent editable snapshot.

The bounded loader validates file hash, schema/indexes, exact source releases, nutrient ranges, portions, relationships and FTS documents once. Food screens share its background load; subsequent queries are short, bounded indexed reads. Favorites accept the new SR namespace and preserve existing Foundation/personal keys.

## Migrations and privacy

No SwiftData model, private canonical schema, normalized rehearsal locator, hosted SQL, account activation or online provider changes. New public tables are `catalog_sources`, `catalog_foods`, `catalog_servings`, `catalog_metadata` and `food_search`; resource application_id is 1128352838 and user_version is 1. The read-only reader creates no sidecar/migration and never inserts source rows into a person's diary. Existing 311 Foundation IDs, names, publication dates, energy methods and macros are preserved.

The importer only downloads with explicit `--download`. It stages both outputs and restores previous bytes on handled rename failures. A process interruption between the two file replacements can leave a mismatch; the app rejects that mismatch through the manifest hash. No personal data, external food lookup, photo, auth token or email is sent. SHA256 checks are integrity checks, not encryption or arbitrary-source authentication.

## Tests and verification report

Final results and evidence are recorded below. Initial simulator attempts exposed a quantity-field layout issue and test cursor/scroll targeting; final passing evidence supersedes those runs. Existing numeric-keyboard invalid-frame diagnostics remain, so this is not a warning-free-runtime claim.

| Checkpoint acceptance criterion | Result and evidence |
| --- | --- |
| Reproducible complete source catalog and audit | PASS — 20 new + 8 existing Python tests; pinned import `--check` reproduces database/manifest. All 311 original Foundation records retain exact values. |
| Indexed read-only source records, source/version bounds and corruption handling | PASS — 7 new package functions, including 35 malformed row/source/schema cases, file/hash/sidecar checks, keyed lookup/FTS and the actual 8,104/14,792 resource. Full package: 81 functions pass across its five target suites. |
| Exact household calculation and editable independent snapshots | PASS — 6 new app functions cover original compatibility, historical preparation, 2 cups/316g/410.8kcal, 2 tbsp/32g/191.36kcal, fractional/invalid weights and favorite reopening. Existing portion/override/failure tests pass. |
| Household UI and source favorites | PASS — final isolated UI verifies rice/cup entry, exact mass/totals after unit switches, historical labeling, favorite reuse and a single log. |
| Existing food routes remain functional | PASS — final affected suite verifies barcode/manual review, USDA editing, local restaurant creation/custom menu, ounces/overrides, recent/frequent/favorites, previous-day copy and same-day preview stability. |
| Build/type-check, app tests and lint | PASS — final Xcode test build, 146 Swift Testing functions + 10 XCTest cases, eight affected UI cases, strict Swift formatting and clean diff whitespace. |
| Architecture/private-store boundary | PASS — verify_phase1.py checks source boundaries/bundled contracts plus 43 disposable canonical SQL cases. Original private schema/resources are unchanged; this does not complete app migration/sync. |
| Physical iPhone / minimum-OS runtime / full accessibility and budgets | OPEN — available QA environment is Xcode27, iPhone17 simulator, iOS27; deployment target remains17. No physical camera, iOS17 runtime, complete VoiceOver/largest-text or first-paint budget certification. |

Package Debug macOS measurements accepted the actual shipped database: isolated open/full validation about 367ms and 30 searches about 25ms; under parallel package load about 588ms/56ms. These are development observations, not physical-device or p95 budget passes. The app moves full validation off the main actor; queries remain synchronous after readiness. No new chart or health estimate is introduced.

Evidence logs are in `docs/evidence/food-database/`. Full app/UI final evidence is `caliber-food-tests-database-05.xcresult`; source reader/package execution is recorded separately. Logs normalize trailing whitespace/line endings only. Corrupt-photo fixtures intentionally emit image-decoding errors; simulator keyboard/AVFoundation/CoreData diagnostics remain device follow-ups. No release certification or full P0 completion is claimed.

## Run and verify

From the repository root:

```sh
python3 -m unittest discover -s scripts -p 'test_import_usda_foods.py' -v
python3 -m unittest discover -s scripts -p 'test_build_food_database.py' -v
python3 scripts/build_food_database.py --archive-dir /path/to/pinned-usda-zips --check
python3 scripts/lint_foundation.py
python3 scripts/verify_phase1.py
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-catalog-package
xcodebuild test \
  -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,name=Caliber Account QA' \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 90 -maximum-test-execution-time-allowance 120 \
  '-only-testing:Caliber (DEV)Tests' \
  '-only-testing:Caliber (DEV)UITests/FoodShortcutsUITests' \
  '-only-testing:Caliber (DEV)UITests/FoodExperienceUITests' CODE_SIGNING_ALLOWED=NO
```

A fresh machine can add `--download` to the import check to retrieve both public pinned ZIPs. Byte reproduction requires the manifest's SQLite writer version, currently3.54.0; the shipped SQLite reader is portable. The optional full-resource package measurement requires `CALIBER_REFERENCE_CATALOG_PATH` and `CALIBER_REFERENCE_CATALOG_SHA256` environment values matching this public resource. Without them that one optional measurement is skipped; synthetic reader tests still run. Choose an available iPhone simulator if the named QA simulator is absent. UI tests use isolated in-memory personal stores.

In Xcode:

1. Open **Caliber (DEV).xcodeproj**, select scheme **Caliber (DEV)**, choose an iPhone simulator and press **⌘R**.
2. Tap **Food Library → Search Foods**, search **rice white long grain enriched cooked**, and select **Rice, white, long-grain, regular, enriched, cooked** labeled **USDA SR Legacy · 2018**.
3. In **Portion Unit**, select **1 cup**. Changing units preserves the current mass, so enter **2** in **Quantity** to choose two complete cups. Tap **Done** above the keyboard. The basis shows **1 cup = 158 g** and the total is **410.8 calories**.
4. Switch to **g** to see **316**, or adjust macros, select the meal/date and tap **Add to Diary**. Existing logs and source nutrition stay separate. Tap **Favorite Food** to retain this source in Favorites.

## Recommended next step

Expand packaged-food/barcode coverage through a chosen compatible source and staged real-label checks, then build current restaurant coverage from approved official/licensed data. The existing provider/contact/reuse decisions remain pending; no OFF/commercial or current-menu import occurred here. Micronutrients, structured private corrections/provenance, source-update reconciliation, recipes and protected portability also remain in BACKLOG. Email setup remains deferred.
