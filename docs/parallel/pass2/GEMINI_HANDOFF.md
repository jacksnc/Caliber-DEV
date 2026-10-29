# Gemini handoff — Pass 2 faster food-entry workspace

- **Status**: Complete & isolated QA verified — ready for Codex merge into `codex/pass2-integration`
- **Branch**: `gemini/food-entry-pass-2` (unmerged stream from common base `96e8068`, per ownership rules)
- **Common base commit**: `96e8068` (`docs: assign the second visual and feature implementation pass`)
- **Implementation commits**:
  - `4457beb` (`4457beb210063f38acf51b1a3e7f38298a3d0e2f` — `feat(fuel): refine food-entry workspace and quick portion review`)
  - `78a189d` (`78a189db67d6991d406f25d042c86680cd21d7ec` — `fix(fuel): distinguish past/today/future logging dates and recipe form spacing`)
  - Followed by the final handoff update commit (`docs(pass2): record isolated Caliber Food Entry QA verification`) at branch `HEAD`
- **Dedicated QA simulator**: **Caliber Food Entry QA** (`4387978B-A0DF-4A04-9525-19805A4340E0`, `iPhone 17`, iOS 27.0)
- **Compare / PR URL**: `https://github.com/jacksnc/Caliber-DEV/compare/codex/pass2-integration...gemini/food-entry-pass-2`
- **Assignment & ownership rules**: [GEMINI_TASK.md](GEMINI_TASK.md), [README.md](README.md), [BASELINE_VERIFICATION.md](BASELINE_VERIFICATION.md)

---

## Scope & owned files changed

All changes stay strictly inside Gemini's owned paths in [README.md](README.md). Zero edits were made to `Models/*`, `App/*`, `Views/RootTabView.swift`, `Views/Diary/DiaryView.swift`, scanner/label/photo internals, restaurants, `Packages/HeliosDesign/*`, `design/tokens.json`, `*.pbxproj`, localization catalogs, CI workflows, scripts, existing test files, or shared planning docs.

### Added (`FoodEntryPass2*`)
- `Caliber (DEV)/Views/Diary/FoodEntryPass2Components.swift` — Helios food-entry hub header/shortcut card (`FoodEntryPass2HubCard`), past/today/future calendar relation & context formatter (`FoodEntryPass2DateRelation`, `FoodEntryPass2ContextFormatter`), sibling `.borderless` quick-review action button (`FoodEntryPass2QuickReviewButton`), modal quick-review container (`FoodEntryPass2QuickReviewSheet`), semantic macro tile strip (`FoodEntryPass2MacroSummaryRow`), actionable empty/no-results recovery card (`FoodEntryPass2EmptyStateCard`), atomic manual-prefill sheet request (`FoodEntryPass2ManualRequest`), and pure manual draft/logger (`FoodEntryPass2ManualDraft`, `FoodEntryPass2ManualLogger`).
- `Caliber (DEV)Tests/FoodEntryPass2Tests.swift` — 5 Swift Testing unit tests covering manual draft macro validation (never inventing `0 g`), comma-locale decimal parsing, backdated meal/library persistence plus failed-save rollback, past/today/future date classification (`"Past date"` vs `nil` vs `"Future date"`), and cross-timezone `Calendar`/`TimeZone` formatting + future `DiaryEntry` retention.
- `Caliber (DEV)UITests/FoodEntryPass2UITests.swift` — 4 XCUITest end-to-end and accessibility-audit suites covering recent quick-review (`+`) prefill/cancel/macro-override/post-log editing, backdated meal propagation across no-results manual entry and recipes without inventing zero macros, future-date logging context (`"Future date"` shown, `"Past date"` absent, exact meal & future day retained), and Graphite/Frost/AX5 (`UICTContentSizeCategoryAccessibilityXXXL`) repeated accessibility audits with named screenshot attachments.

### Modified (owned views & handoff only)
- `Caliber (DEV)/Views/Diary/FoodSearchView.swift`
- `Caliber (DEV)/Views/Diary/AddFoodView.swift`
- `Caliber (DEV)/Views/Diary/FoodNutritionReviewView.swift`
- `Caliber (DEV)/Views/MyFoods/MyFoodsView.swift`
- `Caliber (DEV)/Views/MyFoods/SavedFoodDetailView.swift`
- `Caliber (DEV)/Views/MyMeals/MyMealsView.swift`
- `Caliber (DEV)/Views/MyMeals/SavedMealDetailView.swift`
- `Caliber (DEV)/Views/MyMeals/RecipeIngredientPicker.swift`
- `docs/parallel/pass2/GEMINI_HANDOFF.md`

---

## Delivered behavior & follow-up fixes

1. **Unified native food-entry hub & past/today/future date distinction (`FoodSearchView(mealType:date:)`)**:
   - Displays the active logging destination (`Meal · Today` / `Yesterday` / `Tomorrow` / explicit abbreviated date, `foodEntryContextSummary`) evaluated strictly in the app's injected `Calendar` and `calendar.timeZone` (`Date.FormatStyle(..., locale: locale, calendar: calendar, timeZone: calendar.timeZone)`).
   - Explicitly classifies `date` via `FoodEntryPass2ContextFormatter.dateRelation(for:referenceDate:calendar:)` into `.past`, `.today`, or `.future`:
     - `.past` renders `StatusBadge(.warning, "Past date")`.
     - `.today` renders no off-day badge.
     - `.future` renders a distinct accented `"Future date"` badge (`calendar.badge.clock`) and **never** labels a future logging date `"Past date"`, while retaining the exact selected `mealType` and `date` through every route and logged `DiaryEntry`.
   - Consolidates capture and creation shortcuts into a responsive 2×2 Helios grid (`openBarcode` -> `BarcodeFoodLookupView`, `openLabelScan` -> `LabelScannerView`, `openPhotoEstimate` -> `PhotoEstimateView`, `foodSearchManual` -> `AddFoodView`) and a 3-item library strip (`foodEntryOpenMyFoods` -> `MyFoodsView`, `foodEntryOpenMyMeals` -> `MyMealsView`, `foodEntryOpenRestaurants` -> `RestaurantListView`) that collapses cleanly to vertical stacks at accessibility Dynamic Type sizes.
   - Preserves typed queries across scope switches (`foodSearchScope`: `All Foods`, `Recent`, `Frequent`, `Favorites`) while keeping typed multi-item lists (`"2 eggs, a banana"`), offline USDA matches, personal foods, saved recipes/meals, and restaurant items/builders reachable.
   - Provides actionable empty/no-results recovery (`FoodEntryPass2EmptyStateCard`) with one-tap `"Search All Foods"` (`foodSearchResetScope`) when filtered and `"Enter \"<query>\" Manually"` (`foodSearchCreateFromQuery`) prefilled via atomic `.sheet(item:)` state.

2. **Top-positioned recents & sibling quick-review action (`+`)**:
   - Orders `Recent Foods` directly at the top of browse results (above `Favorites`, `My Foods`, `My Meals`, `Frequent Foods`, and `Restaurants`).
   - Attaches a sibling `.buttonStyle(.borderless)` `+` quick action (`FoodEntryPass2QuickReviewButton`, `foodEntryQuickReview-<rowId>`) alongside `NavigationLink` rows so existing row IDs (`recent-*`, `frequent-*`, `favorite-*`, `catalogFood-*`, `listMatch-*`, `savedRecipe-*`) remain directly on the navigation elements without nested button conflicts or inaccessible wrappers.
   - Tapping `+` opens `FoodEntryPass2QuickReviewSheet` presenting the existing editable review screen (`SavedFoodDetailView`, `FoodNutritionReviewView`, or `SavedMealDetailView`) prefilled with the last-used quantity, `mealType`, and `date`. Confirming writes the same independent `FoodItem` + `DiaryEntry` snapshot; canceling writes nothing; personal macro overrides never mutate source library or USDA reference records; and logged diary snapshots remain editable via `EditDiaryEntryView`.

3. **Meal & date propagation, navigation-bar visibility & recipe manual-ingredient keyboard clearance**:
   - Threads `mealType` and `date` through Barcode, Label Scan, Photo Estimate, Manual Entry, `MyFoodsView(mealType:date:)` -> `SavedFoodDetailView` / `AddFoodView`, and `MyMealsView(mealType:date:)` -> `SavedMealDetailView`.
   - Applies `.toolbar(.visible, for: .navigationBar)` on `FoodSearchView`, `FoodNutritionReviewView`, `MyFoodsView`, `SavedFoodDetailView`, `MyMealsView`, and `SavedMealDetailView` so views pushed onto `DiaryView`'s `NavigationStack` (where `DiaryView` hides its bar via `.compactNavigationTitle("Fuel")`) always retain their Back button and toolbar actions (`createRecipe`, `Add to Diary`, etc.).
   - Tightens `RecipeManualIngredientForm` top/section spacing and disables QuickType autocorrection on ingredient name/portion inputs in `RecipeIngredientPicker.swift` so `recipeIngredientCalories` stays clear of the keyboard accessory bar on fresh simulator boots while keeping `48pt` minimum field heights.

4. **Compact manual entry without invented zero macros (`AddFoodView`)**:
   - Backed by `FoodEntryPass2ManualDraft` and `FoodEntryPass2ManualLogger`. Removes the old `protein.isEmpty ? "0" : protein` fallback so blank macro fields never silently become `0 g` or create calorie-only semantics: all four nonnegative values (`Calories`, `Protein`, `Carbs`, `Fat`) are required, while explicit `"0"` remains valid when a macro is genuinely `0 g`.
   - Preserves serving description, decimal/comma-locale quantity scaling, optional `"Save to My Foods"`, live scaled macro preview (`manualFoodTotalCalories` + `FoodEntryPass2MacroSummaryRow`), clean cancellation (`manualFoodCancel`), failed-save cleanup, and label-scan prefill compatibility (`app.textFields["Calories"]`).
   - Uses concise single-line `TextField` placeholders paired with multi-line caption labels and moves `Save` / `Cancel` into a scalable `.safeAreaInset(edge: .bottom)` bar when `typeSize.isAccessibilitySize` (matching `ProfileView`) so AX5 `UICTContentSizeCategoryAccessibilityXXXL` audits pass with zero `.textClipped` or `.dynamicType` issues.

---

## Smallest follow-up contract for a future shared multi-food draft & Codex hooks

Per [GEMINI_TASK.md](GEMINI_TASK.md) item 5, no multi-food transaction/cart UI or placeholder state is shipped in this PR. When ready to add multi-item staging across search, recents, barcode, and recipes without changing SwiftData models or nutrition integrity rules, the minimal contract is:

```swift
/// Value-type source payload for one staged diary item; never mutates reference records.
enum FoodDraftSource: Sendable {
  case reference(FoodNutritionReference, portion: ResolvedFoodPortion, saveToLibrary: Bool)
  case savedFoodSnapshot(
    name: String,
    servingDescription: String,
    basePerServing: MacroTotals,
    quantity: Double,
    sourceType: FoodSourceType,
    menuItemID: UUID?
  )
  case savedMealPortion(
    mealID: UUID,
    portionUnit: RecipePortionUnit,
    portionAmount: Double
  )
  case manual(
    name: String,
    servingDescription: String,
    perServing: MacroTotals,
    quantity: Double,
    saveToLibrary: Bool
  )
}

struct FoodDraftEntry: Identifiable, Sendable {
  let id: UUID
  var source: FoodDraftSource
  /// Optional per-log complete 4-macro override (never partial/calorie-only).
  var macroOverride: MacroTotals?
}

@MainActor
final class FoodEntryDraftSession: ObservableObject {
  @Published var mealType: MealType
  @Published var date: Date
  @Published private(set) var entries: [FoodDraftEntry] = []

  /// Commits all staged entries atomically in one `ModelContext` transaction by
  /// delegating to `ReferenceFoodLogger`, `RecipeLogger`, and `FoodEntryPass2ManualLogger`
  /// (rolling back inserted `FoodItem` / `DiaryEntry` rows on save error).
  func commitAll(in context: ModelContext) throws
}
```

### Optional Codex-owned integration hooks observed
1. **`Views/RootTabView.swift:60` (Quick Log food sheet)**: Quick Log currently presents `NavigationStack { FoodSearchView() }` with default `mealType: .snack` and `date: .now`. If desired during integration, Codex can pass the active diary `selectedDate` (or an inferred meal for the current time of day) into `FoodSearchView(mealType:date:)`.
2. **`Views/RootTabView.swift` (`CaliberTabBar` re-tap pop-to-root) & legacy UI tests outside `scripts/test_ios.py`**:
   - Re-tapping the already-selected `Fuel` tab in `CaliberTabBar` sets `selection = .fuel` without popping `DiaryView`'s `NavigationStack`. Two older UI test files not listed in `scripts/test_ios.py` (`FoodShortcutsUITests.swift:91,218` and `FoodExperienceUITests.swift:177,195`) tap `app.tab("Fuel")` expecting pop-to-root after pushing from `FoodLibraryView`.
   - `FoodShortcutsUITests.swift:19` also reads `app.navigationBars.firstMatch.frame` unconditionally on `DiaryView`, which hides its `UINavigationBar` via `.compactNavigationTitle("Fuel")`.

---

## Screenshots & accessibility audit evidence (isolated QA simulator)

Recorded in `/tmp/caliber-food-entry-pass2-qa-4387978B.xcresult` on **Caliber Food Entry QA** (`4387978B-A0DF-4A04-9525-19805A4340E0`, `iPhone 17`, iOS 27.0) with `XCUIApplication.auditRepeatedIssues` running `.textClipped` at default size and `[.dynamicType, .textClipped]` at AX5 `UICTContentSizeCategoryAccessibilityXXXL` (no audits weakened):

### Pass 2 workspace attachments (`FoodEntryPass2UITests`)
- `pass2-food-hub-graphite-default` — `FoodSearchView` hub in Graphite (default Dynamic Type)
- `pass2-manual-entry-graphite-default` — `AddFoodView` in Graphite (default Dynamic Type)
- `pass2-quick-review-graphite-default` — `FoodEntryPass2QuickReviewSheet` (`SavedFoodDetailView`) in Graphite (default Dynamic Type)
- `pass2-food-hub-frost-default` — `FoodSearchView` hub in Frost (default Dynamic Type)
- `pass2-manual-entry-frost-default` — `AddFoodView` in Frost (default Dynamic Type)
- `pass2-quick-review-frost-default` — `FoodEntryPass2QuickReviewSheet` (`SavedFoodDetailView`) in Frost (default Dynamic Type)
- `pass2-food-hub-graphite-AX5` — `FoodSearchView` hub in Graphite at `UICTContentSizeCategoryAccessibilityXXXL`
- `pass2-manual-entry-graphite-AX5` — `AddFoodView` (with scalable bottom action bar) in Graphite at `UICTContentSizeCategoryAccessibilityXXXL`

### Scanner, portion-review, restaurant & lookbook attachments verified in the same QA bundle
- `Fictional barcode product review`
- `Fictional imported menu reviewed and logged`
- `USDA food logged with personal macros`
- `graphite-LabelScan`
- `graphite-PhotoEstimate`
- `graphite-ScanResult`
- `graphite-SmartSearch`
- `graphite-Scanner-AX5`
- `graphite-ScannerModes`

---

## Exact verification commands & test results

### Static checks (all PASSED)
```sh
xcrun swift-format lint --strict \
  "Caliber (DEV)/Views/Diary/FoodEntryPass2Components.swift" \
  "Caliber (DEV)/Views/Diary/FoodSearchView.swift" \
  "Caliber (DEV)/Views/Diary/AddFoodView.swift" \
  "Caliber (DEV)/Views/Diary/FoodNutritionReviewView.swift" \
  "Caliber (DEV)/Views/MyFoods/MyFoodsView.swift" \
  "Caliber (DEV)/Views/MyFoods/SavedFoodDetailView.swift" \
  "Caliber (DEV)/Views/MyMeals/MyMealsView.swift" \
  "Caliber (DEV)/Views/MyMeals/SavedMealDetailView.swift" \
  "Caliber (DEV)/Views/MyMeals/RecipeIngredientPicker.swift" \
  "Caliber (DEV)Tests/FoodEntryPass2Tests.swift" \
  "Caliber (DEV)UITests/FoodEntryPass2UITests.swift"
# Exit 0 (0 warnings, 0 errors)

python3 scripts/lint_foundation.py
# Exit 0

python3 scripts/lint_dynamic_type.py --strict "Caliber (DEV)" Packages
# Exit 0: "dynamic type lint: 206 files, 0 errors, 0 warnings"

python3 scripts/gen_tokens.py --check
# Exit 0: "design tokens are up to date"

python3 scripts/check_lookbook.py
# Exit 0: "look book: 0 problems"

python3 scripts/verify_phase1.py
# Exit 0: "PASS: 117 local Markdown file links resolve." / "PASS: Foundation bundle consistency, pure-core boundary and closed diagnostics."
```

### Isolated native unit & UI verification (`Caliber Food Entry QA` — `4387978B-A0DF-4A04-9525-19805A4340E0`)

Executed strictly on `4387978B-A0DF-4A04-9525-19805A4340E0` (`Caliber Food Entry QA`, `iPhone 17`, iOS 27.0) with isolated in-memory stores/preferences (`--progress-ui-testing`); neither the owner's ordinary `iPhone 17` (`384D80B9-60DE-4538-B135-00D31BB69D2E`) nor Codex's `Caliber Lookbook QA` (`60A77BA7-5A23-4A5B-8405-B089F66D6B9F`) was touched:

```sh
xcodebuild test \
  -project "Caliber (DEV).xcodeproj" \
  -scheme "Caliber (DEV)" \
  -destination "platform=iOS Simulator,id=4387978B-A0DF-4A04-9525-19805A4340E0" \
  -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -resultBundlePath /tmp/caliber-food-entry-pass2-qa-4387978B.xcresult \
  -only-testing:"Caliber (DEV)Tests" \
  -only-testing:"Caliber (DEV)UITests/FoodEntryPass2UITests" \
  -only-testing:"Caliber (DEV)UITests/RecipeBuilderUITests" \
  -only-testing:"Caliber (DEV)UITests/FoodExperienceUITests/testOfflineFoodPortionAndPersonalMacroEditCanBeLogged" \
  -only-testing:"Caliber (DEV)UITests/FoodExperienceUITests/testBarcodeManualCaptureConsentAndFictionalProductReview" \
  -only-testing:"Caliber (DEV)UITests/FoodExperienceUITests/testImportedFictionalMenuUsesCategoriesAndPersonalReview" \
  -only-testing:"Caliber (DEV)UITests/ThemeIntegrationUITests/testGraphiteSmartSearch" \
  -only-testing:"Caliber (DEV)UITests/ThemeIntegrationUITests/testGraphiteLabelScan" \
  -only-testing:"Caliber (DEV)UITests/ThemeIntegrationUITests/testGraphiteScanResult" \
  -only-testing:"Caliber (DEV)UITests/ThemeIntegrationUITests/testGraphitePhotoEstimate" \
  -only-testing:"Caliber (DEV)UITests/ThemeIntegrationUITests/testScannerModeSwitcherOpensLabelScan" \
  -only-testing:"Caliber (DEV)UITests/ThemeIntegrationUITests/testScannerLargestTextLayout" \
  CODE_SIGNING_ALLOWED=NO
```

**Result: `** TEST SUCCEEDED **` (exit code `0`)**
- **`Caliber (DEV)Tests`**: **220 Swift Testing tests in 23 suites + XCTest unit suites PASSED** (`4.884s`), including all 5 `FoodEntryPass2Tests` cases.
- **`FoodEntryPass2UITests` (4/4 PASSED)**:
  - `testBackdatedMealCarriesThroughNoResultsManualEntryAndRecipesWithoutInventingZeroMacros` — **PASSED** (`72.060s`)
  - `testFutureLoggingDateShowsFutureBadgeNeverPastDateAndRetainsSelectedMealAndDay` — **PASSED** (`29.460s`)
  - `testGraphiteFrostAndLargestTextAuditsOnFoodEntryWorkspace` — **PASSED** (`73.034s`)
  - `testRecentQuickActionPrefillsLastPortionCancelsCleanlyAndKeepsLoggedSnapshotEditable` — **PASSED** (`47.574s`)
- **`FoodExperienceUITests` (3/3 PASSED)**:
  - `testBarcodeManualCaptureConsentAndFictionalProductReview` — **PASSED** (`28.296s`)
  - `testImportedFictionalMenuUsesCategoriesAndPersonalReview` — **PASSED** (`19.906s`)
  - `testOfflineFoodPortionAndPersonalMacroEditCanBeLogged` — **PASSED** (`55.099s`)
- **`RecipeBuilderUITests` (1/1 PASSED)**:
  - `testCreateMeasuredRecipeAndLogOneCookedPortion` — **PASSED** (`65.155s`)
- **`ThemeIntegrationUITests` (6/6 PASSED)**:
  - `testGraphiteLabelScan` — **PASSED** (`18.311s`)
  - `testGraphitePhotoEstimate` — **PASSED** (`18.285s`)
  - `testGraphiteScanResult` — **PASSED** (`24.820s`)
  - `testGraphiteSmartSearch` — **PASSED** (`14.372s`)
  - `testScannerLargestTextLayout` — **PASSED** (`13.347s`)
  - `testScannerModeSwitcherOpensLabelScan` — **PASSED** (`15.775s`)

---

## Migrations & schema impact

- **None.** No SwiftData `@Model` definitions, migration stages, feature flags (`FUEL-13` remains off), online providers, or bundled nutrition datasets were added or modified.

---

## Remaining limits

- **Physical camera & device checks (`UNTESTED` on simulator)**: Live `AVCaptureSession` camera capture for barcode, nutrition-label OCR, and photo meal estimation requires a physical iPhone (simulator fixture/sample routes were verified on `4387978B-A0DF-4A04-9525-19805A4340E0`). Minimum-supported-iOS physical-device execution also remains to be run on hardware.
- **Intentionally out of scope for Pass 2**: Multi-food batch staging cart (contract documented above), voice food logging (`FUEL-13`), new online food providers, and external recipe discovery/import.
