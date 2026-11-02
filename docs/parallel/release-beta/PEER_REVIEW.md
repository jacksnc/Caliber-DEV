# Independent source reviews — November 2, 2026

## Claude Opus 5.5 — UI helper review

Actual native-chat result: read the four assigned files; no edits or test jobs.
Provisional findings to compare with current native results:

- FoodEntryPass2 `towardTop` currently overrides direction even for an existing,
  hittable target below the viewport. Use the hint only while searching for a
  missing/non-hittable target; use visible frames otherwise.
- The helper uses any search field's frame as its upper boundary. A retained
  background search field behind a review sheet can invalidate that boundary;
  require it to be hittable. Navigation-bar selection has the same active-view
  assumption and needs care.
- `referenceFavorite` is only measured for target height in the meal-switcher
  test. Check it immediately after review opens, before scrolling to later rows.
- Add top/bottom/target-frame diagnostics on reveal failure.
- Two event-synthesis timeouts are not evidence of a helper geometry bug. Run
  them in isolation and adjacent order; inspect possible app hangs/load instead
  of raising timeouts or removing assertions. Actual product failure remains
  possible if controls are unreachable in the captured foreground view.

These are source-review findings, not passing regression evidence.

## Gemini 3.8 Flash High — icon and release-note review

Actual native-chat result: completed on the owner's Mac; reported no edits,
Xcode jobs, personal browser access or provider activation. It also ran the
archive checker unit tests and existing static checks read-only.

- Independently confirmed both approved assets are opaque RGB 1254×1254 PNGs,
  full bleed without baked outer corner masking. Exact 1024-square downsampling
  is needed for the existing catalog slots.
- Suggested optional vertical repositioning. Codex defers it because the owner
  approved this composition, and optical centering is a design preference.
- Proposed an explicit tinted asset; its asserted transparency requirements were
  not independently verified and are not adopted. The iOS catalog will supply
  the approved normal/dark mark with no empty tinted slot.
- Flagged the release note's original no-copy scope after Codex had begun the
  authorized follow-up. The original checkpoint was accurate at 85dd887; current
  notes now explicitly record the later 13-file QA patch integration.
- Requested clearer repo-root evidence paths and noted the original file list
  omitted the committed archive-check JSON. Those documentation changes are
  accepted; the evidence is linked relative to its actual document.

Codex independently inspected both images, their dimensions/alpha, source
provenance and exact downsample. No image generation or redesign in this batch.
