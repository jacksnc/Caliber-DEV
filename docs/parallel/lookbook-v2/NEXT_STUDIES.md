# Bounded graphics, widgets and beta studies

Planning only. Start these after the V2 book/handoff checkpoint and iPhone work.
Original logo on black with gold infinity is deferred at the owner's request.

## Graphics process

Each assigned model writes its own brief: purpose, placement, two theme palettes,
size variants, accessibility fallback and prohibited content. Produce two or
three original concepts, critique at actual display size and select one with
source, prompt, model/tool, creation date and asset rights/provenance. Code-native
CSS/SVG/SwiftUI art is preferred for UI. Bitmap art is appropriate for optional
illustrations, with no generated text, numeric scales or medical measurements.
No competitor screenshots/assets, stock bodies, personal photos or remote fonts.

First candidates: a quiet empty-diary illustration; a progress check-in motif;
an activity illustration. Do not add decorative art above the primary logging
action. Compare Frost contrast, reduced motion/transparency and large text.

## Widget roadmap

| Priority | Widget | Visible default | Tap destination | Required implementation work |
| --- | --- | --- | --- | --- |
| First | Nutrition + Add Food | Optional daily energy/macros, neutral empty state | Existing food hub with current day | WidgetKit target, consented shared snapshot, freshness label, locale/day-boundary tests |
| First | Resume workout | Workout name and saved progress, no inferred prescription | Existing active workout | Stable deep link, stale-session handling, snapshot after successful save |
| Next | Progress check-in | Private-neutral check-in action; weight/photo hidden by default | Existing progress capture | Per-field display consent, locked-device rules, image exclusion and freshness |
| Later | Private Stack shortcut | Neutral app/action name; no compound, amount or schedule | Opted-in locked Stack entry | Separate opt-in, authentication route, no protected-store snapshot to widgets |

Small/medium home-screen first. Accessory/lock-screen widgets must default to
neutral shortcuts. No account tokens or health records in a shared container.
Shared snapshot is a new privacy boundary requiring a documented data contract,
expiry and explicit review before implementation. No AppGroup/WidgetKit target,
entitlement or direct logging intent is added by this design plan.

## Fictional 3D syringe study

Goal: test whether a restrained, rotatable illustration clarifies a validated
measurement without hiding its exact text. Begin as an explicitly fictional
design prototype, separate from the real Stack logbook and all runtime routes.
Use procedural geometry/materials with a flat fallback; no real drug names,
suggested doses, recommended protocols or inferred final solution volume.

The future render contract must carry validated source labels, exact canonical
decimal values, display strings, syringe calibration/capacity and rendering
status from a reviewed engine. mL, mass and syringe markings are distinct;
biological IU cannot be inferred from syringe markings. Tick positions and fill
must derive from that validated contract. Never read a number from generated
art. Unknown calibration, invalid/out-of-range input or ambiguous final volume
shows an unavailable state, not a plausible-looking fill. Exact text/table is
primary; 3D is redundant. No animation of administration or dose recommendation.

Golden-vector, unit-conversion, rounding, locale and range tests precede any live
wiring. STK-06 eligibility/legal/clinical review in docs/COMPLIANCE.md remains a
release blocker; fictional art does not clear it. No new live calculator here.

## AI-assisted beta matrix

1. iPhone: existing food add/edit/copy, goals cancel/save, workout resume/set
   editing, progress photo/weight/notes and Stack opt-out/lock. Use fictional
   stores and owned simulators only; no health inference or real account writes.
2. Frost first, then Graphite: default text, AX sizes, keyboard, long names,
   no goals, empty data, number-free mode, reduced motion/transparency/contrast.
3. iPad/resizing: compact and wide split views, orientation changes, narrow
   windows and keyboard. Foldable means adaptive layout study, no Android port.
4. Separate design review from evidence: each finding names screen, steps,
   expected/actual behavior, severity, reproduction, screenshot and exact build.
5. Fix reproducible P0 bugs first. Rank feature proposals by logging friction,
   accessibility, implementation cost and existing brief priority. Do not use
   model agreement as proof of correctness or auto-enable gated features.

Owners: Codex integrates native work and evidence; Claude critiques hierarchy and
graphics; Gemini reviews responsive food flows and Frost. Peer work remains in
separate branches with file ownership refreshed before each new batch.
