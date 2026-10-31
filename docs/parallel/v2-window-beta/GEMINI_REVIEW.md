# Frost Food Source and Evidence Review

**Date:** 2026-10-31  
**Author:** Gemini (independent source and evidence review)  
**Branch:** `gemini/v2-frost-review`  
**Base Seed:** `3183869366dcbb81ddaea6a3eb6c568b933ad841`  
**Scope:** Document-only review of Frost food hub, manual entry, quick review, reference review sources, and repository native captures (`output/screenshots/v2-native/`). No simulator runs, app builds, or test executions performed in this batch.

---

## Actionable Findings

### 1. Pushed Reference Food Review Navigation Bar Bleed in Frost
- **Screen:** Reference Food Review (`FoodNutritionReviewView`)
- **Citation:** `Caliber (DEV)/Views/Diary/FoodNutritionReviewView.swift:274-276` and `output/screenshots/v2-native/final-review/v2-reference-review-frost-default.png`
- **Observed:** In Frost theme, the navigation bar uses default translucent navigation chrome with inline title `"Review Food"` and a circular back chevron. When form content scrolls beneath, section header text and the `"Adjust macros for this log"` toggle visually bleed through the frosted navigation background directly behind the title and chevron, reducing contrast and visual clarity.
- **Expected:** An opaque or solid surface treatment matching `HeliosTheme.palette.opaque.surface` behind the navigation bar in Frost mode, ensuring scrolled form controls do not bleed through navigation chrome.
- **Severity:** Medium (Legibility & Visual Polish)
- **Evidence Level:** Native capture observation (`output/screenshots/v2-native/final-review/v2-reference-review-frost-default.png`)

### 2. Differing Grid Rhythm Between Shortcut Tiles and Library Tiles in Food Hub
- **Screen:** Food Entry Hub Card (`FoodEntryPass2HubCard`)
- **Citation:** `Caliber (DEV)/Views/Diary/FoodEntryPass2Components.swift:501-573` and `output/screenshots/v2-native/food/v2-food-hub-frost-default.png`
- **Observed:** In the default dynamic type layout, the upper capture routes (`Barcode`, `Label`, `Photo`, `Manual`) use horizontal tile structures (`HStack` icon + label, 2-column grid), whereas the lower library routes (`My Foods`, `Meals`, `Restaurants`) use vertical tile structures (`VStack` icon + count above label, 3-column grid). In Frost's high-key white palette, having two distinct grid rhythms stacked immediately inside the same card creates visual tension and conflicting alignment anchors.
- **Expected:** Consistent internal alignment rhythm and clear visual grouping between quick capture inputs and library navigation tiles, matching Lookbook V2 specifications.
- **Severity:** Low (Design Consistency & Visual Polish)
- **Evidence Level:** Native capture observation (`output/screenshots/v2-native/food/v2-food-hub-frost-default.png`)

### 3. Manual Entry Row Background and AX5 Disabled Contrast in Frost
- **Screen:** Manual Food Entry (`AddFoodView`)
- **Citation:** `Caliber (DEV)/Views/Diary/AddFoodView.swift:52, 94-96, 117` and `output/screenshots/v2-native/food/v2-manual-entry-frost-AX5.png`
- **Observed:** `AddFoodView` continues to use legacy `CaliberRowBackground()` (line 52) rather than the unified `FoodEntryV2RowBackground()`. At accessibility scale AX5, the bottom safe area inset uses `.background(.bar)` (line 117), where the disabled `"Save"` button foreground is rendered using `theme.palette.text.secondary.color` (line 95). Against Frost's light bar background, this secondary text color provides inadequate visual contrast before required fields are entered.
- **Expected:** `AddFoodView` should adopt `FoodEntryV2RowBackground()` and `FoodEntryV2Surface` consistent with other food entry screens. The disabled action state in the AX5 bottom bar should maintain WCAG AA contrast (≥ 4.5:1) against the underlying surface.
- **Severity:** Medium (Accessibility & Theming Consistency)
- **Evidence Level:** Native capture observation (`output/screenshots/v2-native/food/v2-manual-entry-frost-AX5.png`)

### 4. Hardcoded System Blue Tint on Favorite Swipe Action
- **Screen:** Food Search Results / Reuse Rows (`FoodSearchView`)
- **Citation:** `Caliber (DEV)/Views/Diary/FoodSearchView.swift:694`
- **Observed:** The trailing swipe action for starring/unstarring a food item in `reuseRow` hardcodes `.tint(.blue)`. In Frost theme, bright system blue clashes with the semantic Helios design tokens (`theme.palette.accent.base.color` or status palette).
- **Expected:** Swipe actions should use semantic Helios palette tokens (`theme.palette.accent.base.color` or `theme.palette.border.strong.color`) rather than raw system colors to preserve Frost theme fidelity.
- **Severity:** Low (Theming Hygiene)
- **Evidence Level:** Source hypothesis needing reproduction

### 5. Pre-Existing Keyboard Presentation Invalid Frame Layout Warning
- **Screen:** Keyboard Presentation & Safe Area Resizing (`FoodSearchView`, `AddFoodView`)
- **Citation:** Documented in `docs/parallel/v2-native/VERIFICATION.md:63-65` and `baseline-keyboard-summary.json`
- **Observed:** Presenting and dismissing the software keyboard triggers the console warning: `"Invalid frame dimension (negative or non-finite)."`. Codex verified via diagnostic keyboard-focus tests on unchanged baseline `a07ceb9` that this warning reproduces independently on baseline code. It represents an inherited UIKit/SwiftUI safe area layout pass during first-responder transitions rather than a regression introduced by the V2 food views.
- **Expected:** Safe area inset transitions should resolve non-negative finite geometry passes during keyboard animations.
- **Severity:** Low (Runtime Layout Warning; pre-existing, non-fatal)
- **Evidence Level:** Documented runtime warning / baseline reproduction (known issue)

### 6. Automated Accessibility System Audit Element Eviction on Deep Scroll Rows
- **Screen:** Large-Text Deep Food Review (`FoodNutritionReviewView` / `FoodEntryPass2MacroSummaryRow`)
- **Citation:** Documented in `docs/parallel/v2-native/VERIFICATION.md:88-93` and `final-layout-diagnostic-summary.json`
- **Observed:** Automated XCTest accessibility system audits (`performAccessibilityAudit`) at AX5 on deep review screens result in an `INCONCLUSIVE` outcome because offscreen or virtualized elements (such as `foodEntrySummary-fat`) are evicted during font-size inspection queries. Codex replaced the automated audit on deep rows with explicit measured growth and viewport containment checks (>30% growth, valid bounds inside viewport). Full automated system audit coverage remains incomplete for virtualized deep list rows.
- **Expected:** Distinguish passing component-level accessibility checks from full-surface automated audit coverage. Deep form containers should either retain audit accessibility elements during inspection or document explicit programmatic measurement bounds as the verified standard.
- **Severity:** Medium (Testability & Accessibility Audit Limitation)
- **Evidence Level:** Documented audit limitation / test harness observation (known limitation)

---

## Limitations & Verification Boundary

1. **Document-Only Review:** This evaluation was performed strictly via source inspection and analysis of existing repository captures (`output/screenshots/v2-native/` and `design/lookbook-v2/`). No local builds, unit tests, or simulator runs were conducted by Gemini.
2. **Device Ownership:** Codex owns all one-at-a-time native simulator QA on assigned test targets (iPhone SE3 QA `2998CE67-7D71-460B-AD69-76DAA4D014F6` and iPad Air 11 M4 QA `B02CFF79-2810-4011-B8CF-72F205F5ACC5`).
3. **No Certification Claim:** No claim of warning-free runtime execution or 100% accessibility certification is made. Known keyboard warnings and deep-row audit limitations remain tracked.
