# Food data, barcode tools, restaurant tools and normalized-copy checkpoint

Date: 2026-10-14. Branch: `codex/phase1-foundation`. This is an incremental Foundation/Fuel checkpoint, **not completion of Phase 1 or all FUEL P0 requirements**. Live SwiftData storage remains active, cloud activation remains off, and email setup stays pending.

## Plan

1. Project a saved legacy archive into a separate GRDB rehearsal target.
2. Reconcile typed values, totals, relationships, photo bytes and restart/retry behavior.
3. Replace mock generic-food search with a reproducible offline USDA catalog.
4. Review portions and personal macro changes before saving a diary snapshot.
5. Add native/manual barcode capture and a swappable, separately gated lookup adapter.
6. Improve restaurant search and personal menu tooling without importing restricted datasets.
7. Run unit/UI/import/lint checks and review the final diff.
8. Deliver complete source, evidence, limitations and next actions.

## File tree

```text
Caliber (DEV)/
  App/BarcodeLookupCoordinator.swift
  Resources/{FoodCatalog.json,FoodLookupConfiguration.json,ThirdPartyNotices.txt}
  Services/{FoodCatalogTypes,BundledFoodSearchService,FoodNutritionReference}.swift
  Services/{BarcodeService,BarcodeNutritionProduct,BarcodeCaptureService,OpenFoodFactsBarcodeService}.swift
  Services/RestaurantSourceDirectory.swift
  Utilities/BarcodeValue.swift
  Views/Diary/{FoodSearchView,FoodNutritionReviewView,BarcodeFoodLookupView,BarcodeScannerView}.swift
  Views/Restaurants/{RestaurantListView,RestaurantDetailView,AddRestaurantView}.swift
  Views/FoodLibrary/FoodLibraryView.swift
  Views/Foundation/TodayFoundationView.swift
Caliber (DEV)Tests/
  {FoodCatalogTests,ReferenceFoodLoggingTests,BarcodeLookupTests,BarcodeCoordinatorTests,BarcodeValueTests}.swift
  LegacySnapshotTests.swift
Caliber (DEV)UITests/{FoodExperienceUITests,RestaurantCustomizationUITests}.swift
Packages/CaliberFoundation/
  Sources/CaliberDatabase/LegacyNormalizedProjection.swift
  Tests/CaliberDatabaseTests/LegacyNormalizedProjectionTests.swift
scripts/{import_usda_foods,test_import_usda_foods,lint_foundation}.py
docs/{DECISIONS,BACKLOG,CHANGELOG,HOW_WE_CALCULATE,LICENSES,MIGRATIONS,SECURITY}.md
docs/adr/{010-normalized-copy-rehearsal,011-offline-food-and-barcode}.md
```

The source delivery contains complete files, tests and checked-in resources; no executable is required. Xcode's folder synchronization includes the new source/tests/resources automatically. The only project setting change adds the camera usage description to Debug and Release.

## Migrations and data safety

No SwiftData model, live store locator, shared canonical schema resource or hosted SQL changed. A rehearsal-only v4 migration runs exclusively in `normalized-rehearsal-v1/normalized-copy.sqlite` beneath an explicit target directory. One immutable snapshot per target, atomic failure/retry and UUIDv7 mapping preserve exact source evidence. Unrelated existing databases and changed/tampered sources/targets are rejected.

All 15 models have typed reconstruction. Canonical metadata/meal/weight/note/group/photo metadata projections coexist with compatibility tables for arbitrary portion nutrition, exact diary snapshots, quantities, signed modifiers, profiles and unlinked records. Unknown gram weights and historical zones are never invented. The required timezone is explicitly recorded as an assumption. Photos remain original local bytes; encryption, EXIF stripping, biometric protection and portable backup are not established by this rehearsal.

## Verification report

Final results: **74 package functions, 105 app functions + 10 XCTest cases, eight importer tests and five distinct UI tests pass**. The app/Food UI final run is `caliber-food-tests-08`; the unchanged restaurant swipe suite passed in `caliber-food-tests-04`. Strict lint and catalog reproduction pass. Earlier integration runs exposed SwiftUI section declarations, a test macro expression, a hidden search field and a read-only memory fixture problem; fixes precede final evidence.

| Acceptance criterion for this checkpoint | Result / evidence |
| --- | --- |
| Complete reproducible offline food catalog | PASS — 311 USDA Foundation foods, exact pinned archive/resource SHA256 in LICENSES; eight importer tests and `--check` reproduction. |
| Source nutrition remains read-only; personal log editable | PASS — unit tests preserve source/old diary values; UI checks 150g banana portion, personal macro edit and saved confirmation. |
| Invalid/missing nutrition not silently zeroed | PASS — unit/import fixtures cover missing/negative/nonfinite/wrong unit, volume basis and net vs total carbohydrate. |
| Native/manual barcode capture and one validated code | PASS for simulator manual capture/check-digit/review; hardware camera remains UNVERIFIED. |
| Provider/permission gate, minimal requests, cancellation | PASS with fictional fixtures — tests cover disabled configuration, no calls without permission, withdrawal/late result, GTIN equality, bounded parse/throttle and safe errors. No real provider request occurred. |
| Restaurant categories/custom items and eligible doubling | PASS — isolated UI/storage tests; new official menu imports remain pending permission/licensed source. |
| All-model normalized reconciliation and reopen | PASS package suite — all 15 types, 21-record fixture, exact totals, 3 photos/196,612 bytes, failure rollback/retry/reopen and zero migration outbox. Canonical/compatibility counts overlap. |
| Public SwiftData adapter → archive → normalized integration | PASS — app test checks exact all-model recapture, totals, photos, reopened target and unchanged source/archive. |
| Swift type-check, strict lint and diff review | PASS — final Xcode test build, strict formatter, importer tests/reproduction and reviewed diff. |
| Full master Phase-1 acceptance / full P0 Fuel | OPEN — physical/iOS17 runtime/performance/accessibility/vault/CI and broader product requirements remain in BACKLOG. |

## Executed evidence and limits

- Xcode 27, iPhone 17 dedicated **Caliber Account QA** simulator, iOS 27; app deployment target remains iOS17. This does not prove behavior on an iOS17 runtime or physical device.
- `docs/evidence/food-and-normalized/`: full final app/Food UI log, separate passing restaurant suite extract, full package log, importer/reproduction and strict lint/diff evidence. No real product lookup or personal health data was used.
- Package: 3 chart + 32 core + 22 database + 8 integration + 9 seed/calendar functions = **74**. The eight new normalized database cases are included in the 22, not additional.
- App: **105 Swift Testing functions** (including parameterized cases) and **10 XCTest cases** (8 barcode utility + 2 existing template cases), zero failures in the final run. Three Food UI cases pass; two restaurant swipe cases passed separately against unchanged restaurant/builder code.
- Visual review: source-attributed barcode review, personal restaurant entrée and USDA saved confirmation screenshots checked. No new chart was introduced; physical-device chart/performance and full accessibility budgets are still open from Foundation.
- Diagnostics: Xcode skipped AppIntents metadata because the app has no AppIntents dependency. The simulator logged transient invalid-frame warnings when numeric keyboards opened; tested editing and layouts completed successfully, but this warning and camera/keyboard/device behavior remain a follow-up. Existing corrupt-image fixture tests intentionally log thumbnail-decoding errors. No claim of a warning-free runtime is made.
- Initial integration/test-harness failures are fixed; final evidence is distinguished from those earlier attempts. No full release/privacy/legal certification is claimed.

## Run and verify

From the repository root:

```sh
python3 -m unittest discover -s scripts -p 'test_import_usda_foods.py' -v
python3 scripts/import_usda_foods.py --archive /path/to/pinned-foundation.zip --check
python3 scripts/lint_foundation.py
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-package-check
xcodebuild test \
  -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,name=Caliber Account QA' \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 90 -maximum-test-execution-time-allowance 120 \
  '-only-testing:Caliber (DEV)Tests' \
  '-only-testing:Caliber (DEV)UITests/FoodExperienceUITests' \
  '-only-testing:Caliber (DEV)UITests/RestaurantCustomizationUITests' CODE_SIGNING_ALLOWED=NO
```

Select another available iPhone simulator if the QA simulator is absent. Tests use isolated in-memory personal stores and fictional barcode fixtures, with no live product or cloud request. The importer command requires the pinned ZIP; adding `--download` explicitly permits its bounded USDA public download.

In Xcode, open **Caliber (DEV).xcodeproj**, select scheme **Caliber (DEV)** and an iPhone simulator, then **Product → Run (⌘R)**. Tap **Food Library → Search Foods**, search **bananas**, choose the preparation, enter grams, optionally switch on **Adjust macros for this log**, and tap **Add to Diary**. **Food Library → Scan a Barcode** opens camera/manual code tools; online lookup is visibly pending setup. Use **Enter Food from Label** for manual nutrition. **Restaurants → +** creates a personal restaurant; open it and tap **+** for a custom menu item. Swipe custom items left for **Edit/Delete**. Existing Chipotle builders limit double portions to eligible ingredients.

## Remaining setup and recommended next step

Resolve the pending barcode provider/reuse choice and real owner contact/usage setup, then verify an authorized range of real labels in staging before enabling production. Resolve licensed restaurant nutrition coverage before new official menu imports. Meanwhile finish physical-camera/accessibility checks and the structured canonical read-model/private attachment work. Email sender/delivery setup remains deferred. No paid account, personal-data deletion, real diary upload or live migration occurred.
