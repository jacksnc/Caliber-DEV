# Claude assignment — second visual pass

Work on `claude/visual-pass-2` from the seeded common base. Read
[coordination and ownership](README.md), root `AGENTS.md`, `docs/DESIGN.md`,
`docs/LOOKBOOK_ALIGNMENT.md` and `docs/RECORDING_FEATURE_REVIEW.md` first.
The owner requests native implementation, not another HTML-only look book.

## Deliver

1. Refine owned Helios surfaces, spacing, headings, charts, selections and empty
   states in Today/Progress toward the committed reference. Extend the native
   pass; do not replace working screens with mock data or fixed screenshots.
2. Keep Graphite/Frost visually coherent, semantic macro colors stable, and
   Reduce Transparency/Increase Contrast/Reduce Motion behavior intact. Touch
   token values only if there is a demonstrated need and regenerate/audit them.
3. Make Progress hierarchy and timeline affordances clearer. Keep the actual
   photo/weight/notes timeline and all add/edit/delete routes. Do not add new
   statistics, projection math, hydration/Health data, card personalization or
   global date selection in this PR.
4. Deliver an accessible standalone appearance-preview component in a new owned
   component file if it improves Settings. Keep its inputs simple (`Binding` to
   existing theme selection); document insertion for Codex rather than editing
   `FoundationSettingsView`.
5. Maintain accessible tap targets, scalable/wrapping text, honest empty states,
   chart method access, and the no-bleed floating dock. Preserve identifiers and
   public view initializers/callbacks.

## Verification

Run token generation check, look-book validator, Helios package tests, strict
Dynamic Type lint and native ThemeIntegration tests where available. Include
before/after Graphite/Frost captures and AX5 captures from fictional fixtures.
Record skipped/unavailable checks explicitly. Add focused `VisualPass2UITests`
only for meaningful behavior/layout regressions; no audit suppressions.

Update only [your handoff](CLAUDE_HANDOFF.md), commit conventional changes, push
your branch and return its commit/PR. Do not merge into integration or modify
Gemini/Codex-owned paths. Use original symbols/assets and our design tokens;
recording features are references, not permission to copy competitor material.
