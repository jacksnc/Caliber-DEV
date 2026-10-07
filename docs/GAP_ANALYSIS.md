# Current app audit

Audited 2026-10-07 from the local working tree, including existing staged and untracked files. The README-only remote assumption in the brief does not describe this checkout. Local Git started at `main`, commit `0a75d86`, with no configured remote and substantial owner work in progress. The requested phase branch preserves that work. The separate peptide tracker mentioned in the brief is **not present in the inspected tree**; this audit does not claim it does not exist elsewhere.

## Source evidence

| Area | Observed source / current capability | Gap against the master brief |
|---|---|---|
| App | `Caliber (DEV)/App/Caliber__DEV_App.swift`, `Views/RootTabView.swift`; native SwiftUI, 15 registered SwiftData models; Diary/Add/Food Library/Progress/Profile tabs | Today/Train/Fuel/Stack navigation, configurable modules, Quick Log, adult gates, i18n, design system and operational Profile not implemented |
| Food | `Models/{FoodItem,DiaryEntry,Restaurant,MenuItem,MenuItemModifier}.swift`, `Views/Diary/`, `Utilities/{NutritionInput,MacroCalculator,DiaryEntryEditor}.swift` | Working manual entry, macro snapshots/editing and totals are a foundation; no full canonical nutrient/serving/source/recipe/target/coverage pipeline |
| Restaurants | `Views/Restaurants/`, `Services/RestaurantCatalogSeeder.swift`, `ViewModels/BuildYourOwnViewModel.swift` | Sample catalogs/buildable Chipotle ingredients and custom menu actions exist; source freshness/licensing and production database coverage need review; not a licensed chain-food integration |
| Service seams | `Services/{FoodSearchService,BarcodeService,AIScannerService,RestaurantLibraryService}.swift` | Swap-friendly protocols exist; barcode and AI are interfaces, not operational scanner/backend features; offline search is not the complete multi-source search pipeline |
| Meals | `Models/{SavedMeal,SavedMealItem}.swift`, `Views/MyMeals/` | Model/detail foundation exists; create-meal flow is missing; recipes, day cloning, planned/eaten semantics and advanced measures are not complete |
| Body | `Models/{WeightEntry,ProgressEntry,ProgressPhoto}.swift`, `Views/Progress/` | Daily optional weight/notes/photos, month timeline, editing/deletion and graph work. Weight storage is pounds/Double; no EWMA, measurement system, goals/projections, Health sync, photo vault or safety modes |
| Chart | `Views/Progress/WeightTrendChart.swift`, `Utilities/WeightProgressSummary.swift` | A raw weight line and first-to-latest change; lacks the common range/method/coverage/accessibility-table/export/insight contract and unified timeline |
| Train | No workout/exercise/routine/program/set models or screens in inventory | Entire training module, math/PR/volume/schedule/plate engines and live logging flows remain to build |
| Stack | No protocol/dose/vial/calculator store or module in inventory | Isolated store, gating, schedules, calculator, private reports and clinical/policy review are all future work |
| Platform | No HealthKit/auth/sync/local SQL migrations/CI/package manifest/localized-string catalog found | Account/RLS/sync conflicts, durable outbox, export/import/delete, settings, private storage and operational monitoring need implementation |
| Tests/build | App + unit + UI-test targets; `Caliber (DEV)Tests/` and `Caliber (DEV)UITests/ProgressUITests.swift` | Current relevant suite passes; no evidence yet for master-brief core branch coverage, all-chart snapshots, 12-month demo, physical-device performance or release compliance |

Source inventory hashes and line counts are in `architecture/source-inventory.json` (67 Swift/project files, 6,582 lines). This is evidence for the audited source version, not a remote-repository audit. Current deployment target is iOS 27.0, Swift language setting 5.0, on Xcode 27.0; the owner's original iOS17+ target requires a compatibility pass before changing it.

## Preserve and evolve

1. Preserve current screens, calculation helpers, service protocols and user logs. Introduce repository adapters beneath one feature at a time.
2. Keep diary nutrition snapshots independent of mutable menu data; preserve custom items and supported-double ingredient rules during migration.
3. Copy legacy UUIDv4 IDs through an explicit stable v7 map and preserve entered lb values. Never reinterpret pounds as kilograms or open SwiftData's private SQLite directly.
4. Preserve photos/order and standalone old weights. Migration must reopen a fresh store, reconcile hashes/counts/relationships, and pass failure recovery before switching the active store.
5. Redesign navigation after feature boundaries and safety gates exist; do not replace working logging flows with placeholders to match the new tab names.

No complete numbered master-brief requirement is asserted solely from a partial prototype. `architecture/requirements.json` records partial/not-implemented/backlog status separately from proposed acceptance tests.

## Executed baseline

The current iOS app built and the targeted baseline passed: 59 Swift Testing cases, two existing XCTest cases, and two Progress UI tests (63 total), simulator iPhone17/iOS27.0. Full command and output evidence are in VERIFICATION.md. Restaurant UI flows were not re-executed in this phase. No future Train/Stack engine is covered by this count.
