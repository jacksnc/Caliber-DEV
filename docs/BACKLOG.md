# Backlog and delivery map

223 traceability rows: 211 explicit brief IDs plus 12 local subclause/integration IDs. 81 P0, 116 P1, 26 P2. Priorities are preserved; inclusion in a phase does not promote a P1 feature.

All listed acceptance tests are planned. Full P0 table/screen/test mappings are in REQUIREMENTS.md and architecture/requirements.json. P1 flags default off; P2 is not implemented. Cross-domain privacy gates apply even when a feature is enabled.

## P0

| ID | Phase | Feature | Current status |
|---|---|---|---|
| TRN-01 | 2 | ≥ 600 seeded exercises (target 800+) | not-implemented |
| TRN-02 | 2 | Unlimited custom exercises (free tier) | not-implemented |
| TRN-03 | 2 | Metric types | not-implemented |
| TRN-04 | 2 | Search/filter | not-implemented |
| TRN-10 | 2 | Start from | not-implemented |
| TRN-11 | 2 | Set row | not-implemented |
| TRN-12 | 2 | Auto-fill the next set from the previous set or plan target; "copy last set"; "fill remaining"; swipe to delete/duplicate; long-pr | not-implemented |
| TRN-13 | 2 | Set types (color + glyph) | not-implemented |
| TRN-14 | 2 | Supersets, giant sets, circuits | not-implemented |
| TRN-15 | 2 | Notes | not-implemented |
| TRN-16 | 2 | Mid-workout edits | not-implemented |
| TRN-17 | 2 | Live header | not-implemented |
| TRN-18 | 2 | Finish flow | not-implemented |
| TRN-19 | 2 | Bodyweight auto-attached from the latest weigh-in for BW-based exercises and relative-strength math | not-implemented |
| TRN-30 | 2 | Rest timer | not-implemented |
| TRN-31 | 2 | Plate calculator | not-implemented |
| TRN-32 | 2 | Warm-up generator from the top working set (default ramp 40%×8, 60%×5, 75%×3, 90%×1; editable templates; respects the plate invent | not-implemented |
| TRN-33 | 2 | 1RM and rep-max tools | not-implemented |
| TRN-40 | 2 | Routines | not-implemented |
| TRN-41 | 2 | Scheduling | not-implemented |
| TRN-50 | 2 | PR engine, evaluated live on ✓ and recomputed on edit/delete | not-implemented |
| TRN-51 | 2 | Per-exercise records table (rep-max grid, best e1RM/set/session, dates) and a records timeline | not-implemented |
| TRN-60 | 2 | Taxonomy of ≥ 18 regions | not-implemented |
| TRN-61 | 2 | Set-counting mode (user setting) | not-implemented |
| TRN-62 | 2 | Weekly volume per muscle (sets, tonnage, frequency) versus target bands (MEV/MAV/MRV or custom; common hypertrophy default ~10-20  | not-implemented |
| TRN-63 | 2 | Muscle heat map on a front/back body figure | not-implemented |
| TRN-70 | 2 | History as list + calendar; filter by exercise/muscle/routine; note search; edit/delete with automatic PR/stat recompute | not-implemented |
| TRN-71 | 2 | Per-exercise stats page (charts in §3) plus a full session table | not-implemented |
| TRN-72 | 2 | Compare a workout with last time, best, and the average of the last N | not-implemented |
| TRN-92 | 2 | Full CSV/JSON export of all training data | not-implemented |
| VZ-T1 | 1 | Macro rings | not-implemented |
| VZ-T2 | 1 | Training card | not-implemented |
| VZ-T4 | 1 | Weight tile | not-implemented |
| VZ-T5 | 1 | Week strip | not-implemented |
| VZ-T7 | 1 | Hydration | not-implemented |
| VZ-W1 | 2 | e1RM trend (hero) | not-implemented |
| VZ-W2 | 2 | Best set per session | not-implemented |
| VZ-W3 | 2 | Session volume | not-implemented |
| VZ-W4 | 2 | Rep-max grid | not-implemented |
| VZ-W9 | 2 | Session summary | not-implemented |
| VZ-W10 | 2 | Previous vs current | not-implemented |
| VZ-W12 | 2 | Weekly sets per muscle | not-implemented |
| VZ-W13 | 2 | Muscle heat map (hero) | not-implemented |
| VZ-W19 | 2 | Training calendar | not-implemented |
| VZ-F1 | 4 | Day macros | not-implemented |
| VZ-F2 | 4 | Calorie bars | not-implemented |
| VZ-F3 | 4 | Macro split | not-implemented |
| VZ-F5 | 4 | Weight vs calories | not-implemented |
| VZ-F7 | 4 | Adherence calendar | not-implemented |
| VZ-B1 | 4 | Weight | partial-prototype |
| VZ-S1 | 6 | Dose timeline | not-implemented |
| VZ-S2 | 6 | Adherence | not-implemented |
| VZ-S6 | 6 | Injection-site map | not-implemented |
| VZ-S7 | 6 | Inventory gauges | not-implemented |
| VZ-S9 | 6 | Symptoms | not-implemented |
| FUEL-01 | 4 | Instant search (offline recents, favorites, frequent), copy yesterday / copy meal, quick-add kcal/macros, custom foods, barcode, m | partial-prototype |
| FUEL-02 | 4 | Food-database layer with a canonical schema | partial-prototype |
| FUEL-03 | 4 | Serving UX | partial-prototype |
| FUEL-04 | 4 | Custom foods and recipes | partial-prototype |
| FUEL-05 | 4 | Saved meals/templates, day cloning, planned vs eaten | partial-prototype |
| FUEL-06 | 4 | Water, caffeine, alcohol (units + kcal), non-peptide supplements — quick log | not-implemented |
| FUEL-07 | 4 | Per-meal notes, hunger/mood tags, photos | partial-prototype |
| FUEL-20 | 4 | Target setup | not-implemented |
| FUEL-21 | 4 | Day types | not-implemented |
| STK-01 | 6 | Compounds | not-implemented |
| STK-02 | 6 | Protocols | not-implemented |
| STK-03 | 6 | Schedule engine | not-implemented |
| STK-04 | 6 | Dose log | not-implemented |
| STK-05 | 6 | Reminders | not-implemented |
| STK-06 | 6 | Reconstitution and draw calculator — math only; it never suggests a dose | not-implemented |
| STK-07 | 6 | Inventory | not-implemented |
| STK-08 | 6 | Injection-site tracking | not-implemented |
| STK-09 | 6 | Side effects and symptoms | not-implemented |
| BODY-01 | 4 | Weigh-ins (manual, Health sync, smart-scale CSV), EWMA trend, goal, rate of change, projected date; tags (post-travel, illness…) | partial-prototype |
| BODY-02 | 4 | Measurements | not-implemented |
| BODY-07 | 4 | Safety rails (BMI/rate caps, hide-numbers mode, ED-sensitive defaults) — §11 | not-implemented |
| PLAT-01 | 1 | Onboarding to first value in ≤ 90 s | not-implemented |
| PLAT-02 | 1 | Settings | partial-prototype |
| PLAT-03 | 1 | Accounts and sync | not-implemented |
| PLAT-04 | 1 | Data portability | not-implemented |
| FUEL-INT-01 | 4 | Health weight and steps integration (§4.4 unnumbered P0) | not-implemented |

## P1

| ID | Phase | Feature | Current status |
|---|---|---|---|
| TRN-05 | 3 | Exercise page | not-implemented |
| TRN-06 | 3 | Gym profiles | not-implemented |
| TRN-20 | 3 | Plan targets shown inline (e | not-implemented |
| TRN-21 | 3 | Backfill past workouts with a date picker; paste or speak "squat 100x5x3, bench 80x8x3" → parsed rows with confirmation | not-implemented |
| TRN-22 | 3 | Unilateral L/R logging; dumbbells logged per hand, with an optional "count both hands" tonnage setting (default off) | not-implemented |
| TRN-23 | 3 | Cardio/conditioning | not-implemented |
| TRN-34 | 3 | Calculators | not-implemented |
| TRN-35 | 3 | Stopwatch; isometric-hold timer; EMOM/Tabata/AMRAP timers (shared with TRN-23) | not-implemented |
| TRN-36 | 3 | Energy-expenditure estimate per session (MET/HR/RPE blend), labeled as an estimate; writes to Health when permitted | not-implemented |
| TRN-42 | 3 | Program builder (weeks × days × exercises × progression rules) with generic templates — PPL, upper/lower, full-body, body-part spl | not-implemented |
| TRN-43 | 3 | Progression engine, per exercise and selectable | not-implemented |
| TRN-44 | 3 | Mesocycle manager (RP-style volume landmarks) | not-implemented |
| TRN-45 | 3 | Stall detection | not-implemented |
| TRN-46 | 3 | Deload scheduler and fatigue flags (same load needing a higher RPE, falling reps, poor sleep/HRV, rising soreness) | not-implemented |
| TRN-47 | 3 | Injury mode | not-implemented |
| TRN-52 | 3 | Strength standards | not-implemented |
| TRN-53 | 3 | Goals | not-implemented |
| TRN-54 | 3 | Consistency | not-implemented |
| TRN-64 | 3 | Recovery estimate per muscle from volume, proximity to failure, soreness feedback, and sleep/HRV where available; ready/recovering | not-implemented |
| TRN-65 | 3 | Balance analytics | not-implemented |
| TRN-73 | 3 | Weekly/monthly/yearly training reports; shareable "Year in Lifting" recap | not-implemented |
| TRN-74 | 3 | Typo guards | not-implemented |
| TRN-80 | 3 | Apple Watch app (SwiftUI) | not-implemented |
| TRN-81 | 3 | HealthKit / Health Connect | not-implemented |
| TRN-82 | 3 | Widgets (next workout, weekly sets ring, streak), Live Activities, App Intents/Shortcuts ("Start Push Day", "Log set"), Control Ce | not-implemented |
| TRN-93 | 3 | Import from Strong, Hevy, StrengthLog, Fitbod and JEFIT CSVs with a column-mapping and exercise-matching screen and a dry-run summ | not-implemented |
| VZ-T3 | 7 | Stack card | not-implemented |
| VZ-T6 | 7 | Consistency tiles | not-implemented |
| VZ-T8 | 7 | Readiness tile | not-implemented |
| VZ-T9 | 7 | Insight of the day | not-implemented |
| VZ-T10 | 7 | Layout editor | not-implemented |
| VZ-W5 | 3 | Load–rep scatter | not-implemented |
| VZ-W6 | 3 | Intensity and rep-range distribution | not-implemented |
| VZ-W7 | 3 | RPE-at-load trend | not-implemented |
| VZ-W8 | 3 | Rep decay and rest | not-implemented |
| VZ-W11 | 3 | Density trend | not-implemented |
| VZ-W14 | 3 | Muscle × week grid | not-implemented |
| VZ-W15 | 3 | Frequency per muscle | not-implemented |
| VZ-W16 | 3 | Balance | not-implemented |
| VZ-W17 | 3 | Volume load by week | not-implemented |
| VZ-W18 | 3 | Mesocycle overlay | not-implemented |
| VZ-W20 | 3 | PR wall / timeline | not-implemented |
| VZ-W21 | 3 | Strength-standards ladder | not-implemented |
| VZ-W22 | 3 | Powerlifting total and points | not-implemented |
| VZ-W23 | 3 | Relative strength | not-implemented |
| VZ-W24 | 3 | Cumulative tonnage | not-implemented |
| VZ-W25 | 3 | Plan adherence | not-implemented |
| VZ-W27 | 3 | Weekly report card | not-implemented |
| VZ-F4 | 4 | Energy balance | not-implemented |
| VZ-F6 | 4 | Adaptive expenditure | not-implemented |
| VZ-F8 | 4 | Micronutrients | not-implemented |
| VZ-F9 | 4 | Protein distribution | not-implemented |
| VZ-F11 | 4 | Top contributors | not-implemented |
| VZ-F12 | 4 | Hydration, caffeine, alcohol | not-implemented |
| VZ-F13 | 4 | Limits | not-implemented |
| VZ-F14 | 4 | Training vs rest day intake | not-implemented |
| VZ-F15 | 4 | Weekly calorie budget | not-implemented |
| VZ-F16 | 4 | Health score | not-implemented |
| VZ-F17 | 4 | Diet-phase timeline | not-implemented |
| VZ-B2 | 7 | Composition | not-implemented |
| VZ-B3 | 7 | Measurements | not-implemented |
| VZ-B4 | 7 | Progress photos | partial-prototype |
| VZ-B5 | 7 | Sleep / HRV / RHR | not-implemented |
| VZ-B6 | 7 | Steps and active energy | not-implemented |
| VZ-B7 | 7 | Rate-of-change gauge | not-implemented |
| VZ-B8 | 7 | Lean-mass preservation | not-implemented |
| VZ-S3 | 6 | Estimated active level | not-implemented |
| VZ-S4 | 6 | Cumulative and weekly dose | not-implemented |
| VZ-S5 | 6 | Cycle / titration Gantt | not-implemented |
| VZ-S8 | 6 | Cost | not-implemented |
| VZ-S10 | 6 | Biomarkers | not-implemented |
| VZ-S11 | 6 | Outcome overlays | not-implemented |
| VZ-S12 | 6 | Check-ins | not-implemented |
| VZ-X1 | 7 | Master Timeline (hero) | not-implemented |
| VZ-X2 | 7 | Correlation explorer | not-implemented |
| VZ-X3 | 7 | Weekly "State of You" | not-implemented |
| VZ-X4 | 7 | Phase comparison | not-implemented |
| VZ-X5 | 7 | Goals dashboard | not-implemented |
| VZ-X7 | 7 | Annual recap | not-implemented |
| VZ-X8 | 7 | Clinician/coach report | not-implemented |
| VZ-X9 | 7 | Dose-cycle overlay | not-implemented |
| FUEL-10 | 5 | Photo scan → items + estimated grams + confidence | not-implemented |
| FUEL-11 | 5 | Barcode + label | not-implemented |
| FUEL-12 | 5 | Voice/text | not-implemented |
| FUEL-13 | 5 | Restaurants | partial-prototype |
| FUEL-22 | 4 | Adaptive targets (your own implementation, MacroFactor-inspired) | not-implemented |
| FUEL-23 | 4 | Per-meal targets (protein distribution), grams-or-% toggle, net carbs | not-implemented |
| FUEL-24 | 4 | Micronutrient targets by age/sex (RDA/AI/UL; cite NIH/NASEM), supplements included, UL flags worded neutrally | not-implemented |
| FUEL-25 | 4 | GLP-1 support mode | not-implemented |
| FUEL-26 | 4 | Intermittent fasting | not-implemented |
| FUEL-28 | 4 | Health score (0-10, transparent) | not-implemented |
| STK-10 | 6 | Estimated active level | not-implemented |
| STK-11 | 6 | Bloodwork and biomarkers | not-implemented |
| STK-12 | 6 | Clinician/coach report (PDF/PNG) | not-implemented |
| STK-13 | 6 | Cost tracking | not-implemented |
| STK-14 | 6 | General medication/supplement tracking on the same engine ("my stack" view) | not-implemented |
| STK-15 | 6 | Check-ins | not-implemented |
| STK-20 | 6 | Privacy and discretion | not-implemented |
| BODY-03 | 7 | Progress photos | partial-prototype |
| BODY-04 | 7 | Sleep, HRV, resting HR, steps and active energy from Health/wearables (read-only); a transparent readiness composite (documented w | not-implemented |
| AI-01 | 5 | Universal Logger | not-implemented |
| AI-02 | 7 | Grounded coach chat | not-implemented |
| AI-03 | 7 | Weekly review (VZ-X3) | not-implemented |
| AI-06 | 5 | Safety layer | not-implemented |
| AI-07 | 5 | Engineering controls | not-implemented |
| PLAT-05 | 8 | Widgets, Live Activities, Shortcuts, Control Center controls and Watch complications (see TRN-80 | not-implemented |
| PLAT-06 | 8 | Notification framework | not-implemented |
| PLAT-07 | 8 | Subscriptions via RevenueCat | not-implemented |
| PLAT-08 | 8 | Observability | not-implemented |
| PLAT-09 | 8 | Support | not-implemented |
| FUEL-04.PHOTO_RECIPE | 4 | Photo-to-recipe and nutrition-label OCR | not-implemented |
| STK-01.REFERENCES | 6 | Cited neutral compound reference list | not-implemented |
| STK-07.GS1 | 6 | GS1 DataMatrix inventory scan | not-implemented |
| PLAT-04.IMPORTERS | 8 | Mapping/dry-run importers and streaming Apple Health XML | not-implemented |
| FUEL-INT-02 | 4 | Diet/allergen tags, glycemic metrics, widgets, share extension and nutrition CSV/PDF | not-implemented |
| FUEL-INT-04 | 4 | Health nutrition/water write and active-energy read (proposed priority; untagged clause) | not-implemented |

## P2

| ID | Phase | Feature | Current status |
|---|---|---|---|
| TRN-07 | Later | Video library with loop/slow-mo; opt-in on-device form check (AI-05) | backlog |
| TRN-24 | Later | Hands-free voice logging via App Intents/Siri | backlog |
| TRN-48 | Later | AI program generator and "I only have 30 minutes" workout compressor (§7) | backlog |
| TRN-49 | Later | Competition prep | backlog |
| TRN-83 | Later | Strava export; Garmin/Whoop/Oura via an aggregator; BLE heart-rate straps; barbell-velocity sensors | backlog |
| TRN-90 | Later | Follow/feed/kudos, shared routines, opt-in standards leaderboards, challenges, live training-partner session | backlog |
| TRN-91 | Later | Coach mode | backlog |
| VZ-W26 | Later | Time-of-day performance | backlog |
| VZ-F10 | Later | Meal timing | backlog |
| VZ-F18 | Later | Peri-workout nutrition | backlog |
| VZ-X6 | Later | "What changed?" | backlog |
| VZ-X10 | Later | Recomp scoreboard | backlog |
| FUEL-14 | Later | Smart suggestions | backlog |
| FUEL-27 | Later | Meal planner + grocery list | backlog |
| STK-16 | Later | PK helpers | backlog |
| STK-17 | Later | Travel mode (timezone plan, packing-checklist notes); partner/caregiver read-only reminders with consent; "protocol review" summar | backlog |
| BODY-05 | Later | Optional cycle-tracking import from Health to contextualize training/nutrition | backlog |
| BODY-06 | Later | Tape-based body-fat estimators, labeled as estimates | backlog |
| AI-04 | Later | Program generator and workout compressor (goals, days, equipment, injuries, priorities → editable routines with rationale) | backlog |
| AI-05 | Later | Opt-in on-device form analysis (pose estimation); no video upload by default | backlog |
| PLAT-10 | Later | Web companion (read-only dashboards, import/export), Android parity, tablet/iPad layouts, public API/webhooks and Google Sheets ex | backlog |
| TRN-80.WEAROS | Later | Wear OS client | backlog |
| STK-11.LAB_OCR | Later | Lab PDF OCR with confirmation | backlog |
| STK-11.CLINICAL_RECORDS | Later | Apple Health Clinical Records | backlog |
| STK-12.SECURE_LINK | Later | Expiring consented report link | backlog |
| FUEL-INT-03 | Later | CGM glucose overlay | backlog |

## Dependencies and unresolved scope

- TRN-10 P0 mentions an AI start; AI program generation is P2. Program-day storage is included; the AI start cannot be called complete or faked before its dependency/scope is approved.
- P0 TRN-17/30 and STK-04/05 need a subset of platform hooks that are broadly tagged P1 elsewhere. Deliver their required subset with the P0 feature; optional Watch/platform breadth stays flagged.
- TRN-63 estimated recovery depends on TRN-64 P1. Sets/tonnage/recency are P0; recovery mode remains disabled pending its reviewed engine.
- Safety prerequisites from BODY-07, adult gating, hide-numbers and private storage precede sensitive flows, even where full onboarding/privacy polish is listed later.
- Phase 1 Android execution conflicts with the native alternative and PLAT-10 P2. Proposed owner amendment: native iOS first, Kotlin/Compose later.
- §3 asks <150ms first paint over five years; §10.2 allows <400ms for five years. Use <150ms as the stricter target; report both thresholds and never silently relax it.
- FUEL-INT-04 priority is an explicit proposal for an untagged clause; phase-4 Health writing scope still needs confirmation before implementation.
- P0 ports and account flows have planned contracts; backend provisioning, auth entitlements, RLS and live multi-device verification remain Phase 1 gates.
- Release of the calculator requires qualified policy eligibility; no public release, entitlement or approved medical status is claimed.

## Foundation follow-through (P0 dependencies, not deferred to P2)

- PLAT-03: configure owner-approved Supabase project/region; wire consent, hosted login/logout/revocation, account recovery/delete, live domain adapters, uploads and foreground/background sync. Verify two actual clients, conflicts, interruption/retry, region and encrypted backup recovery.
- PLAT-03 deployment checkpoint (2026-10-10): approved DEV schema/gateway deployed. Hosted catalog, simulated-claim isolation/rollback, key-free HTTP rejection and eighteen positive signed-token auth/isolation criteria pass. Two owner-authorized fictional accounts and synthetic notes remain in DEV; issued sessions were logged out and temporary passwords discarded. Close or deliberately implement signup, verify gateway abuse controls/shared-IP handling, CAPTCHA integration and provider logging before activation. See HOSTED_DEPLOYMENT_VERIFICATION.md.
- PLAT-03 safeguards checkpoint (2026-10-11): general signup closed; database-backed sign-in/refresh guard deployed and verified with concurrent calls and genuine sessions. Consent, recovery/delete, direct-provider bot protection, scheduled security-counter retention and provider logging/backup policies remain activation/release gates. No per-device/IP, WAF or complete retention claim. See AUTH_HARDENING_VERIFICATION.md and ADR-007. Four fictional QA accounts/notes now remain in DEV; their temporary passwords were discarded and issued sessions logged out.
- PLAT-03 account lifecycle checkpoint (2026-10-12): optional permission and local withdrawal, recovery-code client/server flow and password-confirmed hosted self-deletion implemented; migration 004 and exact gateway deployed. Twelve live lifecycle criteria and hosted cleanup pass for one new disposable fixture, now deleted; the four earlier QA accounts remain. Recovery HTML is prepared but hosted SMTP/template setup and actual delivery/reset are pending. App activation remains off; provider bot/logging/retention gates and separately consented personal domain sync are still open. See ACCOUNT_LIFECYCLE_VERIFICATION.md and ADR-008.
- PLAT-03: finish normalized SwiftData→GRDB mapping and photo-vault protections; restore rehearsal and approval before irreversible cutover. Current archive proves lossless rehearsal only.
- PLAT-03 local restore checkpoint (2026-10-13): saved/reopened legacy archive now reconstructs all 15 current model types in a separate memory container with exact rows/relationships/photos and strict failure checks. This closes the legacy graph-mapping rehearsal only; normalized GRDB persistence, restart durability, vault encryption and live cutover remain open. Owner deferred email setup in favor of local work. See LOCAL_RESTORE_VERIFICATION.md and ADR-009.
- PLAT-02: audit every dynamic string and accessibility phrase; translate only when reviewed. Verify chosen decimal formats in existing entry forms as well as new package parsing.
- PLAT-02 / §10.2: execute iOS17 runtime/device checks, largest Dynamic Type/VoiceOver, every-chart image baselines and required physical-device performance/coverage budgets.
- §12 Phase1: run hosted CI after connecting the intended remote; local Xcode27 verification does not establish the Xcode16.4 CI result.
- §11: encrypted Stack store, private attachment vault, consent/lock/region/store gates and qualified policy review precede real Stack capture. Simulation markers do not satisfy these requirements.

These entries preserve the existing requirement priorities. They are unfinished Foundation/release gates, not completed or newly optional features.

## Food/data checkpoint — 2026-10-14

- FUEL-01/02/03 are **partially implemented**: 311 offline USDA foods, explicit gram review, personal macro overrides and native/manual barcode capture. Remaining P0 scope includes production packaged-food coverage, recents/frequency/favorites/copy flows, broader serving units and structured canonical source metadata. Do not mark the full requirements complete.
- Optional OFF adapter is fixture-tested and defaults off. Resolve the pending provider/reuse choice, real contact User-Agent, official usage setup and release obligations before live requests. Review coverage using authorized real products; current parser requires explicit total carbs and may reject many records. No offline packaged-product cache or label OCR yet (FUEL-11 P1 remains flagged).
- Restaurant tooling now supports adding local restaurants plus existing custom menu create/edit/delete, categorized browsing, improved search and official-source links. New official restaurant table imports remain pending reuse permission/licensed source; sample menus are not production coverage (FUEL-13 P1 remains flagged).
- PLAT-03 normalized rehearsal maps all 15 models into a separate GRDB target and reconciles exact typed values. Unknown serving grams remain compatibility rows, not fabricated canonical nutrients/log grams. Finish canonical app repositories/read-model integration, protected attachments/backup and migration review before live cutover.
- Verify native camera permission denial/retry, real barcode decoding, rotation, background/interruption and accessibility on a physical iPhone. Simulator manual capture is not a hardware-camera pass.
- Email sender and delivery/reset verification remain deferred per the owner's explicit instruction. No hosted account/sync activation occurred in this checkpoint.

## Food reuse checkpoint — 2026-10-14

- FUEL-01 local recents, frequency, favorites and reviewed day/meal copying are now implemented. Diary Add opens unified search with its selected meal/date; repeat review defaults to the last quantity. Quick-add polish, custom meal-slot times and broader serving/database coverage remain P0 work; this does not close all FUEL-01/02/03/05 scope.
- FUEL-03 supports g, weight oz and explicit source portions. Unknown-mass servings remain multipliers. Slider interaction, household measures, density, yield factors and volume conversions remain; conversions need truthful source metadata; do not infer them.
- Favorite keys are separate device preferences and are not included in the legacy model archive. Full preference portability, source-version/removal reconciliation and account-specific migration remain open with the protected export/import work.
- Native camera/iOS17 runtime, largest accessibility size/VoiceOver and physical-device/large-history budgets remain pending. The existing simulator numeric-keyboard layout warning is tracked; no warning-free-runtime claim.
- No new food dataset or restaurant import occurred here. Live barcode provider/contact/terms setup, licensed restaurant coverage and email delivery configuration stay pending. Source 311-food USDA catalog and restricted default online configuration are unchanged.
