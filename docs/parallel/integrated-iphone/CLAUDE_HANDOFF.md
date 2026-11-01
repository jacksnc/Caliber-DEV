# Claude — energy display consistency handoff

Branch: `claude/energy-display`, from the exact seed
`8bb00df5a22dc2c51de45416034fbd9e09201c47` (`origin/codex/integrated-iphone-qa`, which
includes e5aaa04). Fresh separate checkout `/home/user/energy`. Older checkouts were
inspected clean and left untouched: `/home/user/cw` (claude/cards-widgets, 5af0a69),
`/home/user/cdiary`, `/home/user/v2n` and the primary clone. Nothing was merged or rebased.
The delivery commit is the `claude/energy-display` commit that adds this file. Its SHA is
in the thread reply.

## Files
- `Caliber (DEV)/Views/Components/CaliberEnergyDisplay.swift` (new): the display helper.
- `Caliber (DEV)/Views/Diary/DiaryView.swift`: the summary figure, goal, balance, meal
  headings, entry rows and preview environment.
- `Caliber (DEV)/Views/Diary/FoodSearchView.swift`: six food row previews and the preview
  environment.
- `Caliber (DEV)/Views/Diary/CopyDiaryView.swift`: per-food previews and the copy total.
- `Caliber (DEV)Tests/CaliberEnergyDisplayTests.swift` (new).
- `Caliber (DEV)UITests/DiaryEnergyUnitDisplayUITests.swift` (new).
- This file.

Unchanged:
- Stored values, models, the `UnitFormatting` package code and health math.
- `HealthEnergyGoalBreakdown`.
- Settings, runtime, RootTabView, widgets, the project file, existing tests and global
  docs.
- In Diary: the widget-request and navigation-path handling, centred headings, the
  summary swipe gesture, 48pt actions, food routes and number-free mode (which replaces
  the tabs entirely).

## Rationale
`CaliberEnergyDisplay(unit:locale:)` takes canonical kcal and returns text only. It calls
`UnitFormatting.energy` once per figure, so a rounded display figure cannot feed back into
arithmetic. Every total, remaining amount, above-goal amount and ring progress is still
computed in stored kcal, and only the result is converted. Numeric editors, overrides,
label facts and serving inputs do not use the helper.

| Saved unit | Figure | Short label (rows) | In a sentence | VoiceOver |
|---|---|---|---|---|
| kcal | exact recorded value, `NutritionInput.format` ("100.25", "1462") | kcal | calories | calories |
| kJ | `UnitFormatting.number`, at most 1 decimal ("419.4", "6,117") | kJ | kJ | kilojoules |

- **kcal sentences say "calories".** Existing tests I may not edit lock that wording:
  - `diaryCalories` "1462 calories"
  - "of 2350 calories"
  - `copyCalories` "1 food · 100.25 calories"
  - The meal header containing "420 cal"

  Compact row labels changed from the ambiguous "cal" to "kcal".
- **kcal figures stay exact and ungrouped,** as before ("2350.25"). Grouping or
  rounding them would change recorded fractional kcal and break existing assertions.
- **kJ is a derived conversion,** so it shows at most one decimal, grouped by locale.
  Exact digits such as 419.446 would imply false precision.

Visible changes in kcal mode:
- Entry rows and food search and copy row labels read "kcal" instead of "cal".
- Meal headings read "· 420 calories" instead of "· 420 cal".

Everything else in kcal mode is the same text as before.

## Tests (written, not run: no Swift toolchain in the cloud)
- `CaliberEnergyDisplayTests` (Swift Testing):
  - Exact kcal figures (100.25, 150.375, 1462, 0), including de_DE "100,25".
  - kJ conversion: 419.4, 6,117, 9,832.4, de_DE "419,4" and "6.117". It also checks
    the helper's output matches calling `UnitFormatting` directly.
  - Summing before display: three 0.04 kcal rows each show "0.2" kJ, while the total
    shows "0.5" kJ, not 0.6.
  - The Diary balance is computed in kcal first: 888 kcal left shows as 3,715.4 kJ, and
    0.25 kcal over shows as "0.25" in kcal or "1" in kJ.
  - Copy, search and heading strings come from `DiaryRepeatLogger.preview` and
    `MacroCalculator`. Stored values are preserved: food 200.5, portions 0.5 and 1.25,
    entries 100.25 and 250.625, total 350.875 and preview equality.
- `DiaryEnergyUnitDisplayUITests` (isolated showcase store and UI-test defaults):
  1. In kcal, it expects "1462 calories" and "of 2350 calories".
  2. It switches to kJ through Settings, then expects:
     - "6,117 kilojoules" and "of 9,832.4 kJ".
     - The balance "3,715.4 … kJ remaining".
     - The meal header and row in kJ, with no " cal" left.
     - The copy total ending in " kJ".
     - Food search rows in kJ, with no " cal".
  3. It switches back to kcal and expects "1462 calories" again, with rows in kcal.

  It takes full-screen captures.

## Checks run in the cloud (Linux; no Xcode, Swift or xcrun)
- `python3 scripts/lint_dynamic_type.py`: 242 files, 0 errors, 0 warnings.
- `python3 scripts/check_tokens.py`: PASS (54 pairs, minimum 5.94:1, 48pt targets).
- `python3 scripts/gen_tokens.py --check`: up to date.
- `python3 -m unittest discover -s scripts -p 'test_*.py'`: 135 tests OK.
- I hand-checked the 100-column limit on added lines. Over-long detail strings that
  predate this change remain.
- `python3 scripts/lint_foundation.py`: **not run** (it fails because `xcrun` is
  missing).
- No compile, package tests or Xcode tests were run.

## UNTESTED: commands for Codex
```sh
xcodebuild test -project "Caliber (DEV).xcodeproj" -scheme "Caliber (DEV)" \
  -destination "id=2998CE67-7D71-460B-AD69-76DAA4D014F6" -derivedDataPath <private> \
  -only-testing:"Caliber (DEV)Tests/CaliberEnergyDisplayTests" \
  -only-testing:"Caliber (DEV)UITests/DiaryEnergyUnitDisplayUITests" \
  -only-testing:"Caliber (DEV)UITests/DiaryV2UITests" \
  -only-testing:"Caliber (DEV)UITests/DiaryMealHeaderUITests" \
  -only-testing:"Caliber (DEV)UITests/FoodShortcutsUITests" \
  -only-testing:"Caliber (DEV)UITests/FoodEntryPass2UITests" \
  -only-testing:"Caliber (DEV)UITests/HealthEnergyUITests" \
  -only-testing:"Caliber (DEV)UITests/WidgetRoutingUITests" \
  -only-testing:"Caliber (DEV)UITests/ResponsiveLayoutUITests"
python3 scripts/lint_foundation.py
```

## Risks and limitations
- **Not compiled.** One construct to watch: the `switch` expressions that now return a
  ternary of `LocalizedStringKey` literals (`remainingLabel` and `aboveGoalLabel`).
- **The UI test's Settings step is a guess.** It finds the Energy picker by a label
  beginning with "Energy" and taps a menu option named "kJ". If the Form renders the
  picker differently, only that step needs adjusting. It is my file, so no existing test
  is affected.
- **Previews:** the DiaryView and FoodSearchView previews now inject
  `FoundationRuntime(previewing: true)`, and DiaryView also gets its `healthEnergy`.
  Before, the Diary preview lacked HealthEnergyModel.
- **"Calories" stays in kJ mode** as the summary metric title, matching the Today card.
- **Non-finite values:** kcal returns "" (from `NutritionInput.format`) and kJ returns
  "—" (from `UnitFormatting.number`). These cannot occur from validated input.
- **Floating-point noise:** a product such as `saved.calories * quantity` can show
  binary noise in kcal, because `NutritionInput.format` uses `String(Double)`. This
  predates the change.

## Cross-boundary needs for Codex
- **Settings wording** (yours): "Hide Calories and Weight", the widget copy, and the Energy
  picker's footnote.
- **HealthEnergySettingsView** (lines 32, 43, 62 and 76) is kcal-only on purpose, for the
  Health allowance. It needs a decision.

## Energy displays still outside my scope (source search at the seed)
- My Foods: `Views/MyFoods/MyFoodsView.swift:116` ("cal").
- My Meals: `MyMealsView.swift:49` ("cal per serving"), `SavedMealDetailView.swift:58`,
  `RecipeEditorView.swift:101,106` and `RecipeIngredientPicker.swift:443` ("calories").
- Diary sheets I do not own: `AddFoodView.swift:203`, `EditDiaryEntryView.swift:95` and
  `FoodEntryPass2Components.swift:847` (review totals, "calories").
- Reference surfaces: the shared `caloriesIdentifier` component behind
  `savedFoodCalories` and `referenceCalories` (`SavedFoodDetailView`,
  `FoodNutritionReviewView`).
- Label and barcode surfaces: `BarcodeFoodLookupView.swift:52` and
  `LabelScannerView.swift:100`. These show label facts in kcal and may rightly stay kcal.
- Restaurant: `RestaurantFitCard` copy.
- Goal setup and Profile (`GoalSetupSummary`, `GoalSetupView`, `ProfileView`) are kcal
  editors and floors, and are deliberately kcal.
- Widgets: snapshots are kcal by design.
- Today and Progress already honour the unit.
