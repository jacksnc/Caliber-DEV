# Claude Opus 5.5 — compact-height Diary handoff

Branch: `claude/v2-compact-diary`. It starts from the coordination seed
`3183869366dcbb81ddaea6a3eb6c568b933ad841` (source checkpoint 84edf55), in a separate
clean worktree (`/home/user/cdiary`). The older `claude/v2-native-surfaces` checkout
is untouched. Nothing was merged or rebased. The delivery commit is the
`claude/v2-compact-diary` commit that adds this file; its SHA is in the thread reply.

## Files
- `Caliber (DEV)/Views/Diary/DiaryView.swift`: header, date and library presentation
  only.
- `Caliber (DEV)UITests/DiaryCompactLayoutUITests.swift`: new.
- `docs/parallel/v2-window-beta/CLAUDE_HANDOFF.md`: this file.

`MacroTotalsSummaryView`, totals, goals, day arithmetic, food sheets, shared styles
and navigation, models, services, settings, flags, locks and providers are unchanged.

## Before (from the capture and the source)
`responsive-frost-Fuel-landscape.png` on a 375-point-tall screen: the date-and-library
card is about 180 points tall. Each `.heliosSecondary` button is 72 points tall,
because the 48-point label frame sits inside the style's own 12-point vertical
padding. The date row is a separate row. The energy card starts around 250 points,
and the tab bar starts around 300 points, so the figure begins below the fold.

## After (intent; native result UNTESTED)
These changes apply only when `verticalSizeClass == .compact` and the text is not an
accessibility size (`usesCompactHeader`):
- **One tight row** (`compactControls`): ‹ previous, date picker, next ›, Food
  Library, Copy a Day, with row insets of 6/12. The `ViewThatFits` fallbacks are two
  short rows (the date row, then both buttons) and then a full-width stack. All
  three hold the same five controls.
- **Compact buttons:** a private `DiaryCompactActionStyle`, used only in this row.
  It has the same `bodyStrong` type, primary text colour and raised `GlassBackground`
  (overlay when pressed) as the Helios secondary style, and a 48-point minimum
  height. It has no padding stacked on a 48-point label, and 12-point horizontal
  padding.
- **Header:** the "Fuel" overline (it repeats the selected tab) is omitted in the
  compact layout only. The "Diary" title, its `screenTitle-Fuel` identifier and the
  profile button stay.
- **Food Library now pushes through state, in every layout.**
  `showsFoodLibrary` + `.navigationDestination(isPresented:)` replace the
  `NavigationLink`. A `NavigationLink`'s push is popped when the link view leaves
  the hierarchy, which a rotation now causes. The identifier `openFoodLibrary`, the
  label "Food Library", the Helios secondary look and the destination are unchanged.
  **Visible portrait difference:** the list's grey disclosure chevron next to the
  Food Library button is gone. Everything else in portrait is the code path before
  this change.

Estimated from the source arithmetic only, so not a simulator pass: the header loses
about 18 points and the controls card shrinks from about 180 to about 60 points. With
the ringed figure, the energy card's figure would then start around 230 to 250
points, above a tab bar at about 300 points. If native QA shows it still below the
bar at default text, the remaining conflict is the summary's fixed 210-point ring,
which this task does not allow me to change.

Identifiers, labels and behavior are unchanged for `diaryPreviousDay`,
`diaryNextDay` ("Previous/Next diary day"), `diaryDate`, `openFoodLibrary`,
`diaryCopyDay` ("Copy a Day"), `diaryAddFood`, the meal add/edit/delete/repeat/copy
controls and the saved targets. Text is not capped and nothing is truncated; labels
wrap and the `ViewThatFits` fallbacks reflow. Accessibility sizes use the full
layout and scroll.

## New test (what it proves)
`DiaryCompactLayoutUITests.testLandscapeShowsCaloriesWithEveryHeaderAction` uses the
showcase fixture with Frost and a saved goal, and runs a real rotation to
`.landscapeLeft`. It skips with `XCTSkip` when the window is 500 points or taller,
which is not compact height.
- **At the initial scroll position, with no drag:** `diaryCalories` is
  "1462 calories", is hittable, and ends above `caliberTabBar`'s top edge.
- **All five controls** are hittable, on screen, above the bar and at least
  47.5 × 47.5 points, with their accessible names.
- **Next day** changes the figure; **Previous** restores "1462 calories".
- **Food Library** pushes, survives landscape → portrait → landscape, and returns.
  The figure is still reachable afterwards.
- **Copy a Day** opens the sheet (`copyConfirm`), then Cancel.
- **Rotating back to portrait** keeps all controls reachable and the same day.
- It takes full-screen `XCUIScreen` captures of landscape and portrait.

No existing assertion was removed or relaxed.

## Checks run in the cloud (Linux, no Xcode or Swift)
- `python3 scripts/lint_dynamic_type.py`: 224 files, 0 errors, 0 warnings.
- `python3 scripts/check_tokens.py`: PASS (54 pairs, minimum 5.94:1, 48-point targets).
- `python3 -m unittest discover -s scripts -p 'test_*.py'`: OK.
- Hand-checked 100-column formatting. `lint_foundation.py` cannot run (it needs
  `xcrun swift-format`).

## UNTESTED — native commands for Codex (Compact QA iPhone SE 3)
```sh
xcodebuild test -project "Caliber (DEV).xcodeproj" -scheme "Caliber (DEV)" \
  -destination "id=2998CE67-7D71-460B-AD69-76DAA4D014F6" \
  -derivedDataPath <private-derived-data> -resultBundlePath <bundle> \
  -only-testing:"Caliber (DEV)UITests/DiaryCompactLayoutUITests" \
  -only-testing:"Caliber (DEV)UITests/DiaryV2UITests" \
  -only-testing:"Caliber (DEV)UITests/ResponsiveLayoutUITests" \
  -only-testing:"Caliber (DEV)UITests/FoodExperienceUITests"
xcrun swift-format lint --strict "Caliber (DEV)/Views/Diary/DiaryView.swift" \
  "Caliber (DEV)UITests/DiaryCompactLayoutUITests.swift"
```
`FoodExperienceUITests` and the `openFoodLibrary()` helper exercise the library
change. Optionally add the new test file to `lint_foundation.py`'s list, which I
don't own.

## Risks
- The single-row fit is estimated from widths: about 540 points needed against about
  600 available in SE 3 landscape. Narrower landscape windows, or xLarge text and up,
  fall back to two rows (about 116 points). The figure may then sit lower.
- `navigationDestination(isPresented:)` on the List inside the tab's NavigationStack
  should be checked against back-swipe and the tab bar or footer overlap that Codex
  is fixing.
- The showcase date is assumed to have entries today and none tomorrow. The
  next-day check asserts only that the figure changes, not a specific value.
