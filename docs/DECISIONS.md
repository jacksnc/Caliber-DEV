# Decisions — Phase 0, 2026-10-07

Status: architecture proposal ready for owner review. Decisions below guide Phase 1; no application storage, UI, or deployment-target change was made in Phase 0. Details and tradeoffs live in `adr/`.

| ID | Choice | Reason / consequence |
|---|---|---|
| D01 | Retain native SwiftUI; pure Swift packages; Swift Charts. | Existing iOS preference and working app; permitted native alternative in §10.1. No React Native rewrite. ADR-001. |
| D02 | Propose iOS 17 minimum; keep the checked-in iOS 27 target until compatibility verification. | Original owner requirement. Current Xcode is 27; deployment support must be tested, not inferred. Android is a later Kotlin/Compose client, pending resolution of §12's Android Phase-1 line. |
| D03 | GRDB + SQLite target repositories; retain SwiftData until a verified copy migration. | Explicit SQL constraints, rollups and sync transactions; no access to SwiftData's private SQLite internals. ADR-002. |
| D04 | Two independent private databases; Stack keys and photos separate. | No Stack values or IDs in core caches; in-memory composition only after authorization. ADR-005. |
| D05 | Supabase auth/Postgres/storage + custom transactional outbox/cursor protocol. | Avoid premature coupling to a particular sync product; append-only revisions preserve conflicts. Cloud activation requires region/account approval. ADR-002. |
| D06 | No paid accounts, cloud deployments, external uploads, signing changes, or datasets acquired in Phase 0. | Architecture and disposable migration verification can proceed locally. |
| D07 | Versioned JSON contracts and golden vectors shared across languages. | Pure Swift on iOS; eventual Kotlin implementation must pass the same vectors. Do not add a second TS math implementation for an iOS-only client. |
| D08 | Stable calendar buckets use stored local date + IANA zone. | Later travel never moves old log dates; week start is an explicit query input. |
| D09 | Canonical kg with original decimal text/unit retained; UUIDv7 for new records. | Existing lb/UUIDv4 data is copied through a stable ID map; never reinterpret an old UUID as v7. Exact entered display is preserved. |
| D10 | Missing data is null/unlogged; measured zero is distinct. | No interpolated clinical values or trend claims; chart gaps and coverage remain visible. |
| D11 | Flags for every P1 requirement default off; P2 backlog only. | Feature maturity, privacy consent, store gate and entitlement are independent switches. P0 dependencies cannot depend on a paid P1 feature. |
| D12 | Safety/age/hide-numbers and import recovery infrastructure move into Foundation. | They must precede target editing, AI or Stack, even though full onboarding polish is in Phase 8. |
| D13 | Core live workout rest notifications/Live Activity support in Phase 2; P0 Stack notification actions in Phase 6. | Later PLAT/TRN P1 platform entries add breadth; cannot postpone the hooks required by earlier P0 acceptance. |
| D14 | Keep manual logging, basic graphs, custom foods/exercises and data portability free. | Entitlements may gate optional analytics, never access to or export of a user's records. |
| D15 | Prefer original exercise cues/illustrations; bundle no third-party data until a pinned license review. | Existing restaurant seed values also require provenance before public distribution. |
| D16 | Use 48pt interactive targets, satisfying the 44pt accessibility minimum. | One-hand logging and largest Dynamic Type; numbers never shrink to illegibility. |
| D17 | Dose/volume fixed point; entered IU, pen clicks and syringe graduations remain different dimensions. | No generic IU↔mg conversion or inferred dose. ADR-005. |
| D18 | Calculator release blocked pending qualified policy/legal review; reverse dilution suggestions off. | §11 prevails over STK-06 ambiguity. A disclaimer alone does not establish store eligibility. |
| D19 | Photo vault and Stack private lock protections precede sensitive capture, even where tagged P1. | Security controls are prerequisites, not paid upgrades. |
| D20 | No live-store migration in this delivery; SQL down scripts are disposable-test tools. | Real rollback is verified snapshot restoration; never drop production tables to roll back. |
| D21 | Domain accents stable, neutral outcomes, safety-only red; externalize strings in Phase 1. | Semantic JSON tokens are delivered now; no visual overhaul of current screens in Phase 0. |
| D22 | Current Git branch `codex/phase0-architecture`; phase-only commit; no push. | Existing staged/uncommitted source is preserved; local repo has no configured remote. |

## Explicit approval points
1. §10.1 allows native iOS and PLAT-10 defers Android, while §12 Phase 1 demands both simulators. Recommended amendment: Phase 1 verifies iOS; Android remains the later Kotlin client. Owner approval required under §0.4(d).
2. STK-06 release eligibility needs a human policy/legal determination; recommended proceed with logging and isolated calculator research, keep its release flag off until qualified. No store submission is authorized by Phase 0.
3. Paid providers/hosting region, dataset terms and any irreversible conversion will be brought back when concrete and necessary. They do not block this architecture package.

## Calculation defaults to freeze before engine implementation

These are engineering conventions for deterministic tests, not clinical clearance. HOW_WE_CALCULATE lists the ambiguities; this table resolves routine conventions while keeping genuine source/clinical gates open.

| Issue | Proposed deterministic default |
|---|---|
| M01 | Finite nonnegative load and positive integer reps; RPE 0–10, nonnegative RIR. Reject a formula-specific denominator/domain failure (Brzycki requires reps <37), without rejecting the underlying high-rep log. Use §9 formulas even at one repetition and label estimates. Low-confidence/PR exclusion if observed **or effective** reps exceed 12. Original Mayhew/Wathan/Lander forms need source verification before coding. |
| M02 | Reject assistance greater than captured bodyweight rather than create negative load. Store bodyweight/source snapshot at completion. Historical snapshots change only through an explicit edit/recompute command. Count-both multiplies per-hand tonnage only, not set count. Warm-ups never earn PRs. |
| M03 | Last valid reading per stored local day, stable `(occurred_at, id)` tie break; recompute that day and all later EWMA values after edit/delete. n is elapsed civil days between these buckets, never elapsed 24-hour intervals. Raw readings remain visible. |
| M04 | Explicit user day-complete status is required for intake coverage; unknown days are not zero. Prefer a 21-day window, allow 14–20 complete elapsed-day span with ≥70% days complete and ≥7 dated weigh-ins spanning the interval. Use endpoint trend difference over elapsed days and mean recorded complete-day intake; missingness is a displayed limitation. Weekly clamp applies once per week from the last accepted target. Confidence starts as qualitative coverage/stability, never an invented statistical CI. |
| M05 | A user selects the published formula coefficient explicitly; unknown eligibility disables automatic target calculation and offers manual tracking. Propose the larger of 0.6g/kg and 20% energy for fat minimum; if protein+fat leaves negative carbs, return incompatible targets rather than negative grams. Clinical applicability/override policy remains open. |
| M06 | Relative mismatch = abs(label kcal − computed kcal) / max(label kcal, computed kcal); both zero means no mismatch; flag strictly >10%. Preserve label calories, explain fiber/polyol/rounding limitations. Never double-count alcohol calories if already included in the label total. |
| M07 | Fixed-point scale and capacity come from explicit dimensioned device/label data. Retain full intermediate decimal precision, round labels only, show unrounded versus drawable values and never silently modify target amount. Reject overflow/unrepresentable values. Final-versus-added-volume handling and instrument eligibility await qualified review. |
| M08 | No IU↔mass or pen-click conversion without authoritative product-specific factors. Incompatible blend dimensions fail. PRN/unknown future schedule yields unknown days of supply. No source-derived clinical recommendation is inferred. |
| M09 | Elapsed time before the event contributes zero. Positive half-life and nonnegative elapsed time; use analytic equal-rate limit when relative rate difference ≤1e−6, with continuity tests. Unknown half-life disables the model. Absorption parameter sources remain a review gate. |
| M10 | Average ranks for ties; undefined correlation for constant series. Positive lag pairs X(day) with Y(day+lag), only actual paired days; require ≥14 pairs and ≥14-day span. Use deterministic seeded moving-block bootstrap (2,000 resamples; block length max(2, round(n^(1/3)))) with percentile CI; report autocorrelation/coverage limitations and multiple-search warnings. Statistical review precedes released insights. |
| M11 | Aggregate same-day values first, Theil–Sen over distinct day pairs, unscaled median absolute residual deviation. Require ≥14 readings over ≥14 days and absolute predicted change over that window >2×MAD plus a unit-specific minimum meaningful change; flat/zero-slope stays 'No clear trend'. Version minimum-change constants after review. |
| M12 | Official coefficients and category definitions remain unimplemented until a pinned, dated source plus worked examples is approved. No fabricated strength percentiles or medication reference values. |

The target schema must retain an explicit complete-day nutrition status for M04; presence of a food row alone cannot establish a fully logged day. Confidence and statistical defaults are inspectable, versioned assumptions, not efficacy claims.

## Phase 1 implementation decisions — 2026-10-08

The owner's “Go” accepted ADR-001's native iOS / later Android amendment. Phase 1 implementation proceeds under that approval; hosted services remain unconfigured.

| ID | Choice | Reason / consequence |
|---|---|---|
| D23 | Six targets/products in one local Swift package. | Independent boundaries without six separate resolver manifests; ADR-006. |
| D24 | iOS deployment target 17; Xcode project format 77. | Compile-time availability verified with current SDK; actual iOS17 execution remains a gate. |
| D25 | Keep live SwiftData; test lossless copy archive on fixtures only. | Avoid unapproved irreversible conversion; canonical mapping/cutover remains future work. |
| D26 | Separate deterministic fictional store, fixed 12-month endpoint and resumable seed checkpoint. | Demo cannot mix with personal diary; retry produces identical records. |
| D27 | Journal-first local/server sync, immutable branches and causal resolution. | Historical resolutions preserve unknown newer branches; domain adapters are not implicitly implemented. |
| D28 | No hosted activation until provider/region/account configuration. | Required setup question remains pending; no cloud account, key or upload was created. |
| D29 | Ephemeral HTTP session, no redirects/cookies/cache; Keychain credentials; typed safe diagnostic vocabulary. | Reduce credential persistence and prevent arbitrary health text in new diagnostics. |
| D30 | Calendar-based chart windows and distinct-day coverage, no interpolation across missing days. | Sparse records cannot stretch “1W” to several months. |
| D31 | English string catalogs with explicit regional formatting choices. | No false translation claim; complete localization audit remains required. |
| D32 | Checkpoint the exact existing app before the Foundation commit. | Hash-verified baseline preserves owner work and makes the Foundation diff reproducible. |
| D33 | CI runs fixture-only UI suites; existing restaurant UI scripts excluded until isolated. | Those older scripts can use the personal persistent store. Unit tests still exercise restaurant editing. |
| D34 | Minimum-OS, hosted CI/cloud, chart image baselines and device budgets stay open. | Local test success cannot establish production or physical-device acceptance. |


## Foundation follow-through — 2026-10-08

| ID | Decision | Reason/evidence |
|---|---|---|
| D35 | Use the owner's existing Caliber DEV Supabase project, `tuvbdozxtkcxnojxbvlh`, `us-east-1`. | Owner selected existing Supabase and supplied its dashboard link; authenticated overview verifies URL/region. No account or key was created. Supersedes D28's unanswered provider choice; hosted deployment remains pending. |
| D36 | Public metadata only in the app; project-scoped Keychain; separate deployment activation flag. | An unverified endpoint cannot silently become active. No client API key/service-role credential. Region routing is requested, not represented as verified full data residency. |
| D37 | Clear local session first; attempt current-session server logout afterward. | Offline logout stays possible. Report remote uncertainty; concurrent newer login remains intact. Supabase verifies authentication and fixed local logout scope. |
| D38 | Locale-aware strict decimal parsing across legacy and Foundation forms. | Preferences must apply to entered values and fractional edits without silent rounding/grouping reinterpretation. Tests cover both decimal separators and finite boundary values. |
| D39 | Verify largest-text chart routes and accessibility audits on the available simulator; keep minimum-OS gate open. | iOS 17.5 arm64 download was unavailable through installed Xcode. Compiling for deployment target 17 with SDK 27 is not runtime proof. |

## Local readiness fixes — 2026-10-10

| ID | Decision | Reason/evidence |
|---|---|---|
| D40 | Use a persistent full-width bottom control to exit the fictional demo. | The native navigation toolbar constrained its text at Accessibility XXXL. A wrapping body label and minimum 48pt touch area stay reachable across chart routes. |
| D41 | Put the Sendable account transport protocol in CaliberIntegrations; keep the UI model on the main actor. | An app-local protocol inherited the app target's main-actor default and prevented independent actor transports. Failed restoration remains retryable without restarting. |
