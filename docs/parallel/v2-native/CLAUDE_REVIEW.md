# Claude Opus 5.5: source review of 76cac66 against Lookbook V2

This is a source-only review of my own surfaces on `claude/v2-native-surfaces` (head
76cac66) while Codex runs integration QA. No app or test source was changed and no
simulator was run. Every width below is arithmetic from the source, not a
measurement. Paths are below `Caliber (DEV)/`, and line numbers are at 76cac66.

Severity: **P1** = wrong or unreadable in a state the contract names; **P2** = V2
gap or degraded state; **P3** = polish.

## Findings

### 1. P1: Train set grid needs more width than a 320-point row has
`Views/Train/ActiveWorkoutView.swift:160-166` (header), `:409-420` (completed row) and
`:485-505` (open row). These existed before 76cac66; I left them.
Outside accessibility sizes, each row is a fixed `24 + 64 + 76 + 58 + 48` points of
columns plus `4 × 8` points of spacing, which is 302 points. The rows use
`listRowInsets` of 16 on each side (`:344`). Inside a 320-point screen's list row, the
content is about 256 points (this assumes about 16 points of list margin per side).
`Spacer(minLength: 0)` cannot shrink fixed frames, so the grid clips or compresses at
320 even at default text. At 375 there are about 311 points against 302 needed, so it
fits with almost no room, and xLarge to xxxLarge text in the 64-point "Previous"
column can still truncate.
Fix (owner of Views/Train): switch to the existing accessibility-size `VStackLayout`
path when the row does not fit (`ViewThatFits`), or drop the "Previous" column into a
caption under the set number below about 340 points. Don't shrink text.

### 2. P1: Progress weight unit can diverge from Today and Train
`Views/Progress/ProgressEntryForm.swift:81,224-229,281` and
`ProgressDashboardView.swift:14,229`, compared with `Views/Foundation/TodayFoundationView.swift:517`
and Train's `runtime.settings.massUnit`. This existed before 76cac66; the new weigh-in
table at `WeightTrendChart.swift:180` inherits it.
The check-in form's unit picker writes only `@AppStorage("progressWeightUnit")`.
Today's weight tile, Train and Profile read `settings.massUnit`, and
`FoundationRuntime.persist()` (App/FoundationRuntime.swift:89-90) overwrites
`progressWeightUnit` with the settings value on the next settings save.
If someone picks kg in a check-in, Progress shows kg while Today shows lb. The next
settings change then flips Progress back without asking.
Fix: needs Codex, because it touches FoundationRuntime and settings. Either make the
form's picker write `settings.massUnit`, or make it a per-entry entry unit only. Stored
pounds are unaffected either way, since only the display unit diverges.

### 3. P2: "0 kcal over" when less than one calorie over the goal
`Views/Foundation/TodayFoundationView.swift:238-246`. The left/over branch compares the
raw value `left < 0` but displays a rounded value with no decimals. A goal of 2,000
with 2,000.3 eaten shows "0 kcal over", and VoiceOver reads "0 kcal over today's goal".
Fix: branch on the rounded value, for example
`let left = (target - energy.eaten).rounded()`, and show "over" only when `left < 0`.
I added this "over" state in 76cac66.

### 4. P2: The new ring captions and VoiceOver sentence are not localizable
`TodayFoundationView.swift:232-247,279,286`. In 76cac66, the "left", "over" and
"eaten" captions and the `spoken` sentence became `String` values passed to
`Text(_: String)`, which is verbatim. The old code passed string literals, so they
were `LocalizedStringKey`. This is a regression for a future string catalog.
Fix: store `LocalizedStringResource` or `LocalizedStringKey` in `Figure`, or build
`Text("\(value) \(unit) left")` inline.

### 5. P2: Today's Stack tile still names the item and amount when unlocked
`TodayFoundationView.swift:639-646`. When the lock is on, it is correct: only "Locked"
shows. When unlocked, Today shows the compound name and amount, as before. The V2
board's Today tile is discreet ("2 of 3 logged today", with no names), and the
contract says Stack should be discreet.
This needs the owner's call, so I didn't change it. A discreet tile could reuse the
same `StackPlanner.today` count that Stack now shows (`StackHomeView.swift:176-180`).

### 6. P2: Today's two tiles stay side by side at the largest non-accessibility sizes
`TodayFoundationView.swift:53-65`. The weight and dose tiles stack only when
`isAccessibilitySize` is true. At 320 points with xLarge to xxxLarge text, each tile
has about 106 points inside it. That fits "Overdue by 1 hr, 20 min", "Nothing
scheduled" and a value in a `metricValue` font, but only cramped.
Fix: `ViewThatFits(in: .horizontal) { HStack…; VStack… }`. Keep the accessibility-size
branch.

### 7. P2: Two Stack rows don't reflow at accessibility sizes
`Stack/StackHomeView.swift:274-288` (`StackDoseRow`, which puts a status badge such as
"Taken 8:00 AM" next to the name) and `:327-347` (`StackCompoundRow`, which puts the
name button next to the "Log" button). Both are plain `HStack`s. At AX5 on 320 points,
the name column gets squeezed down to a few characters per line next to the badge or
the 48-point button.
Fix: `AnyLayout` to `VStackLayout(alignment: .leading)` at accessibility sizes, the
same pattern as Train.

### 8. P2: Missing interaction state: Skip has no undo and fails silently
`StackHomeView.swift:108-114`. Skip inserts a skipped `StackDose` right away, with no
confirmation, no undo and a `try? save()`. Log has a sheet and Train has Undo, but
Skip has neither. If the save fails, the person gets no message.
Fix (presentation only, using the existing model): show a short Undo affordance that
deletes that inserted dose, and route a failed save into an alert. This is a missing
interaction state, not a new engine.

### 9. P2: The weigh-in table is not lazy
`Views/Progress/WeightTrendChart.swift:180`. With "All" selected, every reading is
drawn inside one List row's `VStack`. Daily weigh-ins over several years add up to
1,000+ rows built at once when the table opens.
Fix: put the rows in a `LazyVStack`, or show the newest 30 rows plus a "Show all" row.

### 10. P3 (lower priority): smaller semantics points
- `TodayFoundationView.swift:349`. Eaten macros show one decimal and goals show none
  ("134.0 g of 160 g"). The V2 board uses whole grams. Consider
  `fractionDigits: 0...1`, if UnitFormatting supports a range; otherwise this is
  cosmetic.
- `:356` and `:368`. A macro or energy goal that is exceeded clamps the meter and ring
  to full, with no "over" mark. The text shows the real values, so nothing is
  misreported. A future "over" treatment would need a design call.
- `:100`. The Left/Eaten choice is `@State`, so it resets to Left on every launch.
  That's acceptable; noting it in case persistence is expected.
- `Stack/StackHomeView.swift:176-180`. "x of y logged today" counts only scheduled
  doses. Logs of as-needed items are not included. The wording is accurate for the
  schedule, but "scheduled" could be added if anyone finds it confusing.

## Checked and found no problem (source only)
- **No goal:** a missing profile, or a zero, negative or non-finite goal, gives `nil`
  (`:227-230`). The ring stays empty, the switch is hidden, it shows "eaten · no goal
  set", and the Profile hint appears. No fixed fallback goal or mock value is used.
- **Partial goals:** with a calorie goal and no macro goals, the macro text shows
  without meters. With macro goals only, meters show and there is no Left/Eaten
  switch. Both are consistent.
- **Energy unit:** the goal and eaten values both go through
  `UnitFormatting.energy(_, unit:)`, and the captions use the unit's raw value.
- **Number-free:** `RootTabView` shows `NumberFreeHomeView` instead of the tab view, so
  none of the changed Today, Progress, Train or Stack surfaces render.
  `NumberFreeHomeView` is unchanged and its check-in sheet passes `hidesWeight: true`.
- **Stack opt-out:** the tab is removed (`RootTabView.swift:21-24`) and
  `TodayDoseTile` renders nothing when `!stack.isEnabled`.
- **Stack lock:** `StackLockGate` is unchanged. The new count and Supply card are
  inside `StackDashboard`, which renders only behind the gate. Today shows only
  "Locked" and the "Open Stack" text, as before.
- **Today 320 points:** the card's inside width is about 256 points, so the 240-point
  ring cap fits. Macro columns are about 77 points each at default text, and
  `ViewThatFits` falls back to one column. At accessibility sizes the figure moves out
  of the ring.
- **Train mass units:** history and summary volume now both use `settings.massUnit`.
  Set rows keep the unit each set was entered in.
- **Targets:** the Fuel chips are 42 + 2×3 = 48 points, and the new buttons use
  Helios styles with a 48-point minimum height.

## Unverified risks for Codex QA
- The `v2Surface()` and `progressCardRow()` helpers rely on
  `transformEnvironment(\.heliosTheme)` reaching `GlassBackground` in a `.background`
  closure. Confirm that cards look opaque with Reduce Transparency off, in both
  Graphite and Frost.
- `ProgressUITests.testWeightChartListsWeighInsAsText` may need a scroll to
  `weightTrendReadings` on small simulators. It also assumes the year appears in the
  label for the simulator's locale.
- The swift-format `--strict` layout of the new code was hand-matched, not run.
- VoiceOver reading order of the energy ring, the context element and the three macro
  cells. In Eaten mode, the context element repeats the eaten number.
- Number-free mode removes the Stack routes entirely (there is no logging path while
  numbers are hidden). This was the case before 76cac66 and is a product decision, not
  something this batch can change.

## Scope
This file is the only change. App, tests and other docs are untouched. There is no
merge or rebase. iPad, resizing, Frost beta, widgets and graphics are not started.
