# Food reuse and portion controls

2026-10-14 · `codex/phase1-foundation` · Incremental local Fuel checkpoint. This does not close all master-brief P0 or Foundation acceptance criteria.

## Plan

1. Derive recent/frequent foods from current diary records.
2. Add bounded, key-only favorites and preserve personal favorites in My Foods.
3. Review grams, weight ounces and source-defined portions without guessed density.
4. Copy a chosen meal/day as independent, selectable food snapshots.
5. Keep the selected diary meal/date throughout each Add route.
6. Verify calculations, failure cleanup, calendars, persistence and simulator interactions.
7. Review the diff and document remaining release/setup gates.
8. Save a phase commit and complete source delivery.

## File tree

```text
Caliber (DEV)/
  App/{FoodLibraryPreferences,FoundationRuntime,BarcodeLookupCoordinator}.swift
  Services/{FoodReuseIndex,FoodReuseUITestFixture}.swift
  Utilities/{DiaryDay,DiaryRepeatLogger,FoodFavoriteEditor,FoodPortionMath}.swift
  Views/Components/MacroOverrideSection.swift
  Views/Diary/{FoodSearchView,FoodNutritionReviewView,CopyDiaryView,DiaryView,BarcodeFoodLookupView}.swift
  Views/MyFoods/{MyFoodsView,SavedFoodDetailView}.swift
  Views/MyMeals/SavedMealDetailView.swift
  Views/Restaurants/{RestaurantListView,RestaurantDetailView,MenuItemDetailView,BuildYourOwnView}.swift
  Views/FoodLibrary/FoodLibraryView.swift
Caliber (DEV)Tests/
  {FoodReuseIndexTests,FoodLibraryPreferencesTests,FoodFavoriteEditorTests}.swift
  {DiaryRepeatLoggerTests,DiaryDayTests,FoodPortionMathTests,BarcodeCoordinatorTests}.swift
Caliber (DEV)UITests/FoodShortcutsUITests.swift
scripts/lint_foundation.py
docs/{DECISIONS,BACKLOG,CHANGELOG,HOW_WE_CALCULATE,MIGRATIONS,SECURITY}.md
docs/adr/012-local-food-reuse.md
```

The delivery ZIP contains complete source files and resources, not snippets. Existing Xcode folder synchronization includes the added files; no manual target membership changes are needed.

## What changed

**Recent / frequent / favorites:** Search Foods now has a Show picker for All Foods, Recent, Frequent and Favorites. The newest logged quantity becomes the default when repeating a food. Exact content grouping keeps independent log copies together while preserving distinct preparations, servings and edited nutrition. A personal star first saves that food to My Foods; removing the star retains the saved food and all logs. Favorites persist only bounded source/content keys.

**Portions:** USDA and explicit-mass barcode references offer g, weight oz and source portions. The source basis remains visible. Unit-only switches preserve exact selected grams and personal edits; typing a different amount resets an override. Unknown-mass references offer their original portion multiplier, with no invented household measures or ml-to-g conversion.

**Copying:** Diary has Copy a Day and a copy action beside each meal. Review defaults to yesterday, lets you choose another day/meal and select individual foods, and shows the full copied nutrition total before saving. Original quantity, nutrition, entry note text and provenance are frozen into independent copies. A successful draft disables another Add/Copy tap. Long-pressing an existing diary food also offers Log Again or Repeat This Meal. Completed same-day reviews retain the original source selection so newly added copies cannot inflate the displayed total.

**Context:** Diary's + opens unified food search for the chosen meal/day. That context is forwarded through catalog, barcode, saved food/meal and restaurant/builder review. Nutrition stays editable before adding. No live provider or menu dataset was enabled.

## Migrations

No persistent SwiftData model/schema, normalized rehearsal schema, live locator, hosted SQL or source dataset changes. All 15 legacy types remain compatible. The only new preference is `food.library.favorites.v1`; original records stay in their existing store. Favorite keys are not included in the legacy model archive, so full preference portability remains open. Copying is an explicit user action, not a migration. DEBUG fixtures require the isolated-memory test runtime and never seed normal launches.

## Tests and verification report

**140 app Swift Testing functions + 10 XCTest cases passed**, including 35 new functions. **Nine distinct UI cases passed.** Final affected runs are `caliber-food-tests-reuse-04.xcresult` (unit and copy checks) and `caliber-food-tests-reuse-03.xcresult` (other shortcuts/portion checks); the five unaffected food/barcode/restaurant UI cases passed in `caliber-food-tests-reuse-01.xcresult`. The recorded runs report TEST SUCCEEDED. Strict lint and whitespace checks pass. Package/schema/importer/backend code is unchanged, so its earlier results are not presented as a new execution here.

| Acceptance criterion for this checkpoint | Result and evidence |
| --- | --- |
| Exact grouping, recency, frequency, newest fractional quantity | PASS — 10 index functions cover variants, cutoff, invalid data, ties, representative selection and limits; repeat UI confirms 0.5 portions and a count of 3 logs. |
| Key-only favorite persistence, bounds and failure behavior | PASS — 5 preference + 3 editor functions check persistence/reopen, corruption/bounds and retained drafts/data; UI covers a personal star, USDA star and subsequent reuse. |
| Explicit mass/portion math and no invented density | PASS — 4 math functions cover 4oz = 113.3980925g, source portions, invalid/overflow/underflow and localized input. UI verifies 2 source portions = 200g and preserves an 800.5kcal personal override after switching units. |
| Reviewed independent copies with exact totals/notes/menu links | PASS — 11 repeat functions cover independence, note/quantity/meal/date, storage failure, provenance resolution, duplicates and invalid/overflow inputs. UI selects 300.75kcal from a 500.75kcal previous-day preview and adds it once to a 100.25kcal day, producing 401kcal. Same-day repeat keeps its completed preview at 100.25kcal while the day becomes 200.5kcal. |
| Calendar-safe previous-day boundaries | PASS — calendar and repeat tests exercise 23h/25h DST transitions without fixed-second subtraction. |
| Selected diary context | PASS — catalog UI confirms Add from Breakfast remains Breakfast. Date/meal forwarding is checked in the initializer diff and exact destination-date unit cases; exhaustive backdated UI coverage for every route remains pending. |
| Existing barcode/menu behavior | PASS — original barcode review, USDA editing, restaurant creation, custom Edit/Delete and eligible Chipotle double/regular UI cases pass. Default online configuration remains pending. |
| Build / type-check / strict lint / diff review | PASS — Xcode test builds, 140+10 app checks, strict formatter and reviewed diff. Existing failed test fixtures intentionally log image-decoding diagnostics. |
| Physical camera, iOS17 runtime, full accessibility and budgets | OPEN — tested on Xcode27 / iOS27 iPhone17 QA simulator. Numeric-keyboard layout warnings remain tracked. Full large-history/device performance, VoiceOver/largest-text, source licensing/setup and protected-vault gates are not closed here. |

Screenshots use fictional test foods and were visually inspected. No new chart or health estimate was introduced. No API key, live product request, hosted change, private-photo upload or irreversible migration occurred.

## Run and verify

From the repository root:

```sh
python3 scripts/lint_foundation.py
xcodebuild test \
  -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,name=Caliber Account QA' \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 90 -maximum-test-execution-time-allowance 120 \
  '-only-testing:Caliber (DEV)Tests' \
  '-only-testing:Caliber (DEV)UITests/FoodShortcutsUITests' \
  '-only-testing:Caliber (DEV)UITests/FoodExperienceUITests' \
  '-only-testing:Caliber (DEV)UITests/RestaurantCustomizationUITests' CODE_SIGNING_ALLOWED=NO
```

Choose another available iPhone simulator if the dedicated QA simulator is absent. UI tests use isolated in-memory stores and explicit fictional fixtures. Evidence logs are in `docs/evidence/food-reuse/`; copied logs normalize trailing whitespace/line endings only.

In Xcode, open **Caliber (DEV).xcodeproj**, choose scheme **Caliber (DEV)** and an iPhone simulator, then **Product → Run (⌘R)**. No manual setup is needed for these local features.

- **Food Library → Search Foods → Show** selects Recent, Frequent or Favorites. Open a result, review its quantity/macros and add it. Swipe a recent/frequent food for Favorite, or tap Favorite Food in its review. USDA review has its own star.
- **Review Food → Portion Unit** selects g, oz or source portions when mass is known. oz is weight, not fluid ounces. The number field remains available; Done closes its keyboard.
- **Diary → Copy a Day**, or the copy icon beside a meal, opens source-date selection and review. Select foods, check destination/date/meal, then Copy Foods. Use Done to return.
- **Diary → + beside a meal** now searches food sources while retaining that meal/date. Long-press an existing row for Log Again or Repeat This Meal. All logged values remain editable through the diary's ordinary edit form.

## Recommended next step

Build the recipe/ingredient and meal-template workflow with explicit yield/serving math and preserved snapshots. Continue physical-device accessibility/camera checks separately. Live barcode source/contact/usage setup, licensed restaurant data and email configuration remain pending the owner's decisions; full P0 delivery is still tracked in BACKLOG.
