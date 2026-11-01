# Diary headers, swipe card and widgets session

Date: 2026-11-01 (America/New_York)
Branch: `codex/v2-meal-headers`
Worktree: `/Users/jcrock/Documents/Codex/Caliber-v2-meal-headers`
Base: `ccd74c1`

## Owner request

Improve the Breakfast/Lunch/Dinner/Snack headings; let the nutrition cards swipe
between useful recorded data; create a phone-widget and swipe-card lookbook; ask
Claude and Gemini for independent improvement ideas. Preserve owner data and
keep the work isolated from the personal preview checkout/device.

## Work delivered in this branch

- Native Diary meal headers are centered, include saved item count + recorded
  calories, and expose visible Copy/Add food controls. Actions retain their
  automation identifiers and 48pt minimum size; narrow or large text uses a
  stacked fallback. Empty meal headers still show a 0 item / 0 calorie summary.
- Native daily summary pages through Calories → Protein → Carbs → Fat. Horizontal
  drag is limited to the value panel; metric-name buttons and labeled previous /
  next buttons provide touch alternatives. VoiceOver receives selected page
  information, adjustable behavior and named next/previous actions. The page
  changes immediately without a sliding animation. All values/goals come from
  current `MacroTotals` and `UserProfile`; no new calculations or models.
- `design/lookbook-v2/cards-and-widgets.html`, `.css`, `.js` is a local
  interactive Graphite/Frost prototype for the swipe card, Small/Medium/Large
  phone widgets and a locked-screen privacy preview. Fictional showcase values
  only. The PDF handoff is
  `output/pdf/Caliber-Cards-and-Widgets-Lookbook.pdf` (5 landscape pages).
- No WidgetKit target, App Group, entitlements, widget persistence, shared
  snapshots, external network access or local-user-data path was added.

## Peer review

Prompts were sent in the owner's already-open native Claude and Gemini chats.
Both completed bounded design-only reviews without editing files or running
builds.

Claude (Opus 5.5) recommended one shared selector controlling the current metric
shown across the meal headers, with visible labels as well as swipe, so all meals
remain comparable. It recommended the order Calories → Protein → Carbs → Fat →
Items, honest empty-state messaging, VoiceOver page actions and keeping paging
out of food rows. It specifically warned against whole-card paging and a
`TabView` inside `List` because of delete-gesture and large-text clipping risks.

Gemini (3.8 Flash Medium) recommended a per-meal Overview → Macros → Foods pager,
with named page controls and VoiceOver next/previous actions. For widgets it
suggested Small = energy anchor, Medium = energy + three macros, Large = meal
breakdown; use system-managed sensitive redaction, empty-state prompts, a saved
snapshot time rather than polling, and Graphite/Frost semantic colors. It also
outlined the future extension/App Group/timeline boundary, which is not
implemented here.

Decision: use one shared daily summary card with four metric pages rather than
paging each meal section. It directly satisfies the requested swipe, keeps the
gesture away from editable/deletable rows, and preserves cross-meal comparison.
Header alignment is centered because the owner requested it; peer preference for
leading alignment is recorded but not followed. See V210 in `docs/DECISIONS.md`.

Apple references used to keep the widget proposal platform-grounded:

- [Widget Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/widgets)
- [WidgetFamily](https://developer.apple.com/documentation/widgetkit/widgetfamily)
- [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
- [Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)

## Verification checkpoint

- `xcrun swift-format lint --strict ...`: passed after the final Swift changes.
- `python3 scripts/lint_foundation.py`: passed after the final Swift changes.
- `python3 scripts/lint_dynamic_type.py --strict`: 224 files, 0 errors, 0
  warnings after the final Swift changes.
- HTML parser: passed, unique IDs; bundled Node `--check` passed.
- `git diff --check`: passed after the final source/docs changes.
- Isolated UI suite: the final 3-test run passed 3/3 on `Caliber Compact QA`
  (iPhone SE 3, UUID `2998CE67-7D71-460B-AD69-76DAA4D014F6`). It covers all
  four headers, 48pt actions, Frost accessibility-size layout and metric-button/
  arrow navigation. A one-test direct swipe rerun passed (1/1), and the Graphite
  Breakfast screenshot was exported and inspected. The earlier 0-passed
  runner-canceled bundle is retained as an initial failed attempt, superseded
  by the later passing runs.
- An incremental `xcodebuild build` on the same isolated QA simulator is being
  rerun after the metric pages; record its final exit code and any warnings.
- Latest `xcodebuild build` exited 0 on the isolated QA destination. Xcode logs
  the non-fatal scheme/destination line `Supported platforms for the buildables
  in the current scheme is empty`; there are no Swift compile warnings after the
  earlier localized-string interpolation warning was corrected.
- A separate `xcodebuild test` run of the direct swipe + metric controls passed
  1/1; another header capture run passed 1/1. The screenshots show the centered
  Graphite meal summary and verify the large-text Frost layout visually.
- PDF exporter uses the bundled ReportLab runtime. All five pages were rendered
  and visually reviewed; an overlapping locked-state paragraph/button on page 4
  was fixed, regenerated and re-rendered without clipping. Browser preview of
  file URLs was denied by the native browser security policy; do not bypass it.
  Static HTML/JS checks are allowed.
- The owner's personal iPhone17 simulator and local preview checkout were not
  opened, modified or installed by this session.

## Final steps

1. Commit the reviewed changes with a conventional local commit. Do not push,
   merge, or install into the owner's preview build unless the owner asks.

## Next after this checkpoint

Once the owner reviews/accepts the card interaction, test it on the intended
physical iPhone; next cover foldable layouts and iPad. A native WidgetKit
extension needs its own reviewed data-sharing/privacy contract before coding.
