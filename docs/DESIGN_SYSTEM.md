# Design system

The native app now consumes `Packages/HeliosDesign` and `design/tokens.json`. See `DESIGN.md` for the imported Graphite/Frost specification and `THEME_INTEGRATION_VERIFICATION.md` for app evidence. The proposal below is retained as the original component contract; its old `architecture/design-tokens.json` palette is not the runtime color source.

## Original proposal

Machine-readable values: `architecture/design-tokens.json`. Semantic tokens are the only way product views choose color/type/spacing. Dark is initial theme; light and OLED use the same semantics. Red is reserved for safety. Domain hue is stable for Train/Fuel/Stack/Body. Gains/losses and intake overages use neutral labels and geometry, not good/bad colors.

## Components and contracts

| Component | Input / behavior | Accessibility / verification |
|---|---|---|
| ChartCard | title, deterministic insight, ranges, method, count/coverage, flags | summary + data table; Why reveals inputs; largest Dynamic Type |
| Ring / StatTile | actual, target, units, optional sparkline | overflow arc; explicit numbers or hide-numbers equivalent |
| QuickLog | enabled domains; recent actions | ≥48pt reach targets; keyboard/VoiceOver focus |
| SetRow | previous and current values, set kind, complete/undo | tabular digits; labels and glyphs; no color-only status |
| BodyMap | stable muscle/site region IDs, numeric mode, legend | equivalent region list; front/back not encoded by tint |
| Timeline / heatmap | dated events, gaps, shared cursor | day list and event table; missing ≠ zero |
| Syringe / barbell | exact calculator result DTO | geometry and text share values; unit/capacity validation |
| PhotoCompare | user-owned images, chosen mask, optional numbers | private capture/export; neutral guidance; no body scoring |
| EmptyState | required input count, explicit illustrative sample | never present fictional values as the user's history |
| MethodSheet | formula version, assumptions, sources, confidence | readable plain language; localized accessible links |
| Error / conflict | durable command outcome, retry/resolve actions | persistent actionable text; no health values in logs |

Use SF system typography and tabular numerals, semantic sizes that scale rather than fixed pixel fonts, layout changes at accessibility sizes, 48pt minimum targets, safe-area bottom Quick Log. Background surfaces may be close in tone; controls and chart marks use contrast-tested borders/foregrounds. Categorical palette has at most eight colors, each paired with a distinct symbol/line pattern; contrast alone does not establish color-vision accessibility, which still needs simulation/device review.

Externalize strings in an `.xcstrings` catalog in Phase 1; localized measurement/date/number formatters take settings explicitly. Entered decimal text is retained for edit/display, while canonical numeric values power math. Bidi layout and large labels must not clip. Reduce Motion removes chart draw/celebration animation; normal draw duration capped at 300ms (<400ms brief budget). Haptics are optional and never sole confirmation.

Phase 0 validates token contrast for text and essential marks on surfaces. Full WCAG 2.2 AA, color-vision, VoiceOver and largest-Dynamic-Type audits are NOT established by token checks.
