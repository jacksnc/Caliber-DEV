# Caliber — Master Build Brief for GPT-6 Astra

**Version:** v1 · 2026-10-07 · working name "Caliber" · repo `jacksnc/Caliber-DEV`

## For you, the owner — not part of the prompt

**What this is.** One long brief to paste into Astra so it builds a single "master" app: macro tracker + peptide/protocol tracker + weight-training log + a shared visuals/insights layer. It follows the structure Astra responds to best (goal → context → priority → autonomy → tools → output → verification → stop condition) and is explicit about *when Astra should assume and when it should ask*, because Astra defaults to asking if you don't say.

**How to use it**
1. Paste everything between `PROMPT START` and `PROMPT END` as **one message**. Astra has a ~1M-token context and up to 128k output, so size is not a problem.
2. Run the first reply at the **highest reasoning effort** (Phase 0 architecture and the math engines). Medium effort is fine for UI scaffolding.
3. Reply "go" to advance phases. Astra is told to stop only for decisions that are genuinely yours (§0.4).
4. If you already have macro/peptide code, paste it *after* the brief. Astra will gap-analyse it against the spec instead of rewriting it.
5. Every requirement has a stable ID (e.g. `TRN-43`, `VZ-W1`, `STK-06`), so later you can say "build `VZ-X9` next" or "drop `FUEL-27`".

**Decisions baked in — edit before pasting if you disagree**
- iOS-first React Native (Expo, TypeScript) with native SwiftUI Watch/widget targets; Android-ready (§10).
- The peptide module ("Stack") is a **logbook + calculator only** — no dose advice, no sourcing, no public protocol sharing — and is feature-flagged so a build can ship without it (§5, §11).
- Free tier = unlimited manual logging in all three domains; Pro = AI scans, adaptive targets, advanced analytics (PLAT-07).
- The visuals layer is the differentiator: one timeline, cross-domain overlays, correlations (§3).

**Heads-ups**
- **Name clash:** "Caliber: Strength Training" is an existing, well-reviewed fitness app on the App Store. Clear the name (trademark + store) before you brand anything "Caliber".
- **Store risk:** Apple (App Review Guidelines §1.4 Physical Harm, §5.1.3 Health data) and Google Play (Unapproved Substances, Health apps declaration) both scrutinise this category. §11 is written to pass review, but get a human policy/legal read before submitting.
- **Research limits:** competitor pages (App Store, vendor sites) were blocked from direct fetch in the environment this was written in, so feature lists come from search summaries. The brief tells Astra to verify competitor facts before relying on them. Sources are listed at the bottom.

---

<!-- PROMPT START -->

# CALIBER — MASTER BUILD BRIEF

You are **Astra**, working as principal mobile engineer, data-visualization engineer, product designer and sports-nutrition-aware implementer. This brief is your complete spec. §0 is the operating contract. §1–§8 are requirements, each with a stable ID and a priority tag. §9 holds the data model and the exact math. §10–§11 are architecture and guardrails. §12 is the delivery plan. §13 tells you what to do right now. §14 lists recommended defaults.

Priority tags: **P0** = ships in v1 · **P1** = built in v1 behind a feature flag · **P2** = recorded in `docs/BACKLOG.md`, built later.

## 0. Operating contract

### 0.1 Goal
Build **Caliber** (codename), one mobile app that replaces four:
1. **Fuel** — calorie, macro and micronutrient tracking (benchmarks: MyFitnessPal, Cal AI, MacroFactor).
2. **Stack** — peptide, injectable-protocol and GLP-1 logbook (benchmarks: STACKR, Shotsy).
3. **Train** — weight-training log and programming (benchmarks: StrengthLog, Strong, Hevy, Alpha Progression).
4. **Body & Recovery**, plus the layer none of them have: a **shared visuals and insights layer** that puts food, training, body and doses on one timeline.

Success test: a lifter on a cut, a bulk, or a GLP-1/peptide protocol can log a set, a meal and a dose in ≤ 10 s each, then open one screen and see how training, food, body weight and doses relate.

### 0.2 Context
- The owner already has a macro tracker and a peptide-injection tracker in progress. This brief (a) adds a full weight-training module, (b) adds the unified chart/insight layer, and (c) raises the macro and peptide modules to best-in-class parity.
- Repo `jacksnc/Caliber-DEV` is empty (README only). Treat it as greenfield unless the owner pastes existing code. If they do, gap-analyse it against §2–§8 first and evolve it; don't rewrite working code without a written reason.
- Benchmarks are for feature parity and UX lessons only. Never copy their branding, copy, icons, media, proprietary datasets or program text. Verify any competitor fact against current store listings before relying on it.
- Users: gym-goers who count macros; a growing subset run GLP-1 or peptide protocols and want accurate, discreet logging. Stack is adults-only.
- Real-world use: one hand, sweaty, weak signal, between sets. Design for that first.
- Platform default: iOS first (Apple Health, Watch, widgets, Live Activities), Android-ready.

### 0.3 Instruction priority (highest first)
1. §11 safety, legal and privacy guardrails.
2. §9 correctness of health-related math. If a requirement would force wrong or unsafe numbers, keep the correct math and flag the conflict.
3. The owner's latest message in this chat.
4. This brief: P0 > P1 > P2.
5. Your own judgement on naming, layout and polish.

### 0.4 Autonomy — assume or ask
**Proceed without asking** (record each choice in `docs/DECISIONS.md`) for: file and module layout, naming, library choices inside the default stack (§10), UI details and microcopy, any value marked *default*, test strategy, seed data, refactors, and fixing your own mistakes.

**Stop and ask one focused question** — always include your recommended default so the owner can answer "go" — only when: (a) a choice would change the platform or leave the default stack and an ADR can't justify it; (b) a paid account, API key, store submission or legal sign-off is needed; (c) a change would irreversibly migrate or delete existing user data; (d) two requirements here contradict; (e) a dataset or asset has an unclear license; (f) a requirement would break §11.

Never ask permission to write tests, add types, improve accessibility or refactor your own code.

### 0.5 Tools and delegation
Use everything your environment offers: code execution, test runners, linters, type-checkers, simulators/browser, sub-agents. Fix the shared schema and package boundaries in Phase 0, then run independent workstreams in parallel (chart kit · math engines · nutrition pipeline · schedule/reminder engine · Stack calculator) and integrate them yourself. If you have repository access, commit per phase on a branch with conventional commits; otherwise emit files in the reply. If you cannot execute code, say so once and label every deliverable **UNTESTED** with the exact commands the owner should run.

Think hardest on: Phase 0 architecture, the §9 math engines, sync/conflict handling, the schedule/reminder engine and the reconstitution calculator. Move fast on scaffolding and polish.

### 0.6 Output format (every phase)
1. A plan of ≤ 8 lines.
2. File tree.
3. Complete files — no `...`, no TODO stubs on P0 paths.
4. Migrations.
5. Tests (math engines use the golden vectors in §9.3).
6. Run/verify commands.
7. A **Verification report**: each acceptance criterion for the phase as pass/fail with evidence.
8. Your recommended next step.

Keep prose terse; code, checklists and diagrams carry the answer. Maintain `docs/DECISIONS.md`, `docs/BACKLOG.md`, `docs/CHANGELOG.md` and `docs/HOW_WE_CALCULATE.md` (plain-language method page for every estimate the app shows).

### 0.7 Verification and stop condition
A phase is done when: type-check, lint and tests pass; the §12 acceptance list is green with evidence; every chart for that phase renders from the demo dataset inside the §10.2 budgets; and you have re-read your own diff once for regressions and §11 violations.

The project is done when all P0 items are implemented and demoable on the seeded 12-month dataset, P1 items are flagged, P2 items are in the backlog, the §11 checklist is satisfied, and no placeholder code remains in shipped paths.

## 1. Principles, information architecture and design system

### 1.1 Principles
1. **Speed.** Log a set, a meal or a dose in ≤ 2 taps from Today (≈ 5 s typical). Gym-proof UI: one-handed, targets ≥ 48 pt, large tabular numerals, high contrast.
2. **Offline-first.** Every log works with no network. Sync is background and conflict-safe. No spinners for local operations.
3. **Visuals-first.** Every number earns a chart; every chart earns a one-sentence, deterministic insight.
4. **One timeline.** All domains share a time axis and event markers (workouts, meals, doses, weigh-ins, labs, notes, phases).
5. **Calm, body-neutral tone.** No shame colors or copy. Red is reserved for safety.
6. **User owns the data.** Full export/import, private by default, no ads, no data sale, AI optional.
7. **Honest estimates.** Label estimates as estimates, show ranges/confidence, cite sources for reference values, publish the formulas (`HOW_WE_CALCULATE.md`).

### 1.2 Information architecture
- Tabs: **Today · Train · Fuel · Stack · Progress**, plus a persistent **Quick Log** button (set/workout · food [photo, scan, voice, search] · dose · weigh-in · water · note/symptom). Settings behind the profile avatar.
- **Today:** customizable cards (§3, VZ-T). **Train:** Start · History · Exercises · Stats · Programs. **Fuel:** Diary · Foods (search, custom, recipes, meals) · Targets · Insights · Fasting · Planner. **Stack:** Today · Protocols · Inventory · Calculator · Sites · Log · Labs · Charts · Reports. **Progress:** Master Timeline · Body · Recovery · Correlations · Reports & Recaps · Goals.
- Modules can be switched off (Settings → Modules). Stack is hidden until the user opts in (§5.1, §11).

### 1.3 Design system
- Dark-first with a full light theme and optional OLED black. Semantic tokens (surface, text, border, accent, success/warn/danger, chart-categorical, chart-sequential, chart-diverging) defined once and consumed everywhere.
- One accent per domain (Train, Fuel, Stack, Body), constant everywhere — UI *and* charts. Categorical chart palette ≤ 8 hues, color-blind-safe, validated at WCAG 2.2 AA contrast on both themes. Never encode meaning by color alone (add shape, pattern or label).
- Type: one UI family (SF Pro / Inter / Geist) with **tabular numerals** for every number; a defined scale; Dynamic Type supported.
- Components to build once and reuse: ring, stat tile with sparkline, chart card (title · insight sentence · range chips · "i" method sheet), set row, plate visual, syringe visual, body map, calendar heatmap, timeline, empty state with ghosted sample, skeleton.
- Motion is purposeful (ring fill, chart draw-in ≤ 400 ms, PR celebration) and honors Reduce Motion. Haptics for set complete, PR, rest end, dose logged.

### 1.4 Accessibility and localization
VoiceOver/TalkBack labels everywhere; every chart has a text summary and an accessible data table; WCAG 2.2 AA; 44 pt minimum targets; Dynamic Type up to the largest accessibility size without clipped numerals. Units (kg/lb, cm/in, kcal/kJ, mL/fl oz, °C/°F), decimal separators, week start and language are user settings; all strings externalized from day one.

## 2. TRAIN — weight-training module (IDs `TRN-`)

Benchmark intent: StrengthLog-grade analytics (volume per muscle, weekly set goals, %1RM/RPE/RIR logging, 1RM and warm-up tools, plate calculator, muscles-worked map, programs); Strong-grade logging speed (per-exercise rest timers, set types, supersets, exports, Watch app); Hevy-grade organization and social (routines + folders, muscle distribution, per-exercise records, body measurements, feed); and the adaptive layer of Alpha Progression / Gravl / Dr. Muscle (auto-progression, mesocycles, deloads, recovery-aware planning, injury-aware filtering).

### 2.1 Exercise library
- **TRN-01 · P0** ≥ 600 seeded exercises (target 800+). Fields: name, aliases, primary/secondary muscles *with weights*, equipment, movement pattern (squat/hinge/lunge/push/pull/carry/rotate…), mechanics (compound/isolation), unilateral flag, metric type (TRN-03), cues, media. Use original or properly licensed media and data only. Check the license of any open dataset (e.g., free-exercise-db, wger) before bundling and record attribution duties in `docs/LICENSES.md`.
- **TRN-02 · P0** Unlimited custom exercises (free tier): muscles with weights, equipment, metric type, bar type, notes, photo/video. Rename or merge without losing history.
- **TRN-03 · P0** Metric types: weight×reps · bodyweight×reps · weighted bodyweight (BW + added) · assisted bodyweight (BW − assist) · reps only · duration · weight×duration · distance · distance×duration · per-side flag.
- **TRN-04 · P0** Search/filter: fuzzy name + alias, muscle, equipment, pattern, favorites, recents, custom. Instant and offline.
- **TRN-05 · P1** Exercise page: cues, common mistakes, muscle highlight, ranked alternatives (similarity from muscle + pattern vectors), personal history, records, pinned note.
- **TRN-06 · P1** Gym profiles: equipment available, plate inventory, machine-setting notes per exercise per gym; suggestions respect the active gym (home, commercial, hotel).
- **TRN-07 · P2** Video library with loop/slow-mo; opt-in on-device form check (AI-05).

### 2.2 Live workout logging
- **TRN-10 · P0** Start from: empty · routine · program day · history ("repeat") · AI suggestion. Resume an in-progress workout after app kill/crash. Every set is written to disk the moment it is completed (write-ahead), with undo.
- **TRN-11 · P0** Set row: set # · **previous** (ghost of the last performance of this exercise at this gym; tap to copy) · weight · reps · RPE *or* RIR (user choice) · ✓. Optional columns per exercise: tempo, rest, %1RM, live e1RM, notes. Custom numeric keypad + ± steppers using per-exercise increments (default 2.5 kg / 5 lb; microplate steps down to 0.25 kg).
- **TRN-12 · P0** Auto-fill the next set from the previous set or plan target; "copy last set"; "fill remaining"; swipe to delete/duplicate; long-press drag to reorder.
- **TRN-13 · P0** Set types (color + glyph): warm-up · working · top set · back-off · drop · failure · AMRAP · cluster · rest-pause · myo-rep · custom. Each type declares whether it counts toward volume, hard sets and PRs (defaults: warm-up excluded from all three).
- **TRN-14 · P0** Supersets, giant sets, circuits: group exercises; auto-advance to the next exercise in the group on ✓; rest starts after the round (configurable).
- **TRN-15 · P0** Notes: per exercise (pinned across sessions, e.g., "seat 4, pin 7"), per session, per workout; attach photo/video.
- **TRN-16 · P0** Mid-workout edits: add/skip/replace/reorder exercises; **Swap** shows ranked alternatives for the same muscles and the available equipment.
- **TRN-17 · P0** Live header: elapsed time, volume, sets, PRs; collapses to a mini-bar on every screen with the rest countdown; Live Activity / Dynamic Island on iOS, ongoing notification on Android.
- **TRN-18 · P0** Finish flow: summary (duration, volume, sets, PRs, muscles hit on a mini body map, average RPE, density kg/min), vs-last-time deltas, soreness/energy/mood ratings, notes, "update routine from this workout?", share card.
- **TRN-19 · P0** Bodyweight auto-attached from the latest weigh-in for BW-based exercises and relative-strength math.
- **TRN-20 · P1** Plan targets shown inline (e.g., "8-10 @ RIR 2") with a one-tap progression prompt ("Last: 80×9 @ RPE 8 → try 80×10 or 82.5×8").
- **TRN-21 · P1** Backfill past workouts with a date picker; paste or speak "squat 100x5x3, bench 80x8x3" → parsed rows with confirmation.
- **TRN-22 · P1** Unilateral L/R logging; dumbbells logged per hand, with an optional "count both hands" tonnage setting (default off).
- **TRN-23 · P1** Cardio/conditioning: time, distance, pace, HR zones, RPE, calories; EMOM/AMRAP/Tabata/custom interval timers; import from Health/Strava.
- **TRN-24 · P2** Hands-free voice logging via App Intents/Siri.

### 2.3 Timers and calculators
- **TRN-30 · P0** Rest timer: auto-starts on ✓; defaults per exercise and per set type (suggest ~2-3 min for heavy compounds, ~60-90 s for isolation); ±15 s; skip; sound/vibration/voice; reliable on a locked screen (local notification + Live Activity); records the actual rest per set for analytics.
- **TRN-31 · P0** Plate calculator: target → plates per side with a true-proportion barbell graphic; bars (20/15/10 kg, 45/35 lb, EZ, trap, safety squat, custom); custom plate inventory per gym including fractional plates; nearest loadable weight; reverse mode (plates → total).
- **TRN-32 · P0** Warm-up generator from the top working set (default ramp 40%×8, 60%×5, 75%×3, 90%×1; editable templates; respects the plate inventory); per-exercise saved ramps.
- **TRN-33 · P0** 1RM and rep-max tools: e1RM with a selectable formula (Epley default; Brzycki, Lombardi, Mayhew, O'Conner, Wathan, Lander), RPE-adjusted e1RM, %1RM table for 1-12RM, "what should I lift for N reps".
- **TRN-34 · P1** Calculators: DOTS, IPF GL, Wilks (legacy), Sinclair (Olympic lifting), bodyweight-ratio standards, meet-total tracker. Use the official published coefficients and unit-test against published examples.
- **TRN-35 · P1** Stopwatch; isometric-hold timer; EMOM/Tabata/AMRAP timers (shared with TRN-23).
- **TRN-36 · P1** Energy-expenditure estimate per session (MET/HR/RPE blend), labeled as an estimate; writes to Health when permitted.

### 2.4 Routines, programs and progression
- **TRN-40 · P0** Routines: create/duplicate/archive; folders; per exercise: sets × rep range × target RPE/RIR × rest × notes × superset group; "update routine from last workout"; share via link/QR/file (importable without an account).
- **TRN-41 · P0** Scheduling: weekly plan, calendar, rest days, reminders, missed-workout handling (shift or skip), automatic program position.
- **TRN-42 · P1** Program builder (weeks × days × exercises × progression rules) with generic templates — PPL, upper/lower, full-body, body-part split, powerlifting peaking, GZCL-style tiers, 5/3/1-style waves, linear novice. Implement the *methods* parametrically; never reproduce copyrighted program text. JSON import/export.
- **TRN-43 · P1** Progression engine, per exercise and selectable: (a) linear (add X on success, deload after N fails) · (b) double progression (climb the rep range, then add load) · (c) % of training max / 1RM with weekly waves · (d) RPE autoregulation (load from target reps + RPE via e1RM) · (e) top set + back-off at −x% · (f) mesocycle volume ramp. Output: a "next time" suggestion plus a reason string. Round to the **nearest loadable weight** for the active plate inventory. Pure, fully unit-tested functions.
- **TRN-44 · P1** Mesocycle manager (RP-style volume landmarks): 4-8 week blocks that start near MEV, add ~1 set/muscle/week toward MAV/MRV, take 3-tap post-session feedback (soreness, pump, performance), auto-schedule a deload (~50% volume, lower intensity), end-of-block report. Landmarks per muscle are editable defaults, presented as heuristics, not rules.
- **TRN-45 · P1** Stall detection: no e1RM progress over N weeks → ranked suggestions (deload, variation swap, volume change, sleep/nutrition flags). Deficit-aware: do not frame a stall as failure while the user is in a calorie deficit — say so.
- **TRN-46 · P1** Deload scheduler and fatigue flags (same load needing a higher RPE, falling reps, poor sleep/HRV, rising soreness).
- **TRN-47 · P1** Injury mode: mark a joint/body part → filter and substitute exercises, adjust volume counters, log pain scores and rehab notes per exercise.
- **TRN-48 · P2** AI program generator and "I only have 30 minutes" workout compressor (§7).
- **TRN-49 · P2** Competition prep: meet attempts, peaking/taper; physique mode (weak-point emphasis).

### 2.5 PRs, records, standards, goals
- **TRN-50 · P0** PR engine, evaluated live on ✓ and recomputed on edit/delete. Types: heaviest weight · best e1RM · best set volume · best session volume · **rep records** (best weight for ≥ N reps, N = 1-12, "at-least-N" rule so 100×8 also updates 1-8) · longest hold / fastest pace. Warm-ups never count. Celebration respects Reduce Motion.
- **TRN-51 · P0** Per-exercise records table (rep-max grid, best e1RM/set/session, dates) and a records timeline.
- **TRN-52 · P1** Strength standards: per lift by sex and bodyweight (age optional) → a level ladder with progress and percentile; data-driven table with source citations; the user can hide it.
- **TRN-53 · P1** Goals: target load × reps by date; weekly set targets per muscle; sessions per week; projected completion date from the trend.
- **TRN-54 · P1** Consistency: weekly (not daily) streaks versus plan; streak freeze; opt-out; no guilt notifications.

### 2.6 Muscle and volume engine
- **TRN-60 · P0** Taxonomy of ≥ 18 regions: chest (clavicular/sternal), lats, upper back/traps/rhomboids, lower back, front/side/rear delts, biceps, triceps, forearms, abs/obliques, glutes, quads, hamstrings, adductors, abductors, calves, neck.
- **TRN-61 · P0** Set-counting mode (user setting): **direct only** · **fractional** (primary 1.0, secondary 0.5 default, editable per exercise) · **hard sets** (count only sets within RIR ≤ 4 when RIR is logged; unlogged sets count).
- **TRN-62 · P0** Weekly volume per muscle (sets, tonnage, frequency) versus target bands (MEV/MAV/MRV or custom; common hypertrophy default ~10-20 hard sets per muscle per week, editable) with neutral under / in-range / over status.
- **TRN-63 · P0** Muscle heat map on a front/back body figure: metric (sets · tonnage · days since trained · estimated recovery) × period (today / 7d / 30d / custom); tap a muscle → its contributing exercises.
- **TRN-64 · P1** Recovery estimate per muscle from volume, proximity to failure, soreness feedback, and sleep/HRV where available; ready/recovering map; documented heuristic with user override.
- **TRN-65 · P1** Balance analytics: push:pull, quad:ham, upper:lower, anterior:posterior, L:R; flags neglected muscles.

### 2.7 History and stats
- **TRN-70 · P0** History as list + calendar; filter by exercise/muscle/routine; note search; edit/delete with automatic PR/stat recompute.
- **TRN-71 · P0** Per-exercise stats page (charts in §3) plus a full session table.
- **TRN-72 · P0** Compare a workout with last time, best, and the average of the last N.
- **TRN-73 · P1** Weekly/monthly/yearly training reports; shareable "Year in Lifting" recap.
- **TRN-74 · P1** Typo guards: flag values far outside the user's history (1000 kg, 0 reps) with an undo toast.

### 2.8 Wearables and platform hooks
- **TRN-80 · P1** Apple Watch app (SwiftUI): active workout, set entry with Digital Crown, rest haptics, HR, start routine, log dose, log water. Wear OS later (P2).
- **TRN-81 · P1** HealthKit / Health Connect: write strength workouts (duration, energy, HR association); read HR, HRV, sleep, steps, active energy, body weight, body fat.
- **TRN-82 · P1** Widgets (next workout, weekly sets ring, streak), Live Activities, App Intents/Shortcuts ("Start Push Day", "Log set"), Control Center controls.
- **TRN-83 · P2** Strava export; Garmin/Whoop/Oura via an aggregator; BLE heart-rate straps; barbell-velocity sensors.

### 2.9 Social and coaching (default OFF, privacy-first)
- **TRN-90 · P2** Follow/feed/kudos, shared routines, opt-in standards leaderboards, challenges, live training-partner session.
- **TRN-91 · P2** Coach mode: assign programs, review logs, comment, adjust targets; scoped, time-limited, revocable access granted by the client.

### 2.10 Import / export
- **TRN-92 · P0** Full CSV/JSON export of all training data.
- **TRN-93 · P1** Import from Strong, Hevy, StrengthLog, Fitbod and JEFIT CSVs with a column-mapping and exercise-matching screen and a dry-run summary.

## 3. VISUALS — charts and data-viz layer (IDs `VZ-`)

This is the product's signature. Build one reusable chart kit (§3.2), then compose every screen from it.

### 3.1 Global chart standards
- **Ranges:** 1W · 1M · 3M · 6M · 1Y · All · Custom; "compare to previous period" toggle; selection persisted per chart.
- **Interaction:** scrub crosshair with haptic ticks and a tooltip (value, date, delta); pinch-zoom/pan on time series; tap a mark → drill into the underlying entries; long-press to add an annotation; double-tap resets.
- **Trend tools:** raw / EWMA / moving average / robust linear (Theil–Sen) toggle; goal lines; projected date to goal as a dashed line with an uncertainty band.
- **Shared event markers** on every time chart (toggle by category): protocol start/stop/dose change, mesocycle start/deload, diet phase, injury, illness, travel, lab draw, note.
- **Insight line** on every chart card: a deterministic, templated sentence ("Squat e1RM +6% in 8 weeks") with a "Why?" sheet showing formula, window and data used. No causal language. Optional AI narration may only rephrase computed facts.
- **Honest data:** gaps stay gaps (optional dotted interpolation); show N and logging coverage; empty/low-data states show a ghosted sample and "log 5 more days to unlock".
- **Encoding rules:** zero baseline for bars; no 3D; avoid dual axes (use small multiples or a labeled, user-toggled normalized overlay); tabular numerals; adaptive tick density; units and locale aware.
- **Color:** domain accents constant; sequential ramps for magnitude, diverging ramps for above/below target; color-blind-safe categorical set; pattern/shape redundancy; both themes validated for contrast.
- **Performance:** 5 years of daily data at 60 fps (LTTB downsampling, memoized aggregates, daily rollup tables — §9.1); first paint from cache < 150 ms.
- **Accessibility:** every chart exposes a text summary and an accessible data table; audio-graph-style sonification where the platform supports it; honors Reduce Motion.
- **Export:** PNG share card (with an option to **hide absolute numbers**), PDF report, CSV of the underlying series.
- **Testing:** a golden-image test per chart from fixtures; property tests that rollups equal raw sums (day = sum of entries; week = sum of days).

### 3.2 Chart kit (build once)
Line/trend · bar + target band · stacked bar · area · scatter (+ iso-lines) · calendar heatmap · grid heatmap (muscle × week) · concentric rings · donut · radar · sparkline · bullet gauge · histogram · slope/dumbbell (before → after) · swimlane/Gantt timeline · multi-track synchronized timeline · **body map** (muscle heat map; injection-site map) · photo compare (slider, onion-skin) · syringe graphic · barbell/plate graphic.

### 3.3 Hero visuals — spec and build these first
- **Rings (Today):** four concentric rings (kcal outer, then protein, carbs, fat); consumed ↔ remaining toggle; going over a target shows an overflow arc in a neutral accent, never red.
- **Muscle heat map:** front/back figure (neutral base by default, optional male/female bases); regions map 1:1 to the TRN-60 taxonomy; modes: sets, tonnage, days since trained, estimated recovery; time slider; "this week vs last week" delta mode; legend with thresholds taken from the user's own targets.
- **e1RM chart:** line of best e1RM per session; dots colored by rep range (1-5 / 6-12 / 13+); PR markers; regression-slope label ("+1.2 kg/month"); formula toggle; RPE-adjusted option.
- **Master Timeline:** 5-8 synchronized tracks (weight trend · calories/protein · training volume · doses with active-level curve · sleep/readiness · symptoms) on one scrubbable x-axis; one cursor reads every track; event markers; collapsible tracks; "zoom to phase".
- **Injection-site map:** front/back silhouette with tappable zones, L/R, recency heat, "least recently used" highlight; works in discreet mode (neutral labels).
- **Syringe graphic:** U-100 0.3/0.5/1 mL barrels with a fill line and unit ticks that match the calculator's result exactly (the same function feeds both).
- **Barbell graphic:** plates in true proportion, standard kg plate colors, updating live with the plate calculator.

### 3.4 Chart catalog
P = priority. Every chart card follows §3.1.

**Today (VZ-T)**

| ID | P | Visual | Spec |
|----|---|--------|------|
| T1 | P0 | Macro rings | Per §3.3; tap → macro detail; per-meal stacked bar beneath |
| T2 | P0 | Training card | Today's planned session, last-performance ghost, Start button; if none, "suggested next" |
| T3 | P1 | Stack card | Due/overdue doses, next-dose countdown, active-level sparkline per compound; hidden when the module is off |
| T4 | P0 | Weight tile | EWMA sparkline, kg/week arrow, progress to goal |
| T5 | P0 | Week strip | 7 days × food/train/dose dots; tap a day to open it |
| T6 | P1 | Consistency tiles | Logging streak, sessions vs plan, 30-day dose adherence; opt-out |
| T7 | P0 | Hydration | Ring + quick-add |
| T8 | P1 | Readiness tile | Composite + its drivers, tagged "estimate" |
| T9 | P1 | Insight of the day | Deterministic sentence + "Why?" |
| T10 | P1 | Layout editor | Drag/hide/resize cards; presets: Lifter, Cutter, GLP-1 support |

**Train (VZ-W)**

| ID | P | Visual | Spec |
|----|---|--------|------|
| W1 | P0 | e1RM trend (hero) | Per §3.3 |
| W2 | P0 | Best set per session | Scatter: x = date, y = weight; size = reps; color = RPE |
| W3 | P0 | Session volume | Bars + 4-week moving average; toggle total vs hard sets |
| W4 | P0 | Rep-max grid | Rows 1-12RM × columns by month; cell = best weight; new PRs outlined |
| W5 | P1 | Load–rep scatter | All working sets with iso-e1RM curves; reveals rep-range strengths |
| W6 | P1 | Intensity and rep-range distribution | Histogram of %e1RM; strength/hypertrophy/endurance split donut |
| W7 | P1 | RPE-at-load trend | RPE for a fixed load over time (efficiency) |
| W8 | P1 | Rep decay and rest | Average reps by set number; rest time vs performance |
| W9 | P0 | Session summary | Duration, volume, sets, PRs, mini muscle map |
| W10 | P0 | Previous vs current | Ghost bars per exercise and set |
| W11 | P1 | Density trend | Volume per minute over time |
| W12 | P0 | Weekly sets per muscle | Horizontal stacked bars with MEV/MAV/MRV bands behind; tap → contributing exercises |
| W13 | P0 | Muscle heat map (hero) | Per §3.3 |
| W14 | P1 | Muscle × week grid | Heatmap, color = sets; gaps are visible |
| W15 | P1 | Frequency per muscle | Lollipop: sessions per week |
| W16 | P1 | Balance | Radar normalized to targets + push:pull, quad:ham, upper:lower ratio list |
| W17 | P1 | Volume load by week | Stacked by muscle or movement pattern |
| W18 | P1 | Mesocycle overlay | Shaded phases, volume ramp, deload markers, performance trend |
| W19 | P0 | Training calendar | GitHub-style heatmap, intensity = volume; tap a day → that workout |
| W20 | P1 | PR wall / timeline | Milestones by date and type |
| W21 | P1 | Strength-standards ladder | Level progress per lift + radar across lifts |
| W22 | P1 | Powerlifting total and points | Squat+bench+deadlift total, DOTS / IPF GL over time |
| W23 | P1 | Relative strength | e1RM ÷ bodyweight trend |
| W24 | P1 | Cumulative tonnage | Odometer + exercise treemap; playful equivalents toggle (off by default) |
| W25 | P1 | Plan adherence | Sessions per week vs plan; completion % |
| W26 | P2 | Time-of-day performance | Heatmap of when sessions go best |
| W27 | P1 | Weekly report card | Auto-generated, shareable |

**Fuel (VZ-F)**

| ID | P | Visual | Spec |
|----|---|--------|------|
| F1 | P0 | Day macros | Rings + stacked bar per meal (P/C/F) |
| F2 | P0 | Calorie bars | 7/30 days, target line, 7-day average, neutral over/under shading |
| F3 | P0 | Macro split | Donut (% of kcal) + protein g/kg gauge |
| F4 | P1 | Energy balance | Intake vs estimated expenditure area, cumulative deficit/surplus line, predicted weight change |
| F5 | P0 | Weight vs calories | Small multiples on a shared x-axis |
| F6 | P1 | Adaptive expenditure | Line with confidence band; step-informed markers |
| F7 | P0 | Adherence calendar | In-range days; streak counters |
| F8 | P1 | Micronutrients | % of RDA/AI bars (radar optional), UL warnings, gap finder |
| F9 | P1 | Protein distribution | By meal vs a per-meal threshold (default 0.3 g/kg) |
| F10 | P2 | Meal timing | Hour × day heatmap, eating window, fasting timeline |
| F11 | P1 | Top contributors | Ranked foods by protein / kcal / sodium / fiber |
| F12 | P1 | Hydration, caffeine, alcohol | Trend lines |
| F13 | P1 | Limits | Fiber / sugar / sat fat / sodium vs limits |
| F14 | P1 | Training vs rest day intake | Paired bars |
| F15 | P1 | Weekly calorie budget | Bullet chart (flex mode) |
| F16 | P1 | Health score | Daily trend + sub-score breakdown |
| F17 | P1 | Diet-phase timeline | Cut / bulk / maintain / diet break with realized rate of change |
| F18 | P2 | Peri-workout nutrition | Protein/carbs relative to session time |

**Body and recovery (VZ-B)**

| ID | P | Visual | Spec |
|----|---|--------|------|
| B1 | P0 | Weight | Scatter + EWMA trend + goal line + projected date + rate band |
| B2 | P1 | Composition | Body-fat %, lean/fat mass stacked area; method tags (scale/DEXA/caliper/visual); error bars |
| B3 | P1 | Measurements | Multi-line and small multiples; waist:hip, waist:height |
| B4 | P1 | Progress photos | Timeline grid, side-by-side slider, onion-skin; guided poses; biometric-locked vault; hide-numbers share |
| B5 | P1 | Sleep / HRV / RHR | Trends + readiness composite |
| B6 | P1 | Steps and active energy | Daily bars + 7-day average |
| B7 | P1 | Rate-of-change gauge | kg/week and % bodyweight/week, neutral coloring, safe-range indicator |
| B8 | P1 | Lean-mass preservation | Δweight vs Δlean/waist, protein adherence, resistance sessions per week (cuts and GLP-1 use) |

**Stack (VZ-S)**

| ID | P | Visual | Spec |
|----|---|--------|------|
| S1 | P0 | Dose timeline | Swimlane per compound; taken/late/skipped/missed markers; zoomable |
| S2 | P0 | Adherence | Calendar + rings per protocol; 30/90-day % |
| S3 | P1 | Estimated active level | Per-compound curve + stacked overlay; steady-state band; next-dose marker; assumptions sheet; hidden if half-life unknown |
| S4 | P1 | Cumulative and weekly dose | Step markers for titration changes |
| S5 | P1 | Cycle / titration Gantt | Planned vs actual; on/off; washout |
| S6 | P0 | Injection-site map | Recency heat, L/R, rotation helper |
| S7 | P0 | Inventory gauges | Remaining mL/doses, days left, beyond-use countdown, run-out forecast |
| S8 | P1 | Cost | Per dose / mg / month; total spend; reorder planner |
| S9 | P0 | Symptoms | Symptom × day heatmap + severity timeline with dose markers; "days since dose" distribution |
| S10 | P1 | Biomarkers | Small multiples with reference bands and dose/phase annotations |
| S11 | P1 | Outcome overlays | Weight / waist / BF% / appetite / sleep with dose phases shaded |
| S12 | P1 | Check-ins | Appetite / energy / mood trends |

**Cross-domain (VZ-X)** — the differentiators

| ID | P | Visual | Spec |
|----|---|--------|------|
| X1 | P1 | Master Timeline (hero) | Per §3.3 |
| X2 | P1 | Correlation explorer | Any two series + lag 0-14 days; scatter + trendline; Spearman ρ, n, bootstrap CI; n ≥ 14 gate; coverage shown; copy says "association, not cause" |
| X3 | P1 | Weekly "State of You" | 3 wins · 2 flags · 1 suggestion + charts; PDF/PNG |
| X4 | P1 | Phase comparison | Two date ranges side by side (before/after a protocol change, cut vs maintenance) with deltas |
| X5 | P1 | Goals dashboard | All domains, projected dates |
| X6 | P2 | "What changed?" | When a trend breaks, rank candidate factors (intake, volume, sleep, dose change) by effect size; descriptive only; multiple-comparison warning |
| X7 | P1 | Annual recap | Shareable, hide-numbers option |
| X8 | P1 | Clinician/coach report | PDF: protocol summary, adherence, symptoms, labs, weight/waist, dated |
| X9 | P1 | **Dose-cycle overlay** | Average intake, protein, energy and training performance by days since last dose (0-7+), e.g., "protein dips on days 1-2 after a dose"; descriptive only |
| X10 | P2 | Recomp scoreboard | Waist ↓ · e1RM ↑ · weight stable · protein adherence |

### 3.5 Insight engine
Deterministic by design: a stats module computes facts (robust slopes, deltas, adherence, coverage) → a template library renders sentences. Gates: minimum N, minimum time span, and signal > noise (e.g., change > 2× the MAD of the detrended series); otherwise show "No clear trend yet". Each insight stores its inputs for the "Why?" sheet. Unit-test with fixtures that include noisy, flat and gappy data. AI may rephrase an insight; it may never invent one.

## 4. FUEL — nutrition and macros (IDs `FUEL-`)

Benchmark intent: MyFitnessPal-class database and logging depth (search, barcode, recipes, meals, custom macro/micro goals, fasting, verified foods, meal planner); Cal AI-class speed (photo-first logging, label scan, health score, widgets, streaks); MacroFactor-class intelligence (trend weight, adaptive expenditure, weekly check-ins).

### 4.1 Logging
- **FUEL-01 · P0** Instant search (offline recents, favorites, frequent), copy yesterday / copy meal, quick-add kcal/macros, custom foods, barcode, meal slots (4 by default plus custom, each with a time).
- **FUEL-02 · P0** Food-database layer with a canonical schema. Sources: USDA FoodData Central (generic foods), Open Food Facts (packaged foods/barcodes; honor ODbL attribution and share-alike duties), and an optional licensed commercial database for restaurants/brands (evaluate Nutritionix/FatSecret/Edamam-class licenses and cost). Rank by quality (verified > label > user-submitted), dedupe, normalize to per-100 g, store household measures and density, "report an error", private user corrections.
- **FUEL-03 · P0** Serving UX: g / oz / cup / ml / tbsp / piece; smart default; slider + numeric entry; live macro preview; multiplier.
- **FUEL-04 · P0** Custom foods and recipes: ingredient builder with servings and a **raw → cooked yield factor**; import a recipe from a URL (schema.org Recipe). P1: photo → recipe; nutrition-label OCR → custom food.
- **FUEL-05 · P0** Saved meals/templates, day cloning, planned vs eaten.
- **FUEL-06 · P0** Water, caffeine, alcohol (units + kcal), non-peptide supplements — quick log.
- **FUEL-07 · P0** Per-meal notes, hunger/mood tags, photos.

### 4.2 AI-assisted logging
- **FUEL-10 · P1** Photo scan → items + estimated grams + confidence. Per-item edit (swap match, change portion), add-on prompts (oil, sauces), depth/LiDAR or reference-object scaling when available, multi-photo, **"Fix with words"** ("that was 2 tbsp olive oil"), save as meal. Pipeline (§7 AI-07): a vision model proposes items and grams → map to database entries → deterministic macro math → the user confirms. **The model never supplies final macros.**
- **FUEL-11 · P1** Barcode + label: EAN/UPC with an offline cache; fall back to nutrition-facts OCR with a structured parse and a sanity check (kcal ≈ 4P + 4C + 9F within 10%).
- **FUEL-12 · P1** Voice/text: "two eggs, toast with butter, a banana" → structured items with confirmation chips; multi-meal utterances.
- **FUEL-13 · P1** Restaurants: chain database; "describe the dish" returns a min / typical / max range.
- **FUEL-14 · P2** Smart suggestions: foods that best fill the remaining macros (the user's favorites first), leftovers planner, pantry/grocery scan.

### 4.3 Targets and coaching
- **FUEL-20 · P0** Target setup: BMR via Mifflin–St Jeor (Katch–McArdle if body fat is known) × activity (or steps-informed); goal (cut / maintain / lean bulk / bulk / recomp) with a rate (kg or % bodyweight per week); macro presets (balanced, high-protein, low-carb, keto, vegetarian…); protein default 1.6–2.2 g/kg (2.0 mid-range, higher in deficits); fat floor (default 0.6 g/kg or 20% of kcal); fiber 14 g per 1,000 kcal; carbs = remainder; §11 safety floors apply.
- **FUEL-21 · P0** Day types: training vs rest day (auto from the schedule), carb-cycling presets, per-weekday overrides, weekly calorie budget (flex), refeed / diet-break scheduler.
- **FUEL-22 · P1** Adaptive targets (your own implementation, MacroFactor-inspired): EWMA trend weight, expenditure estimated from intake + trend, weekly check-in with a recommended target change, confidence and data-sufficiency gating, step-informed option, manual override, pause for illness/travel.
- **FUEL-23 · P1** Per-meal targets (protein distribution), grams-or-% toggle, net carbs.
- **FUEL-24 · P1** Micronutrient targets by age/sex (RDA/AI/UL; cite NIH/NASEM), supplements included, UL flags worded neutrally.
- **FUEL-25 · P1** **GLP-1 support mode:** protein-first layout, small-meal-friendly logging, hydration and fiber nudges, nausea-day quick log, lean-mass-preservation insights (protein g/kg, resistance sessions per week, weight vs waist/lean estimate); repeated very-low intake → a gentle "talk to your clinician" prompt. Evidence basis: resistance training plus roughly 1.6–2.2 g/kg protein is commonly recommended to limit lean-mass loss during GLP-1 weight loss.
- **FUEL-26 · P1** Intermittent fasting: timer, schedules (16:8, 5:2, custom), eating window, Live Activity; hidden for users flagged ED-risk (§11).
- **FUEL-27 · P2** Meal planner + grocery list: week plans from macros, diet tags, allergies and budget; exportable list.
- **FUEL-28 · P1** **Health score** (0-10, transparent): implement the open Nutri-Score algorithm or a documented custom score (protein density, fiber, added sugar, saturated fat, sodium, NOVA flag). Every point is explainable; never moralize foods.

### 4.4 Integrations and extras
- Apple Health / Health Connect: write dietary energy, macros, water; read steps, active energy, weight, body fat (**P0** for weight and steps).
- P1: allergen and diet tags (vegan, halal, kosher, gluten-free), glycemic index/load, sugar-alcohol net carbs, widgets, Watch complications, Siri Shortcuts, a share extension for recipe URLs, import from MyFitnessPal/Cronometer CSV, CSV/PDF export.
- P2: CGM glucose overlay from Health on meals and doses.

## 5. STACK — peptide and protocol tracker (IDs `STK-`)

Benchmark intent: STACKR-class dose logging, reminders, widgets, vial/pen inventory and half-life-based active-level charts; Shotsy-class GLP-1 logging with side effects and multi-medication schedules; the category-standard reconstitution calculator and injection-site body map. **Stack is a logbook and a calculator. It is not a source of medical advice.**

### 5.1 Ground rules for this module (also enforced in §11)
- No dose recommendations, titration advice, stacking advice, efficacy or benefit claims, vendor/sourcing links, marketplace or affiliate links, and **no public protocol sharing or community feed**.
- Adults only (18+), explicit opt-in with disclaimer and acknowledgement; hideable/disableable at any time; remote region/store kill-switch via feature flag; a build-time flag so a build can omit the module entirely.
- Clinical-neutral UI language ("dose", "injection", "protocol"); no slang.
- Reference data (names, class, published half-life, label storage, regulatory status by region) only with a citation and a date. **No benefit or dosing fields** in seeded data.

### 5.2 Compounds, protocols, schedules
- **STK-01 · P0** Compounds: user-created (P0) or picked from a neutral reference list (P1). Fields: name/aliases, class, routes, units, forms (vial/pen/tablet/nasal/topical), published half-life with a citation or "unknown", regulatory-status badge by region (approved Rx · unapproved · prohibited in sport) with source and date, label storage notes.
- **STK-02 · P0** Protocols: one or more compounds; amount + unit (mcg / mg / IU / mL / units / pen clicks); route; schedule; start/end; notes; color; pause/resume; **version history** ("what changed when"); user-made templates and stacks (grouped compounds sharing one reminder); multiple concurrent protocols. Schedule types: daily · every N days · weekdays · N× per week · weekly · biweekly · monthly · on/off cycles (e.g., 5-on/2-off, 8-on/4-off) · PRN · titration step lists (date → amount) · custom iCal RRULE; time(s) of day; with-food/fasted note.
- **STK-03 · P0** Schedule engine: generates occurrences; handles DST and timezone/travel (floating vs fixed times); state machine due → taken / late / skipped / missed; late windows; snooze; property-tested.
- **STK-04 · P0** Dose log: one tap from notification / widget / Watch / Siri; actual amount and time; site (body map); route; vial or pen used (auto-deduct); needle/syringe; lot/batch; notes; photo; quick check-in (energy, appetite, mood, sleep, 1-5); pain/redness/bruise rating; edit/delete with an audit trail; backfill; double-dose guard ("You logged this N hours ago — log another?").
- **STK-05 · P0** Reminders: local notifications with actions (Log · Snooze · Skip); repeat-until-logged option; quiet hours; refill and expiry reminders; widgets (next dose + countdown, today's checklist); Live Activity for "due soon". **Discreet mode:** neutral notification text, no compound names on the lock screen.

### 5.3 Calculator, inventory, sites
- **STK-06 · P0** Reconstitution and draw calculator — **math only; it never suggests a dose.** Inputs: amount in vial (mg / mcg / IU), diluent volume (mL), target dose; syringe (U-100 0.3/0.5/1 mL, U-40, custom); pen mode (fixed dose per click); oral/nasal/topical. Outputs: concentration, draw volume (mL and syringe units), doses per vial, days of supply, expected waste. Blends: ratio or per-component amounts. Reverse mode: pick a diluent volume so the draw lands on whole units. **Safety UX:** show the math step by step; hard warnings for draws < 2 units or > barrel capacity, unit mismatches and implausible results; footer "Verify with your label, pharmacist or prescriber"; saved presets attach to a vial; one function feeds both the numbers and the syringe graphic. Golden vectors + property tests (§9.3).
- **STK-07 · P0** Inventory: lifecycle sealed → reconstituted/opened → in use → empty / expired / discarded; reconstitution date and a user-entered beyond-use date (prompt to copy it from the label; no hard-coded shelf-life claims); storage (fridge / freezer / room); remaining volume/doses auto-depleted by logged doses with priming/waste adjustments; low-stock, expiry and run-out forecasts; lot/batch; supplier as free text; price → cost per dose; photos of label/COA. P1: scan the GS1 DataMatrix on pharma packs (GTIN, lot, expiry) where present.
- **STK-08 · P0** Injection-site tracking: front/back body map with tappable zones (abdomen quadrants, thighs, glutes, deltoids, upper arms, flanks…), L/R, SC/IM tag chosen by the user; recency heat; a **rotation helper** = least-recently-used zones (bookkeeping, not clinical advice); avoid-zone marking (scar/lump); per-site notes and reaction photos.
- **STK-09 · P0** Side effects and symptoms: picker + free text, severity 1-5, onset relative to dose, link to protocol(s), photos; a red-flag banner with generic guidance ("seek medical care for severe or concerning symptoms; call emergency services for signs of a severe allergic reaction").

### 5.4 Analytics, labs, reports
- **STK-10 · P1** Estimated active level: 1-compartment model with optional absorption lag, from a cited or user-entered half-life; multi-compound overlay; steady-state shading; labeled "illustrative estimate, not a blood level"; **disabled when half-life is unknown**; unit-tested against analytic solutions (§9.3).
- **STK-11 · P1** Bloodwork and biomarkers: manual entry, panel templates (CBC, CMP, lipids, HbA1c/fasting glucose/insulin, thyroid, sex hormones, IGF-1, liver/kidney, CRP, ferritin, vitamin D…), custom markers, unit conversion (mg/dL ↔ mmol/L), lab-specific reference ranges, neutral low/high flags, trends with dose annotations, user-set retest reminders. P2: lab-PDF OCR with confirmation; Apple Health Clinical Records import.
- **STK-12 · P1** Clinician/coach report (PDF/PNG): protocol summary, adherence, dose history, symptoms, weight/waist/BF trend, labs; date range; redaction options. P2: expiring secure share link.
- **STK-13 · P1** Cost tracking: price per vial/pen, cost per mg / dose / month, reorder planner.
- **STK-14 · P1** General medication/supplement tracking on the same engine ("my stack" view). Duplicate-class and interaction warnings ship **disabled** until a clinician-reviewed dataset exists.
- **STK-15 · P1** Check-ins: daily/weekly (appetite, energy, sleep, mood, GI, custom metrics) feeding charts.
- **STK-16 · P2** PK helpers: accumulation factor, time to steady state (~4-5 half-lives), washout estimate — informational only.
- **STK-17 · P2** Travel mode (timezone plan, packing-checklist notes); partner/caregiver read-only reminders with consent; "protocol review" summary assistant (within the AI-06 limits).
- **STK-20 · P1** Privacy and discretion: biometric lock for the module and its photos; app-switcher blur; neutral notification text; optional alternate app icon/name; a separate encrypted store for Stack data (optional E2EE).

## 6. BODY and RECOVERY (IDs `BODY-`)

- **BODY-01 · P0** Weigh-ins (manual, Health sync, smart-scale CSV), EWMA trend, goal, rate of change, projected date; tags (post-travel, illness…).
- **BODY-02 · P0** Measurements: neck, shoulders, chest, arms L/R, forearms, waist (selectable landmarks), hips, thighs L/R, calves L/R, custom; body-fat % with a method tag; derived lean/fat mass.
- **BODY-03 · P1** Progress photos: guided front/side/back poses, lighting/distance guide, ghost overlay for alignment, timeline + slider, biometric-locked vault, crop/blur for sharing.
- **BODY-04 · P1** Sleep, HRV, resting HR, steps and active energy from Health/wearables (read-only); a transparent **readiness composite** (documented weights, labeled estimate); a 10-second subjective check-in (sleep quality, soreness, stress, motivation).
- **BODY-05 · P2** Optional cycle-tracking import from Health to contextualize training/nutrition. This is the most sensitive data class (§11); off by default.
- **BODY-06 · P2** Tape-based body-fat estimators, labeled as estimates.
- **BODY-07 · P0** Safety rails (BMI/rate caps, hide-numbers mode, ED-sensitive defaults) — §11.

## 7. AI layer (IDs `AI-`)

- **AI-01 · P1** **Universal Logger:** one text/voice box → structured entries across domains (sets, foods, doses, weigh-ins, symptoms, water) shown as editable chips. It never auto-saves doses or other health-critical entries without confirmation. Learns the user's aliases ("my usual shake").
- **AI-02 · P1** **Grounded coach chat:** answers questions about the user's own data through deterministic query tools (e.g., `get_weekly_sets(muscle, range)`, `get_e1rm(exercise, range)`, `get_day_macros(date)`, `get_adherence(protocol, range)`). Every answer cites the chart/data behind it. Drafts routines and meal ideas. Refuses or redirects out-of-scope requests (AI-06).
- **AI-03 · P1** Weekly review (VZ-X3): deterministic stats + optional LLM narration.
- **AI-04 · P2** Program generator and workout compressor (goals, days, equipment, injuries, priorities → editable routines with rationale).
- **AI-05 · P2** Opt-in on-device form analysis (pose estimation); no video upload by default.
- **AI-06 · P1** **Safety layer:** pre- and post-filters plus a system policy for requests about dosing, titration, stacking, sourcing, diagnosis or extreme dieting; helpful refusal templates that redirect to a clinician and to the app's logging tools; a ≥ 100-prompt red-team suite in CI; privacy-safe refusal telemetry.
- **AI-07 · P1** Engineering controls: provider-agnostic gateway (keys server-side only, default to the owner's existing provider); structured outputs (JSON Schema); image downscale + EXIF strip; caching; per-user quotas by tier; streaming UI; retry/backoff; graceful fallback to manual entry; model/prompt versioning; a **food-photo eval harness** (≥ 200-meal golden set; report median and P90 absolute % error for kcal and protein; rerun on every model/prompt change); zero-retention / no-training API settings; on-device ML for barcode/OCR where possible. The app is fully usable with AI switched off.

## 8. Platform, monetization and growth (IDs `PLAT-`)

- **PLAT-01 · P0** Onboarding to first value in ≤ 90 s: goal, units, experience, schedule/equipment, diet basics; the Stack opt-in gate (age + disclaimer); just-in-time permission prompts; import from other apps; **demo mode** with the seeded dataset so users can explore the charts before logging anything.
- **PLAT-02 · P0** Settings: units, theme, modules, rest defaults, set-count mode, e1RM formula, week start, notifications, privacy/security (lock, discreet mode), export/import/delete account, AI toggles, accessibility, language, subscription.
- **PLAT-03 · P0** Accounts and sync: Sign in with Apple / Google / email; offline-first local DB with background sync; per-record conflict resolution (logical clocks, tombstones; append-only logs for sets and doses); multi-device; account deletion honored within 30 days.
- **PLAT-04 · P0** Data portability: full JSON + CSV export of everything. **P1:** importers (Strong, Hevy, StrengthLog, Fitbod, JEFIT, MyFitnessPal, Cronometer, Apple Health `export.xml` via a streaming parser) with a mapping UI and a dry-run.
- **PLAT-05 · P1** Widgets, Live Activities, Shortcuts, Control Center controls and Watch complications (see TRN-80..82, §4.4, STK-05).
- **PLAT-06 · P1** Notification framework: categories, quiet hours, bundling, actionable; no guilt; "streak at risk" only if opted in.
- **PLAT-07 · P1** Subscriptions via RevenueCat. **Free:** unlimited manual logging in all three domains, core charts, custom exercises/foods. **Pro:** AI-scan quota, adaptive targets, advanced analytics (volume landmarks, standards, correlations, Master Timeline), active-level charts, labs, reports, Watch/widgets, program builder. Annual + lifetime options; transparent trial; no dark patterns; restore purchases.
- **PLAT-08 · P1** Observability: crash reporting and analytics with health values scrubbed (event names and counts only); remote feature flags; performance tracing.
- **PLAT-09 · P1** Support: in-app feedback with opt-in log attach, changelog, "How we calculate" pages.
- **PLAT-10 · P2** Web companion (read-only dashboards, import/export), Android parity, tablet/iPad layouts, public API/webhooks and Google Sheets export for power users.

## 9. Data model and calculation specs

### 9.1 Conventions
- **IDs:** UUID v7. Every row has `created_at`, `updated_at`, `deleted_at` (tombstone) and `source` (manual / import / health / ai).
- **Time:** store `occurred_at` (UTC), `tz` (IANA) and `local_date` (YYYY-MM-DD at the moment of logging). **All day/week aggregation uses `local_date` and the user's week start — never UTC midnight.**
- **Units:** canonical kg, g, mL, µg, cm, kcal. Also store **the value and unit as entered** and display what the user entered (135 lb must show 135, never 134.99). Dose amounts and volumes are integers (µg, µL) or fixed-point decimals — never binary floats. Money = integer minor units.
- **Derived data:** maintain **daily rollup tables** (nutrition, training-by-muscle, body, stack), updated on write and rebuildable by an idempotent job. Charts read rollups.
- **Series Registry and Event Registry:** a Series Registry (id, domain, unit, kind [daily / event / instant], aggregation [sum / mean / last / max], color token, source query) and an Event Registry feed the Master Timeline, Correlation Explorer and reports generically. Every new metric registers once and appears everywhere.

### 9.2 Core entities (non-exhaustive — Phase 0 produces the full ERD)
Profile, Settings · Exercise, ExerciseMuscle(weight), Equipment, GymProfile, PlateInventory · Routine, RoutineExercise, Program, ProgramWeek/Day, ProgressionRule, Mesocycle · Workout, WorkoutExercise, Set(type, weight, reps, rpe, rir, duration, distance, side, tempo, rest_actual, completed_at), PRRecord · Food, FoodServing, FoodSource, LogEntry(meal slot), Recipe, RecipeIngredient, MealTemplate, WaterLog, NutrientTarget, DayTargetOverride, ExpenditureEstimate · WeighIn, Measurement, Photo, CheckIn · Compound, Protocol, ProtocolStep, ScheduleRule, DoseOccurrence, DoseLog, Vial, InjectionSite, SideEffect, Biomarker, LabResult · Event (annotation), Goal, Insight (cached with its inputs), Attachment, AuditLog (dose/lab edits), SyncState.

### 9.3 Formulas and golden test vectors
Implement as pure functions in `packages/core` with 100% branch coverage. The vectors below are **arithmetic tests, not dosing guidance.**

- **e1RM** (w = weight, r = reps): Epley = `w(1 + r/30)` → 100 kg × 5 = **116.67**. Brzycki = `36w/(37 − r)` → 100 × 5 = **112.5**. O'Conner = `w(1 + 0.025r)` → **112.5**. Lombardi = `w·r^0.10` → **117.46**. Mayhew, Wathan, Lander per their published forms (tolerance ±0.1). **RPE-adjusted:** use `r + RIR` with `RIR = 10 − RPE`. Confidence is "low" above 12 reps; such sets are excluded from e1RM PRs by default.
- **Volume load** = Σ weight × reps over counted sets (warm-ups excluded by default). Bodyweight rules: BW + added (weighted), BW − assist (assisted). Dumbbells: per-hand × reps unless "count both hands".
- **Fractional sets:** a set's contribution to muscle m = weight_m (primary 1.0, secondary 0.5 by default). **Hard set:** a counted set with RIR ≤ 4 (or RIR unlogged).
- **PR rule (rep records):** a set (w, r) sets record(N) for every N ≤ r where w > best_w(N).
- **BMR** Mifflin–St Jeor: `10·kg + 6.25·cm − 5·age + 5` (male) or `− 161` (female). Katch–McArdle: `370 + 21.6·LBM_kg`. Default activity multipliers 1.2 / 1.375 / 1.55 / 1.725 / 1.9.
- **Weight trend (EWMA):** `trend_t = trend_{t−1} + α·(w_t − trend_{t−1})`, α = 0.1, first value seeds the trend; across a gap of n days use the effective gain `1 − (1 − α)^n`.
- **Expenditure estimate (default):** `TDEE ≈ mean(intake over window) − (Δtrend_kg × 7,700 / days)`; window 14-21 days; require ≥ 70% of days logged; clamp weekly target moves (default ±150 kcal); report confidence.
- **Energy check:** `kcal ≈ 4P + 4C + 9F + 7·alcohol_g`; flag > 10% mismatch.
- **Reconstitution / draw:** `concentration (mg/mL) = vial_mg / diluent_mL`; `draw_mL = dose_mg / concentration`; `U-100 units = draw_mL × 100`; `doses per vial = vial_mg / dose_mg` (floor for full doses). Vectors:
  - 5 mg vial + 2 mL, dose 0.25 mg → 2.5 mg/mL, **0.10 mL = 10 units**, 20 doses.
  - 10 mg + 1 mL, dose 2.5 mg → 10 mg/mL, **0.25 mL = 25 units**, 4 doses.
  - 2 mg + 2 mL, dose 0.3 mg → 1 mg/mL, **0.30 mL = 30 units**, 6 full doses.
  - Blend, 10 mg total at 1:1 in 2 mL, draw 0.10 mL → 250 µg of each component.
  - Property test: dose → draw → dose round-trips within rounding tolerance for every syringe type.
- **Active-level model** (relative amount, not concentration): `k_e = ln2 / t½`. Instant absorption: `L(t) = Σ D_i · 0.5^((t − t_i)/t½)`. With absorption rate k_a: `L(t) = Σ D_i · k_a/(k_a − k_e) · (e^(−k_e·Δt) − e^(−k_a·Δt))`, with the k_a ≈ k_e limit `D_i · k_e · Δt · e^(−k_e·Δt)`. Accumulation factor at interval τ: `R = 1 / (1 − 0.5^(τ/t½))`.
- **Correlation:** Spearman ρ by default; bootstrap 95% CI; require n ≥ 14 paired points; optional lag 0-14 days; always report coverage.
- **Robust trend:** Theil–Sen slope with a MAD-based noise estimate for the insight gates (§3.5).
- **Standards and points:** DOTS, IPF GL, Wilks and Sinclair use the official published coefficient tables, stored as versioned data with citations and unit-tested against published worked examples.

## 10. Architecture and non-functional requirements

### 10.1 Default stack (override only via ADR)
- **Mobile:** React Native + Expo (TypeScript, strict), Expo Router, dev client; native modules/targets for HealthKit / Health Connect, Live Activities, widgets and the Watch app (SwiftUI targets via config plugins). Alternative if the owner prefers best-in-class iOS: native SwiftUI (SwiftData/GRDB, Swift Charts, WidgetKit, ActivityKit, App Intents) with Kotlin/Compose later. Flutter only with an ADR.
- **Local data:** SQLite (expo-sqlite or op-sqlite) + Drizzle ORM migrations (or WatermelonDB — decide in Phase 0). Sync via a PowerSync/ElectricSQL-class engine or a custom outbox + cursor pull; decide by ADR.
- **Backend:** Supabase (Postgres, Auth, Storage, Row-Level Security, Edge Functions) or Fastify + Postgres; typed contracts with zod/OpenAPI; region-pinned; encrypted backups.
- **State/data:** Zustand + TanStack Query; zod schemas shared by app and server.
- **Charts:** react-native-skia + Victory Native XL (or custom Skia); Reanimated + Gesture Handler for scrubbing; d3-scale/shape/array/time for math; LTTB downsampling. Body maps: SVG paths (react-native-svg); an open-source body-highlighter component is acceptable after a license check.
- **AI gateway:** server-side edge function(s) wrapping vision/LLM providers; structured outputs; provider-agnostic interface; secrets never on device.
- **Payments / analytics / crash:** RevenueCat · PostHog (EU/self-host) or Aptabase · Sentry with scrubbing.
- **Quality:** Jest + React Native Testing Library; Maestro E2E; fast-check property tests; ESLint/Prettier/tsc strict; GitHub Actions + EAS Build/Submit/Update; Dependabot + secret scanning.
- **Repo layout (pnpm workspace):** `apps/mobile` · `apps/watch` (SwiftUI) · `packages/core` (pure TS: every math engine, the schedule engine and the insight engine; no RN dependencies) · `packages/charts` · `packages/ui` · `packages/db` · `packages/data` (seed exercises, standards, nutrient tables, each with its license) · `supabase/` · `docs/`.

### 10.2 Budgets and quality bars
- Cold start < 2 s on a mid-range phone; 60 fps scrolling and scrubbing; chart first paint from cache < 150 ms (1 year) and < 400 ms (5 years); local queries p95 < 50 ms; set-log write < 30 ms.
- No lost data: a set, dose or meal is durable the moment the user confirms it. Migrations are reversible and tested on the demo database. Sync conflicts never silently drop an entry.
- Tests: `packages/core` 100% branch coverage; overall ≥ 80%; every chart has a golden-image test and an accessibility test; the schedule engine is property-tested across DST/timezone boundaries.
- Reliability: crash-free sessions ≥ 99.5% in beta. Battery: no continuous GPS or background polling beyond Health observers.
- Security (OWASP MASVS L1; L2 for Stack data): Keychain/Keystore, biometric lock, TLS, RLS on every table, input validation, no health values in logs/analytics/crash reports, least-privilege keys, dependency and secret scanning, an incident-response note in `docs/SECURITY.md`.

## 11. Safety, compliance and privacy guardrails (highest priority)

1. **Scope and disclaimers.** Caliber is a logging, calculation and education tool — not medical advice, diagnosis or treatment. Show this at onboarding, in Settings, and on every Stack screen that shows a calculation. Encourage consulting a licensed clinician for any medical decision.
2. **Age.** v1 is 18+ (age gate at onboarding), which also reduces exposure under COPPA and age-appropriate-design rules (counsel to confirm). Revisit before opening to teens.
3. **Stack module.** Everything in §5.1, plus: explicit opt-in, hideable, remote-killable by region/store, buildable without the module. No dose recommendations, no efficacy claims.
4. **No facilitation of sales or sourcing** of any drug or peptide: no vendor listings, affiliate links or marketplace; no public sharing of protocols or doses.
5. **Store policy.** Design to pass review and get a human policy read before submission. Apple App Review Guidelines §1.4 (Physical Harm: medical apps that could give inaccurate data get extra scrutiny; accuracy claims need disclosed methodology; apps may not facilitate drug sales) and §5.1.3 (Health data: no advertising/data-mining use, no selling, consent before sharing). Google Play Unapproved Substances policy, Health Content and Services policy, the Health apps declaration and Health Connect data-use rules. Verify the current text of each; set age ratings for injectable-drug content.
6. **Privacy law.** Treat all data as sensitive health data: minimization, export/delete on request, retention limits, consent records. Have counsel confirm obligations under GDPR Art. 9 (EU/UK), CCPA/CPRA sensitive personal information, the Washington My Health My Data Act and the FTC Health Breach Notification Rule; HIPAA likely does not apply unless integrating with covered entities. No ads, no data sale, no third-party SDK that receives health values. Health data is never used for advertising or model training.
7. **Eating-disorder and body-image safety.** Defaults: calorie floor ≥ 1,200 (female) / 1,500 (male) kcal, changeable only with an explicit clinician-override acknowledgement; default weight-loss rate cap ≤ 1% of bodyweight per week; BMI < 18.5 blocks deficit goals and shows support resources; **hide-numbers mode** (no calories or weights displayed); no "good/bad food" language; streaks and fasting are opt-in and are hidden for users who show risk signals (very low intake, rapid-loss goals, repeated floor overrides) with a gentle prompt toward support/a clinician; show regionally appropriate resources.
8. **Accuracy and honesty.** Every estimate is labeled as an estimate with method and confidence. AI-derived values show ranges. Active-level curves are never described as blood levels. All math has golden tests. Reference data carries citations and dates. `HOW_WE_CALCULATE.md` is user-facing.
9. **AI safety.** AI-06 in full. The model never outputs doses or medical recommendations. Macro numbers always come from the database, never from the model. Critical entries need confirmation.
10. **IP and licensing.** No copying of competitor assets, copy, branding or third-party program text. Exercise media and food/nutrient datasets only with compatible licenses (record attribution/share-alike duties, e.g., Open Food Facts ODbL, CC-BY-SA exercise data). Programs are generic parametric methods.
11. **Anti-doping.** Where regulatory data is shown, include a "listed on the WADA Prohibited List" flag (sourced, dated, refreshed annually) for tested athletes.
12. **Release gate.** A checklist in `docs/COMPLIANCE.md` covering items 1-11, plus the §10.2 security bullet, must be fully ticked with owner sign-off before any store submission.

## 12. Roadmap, phases and acceptance criteria

Work phase by phase. Within a phase, finish P0 before P1. Each phase ends with the §0.6 Verification report.

**Phase 0 — Audit and architecture** (highest reasoning effort)
- Deliver: gap analysis (if the owner pasted code); ADRs (stack, DB + sync, charts, AI gateway, how Stack is gated/distributed); ERD + SQL migrations v1 covering every P0 ID; package layout; design tokens + component inventory; Series and Event registries; risk register; test plan; backlog mapped to IDs.
- Done when: the owner can approve from one read, and every P0 ID maps to a table, a screen and a test.

**Phase 1 — Foundation**
- Deliver: monorepo, CI, design system + chart-kit skeleton, navigation, local DB + migrations, auth + offline-first sync with conflict-resolution tests (PLAT-03), settings/units/i18n (PLAT-02), feature flags, error boundary, log scrubber, the **demo-data generator** (12 months: a program with a deload, a cut phase, a titrating protocol, missed days, noisy weigh-ins) with a demo-mode toggle.
- Done when: the app boots on an iOS simulator and an Android emulator; CI is green; the demo dataset loads and survives a migration.

**Phase 2 — Train core** (all TRN P0 + VZ-W P0)
- Deliver: TRN-01..04, 10..19, 30..33, 40..41, 50..51, 60..63, 70..72, 92; VZ-W P0 charts.
- Done when: (a) a 6-exercise workout logs in < 3 min with ≤ 2 taps per set after the first; (b) killing the app mid-workout and reopening resumes with zero data loss; (c) the PR engine matches the golden fixtures, including edit/delete recompute; (d) the plate calculator is exact for kg and lb inventories; (e) e1RM, volume and fractional-set engines are 100% branch-covered; (f) a 200-workout history scrolls at 60 fps; (g) all VZ-W P0 charts render from demo data inside budget.

**Phase 3 — Train analytics and programming** (all remaining TRN P1 + VZ-W P1)
- Deliver: program builder, progression engine, mesocycle manager, stall/deload logic, injury mode, standards, goals, balance, recovery, reports, importers, Watch app, widgets, Live Activities.
- Done when: all six progression schemes pass unit tests and return reason strings; a simulated mesocycle yields the expected volume ramp and deload; every chart passes golden-image and accessibility tests; importers round-trip sample Strong/Hevy/StrengthLog files.

**Phase 4 — Fuel core**
- Deliver: FUEL-01..07, 20..26, 28; BODY-01, 02, 07 (weigh-ins, measurements and the safety rails — these must exist before targets go live); Health sync (weight, steps, nutrition); all VZ-F P0 plus F4, F6, F8, F9; VZ-B1.
- Done when: a typical day logs in < 90 s via search/barcode/favorites; stored macros reconcile with the database within rounding; target-engine tests pass; adaptive TDEE converges to within ±100 kcal of the true value on synthetic data after 3 weeks of clean logs; tests prove the BODY-07 rails block a 900 kcal target and any deficit goal when BMI < 18.5.

**Phase 5 — AI logging**
- Deliver: FUEL-10..13, AI-01, AI-06, AI-07 including the eval harness.
- Done when: photo → confirmed entry takes ≤ 3 taps; the eval report is committed (median and P90 error on the golden set); a test proves the model never supplies final macros; the red-team suite passes; the app works fully with AI off.

**Phase 6 — Stack**
- Deliver: STK P0 + P1 (calculator, schedule engine, reminders, inventory, site map, side effects, active-level model, labs, reports, discreet mode), VZ-S, module gating (feature flag + build flag).
- Done when: calculator golden vectors and property tests pass; schedule-engine property tests pass across DST/timezone boundaries; notification actions work with the app backgrounded and killed; vial depletion matches logged doses; the app compiles and runs with the Stack module excluded at build time.

**Phase 7 — Body, recovery and cross-domain insights**
- Deliver: BODY-03..04, the rest of VZ-B, VZ-X (X1-X5, X7-X9), AI-02 and AI-03 (grounded coach chat and weekly review, both built on deterministic query tools over every domain), goals dashboard, readiness.
- Done when: the Master Timeline scrubs at 60 fps with 365 days × 6 tracks; the Correlation Explorer enforces n ≥ 14 and reports CIs; the weekly report generates in < 2 s offline; every insight sentence is traceable to its inputs.

**Phase 8 — Platform polish and launch readiness**
- Deliver: onboarding (PLAT-01), importers (PLAT-04 P1), widgets/Live Activities/Shortcuts/complications for Fuel and Stack (PLAT-05), notification framework (PLAT-06), subscriptions/paywall (PLAT-07), observability (PLAT-08), support pages (PLAT-09), accessibility audit, performance pass, security review, the §11 checklist, store-listing drafts, privacy policy + data map, TestFlight/Play internal beta plan.
- Done when: all acceptance lists are green; `HOW_WE_CALCULATE.md` is complete; `COMPLIANCE.md` is fully ticked and signed off by the owner; beta crash-free sessions ≥ 99.5%.

## 13. Your first response

Do not wait for permission. In this order:
1. Restate the goal and your key assumptions in ≤ 10 lines.
2. Deliver Phase 0: gap analysis (if the owner pasted code), ADRs, ERD + SQL migrations v1, package layout, design tokens and component inventory, Series/Event registries, risk register, test plan, and a backlog mapped to IDs.
3. List at most 5 blocking questions, each with your default — **only** if §0.4 permits asking.
4. End with: "Ready for Phase 1 — say go."

## 14. Recommendations (apply unless the owner overrides)

1. **Make the one-timeline thesis the hero.** The Master Timeline, the Dose-cycle overlay (VZ-X9), the Correlation Explorer and the weekly "State of You" are what no single competitor has. They belong in the first store screenshots.
2. **Be generous in free.** Unlimited manual logging in all three domains; paywall analytics depth and AI quotas, not the basics. Paywalled basics are the opening competitors leave.
3. **Deterministic-first AI.** The model identifies, parses and narrates; databases and code compute; show ranges; measure error on every model change (AI-07).
4. **Own the GLP-1 lean-mass niche.** GLP-1 mode (FUEL-25) + resistance-training prompts + body-composition tracking (VZ-B8) address a fast-growing, well-evidenced need. Add the clinician report (VZ-X8) to build trust.
5. **Decouple Stack.** A separate, flag-gated package with its own privacy store, so a build without it can ship if a store objects. Get a clinician advisor to review Stack copy, and a policy/legal read before submission.
6. **Cut switching friction on day one.** Importers for Strong, Hevy, StrengthLog and MyFitnessPal, and a "Switch to Caliber" flow.
7. **Close the loop with readiness.** Sleep/HRV/soreness → a suggested session intensity, shown as a suggestion with its drivers, never as an order.
8. **Test like a lifter.** Test in a real gym with chalky, sweaty hands: rest-timer-first, big numerals, one-hand reach. This is where Strong and Hevy win loyalty.
9. **Trust through transparency.** Publish "How we calculate", cite standards and landmarks, and have a sports-science advisor review the defaults (volume landmarks, standards, e1RM, protein ranges).
10. **Measure the master-app thesis** (privacy-safe): time to first log per domain; % of users active in ≥ 2 domains by day 30; D1/D7/D30 retention; AI edit rate; paywall conversion.
11. **Clear the name.** "Caliber: Strength Training" already exists on the App Store. Check trademark and store availability before branding.
12. **Run a real beta.** 20-30 testers across lifters, cutters and GLP-1 users; dogfood for 4 weeks before submission.
13. **After v1.** CGM overlay, Garmin/Whoop/Oura, barbell-velocity sensors, meal planner, web app, Wear OS, coach dashboard, gym/team plans.

<!-- PROMPT END -->

---

## Sources consulted (as of 2026-10-07)

Competitor features were gathered from search summaries of the pages below (direct fetches were blocked). Treat them as starting points and verify against current store listings.

- STACKR (peptide/GLP-1 tracker): [App Store listing](https://apps.apple.com/us/app/stackr-peptide-tracker/id6764821587) · [getstackr.app](https://getstackr.app/) · category roundup of peptide trackers: [Stack – Peptide Tracker](https://apps.apple.com/us/app/stack-peptide-tracker/id6773488687)
- Shotsy (GLP-1 tracker): [App Store listing](https://apps.apple.com/us/app/-/id6499510249)
- Cal AI: [App Store listing](https://apps.apple.com/app/id6535683072) · [MyFitnessPal acquires Cal AI (Mar 2026)](https://pulse2.com/myfitnesspal-acquires-cal-ai-to-expand-ai-powered-nutrition-tracking-portfolio)
- MyFitnessPal tiers and features: [fitbudd overview](https://www.fitbudd.com/post/myfitnesspal-app-cost) · [2026 Winter Release](https://lite.aol.com/sports/other/story/0022/20260224/9659625.htm)
- MacroFactor: [expenditure algorithm](https://macrofactor.com/algorithm-accuracy/) · [2026 review](https://calorie-trackers.com/reviews/macrofactor/)
- StrengthLog: [bodybuilding app page](https://www.strengthlog.com/strengthlog-bodybuilding-app/) · [App Store listing](https://apps.apple.com/app/apple-store/id1434229662)
- Hevy: [features guide](https://help.hevyapp.com/hc/en-us/articles/33106320824727-Everything-You-Need-to-Know-About-the-Hevy-App-2025-Features-Guide) · [muscle-group chart](https://www.hevyapp.com/features/muscle-group-workout-chart/) · [Pro vs free](https://help.hevyapp.com/hc/en-us/articles/35119778922263-Hevy-Pro-Subscription-How-to-get-Pro-and-What-Does-It-Include)
- Strong vs Hevy: [comparison](https://setgraph.app/ai-blog/hevy-vs-strong-app-comparison-2026)
- Adaptive strength apps: [Alpha Progression vs Gravl](https://alphaprogression.com/en/blog/best-gravl-alternatives)
- Volume landmarks (RP-style): [overview](https://arvo.guru/resources/methods/rp-training)
- GLP-1, protein and resistance training: [IDEA](https://www.ideafit.com/glp-1-medications-and-lean-mass-why-resistance-training-matters/) · [Clinical Nutrition Center](https://www.clinicalnutritioncenter.com/research/resistance-training-glp1-therapy-muscle-preservation)
- GPT-6 Astra and how to prompt it: [GitHub changelog](https://github.blog/changelog/2026-09-04-gpt-6-astra-is-generally-available-in-github-copilot) · [prompting guide](https://promptessor.com/blog/gpt-6-astra-prompting-guide) · [CometAPI guide](https://www.cometapi.com/gpt-6-astra-prompting-guide/) · [Elser guide](https://www.elser.ai/blog/gpt-6-astra-prompt-guide)
- Store policies: [Apple guideline changes for health/medical apps](https://www.healthcaredive.com/news/apple-raises-entry-bar-for-medical-health-apps/425810/) · [Apple 1.4 rejection thread](https://developer.apple.com/forums/thread/134169) · [Google Play policy](https://support.google.com/googleplay/android-developer/answer/9878878)
- Name clash: [Caliber: Strength Training](https://apps.apple.com/app/id1482405410)

