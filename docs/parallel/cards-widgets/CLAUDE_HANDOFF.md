# Claude — swipeable Today fuel card handoff

Branch: `claude/cards-widgets`, from seed `300388e` (includes the packaged-food and Diary
work `e6ba3ec`), in a clean separate worktree. `/home/user/cdiary` and `/home/user/v2n`
are untouched. Nothing was merged or rebased. The delivery commit is the
`claude/cards-widgets` commit that adds this file; its SHA is in the thread reply.

## Files
- `Caliber (DEV)/Views/Components/CaliberInfoCardPager.swift` (new): a generic pager.
- `Caliber (DEV)/Views/Foundation/TodayFoundationView.swift`: the fuel card only.
- `Caliber (DEV)UITests/TodayInfoCardPagerUITests.swift` (new).
- This file.

Diary (its swiping summary and centred headings), math, models, storage, providers,
flags, locks, settings, widgets and the shared project are unchanged. The project uses
synchronized groups, so the new files need no project edit.

## What changed
The Today fuel card ("Nutrition today") now pages Calories → Protein → Carbs → Fat.
Each page draws the same ring and figure as before, from the existing
`MacroCalculator.totals` for today and the saved profile goals. Left/Eaten, the
"<1 [unit] over" rule, Open Fuel (`todayOpenFuel`) and Set goals (`todaySetGoals`) are
unchanged. When the selected page has no saved goal, the Left/Eaten switch is hidden and
the goal hint shows. No goal is inferred. The workout, weight and Stack tiles and all
logging actions are unchanged.

`CaliberInfoCardPager` (reusable, owns no data):
- **Panel (value area only).** It carries the drag and nothing interactive. A
  `DragGesture(minimumDistance: 28)` attached with `simultaneousGesture` pages only when
  the drag is ≥44 pt and more than 1.25× its vertical travel, so the screen still
  scrolls. Paging wraps. There is no TabView and no fixed height.
- **Named tabs**, one per page. Each shows the page name and its eaten value
  ("142 g"), so all four figures stay glanceable. That replaces the old macro grid.
  They sit in one row when they fit, then a two-column grid, then one column at AX
  sizes. Each is ≥48 pt tall and shows selection with fill, a stronger edge, bold text
  and the selected trait.
- **Previous/Next** 48 pt circular buttons, with a position caption ("Protein · 2 / 4")
  that wraps between them.
- **VoiceOver.** The panel is one element whose value is "Protein, page 2 of 4". It
  supports the adjustable action (swipe up/down) and the named actions "Next page" and
  "Previous page". Every change posts that page announcement. The card is a container
  named "Today's nutrition".
- **No autoplay.** The page changes only with a short cross-fade, and with no animation
  under Reduce Motion. Nothing slides.
- Surfaces are opaque (raised, or a subtle accent fill). Text is never capped or shrunk.

Identifiers: `todayFuel-panel`, `todayFuel-page-{calories,protein,carbs,fat}`,
`todayFuel-previous`, `todayFuel-next`.

## Test added (written, not run)
`TodayInfoCardPagerUITests` uses the showcase fixture with Frost. Goals are 2,350 kcal,
180, 240 and 70 g. Today's totals are 1,462 kcal, 142, 118 and 52 g.
- `testFuelCardPagesByButtonNameAndSwipeWithoutAutoplay`:
  - The card starts on Calories showing 888 left.
  - Next goes to Protein (38). The Fat tab goes to Fat (18). Previous goes to Carbs
    (122).
  - Left and right swipes on the panel page and wrap.
  - After a 3 s wait the page has not changed (no autoplay).
  - A vertical swipe does not page.
  - All six controls are ≥47.5 × 47.5.
  - `todayStartWorkout` and `openDemo` remain.
- `testFuelCardTabsStackAndStayFullSizeAtAccessibilityText`: at AX3, the tabs stack in
  one column and stay ≥48 pt, and tapping a tab pages.

## Checks run in the cloud (Linux, no Xcode or Swift)
- `python3 scripts/lint_dynamic_type.py`: 227 files, 0 errors, 0 warnings.
- `python3 scripts/check_tokens.py`: PASS (54 pairs, minimum 5.94:1, 48 pt targets).
- `python3 scripts/gen_tokens.py --check`: up to date.
- `python3 -m unittest discover -s scripts -p 'test_*.py'`: 135 tests OK.
- I hand-checked 100-column formatting of the new lines. The over-long string-literal
  lines in the Today file predate this change.

## UNTESTED natively: commands for Codex
Not compiled, not run on a simulator or device, no VoiceOver pass:
```sh
xcodebuild test -project "Caliber (DEV).xcodeproj" -scheme "Caliber (DEV)" \
  -destination "<iPhone simulator>" -derivedDataPath <private-derived-data> \
  -only-testing:"Caliber (DEV)UITests/TodayInfoCardPagerUITests" \
  -only-testing:"Caliber (DEV)UITests/DiaryV2UITests" \
  -only-testing:"Caliber (DEV)UITests/ResponsiveLayoutUITests"
xcrun swift-format lint --strict "Caliber (DEV)/Views/Components/CaliberInfoCardPager.swift" \
  "Caliber (DEV)/Views/Foundation/TodayFoundationView.swift" \
  "Caliber (DEV)UITests/TodayInfoCardPagerUITests.swift"
```
Please also check these by hand:
- The panel drag does not fight the outer ScrollView or the Diary tab swipe.
- VoiceOver does not announce twice (the value change plus the posted announcement).
- Reduce Motion gives an instant change.
- At AX5 the card fits at 320 pt width.
- Any existing Today test that queried the removed macro grid or the old "Fuel today"
  title still passes. I found none by search, but did not run them.

## Known gaps in this work
- With kJ selected, the first page is still titled "Calories" while the value is in kJ.
  It matches the previous card, but "Energy" may read better.
- The tab's eaten value is a separate glance from the ring's Left/Eaten mode. With
  "Left" chosen, the tabs still show eaten. Each is labelled, but they are two figures.
- If a page announcement doubles under VoiceOver, drop the `Announcement` post on
  adjustable changes only. Native evidence is needed first.

## Five ranked remaining app gaps (source review at 300388e, not runtime testing)
1. **P1: the weight unit has two sources of truth.**
   - Evidence:
     - `Views/Progress/ProgressEntryForm.swift:281` writes only `@AppStorage("progressWeightUnit")`.
     - Settings edits `runtime.settings.massUnit` (`Views/Foundation/FoundationSettingsView.swift:34`).
     - `App/FoundationRuntime.swift:90` overwrites the AppStorage key from settings on
       every persist.
     - Progress reads AppStorage (`ProgressDashboardView.swift:14,229`), while Today reads
       settings (`TodayFoundationView.swift:548`).
   - Effect: picking kg in the entry form can show kg in Progress and lb on Today, and
     revert on the next settings save.
   - Bounded fix: have the entry form read and write `runtime.settings.massUnit`. Keep
     the AppStorage key only as the legacy mirror that `persist()` already writes.
2. **P1: Diary and Food search ignore the kJ energy setting.**
   - Evidence:
     - Hard-coded "cal" with raw kcal values at `Views/Diary/DiaryView.swift:250,359`,
       `Views/Diary/FoodSearchView.swift:341,396,546,620,667,699` and
       `Views/Diary/CopyDiaryView.swift:86`.
     - Today and Progress use `UnitFormatting.energy` (`TodayFoundationView.swift:167`,
       `ProgressCards.swift:97`).
   - Bounded fix: one display helper using `UnitFormatting.energy` plus the unit label,
     applied to those rows only, with no math change and a unit test for the kJ label.
3. **P2: Stack "Skip" fails silently and cannot be undone.**
   - Evidence: `Stack/StackHomeView.swift:108-113` inserts a skipped `StackDose` and calls
     `try? context.save()`. The `stackSkipDose` button (`:269`) has no confirmation or
     undo.
   - Bounded fix: `do/catch` with an error message, plus an "Undo" banner that deletes
     that dose, with a UI test.
4. **P2: the weigh-in table is not lazy.**
   - Evidence: `Views/Progress/WeightTrendChart.swift:181` builds
     `ForEach(Array(summary.readings.reversed()))` eagerly inside the card once "Show
     weigh-ins" is on.
   - Effect: years of daily weigh-ins become one long eager list inside the scroll view.
   - Bounded fix: a `LazyVStack` for the rows, or show the latest 30 with a "Show all"
     button, keeping every row's text in full.
5. **P3: the Today Stack tile shows compound names on the home screen once unlocked.**
   - Evidence: `TodayFoundationView.swift:674` shows `next.compoundName` whenever
     `!stack.isLocked`. Unlock is per app visit (`Stack/StackFeature.swift:36-40`).
   - Effect: Today is the screen most likely to be seen by others.
   - Bounded fix: an owner decision on a "Hide names on Today" choice that shows "Next
     dose · 8:00" instead. This needs a settings owner, so I have not built it.
   - Note: the older open item, "Today tile shows Locked after Stack unlock", looks
     addressed in source by the shared `isUnlocked` (`StackFeature.swift:36-40`). That is
     not verified at runtime.
