# ADR-012: Reuse food history without changing the live model schema

Status: implemented locally, 2026-10-14.

The offline catalog and per-log snapshots work, but repeat meals still require unnecessary re-entry. Add recents, frequency, favorite keys and reviewed copying using existing SwiftData records. Preserve the working 15-model schema and the separate canonical migration rehearsal.

`FoodReuseIndex` derives immutable group records with latest timestamp/quantity and distinct log counts. Exact source/portion/nutrition/menu content forms a length-framed SHA256 identity; copied FoodItem UUIDs do not split equivalent foods. Different preparation or edited values do not merge. Source IDs and saved representatives provide reuse without mutating previous intake. Future days and invalid data are excluded. The screen computes one history index per render and limits visible shortcut lists.

`FoodLibraryPreferences` keeps at most 500 validated FDC/content keys in a separate versioned local preference. Personal favorites first save their existing food to My Foods, then persist the key; a crash cannot remove the original diary food. Removing a star keeps that reusable copy. Preference hashes are not encryption, and portability/source-removal reconciliation remain later work.

`DiaryRepeatLogger` freezes all source values, validates the complete selection and resolves menu provenance in the destination context before inserting independent food/log snapshots. Original quantity, notes and meal are preserved unless the user selects another meal. Copy review defaults to the previous calendar day and can select individual foods. All new rows save together; a failure removes only attempted copies, retaining unrelated drafts. Separate successful copy requests intentionally create separate logs; the UI guards an already successful draft against another tap.

`FoodPortionMath` adds exact weight-oz conversion and source-defined mass portions to gram review. Unknown mass is not guessed. Unit-only changes retain the selected physical mass and macro edits; amount edits reset the override. Selected diary meal/date is passed through all relevant review routes. This is a convenience layer, not a new calorie estimate, adaptive target or clinical recommendation.

Strict formatting is extended to the touched legacy views. Equivalent for-in changes satisfy the formatter without changing saved-meal behavior. No new dependency, provider account, hosted migration, live store cutover or licensed dataset import is involved. See FOOD_REUSE_VERIFICATION.md for execution evidence and remaining platform/privacy gates.
