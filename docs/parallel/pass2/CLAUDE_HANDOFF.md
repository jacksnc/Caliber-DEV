# Claude handoff

Status: **delivered for integration, native build UNTESTED.** Branch
`claude/visual-pass-2`, based on `96e8068`. Commits:

- `aa1113f` feat(helios): refine Progress hierarchy, Today states and shared segment/empty-state parts
- `200dd91` feat(settings): add standalone accessible appearance preview picker
- this handoff commit

No PR opened and nothing merged; Codex integrates.

## Environment limits (read first)

This pass was written in a Linux cloud container with no Xcode, `xcrun`,
`swift` or simulator, and the Swift toolchain download host is blocked by the
network policy. **Nothing in this branch has been compiled.** All SwiftUI code
was reviewed by hand against existing patterns in the same files, but Codex must
treat it as UNTESTED until the commands below pass. No Graphite/Frost/AX5
captures were produced; none are claimed.

## Files (all inside Claude ownership)

| File | Change |
| --- | --- |
| `Packages/HeliosDesign/Sources/HeliosDesign/SwiftUI/States.swift` (new) | `HeliosSegmentTrack`, `HeliosSegmentHighlight`, `HeliosEmptyState` |
| `Packages/HeliosDesign/Sources/HeliosDesign/SwiftUI/Gallery.swift` | Gallery shows the empty state |
| `Views/Progress/ProgressDashboardView.swift` | Section hierarchy, timeline header, empty state |
| `Views/Progress/ProgressCards.swift` | Shared segment parts, empty 7-day note, wrapping Macro split header |
| `Views/Progress/WeightTrendChart.swift` | Helios empty state, chart legend |
| `Views/Progress/ProgressTimelineRow.swift` | Helios type roles/tokens, Increase Contrast rail |
| `Views/Foundation/TodayFoundationView.swift` | Shared segment parts, empty Fuel label, goal hint opens Profile |
| `Views/Components/AppearancePreviewPicker.swift` (new) | Standalone theme preview picker |
| `Caliber (DEV)UITests/VisualPass2UITests.swift` (new) | One focused Progress test |

Paths starting with `Views/` are relative to `Caliber (DEV)/`. Token values,
`tokens.json`, generated outputs, models, services, routes, callbacks and public
initializers are unchanged. No migration.

## Behavior

**Helios package.** `HeliosSegmentTrack(cornerRadius:)` and
`HeliosSegmentHighlight(cornerRadius:)` take over the segmented-control drawing
that Today's Left/Eaten switch and the Progress range picker each repeated
(raised glass or opaque fallback, hairline or 1.5 pt strong edge, accent wash
and edge on the selected segment). Pixel output is meant to match the old
inline code. `HeliosEmptyState(symbol:title:message:actions:)` is an icon,
heading (`.isHeader`), one sentence and optional actions; the icon moves above
the text at accessibility sizes and its badge uses `@ScaledMetric`.

**Progress.**
- The range picker now sits in the same section as the weight trend, directly
  above it, and has the accessibility label "Weight trend range". This follows
  the "one filter row above the charts it scopes" rule.
- The Calories card gets a "Nutrition" header that reads "Last 7 days · not
  affected by the range above". Food cards stay seven-day and aren't connected to
  the weight range.
- The Calories card says "No food logged in the last 7 days." when every bar is
  zero, so empty days don't look like measured zeros.
- The Macro split header wraps under its title when space is tight.
- The timeline is always one section with a "Timeline" header. The header
  detail reads "N check-ins · newest first · swipe to edit or delete", or "No
  check-ins yet". Month separators use the Helios section role.
- The empty timeline and empty weight chart use `HeliosEmptyState`. The weight
  empty state no longer draws a tinted panel inside the glass card. The
  "Log Weight" button now uses `.heliosSecondary` (it was `.bordered`). All copy
  is the same, including the string `testTextGrowthAcrossSizes` looks for.
- The weight chart has a small legend ("Weigh-in" dot, "Smoothed trend" line).
  It is hidden from VoiceOver because the chart hint already says the same thing.
- Timeline rows use Helios roles and tokens instead of system styles. The
  weight chip uses `accent.subtle` (the same wash as the selected segments). The
  photo placeholder uses raised glass, or the opaque fallback under Reduce
  Transparency. Under Increase Contrast the rail uses `border.strong`.
- Add/edit/delete, swipe actions, detail route, the delete alert and all
  identifiers are unchanged. New identifiers: `progressNutritionHeader`,
  `progressTimelineHeader`, `progressEmptyAddCheckIn`.

**Today.**
- The Left/Eaten switch uses the shared segment parts.
- "No food logged today" gains a `fork.knife` icon.
- When there are no goals, the goal hint becomes an accent button
  (`todaySetGoals`, at least 44 pt) that calls the existing
  `caliberProfileAction`. It falls back to the previous plain text when no
  action is in the environment. No goal logic or routes are added.
- The Train card's icon tile uses `accent.subtle` instead of a hard-coded
  14% accent.

**Appearance preview** (`AppearancePreviewPicker(selection: Binding<AppTheme>)`).
- Shows System, Frost (Light), Graphite (Dark) and OLED Black as buttons. Each
  one draws a miniature screen in its own palette: canvas, one glass card, text
  bars, the protein/carbs/fat colours and the accent. System is split
  Frost/Graphite, and OLED uses a black canvas.
- Selection is shown by an accent edge, a check mark, an accent wash and the
  `.isSelected` trait.
- The previews follow Increase Contrast (they show the high-contrast palettes)
  and the viewer's Reduce Transparency. Nothing animates.
- The grid is one column at accessibility sizes and two columns otherwise.
  Labels use the same names as the existing picker, and each button has a hint
  (for example "Grey and black glass").
- Identifiers are `appearancePreview` and `appearanceTheme-<rawValue>`.
- It stores nothing new.

## Requested integration patch (Codex-owned files)

1. `Views/Foundation/FoundationSettingsView.swift`, in "Appearance and Privacy":
   put the preview above the existing picker, and keep `appearanceTheme`
   working so current tests still pass. One option is to keep the picker for
   VoiceOver/rotor users:
   ```swift
   AppearancePreviewPicker(selection: $runtime.settings.theme)
     .listRowBackground(Color.clear)
     .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
   ```
   Alternatively, replace the picker and update tests that tap `appearanceTheme`.
2. `scripts/test_ios.py`: add
   `'-only-testing:Caliber (DEV)UITests/VisualPass2UITests'` to `UI_SUITES`.
3. `scripts/lint_foundation.py`: optionally add
   `Views/Progress/ProgressDashboardView.swift`, `ProgressTimelineRow.swift`,
   `Views/Components/AppearancePreviewPicker.swift` and
   `Caliber (DEV)UITests/VisualPass2UITests.swift` to the strict swift-format
   list. Run swift-format on the already-listed Today/ProgressCards/WeightTrendChart
   files either way, because I could not.
4. `docs/DESIGN.md` §4: optionally add rows for `HeliosSegmentTrack`/`HeliosSegmentHighlight`
   (look-book segmented control) and `HeliosEmptyState`.

## Verification

| Check | Result |
| --- | --- |
| `python3 scripts/gen_tokens.py --check` | PASS: tokens up to date (no token changes) |
| `python3 scripts/check_lookbook.py` | PASS: 0 problems |
| `python3 scripts/lint_dynamic_type.py --strict 'Caliber (DEV)' Packages` | PASS: 207 files, 0 errors, 0 warnings |
| `python3 -m unittest discover -s scripts -p 'test_*.py'` | PASS: 130 tests |
| `python3 scripts/verify_phase1.py` | PASS |
| `python3 scripts/lint_foundation.py` | NOT RUN: needs `xcrun swift-format` |
| `swift test --package-path Packages/HeliosDesign` | NOT RUN: no Swift toolchain (download host blocked) |
| Xcode build, unit tests, `ThemeIntegrationUITests`, `VisualPass2UITests` | UNTESTED |
| Graphite/Frost before/after and AX5 captures | NOT PRODUCED |

Commands for Codex:

```sh
python3 scripts/lint_foundation.py
swift test --package-path Packages/HeliosDesign
python3 scripts/test_ios.py --output /tmp/caliber-visual-pass2
# focused:
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:'Caliber (DEV)UITests/VisualPass2UITests' \
  -only-testing:'Caliber (DEV)UITests/ThemeIntegrationUITests' \
  -only-testing:'Caliber (DEV)UITests/ProgressUITests' \
  -only-testing:'Caliber (DEV)UITests/LookbookPolishUITests'
```

Captures to take: `ThemeIntegrationUITests.testGraphiteScreens`,
`testFrostScreens` and `testLargestTextScreens` (Progress and Today), plus the
`#Preview` in `AppearancePreviewPicker.swift` in both themes at AX5.

## Risks and limits

- **Compile risk.** I watched most closely for: `AnyLayout` in `HeliosEmptyState`
  (iOS 16+/macOS 13+, inside the package floor); `switch` expressions returning
  `LocalizedStringKey` in `AppearancePreviewPicker` (Swift 5.9); and the `if`
  inside `Section` content in Progress.
- **Layout to check on device.** Progress rows: the range picker's new bottom
  padding inside a zero-inset row, and the spacing of the new section headers.
  Today: the goal hint button height inside the Fuel card at AX5. Check that the
  repeated AX5 clipping audit still passes. No audit suppressions were added.
- The Progress empty state and the Calories empty note never invent values. No
  statistics, projections, hydration/Health data, card personalisation or global
  date selection were added.
- `VisualPass2UITests` assumes the `--progress-ui-testing` store starts empty,
  which `testTextGrowthAcrossSizes` also relies on.
