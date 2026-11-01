# Claude — energy display consistency

Use the existing Caliber native chat and Opus 5.5 if actually available. Inspect
current branch/dirty state/job before doing anything; do not disturb old work.
Read AGENTS.md and current AI_HANDOFF. Fetch `origin/codex/integrated-iphone-qa`,
verify its published HEAD includes e5aaa04, then create a clean separate checkout and new branch
`claude/energy-display`. Report actual model, checkout, seed and acknowledgment.

Fix the source-review finding in parallel/cards-widgets/CLAUDE_HANDOFF.md rank 2:
Diary, food search and copy previews show raw kcal while Today honors EnergyUnit.
Use the existing UnitFormatting conversion/formatting contract exactly once for
display. Label kJ as kJ and kcal as kcal. Never convert stored values, serving
inputs, package-label facts or personal macro overrides. Avoid using a rounded
display value in calculations. No health formula change or snapshot-schema change.

Owned implementation files:
- Caliber (DEV)/Views/Diary/DiaryView.swift
- Caliber (DEV)/Views/Diary/FoodSearchView.swift
- Caliber (DEV)/Views/Diary/CopyDiaryView.swift
- A new narrowly scoped display helper if necessary under Views/Components,
  named CaliberEnergyDisplay.swift (no edits to shared existing components)
- New focused energy-display tests only, with a unique filename
- docs/parallel/integrated-iphone/CLAUDE_HANDOFF.md

Do not edit FoundationSettingsView, RootTabView, widget sources, packages/math,
global docs, project files or existing tests. Report any cross-boundary need for
Codex. Keep numeric editors explicitly in their source kcal unit until separately
reviewed; this task is display consistency. Preserve number-free behavior,
48pt actions, centered meal headers, card gestures, the reviewed widget request/
navigation-path handling in Diary and every food source route.

Validate fractional kcal and kcal/kJ labels, food rows/copy totals and canonical
value preservation. Run available non-simulator checks; do not run native jobs
alongside Codex. State exact unrun checks honestly. Reread diff, conventional
commit and push only your branch. Handoff includes file list, rationale,
test results, limitations, commit, and any energy-display surfaces still outside
your scope. Codex will review, update Settings wording and run native regression.
