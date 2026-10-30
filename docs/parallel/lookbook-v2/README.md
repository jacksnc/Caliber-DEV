# Lookbook V2 coordination

Owner authorized Codex, Claude Opus 5.5 and Gemini Argon in separate clones.
Read AGENTS.md, docs/LOOKBOOK_V2.md and your role task before editing.
This coordination pack supersedes pass2 ownership only for V2 work.

| Role | Branch | Owned files |
| --- | --- | --- |
| Codex | codex/lookbook-v2 | shell/index, base.css, board.js, fixture.js, diary.html, central docs/export/integration |
| Claude Opus 5.5 | claude/lookbook-v2-design | components.css; today.html, train.html, stack.html, progress.html; CLAUDE_HANDOFF.md |
| Gemini Argon | gemini/lookbook-v2-responsive | responsive.css; food-entry.html, food-review.html; qa/; GEMINI_HANDOFF.md |

All design paths are below design/lookbook-v2/. Handoffs live here.
Never edit another role's files, runtime Swift/tokens, existing v1 or CI.
Do not merge other branches; Codex reviews/integrates. Commit and push only your
assigned branch. Report needed cross-boundary changes in your handoff.
No native build/simulator needed for design work. Do not touch owner's personal
simulator or local-preview checkout. Do not buy credits/change plans/providers.
No personal health data, keys, proprietary menus or licensed assets in prompts.

## Frozen board contract
Standalone HTML: `html lang=en data-theme=dark`; head viewport meta, ../tokens.css,
base.css, components.css, responsive.css in that order; fixture.js then board.js
as deferred scripts. body class=v2-app and data-screen=today|train|diary|stack|
progress|food-entry|food-review. Include `header.app-header` and `nav.app-nav`
empty; shared script fills these. Put all your content in `main.content` with
id=main. Link CSS/scripts relatively. No external URLs, imports or fonts.
Screen title is from body data-screen. Query controls: theme=dark|light,
state=populated|empty|no-goals|long-name|number-free|locked|opted-out,
scale=1|2|3, glass=reduced, contrast=more. board.js sets html attributes.
Use data-state-only="empty" (space-delimited values allowed), data-state-except
and data-demo="key" for the frozen fixture. Generic shared classes below are
owned by Codex; Claude may add component classes without changing their meaning.

Common classes: card, eyebrow, section-head, muted, subtle, metric, num,
primary, secondary, icon-button, row, stack, divider, chip, grid-2, grid-3,
energy (centered overview), macro-grid, macro, meal-card, food-row, food-name,
food-amount, empty-state, sr-only. Use real heading order, buttons/links and
labels. Add `data-demo` for fixture values so totals remain consistent.
Optional meal=Breakfast|Lunch|Dinner|Snacks query retains review context.
Shared script hydrates data-context-meal labels/selects, carries meal through
data-board-link routes and prevents form submits in these design previews.
Fixture global: `window.CALIBER_DEMO` (frozen); no persistence/network calls.
Fixture is synthetic. Use static progress chart geometry from its samples and
provide an accessible text/table alternative. Never imply causal dose insights.
All preview actions explicitly report that no data is saved; board links work.

## Checkpoint
Deliver complete owned boards, not placeholders, with Graphite/Frost screenshots
and truthful checks. Codex will aggregate and export after review. App unchanged
until that checkpoint; native iPhone verification precedes iPad/resizing and beta.
