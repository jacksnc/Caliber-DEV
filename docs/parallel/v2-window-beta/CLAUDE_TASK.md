# Claude — compact-height Diary

Use Opus5.5 in the existing Caliber native thread. Start a clean, separate
claude/v2-compact-diary checkout from the published coordination seed. Preserve
all previous checkouts/branches and unrelated changes. Read AGENTS and README.

Observed native issue: output/screenshots/v2-responsive/compact/
responsive-frost-Fuel-landscape.png shows the Diary header/date/library rows
occupying most of the375pt-height viewport. It scrolls and preserves data, but
the initial energy figure is below the fold. Improve this compact-height layout
while retaining the V2 design and the normal portrait composition.

Own only DiaryView.swift's header/date/library presentation, a new focused
DiaryCompactLayoutUITests.swift if useful, and CLAUDE_HANDOFF.md here. Do not
change MacroTotalsSummaryView, calorie/macro/goal logic, day arithmetic, models,
services, shared appearance/navigation, settings, providers or any other screen.

Acceptance:

- Default compact-phone landscape leaves the calorie figure visible above the
  floating bar at the initial scroll position, if achievable within this scope.
  If that conflicts with readable text/targets, state the conflict instead of
  changing totals or shrinking fonts. Do not conceal actions in the name of fit.
- Keep previous/next day, date picker, Food Library and Copy a Day with the same
  identifiers, accessible names and at least48pt interactive targets.
- All text still scales. Long/localized labels wrap/reflow; AX sizes remain
  scrollable. Preserve state and one stable control set through layout changes.
- Date, Add Food, meal add/edit/delete/repeat/copy and saved targets retain their
  behavior. No implicit default goals, inferred macros or new food records.
- Add a meaningful viewport/action/state check rather than testing constants.
  Use full-screen screenshot capture; native Lists scroll via their actual
  gutter, not global x10 when centered. Never remove existing assertions.

Run checks available in your environment. No Xcode means native UNTESTED with
exact scoped commands for Codex; arithmetic or source review is not a simulator
pass. Commit/push only owned files. Handoff includes exact SHA, before/after
intent, checks actually executed and remaining risks. Stop after delivery. Do
not start tablet/beta/graphics work or write central status documents.
