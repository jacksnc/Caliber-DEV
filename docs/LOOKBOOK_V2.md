# Caliber Lookbook V2

Design checkpoint, not a shipped native build. Base: 8f71cff, 2026-10-30.

## Plan
1. Freeze shared fixture, semantic tokens, screen vocabulary and file ownership.
2. Create Today, Train, Fuel, Stack and Progress in Graphite and Frost.
3. Give Fuel a centered energy summary, balanced macros and clear meal cards.
4. Show the food hub and editable portion/macros review as related boards.
5. Review narrow/large-text/empty/privacy states before native implementation.
6. Export an inspected PDF; map components to existing SwiftUI screens.
7. Implement and verify iPhone first, then iPad/resizing layouts.
8. Run AI-assisted beta, especially Frost; propose ranked additions separately.

## Visual direction
Keep Helios Graphite/Frost identity and semantic palette from design/tokens.css.
Center the summary, not every label. Align food names to the reading edge and
quantities consistently. Prefer intentional spacing, an unmistakable hierarchy,
rounded cards, thin dividers and restrained depth. Avoid making glass the only
source of readable contrast. No decorative gradient may weaken text contrast.
System fonts, original CSS/SVG geometry, no copied competitor assets or logos.
The black/gold infinity logo is deferred.

## Required boards and states
Five main tabs in both themes; Fuel additionally has empty, no-goals,
long-name and number-free states. Stack has locked and opted-out states.
Food hub leads to a meal/date-aware review with editable macros and portions.
Any static illustrative control must be identified as a design preview rather
than implied working persistence. No health model changes in this phase.
Fictional values are from fixture.js; kcal is reported energy, not 4/4/9 inference.

## Layout and accessibility acceptance
320, 375, 390, 430, 480-point widths; short landscape; 200% and 300% text stress.
No horizontal overflow or clipped content; scroll instead of fixed content height.
Main controls at least 48 CSS px. Persistent tab layout may adapt to keep labels
readable. Preserve visible focus, names, contrast and reduced-motion/opaque modes.
HTML font stress is not evidence of native Dynamic Type or VoiceOver support.
iPad/resizing boards follow the approved iPhone checkpoint, not an Android port.

## Later bounded design studies
Original graphics: write a prompt, produce at most three concepts, critique and
select with source/provenance. Prefer code/vector UI artwork. Widgets: nutrition
and Add Food, workout resume, progress check-in; later private Stack deep link.
No WidgetKit/AppGroup work yet. Syringe study uses only fictional render data;
exact markings must be drawn by code, never inferred from an AI illustration.
No live dosage calculator, dose recommendation, unit ambiguity or STK-06 gate change.
See docs/COMPLIANCE.md and docs/HOW_WE_CALCULATE.md.

## Delivery
Canonical source: design/lookbook-v2/index.html. Shareable PDF follows visual QA.
Role handoffs include exact commit, checks, limitations and native mapping.
No migrations; no provider, dataset, math, feature flag or installed-app change.
