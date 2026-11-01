# Gemini Handoff — Cards and Widgets

**Date:** 2026-11-01  
**Author:** Gemini (owner Mac)  
**Branch:** `gemini/cards-widgets`  
**Base Seed:** `300388e6ce5baed6ca9ab265af3d863c84338903`  
**Cherry-Pick:** `9eb6fdd1e81ff8ef48d0f594ddf01a64eda2b02d` (`feat(widgets): define private expiring nutrition snapshots`)  

---

## 1. Owned Deliverables

| File | Purpose |
| :--- | :--- |
| `CaliberWidgets/NutritionWidgetView.swift` | Native Lookbook V2 WidgetKit view supporting `.systemSmall` and `.systemMedium`. Uses recorded kcal without invented goal rings; renders neutral states with no numbers for `.private`, `.stale`, or `.unavailable`. |
| `CaliberWidgets/WidgetPreviewFixtures.swift` | Explicitly fictional mock snapshots for WidgetKit previews, covering current populated, all-zero current, private (sharing off), stale (expired), and unavailable states. |
| `docs/parallel/cards-widgets/GEMINI_HANDOFF.md` | Role handoff, verification records, known gaps, and five ranked independent app findings. |

---

## 2. Widget View Design & Contract Implementation

### Appearance & Theming
- **Dynamic Helios Palette:** Resolves `HeliosPalette.palette(dark:increasedContrast:)` based on `@Environment(\.colorScheme)` and `@Environment(\.colorSchemeContrast)`.
  - Dark mode -> Graphite opaque surface (`#212327`) with hairline/strong border.
  - Light mode -> Frost opaque surface (`#F4F8FD`) with hairline/strong border.
- **Series Color Accents:** Uses semantic data tokens from `palette.data`:
  - Energy: `palette.data.energy.color`
  - Protein: `palette.data.protein.color`
  - Carbs: `palette.data.carbs.color`
  - Fat: `palette.data.fat.color`
- **Zero Invented Math:** Displays recorded kcal directly (`nutrition.calories`), never macro-derived estimates. No daily goal rings or progress bars are rendered (v1 snapshot carries no goals).

### State Handling & Exact Wording
- **`.current` with Positive Totals:** Displays recorded calories (e.g., `1,420 cal`) and compact macro pills/rows.
- **`.current` with All-Zero Totals:** Displays `0 cal` labeled explicitly as `"0 calories logged"`, not inferred empty.
- **`.private` (Sharing Off):** Means sharing is turned off in Settings, not device locked. Displays `"Sharing is Off"`, detail `"Choose what to show in Settings."`, and action `"Open Caliber"`. Never displays `"Unlock to view"`.
- **`.stale` (Past 2-Hour or Day Expiry):** Displays `"Update Needed"`, detail `"Open Caliber to sync today's nutrition summary."`, and action `"Open Caliber"`.
- **`.unavailable` (Invalid/Unreadable Timestamps or Mismatched Timezone):** Displays `"Data Unavailable"`, detail `"Open Caliber to review your nutrition log."`, and action `"Open Caliber"`.
- **Defense in Depth:** Numbers have `.privacySensitive()`. In `.private`, `.stale`, and `.unavailable` states, all nutrition numbers are completely omitted from both the view hierarchy and accessibility tree.

### Navigation Links & Hit Targets
- **Small (`systemSmall`):** Contains whole-card `.widgetURL(URL(string: "caliber://fuel"))` with visible `"Open Fuel"` affordance.
- **Medium (`systemMedium`):** Contains discrete `Link` targets:
  - `"Open Fuel"` -> `caliber://fuel` (minHeight 44pt).
  - `"Add food"` -> `caliber://food/add` (minHeight 44pt, accent fill).
- **Dynamic Type Reflow:** Fully audited with `lint_dynamic_type.py --strict`. At AX sizes, macro pills in small widget hide gracefully to prevent primary calorie clipping; buttons maintain minimum 44pt/48pt tap targets.

---

## 3. Verification & Checks Run

1. **Foundation Snapshot Unit Tests:**
   - Command: `swift test --package-path Packages/CaliberFoundation --filter NutritionWidgetSnapshotTests`
   - Result: 5 tests passed in 0.012s (`widgetDefaultsArePrivateAndContainNoNutrition`, `widgetRejectsInvalidNutrition`, `widgetRejectsTamperedDecodedDatesAndZones`, `widgetExpiresAtLocalMidnightAcrossDST`, `widgetRoundTripPreservesReportedCaloriesAndExactExpiry`).
2. **Formatting & Structure Lint:**
   - Command: `python3 scripts/lint_foundation.py`
   - Result: 0 errors, 0 warnings across all repository foundation packages.
3. **Dynamic Type & Accessibility Text Lint:**
   - Command: `python3 scripts/lint_dynamic_type.py --strict CaliberWidgets`
   - Result: 2 files, 0 errors, 0 warnings.
4. **Older Clone Preservation:**
   - Both `/Users/jcrock/.gemini/antigravity/scratch/Caliber-DEV` (with 7 uncommitted files) and `/Users/jcrock/.gemini/antigravity/scratch/Caliber-v2-frost-review` remain untouched.

---

## 4. Known Gaps & Codex Ownership Boundaries

1. **Target & Entitlements:** Codex owns adding the `CaliberWidgets` extension target to `Caliber (DEV).xcodeproj`, App Group entitlements (`group.com.caliber.app`), `@main struct CaliberWidgetBundle: WidgetBundle`, and `TimelineProvider`.
2. **Deep Link Routing:** Codex owns URL routing in `Caliber (DEV)App.swift` for `caliber://fuel` and `caliber://food/add`.
3. **Lock Screen / StandBy Accessories:** Accessory families (`.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`) are not in the v1 small/medium scope.
4. **Health Adjustments:** Any active Health data reconciliation requested by the owner belongs to Codex separately.

---

## 5. Five Ranked Independent App Findings

### Rank 1: Low Disabled-Action Contrast and Legacy Row Background in Manual Entry
- **Screen & Citation:** `AddFoodView` (`Caliber (DEV)/Views/Diary/AddFoodView.swift:52, 94-96, 117`)
- **Observed Behavior:** `AddFoodView` uses legacy `CaliberRowBackground()` (line 52) rather than `FoodEntryV2RowBackground()`. At accessibility scale AX5, the bottom safe area inset uses `.background(.bar)` (line 117), where the disabled `"Save"` button uses `theme.palette.text.secondary.color` (line 95), yielding low contrast against Frost's light bar background.
- **Expected Behavior:** Form rows should adopt `FoodEntryV2RowBackground()` and `FoodEntryV2Surface`, and disabled action text should maintain WCAG AA contrast (≥ 4.5:1) in Frost theme.
- **Suggested Fix:** Replace `CaliberRowBackground()` with `FoodEntryV2RowBackground()`, and use `theme.palette.text.tertiary.color` with a high-contrast container fill for the disabled state.
- **Evidence Level:** Source-only inspection confirmed by native capture `output/screenshots/v2-native/food/v2-manual-entry-frost-AX5.png`.

---

### Rank 2: Translucent Navigation Chrome Bleed in Frost Reference Review
- **Screen & Citation:** Reference Food Review (`Caliber (DEV)/Views/Diary/FoodNutritionReviewView.swift:274-276`)
- **Observed Behavior:** In Frost theme, `.navigationBarTitleDisplayMode(.inline)` uses a translucent navigation bar. Scrolled form content (section headers, `"Adjust macros for this log"` toggle) visually bleeds through directly behind the `"Review Food"` title and back chevron.
- **Expected Behavior:** Solid opaque surface treatment (`theme.palette.opaque.surface.color`) behind navigation chrome in Frost mode to prevent underlying scroll bleed.
- **Suggested Fix:** Add a solid background modifier or surface configuration behind the inline navigation bar.
- **Evidence Level:** Native capture observation (`output/screenshots/v2-native/final-review/v2-reference-review-frost-default.png`).

---

### Rank 3: Hardcoded System Blue Tint in Food Search Swipe Actions
- **Screen & Citation:** Food Search Reuse Rows (`Caliber (DEV)/Views/Diary/FoodSearchView.swift:694`)
- **Observed Behavior:** The favorite swipe action uses `.tint(.blue)`. In Frost theme, default iOS system blue clashes with Helios tokenized accent colors (`theme.palette.accent.base.color`).
- **Expected Behavior:** Trailing swipe actions should use semantic Helios palette tokens to preserve Frost design system harmony.
- **Suggested Fix:** Replace `.tint(.blue)` with `.tint(theme.palette.accent.base.color)`.
- **Evidence Level:** Source-only inspection.

---

### Rank 4: Pre-Existing Keyboard Presentation Layout Warning
- **Screen & Citation:** Keyboard Focus & Safe Area Transitions (`FoodSearchView.swift:158-161`, `AddFoodView.swift:83-118`, documented in `baseline-keyboard-summary.json`)
- **Observed Behavior:** Activating and dismissing keyboard first responder emits `"Invalid frame dimension (negative or non-finite)."`. Codex verified this reproduces on baseline `a07ceb9` without custom food changes.
- **Expected Behavior:** Safe area bottom inset transitions should resolve non-negative finite geometry passes during keyboard presentation animations.
- **Suggested Fix:** Guard safe area bottom inset transitions with `.animation(.default, value: ...)` or clamp height calculations during first-responder state transitions.
- **Evidence Level:** Runtime warning verified on baseline `a07ceb9` (known non-fatal framework issue).

---

### Rank 5: Virtualized Deep-Row Element Eviction During Automated AX Audits
- **Screen & Citation:** Deep Macro Form Rows (`FoodEntryPass2Components.swift:793-822`, documented in `docs/parallel/v2-native/VERIFICATION.md:88-93`)
- **Observed Behavior:** Automated XCTest `performAccessibilityAudit` at AX5 on deep review screens yields `INCONCLUSIVE` because virtualized row elements (such as `foodEntrySummary-fat`) are evicted during font-size queries (`final-layout-diagnostic-summary.json`).
- **Expected Behavior:** Automated accessibility system audits should be able to evaluate scrollable content, or deep forms must use structure that prevents element eviction during inspection.
- **Suggested Fix:** Maintain explicit scroll container anchoring during audit execution, or rely on Codex's verified programmatic growth/bounds assertions for virtualized deep lists.
- **Evidence Level:** Runtime audit / test harness limitation documented in `VERIFICATION.md`.
