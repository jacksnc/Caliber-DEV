# Verification plan

Phase 0 · 2026-10-07. This is a **plan**, not passing test evidence. No future engine, production migration runner or security suite is implemented by this plan. Disposable SQL tests and a fresh baseline of the existing iOS app were executed separately; their exact scope and evidence are in [VERIFICATION.md](VERIFICATION.md). Supplied arithmetic checks are not clinical validation.

## Evidence rules

Every P0/P1 requirement ID maps to a planned test ID in the Phase 0 traceability registry; P2 is recorded for later specification. See VERIFICATION.md for executed Phase0 schema and existing-app checks. A test record must identify build/commit, fixture/source version, platform/device/OS, runner command, result artifact, expected values/tolerance and reviewer. Planned, blocked, executed-pass and executed-fail are distinct states. A demo that renders is not a persistence or accuracy test.

Use a future pure Swift package for deterministic core engines; Swift Testing/XCTest for unit/integration tests and XCUITest for native flows. The native architecture ADR replaces the brief's Jest/fast-check tooling, not its coverage/property requirements. Do not invent passing coverage: core math/schedule/insight engines require 100% branch coverage and meaningful boundary assertions; overall code target ≥80%. Track exclusions explicitly. Property generation must be deterministic with retained failing seeds.

## Planned core test matrix

| Test family | Fixtures and invariants | Gate / brief mapping |
| --- | --- | --- |
| T-MATH-01 e1RM | Four 100×5 vectors in HOW_WE_CALCULATE; source-approved Mayhew/Wathan/Lander examples (±0.1 per brief); zero/negative/overflow and singularity inputs; RPE adjustment, >12 rule and unlogged effort. | M01 proposed; source verification gate; Train e1RM / §9.3 |
| T-MATH-02 volume/sets/PR | Warm-ups, BW+added/BW−assist, per-hand versus both-hand, unilateral sets, primary1/secondary0.5, RIR4/just above/missing; heavy 5-rep set updates records1–5, ties do not, edit/delete rebuild. | M02 proposed; Train volume/fractional/PR |
| T-MATH-03 units | Exact 1 lb→0.45359237 kg; repeated conversions preserve entered135lb; finite/domain validation; locale decimal inputs; explicit physical dimensions; fixed-point dose arithmetic, overflow rejection. | §9.1; FUEL/BODY/STK |
| T-MATH-04 targets | Formula examples from pinned sources, activity multipliers, no exercise double-count; zero/missing/invalid demographics; no negative macros; floor/override/BMI/rate scenarios approved by clinician. | M05; FUEL targets / BODY-07 |
| T-MATH-05 EWMA | Seed80kg; next day82→80.2; then84 after3-day gap→81.2298. Flat/noisy/gappy histories; same-day policy, timezone changes, edits/deletes and source duplicates. | M03; BODY-01 |
| T-MATH-06 expenditure | Synthetic mean2500kcal over14 elapsed days, trend−0.5kg→2775; +0.5kg→2225. Boundary coverage, skipped days never zero, clamp±150, window endpoints and confidence. | M04; FUEL expenditure. Synthetic tolerance is arithmetic, not real-world accuracy. |
| T-MATH-07 nutrition | 4P+4C+9F+7alcohol;10% boundary/zero denominators; per100g/per-serving/raw-cooked basis; label calories preserved; recipe scaling and residual rounding. | M06; FUEL / AI grounded logging |
| T-MATH-08 draw | All four anonymous vectors in HOW_WE_CALCULATE; dose→draw→dose properties across valid calibrated devices; mg↔µg, mL↔µL; reject IU↔mass without approved potency, ambiguous units/clicks, zero divisor and overflow; barrels and warning boundaries. | M07/M08 and policy gate; STK-06 |
| T-MATH-09 inventory | Whole-amount floor plus remainder, supplied waste/priming; no negative stock; edit/delete/retry adjusts once; variable/PRN supply is unknown unless defined. | STK-04/07; no invented schedule |
| T-MATH-10 illustrative amount | At t0 instant model D; one half-life D/2; linear superposition for same unit/compound; no future-event contribution; unknown half-life disabled; ka=ke analytic limit and continuity near it; positive interval accumulation. | M09; STK-10/16 |
| T-MATH-11 insight | Known positive/negative ranks, ties, constants, <14 pairs, missing dates, lag direction; seeded bootstrap; flat/noisy/outlier series; threshold boundaries, MAD=0 and duplicate times; no causal copy. | M10/M11; §3.5, VZ-X2/X6 |
| T-MATH-12 standards/plates | Pinned official coefficient worked examples for categories/units; exact available plate pairs and inventory counts, impossible target, minimal viable load, kg/lb and bar/collar weight. | M12; Train standards/plate calculator |

## Planned persistence, scheduling and integration

- **T-DATA:** disk-backed migration of representative existing SwiftData stores, including independent restaurant log snapshots, decimal macros, custom menu edit/delete, saved meals, legacy weigh-ins and external photo bytes/order. Reconcile IDs/relationships/entered units and counts, reopen a fresh container, rebuild identical rollups. Failure injection at each migration boundary; verified restore before destructive steps. No live-user store as a fixture.
- **T-DURABLE:** confirm entry only after commit; kill immediately after set/meal/dose/check-in confirmation and reopen. Full disk, permission failure, interrupted photo import and failed save must show an error and preserve previous data/unrelated work. Test on iOS: a macOS SwiftData pass is insufficient for relationship/cascade behavior.
- **T-SCHEDULE:** property tests for DST gaps/overlaps, leap days, month end, every-N-day and RRULE schedules, travel/floating/fixed times, pause/resume and protocol versions. PRN generates no invented next dose. Duplicate notification/widget/Watch/Siri actions and snooze/skip/taken races resolve idempotently. Missed reminder is not taken medication.
- **T-SYNC:** offline writes, two-device edits, repeated delivery, clock skew, cursor interruption, delete/edit conflict and reinstall/restore. Tombstones never resurrect deleted photos/logs; no silent conflict loss; authorization covers storage, RPCs and realtime as well as tables.
- **T-SOURCE:** source adapters retain IDs, citation, effective/retrieval dates and serving basis; menu refresh cannot alter historical nutrition snapshots. License/provenance lint blocks unapproved assets, real-compound dose presets and uncited reference coefficients.

## Planned safety, AI and privacy

- **T-GUARD:** exercise every checkbox in COMPLIANCE §11.1–12. Stack absent-build test proves routes, reference data, schema access, notifications and entitlements are absent. Region/remote disable handles offline/stale states without deleting records. No vendor/public protocol routes. Unknown data is visibly unknown.
- **T-BODY:** clinical-review fixtures for low intake, rapid-loss goals, repeated overrides, unspecified coefficient eligibility and number hiding; no moral food labels. Hiding covers chart accessibility labels, widgets, notifications, exports and recaps. Support resources are local and reviewed.
- **T-AI:** ≥100 versioned red-team prompts covering dosing, titration, combinations, sourcing, diagnosis, extreme dieting, prompt injection, obfuscation and “just hypothetical” requests. Verify no advice/dose generation, safety filters, refusal and no sensitive telemetry. Confirmation required before critical writes; schema/authorization reject tool misuse. Database evidence must support every macro value; AI-off/manual paths work.
- **T-PHOTO-EVAL:** ≥200 consented/licensed meal examples, held-out evaluation split, actual nutrition/portion ground truth and recorded uncertainty. Report median/P90 absolute percentage error for kcal/protein, defining zero-reference handling. Re-run model/prompt changes; detect confidence miscalibration and mismatched restaurant variants. No real-user photos used without explicit appropriate rights.
- **T-SEC:** execute SECURITY matrix: cross-account denial, least privilege, Keychain/locked state, TLS, protected attachments/temp/WAL/backups, EXIF, biometric/deep-link bypass, logs/crash/SDK canaries, consent revocation, export/deletion/retention and incident tabletop. Static scanning alone does not satisfy these checks.

## Planned visual, performance and release checks

Every chart needs golden images and accessibility tests: empty/single/flat/noisy/gappy series, mixed units, large text, VoiceOver, reduced motion and light/dark contrast. Accessible tables expose values without requiring gestures. Downsampling preserves visible gaps and important extrema; drill-down reads original data.

On a named mid-range physical device, measure cold start <2s;60fps scrolling/scrubbing; cached first paint <150ms for1year and <400ms for5years; local-query p95<50ms; set-log write<30ms. §3.1 also asks for <150ms first paint with five years. Adopt that stricter 150ms target for both ranges and report both the 150ms and 400ms thresholds; neither has been measured in Phase 0. Record dataset size, percentile, warm/cold state and build. Beta crash-free sessions target≥99.5%; no continuous GPS or unrelated background polling. Telemetry for these measurements must not contain health content.

Release requires a fresh app build/unit/integration/UI suite, appropriate physical-device runs, reviewed coverage, migration restore rehearsal, source/license audit and the signed COMPLIANCE checklist. None of these future results is claimed by Phase 0.
