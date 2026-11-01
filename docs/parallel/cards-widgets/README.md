# Cards and iPhone widgets — 2026-11-01

Owner authorized Codex to coordinate Claude and Gemini and implement swipeable
info cards and iPhone widgets. Seed: e6ba3ec. New work supersedes the older
window-beta ownership pack only for these assigned branches. Preserve old work.

| Owner | Branch | Exclusive paths |
| --- | --- | --- |
| Codex | codex/cards-widgets | project/entitlements, shared widget contract and persistence, runtime/settings/deep links, aggregate docs, integration tests |
| Claude | claude/cards-widgets | TodayFoundationView.swift; new Views/Components/CaliberInfoCardPager.swift; dedicated pager UI tests; CLAUDE_HANDOFF.md |
| Gemini (owner Mac) | gemini/cards-widgets | CaliberWidgets/NutritionWidgetView.swift; CaliberWidgets/WidgetPreviewFixtures.swift; GEMINI_HANDOFF.md |

Both peers: independently inspect current source and report the five most
important unfinished app areas, evidence, priority and bounded next action.
Do not describe a source review as runtime evidence. Commit only owned files.
Do not merge, rewrite old branches, edit global docs, run simulator jobs, change
providers/math/storage, or touch the owner's local-preview checkout or data.
Codex reviews each diff and runs the isolated native checks sequentially.

## Card contract

Diary already has an accessible swipeable daily summary; do not redo Diary or
meal headings. Claude extends Today fuel information with Calories/Protein/Carbs/
Fat pages using existing logged totals and goals. Keep workout and other actions
visible. No auto advance; named tap alternatives, page announcement, 48pt targets,
AX5 wrapping and Reduce Motion. Limit drag to the value panel so vertical scroll
and row deletion remain intact. Do not infer missing values or new goals.

## Widget contract (frozen for peers)

Codex owns Foundation-only `NutritionWidgetSnapshot` in CaliberCore. Public read
properties: `generatedAt: Date`, `expiresAt: Date`, `dayStart: Date`,
`timeZoneIdentifier: String`, `nutrition: NutritionWidgetValues?`.
Values: `calories: Double`, `proteinGrams: Double`, `carbohydrateGrams: Double`,
`fatGrams: Double`. Calories use recorded kcal, never macro-derived estimates.
`displayState(at: Date, timeZone: TimeZone) -> NutritionWidgetDisplayState` returns
`.private`, `.current`, `.stale`, or `.unavailable`. Defaults contain no nutrition.
No goals in v1 snapshot, no account/Stack/weight/notes/photos/food names.

Gemini creates `NutritionWidgetView: View` with public/internal initializer
`init(snapshot: NutritionWidgetSnapshot, now: Date)` and reads
`@Environment(\.widgetFamily)`; supports small and medium. Imports SwiftUI,
WidgetKit, CaliberCore and HeliosDesign. Codex supplies extension entry/provider.
Use existing themes/tokens; support system light/dark as Frost/Graphite. Neutral
private/empty/stale states show no numbers. One small Open Fuel action and medium
Open Fuel/Add food links may use `caliber://fuel` and `caliber://food/add` (Codex
owns routing). No interactive logging or network calls. Fixture values must be
explicitly fictional and confined to preview fixture source.

Codex implements opt-in sharing default off, writes only after successful saves,
expires at local midnight (or earlier invalidity), rejects timezone mismatch and
invalid/nonfinite values, removes shared values on opt-out and dataset switch.
Do not enable sharing in the owner's app or access its private store.

## Delivery

Each peer handoff: seed/commit, files, design reasoning, tests actually run,
known gaps, five ranked independent app findings. Push own branch if available;
never claim iPhone/widget validation without native evidence. Codex owns target,
signing/build, privacy review, aggregate verification and local preview updates.
