# Frost Food Feature & UX Proposals

**Date:** 2026-10-31  
**Author:** Gemini (independent review proposals)  
**Branch:** `gemini/v2-frost-review`  
**Base Seed:** `3183869366dcbb81ddaea6a3eb6c568b933ad841`  
**Scope:** At most three small, ranked feature and interaction proposals addressing logging friction and workflow ergonomics within the V2 food interface. Conforms strictly to existing architecture without introducing new dependencies, medical/dose logic, competitor datasets, or widgets.

---

## Ranked Proposals

### Rank 1: One-Tap Quick-Add for Recent and Frequent Items
- **Classification:** Missing Functional Shortcut (Interaction Acceleration)
- **Problem & Logging Friction:** When logging recurring daily staples (e.g., morning coffee, standard protein shake), tapping the `+` button opens `FoodEntryPass2QuickReviewSheet`, requiring an additional tap on `"Add to Diary"` plus the sheet presentation/dismissal animation (2 taps + modal transition). For a user logging the identical portion every day, this represents unnecessary friction.
- **Proposed Solution:** Introduce a secondary quick-action affordance on recent/frequent rows (e.g., long-press or a direct swipe-to-log action) that commits the item using its last recorded portion directly to the target meal and date, bypassing the review sheet while displaying the existing transient saved confirmation badge.
- **Effort:** Small. Leverages existing `save()` pathways in `FoodSearchView.swift` and `ReusableFood` records.
- **Brief Fit:** High. Directly reduces repetitive logging friction for high-frequency foods without altering underlying models or nutrition math.

---

### Rank 2: Clear Visual Indicator for Custom Macro Overrides in Review
- **Classification:** Clarity & User Confidence (Visual Hierarchy)
- **Problem & Logging Friction:** In `FoodNutritionReviewView` and `SavedFoodDetailView`, users can expand `MacroOverrideSection` and customize individual macro values for a single log. While `FoodEntryV2NutritionOverviewCard` recalculates calories and macros immediately, there is no explicit visual pill or badge (such as `"Customized"`) indicating that the active values diverge from the canonical database/catalog source.
- **Proposed Solution:** Display a compact, non-intrusive badge (e.g., `theme.palette.accent.base` pill with text `"Custom Macros"`) in `FoodEntryV2NutritionOverviewCard` whenever `override != nil` or `isEditing` is active.
- **Effort:** Minimal. Adds a single conditional badge view in `FoodEntryV2NutritionOverviewCard` driven by existing `isEditing`/`override` state.
- **Brief Fit:** High. Protects data trust by making user-modified nutrition explicitly identifiable prior to tapping `"Add to Diary"`.

---

### Rank 3: Search Query Reset Affordance on Meal Destination Switch
- **Classification:** Workflow Ergonomics (Navigation Fluidity)
- **Problem & Logging Friction:** When switching target meal destination pills in `FoodEntryPass2HubCard` (e.g., switching from Breakfast to Lunch), any active search text or filter selection remains unchanged in `FoodSearchView`. If a user entered a search specific to one meal and then switches meals to log something else, they must manually select the search field and clear the text.
- **Proposed Solution:** Provide a lightweight affordance or query clear reset when switching meal destination pills while in an empty-results or filtered state, allowing a clean transition without manual backspacing.
- **Effort:** Minimal. Simple handling in `onChange(of: selectedMealType)` or search bar binding.
- **Brief Fit:** Medium. Smooths multi-meal logging sessions within the unified food search experience.
