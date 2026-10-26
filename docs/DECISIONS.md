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

## Hosted preparation — 2026-10-10

| ID | Decision | Reason/evidence |
|---|---|---|
| D42 | Stage the exact tested bundle and atomic migration in the existing DEV project; compare editor copies before deployment. | No applicable Supabase connector or installed CLI was available. Fresh metadata confirms object names are available. Browser permission/authentication changes need action-time confirmation; app activation remains off until hosted verification. |
| D43 | Verify deployed catalog permissions separately from positive authentication. | The catalog query catches RLS and public-execution regressions locally. Hosted simulated-claim fixtures cannot prove JWT/sign-in/refresh/logout behavior. No personal records or credentials are needed for preflight. |

## Hosted deployment — 2026-10-10

| ID | Decision | Reason/evidence |
|---|---|---|
| D44 | Apply only the approved Foundation migration and gateway relay setting to DEV; keep app activation off. | Owner gave action-time approval. Six hosted permission checks, twelve simulated-claim behavior assertions, eleven HTTP rejection requests and eighteen genuine signed-token criteria pass. Provider hardening remains required. Other existing auth settings were inspected, not changed. |
| D45 | Create only the two named fictional confirmed DEV users under the owner's explicit “you do it” authorization. | This instruction supersedes the initial browser-guideline handoff. Independent generated passwords were held in a private temporary file, never printed or committed, and discarded after verification. The interactive runner keeps response tokens out of reports. Both test accounts and their synthetic notes remain; all test sessions were logged out. |
| D46 | Treat the current Auth limits as provider controls, not verified per-device gateway protection. | IP forwarding is off and the anonymous server key cannot use forwarded-IP rate limiting. Shared egress and existing signup/CAPTCHA settings require a reviewed hardening design before activation; no key/limit/protection was changed as a shortcut. |

## DEV authentication safeguards — 2026-10-11

| ID | Decision | Reason/evidence |
|---|---|---|
| D47 | Disable public signup in the existing DEV project; retain existing-user email access and confirmation. | Implements the brief's disabled-by-default registration policy under the owner's request for the next safeguards. Saved/reloaded provider state proves signup off; anonymous signup stays off. No invitation/email, real-account edit or data deletion. |
| D48 | Use guarded, shared Postgres token buckets rather than a process-local or caller-IP counter. | ADR-007; uses existing stack and database, no service-role key/new provider. A generated internal server-only guard authenticates the constrained budget RPC; private tables store only its digest and keyed identifiers. Six simultaneous hosted attempts cannot overspend a five-token identity burst. |
| D49 | Use separate sign-in/refresh capacities and leave local-scope logout outside these budgets. | A depleted login bucket cannot obstruct logout. Guard outages deny pre-login calls; 429 surfaces a localized wait message. Existing provider limits remain unchanged; global availability/direct-Auth/retention limitations stay explicit. |
| D50 | Use a separate fictional `auth-guard` fixture pair and owner IDs for the deployment regression. | Preserve the earlier QA fixture ownership/history. Eighteen genuine auth criteria pass; all issued sessions logged out and temporary credentials removed. Two new ordinary accounts/synthetic notes remain, without emails or personal health uploads. |
| D51 | Scope expired-counter cleanup to the already-locked route; preserve migration 002 and apply forward correction 003. | Final review identified a possible cross-route lock cycle after idle periods. Fresh database tests verify isolation of cleanup; existing grants/configuration and Auth/owner/limit contracts remain intact. Hosted source/body checks verify the final definition. |

## Optional account lifecycle — 2026-10-12

| ID | Decision | Reason/evidence |
|---|---|---|
| D52 | Require versioned optional account permission before restoration, login and recovery. | Email/auth/security processing is disclosed separately from health sync, photos, AI and analytics. Server acceptance is tied to the authenticated subject and server clock; local withdrawal preserves logs. ADR-008. |
| D53 | Use email recovery codes with no returned/saved recovery session. | No custom URL/deep-link setup; independent guarded request/verify budgets and explicit revocation uncertainty. The existing dashboard requires SMTP before template editing, so sender setup and actual delivery remain pending. No provider credentials or paid account were supplied. |
| D54 | Limit server administrative use to password-reauthenticated self-deletion. | Built-in service-role environment key only; never exposed to client/artifacts. Authoritative Auth subject must match password authentication; no caller-selected target. This narrow capability supersedes ADR-007's earlier no-admin-route statement. |
| D55 | Preserve local health data when deleting only the hosted account. | UI explicitly explains scope; credential clearing occurs after server acknowledgement, with recoverable Keychain failures. Dedicated simulator proves a local progress note survives. |
| D56 | Apply additive migration 004 without resetting counters, and delete only a new disposable lifecycle fixture. | Hosted twelve-criterion probe and catalog cleanup pass; four earlier QA accounts remain. No personal migration/upload/deletion occurred. |
| D57 | Leave app activation off until sender and provider safeguards are verified. | Local/hosted permission and deletion proof do not certify email delivery, provider retention, public bot protection, encrypted domain sync or full Phase 1. |

## Local restore rehearsal — 2026-10-13

| ID | Decision | Reason/evidence |
|---|---|---|
| D58 | Defer email setup and continue local Foundation work. | Owner explicitly selected this option; no sender/provider/hosted configuration is changed. |
| D59 | Restore saved legacy snapshots into a fresh in-memory SwiftData graph. | ADR-009: all 15 types can be checked without a live store/file destination. A disk-copy experiment exposed retained-handle cleanup diagnostics; the planned canonical target remains GRDB. This is mapping evidence, not disk durability. |
| D60 | Fail on unknown fields, inconsistent references/types or changed totals rather than silently repair a copy. | Exact recapture includes photo bytes, UUIDs, inverse relationships, menu/diary nutrition and original pounds. The future normalized projection must independently reconcile this evidence. |

## Food pipeline and normalized copy — 2026-10-14

| ID | Choice | Reason / consequence |
| --- | --- | --- |
| D61 | Keep normalized conversion in a separately named `normalized-rehearsal-v1/normalized-copy.sqlite` target. | One immutable archive snapshot per target, stable UUIDv7 mapping, strict reconciliation and atomic retry; no live locator switch. ADR-010. |
| D62 | Preserve legacy portion nutrition in typed compatibility tables when gram mass is unknown. | Canonical per-100g nutrition and food-log gram columns cannot truthfully represent an old arbitrary serving. No invented 100g basis, density, target date or historical timezone. Canonical metadata/meal/weight/note projections coexist with exact typed legacy values. |
| D63 | Bundle 311 complete USDA Foundation foods from the pinned April 30, 2026 CC0 archive. | Offline search has a reproducible source and preparation qualifiers; null, missing and negative source nutrient values are omitted, never converted to zero. ADR-011. |
| D64 | Review an immutable source, then save a new editable personal food and diary snapshot. | Grams scale the explicit basis once; optional macro edits apply to that portion. Existing SwiftData schema stays unchanged; source ID/basis remain in the existing serving description. Structured live provenance migration is later work. |
| D65 | Build a native on-device barcode scanner and keep manual entry available. | GTIN text/checksum validation preserves zeroes and UPC/EAN equivalence. No camera image is uploaded; UPC-E is explicitly unsupported. Physical-camera validation remains required. |
| D66 | Keep online lookup `provider: pending`; implement an optional Open Food Facts v3.6 adapter against fictional fixtures. | Provider choice and reuse terms, real owner contact and current usage setup are unresolved. No product lookup/ingestion or setup-form submission occurred. Adapter defaults to staging when explicitly configured. |
| D67 | Require separate versioned permission before online barcode transmission. | Account consent is unrelated. Fixed host/fields, bounded ephemeral transport, cancellation/stale-result guards and manual fallback keep the request limited to the barcode and connection metadata. No photo, diary or account token is sent. |
| D68 | Reject barcode nutrients without complete kcal/protein/total-carbohydrate/fat and one explicit basis. | Current OFF carbohydrate fields distinguish net from total. Do not infer missing zeros or volume density; keep community data visibly reviewable and separate from USDA. |
| D69 | Extend restaurant search and personal restaurant creation; defer new official menu imports pending reuse rights. | Public source links help label checking. Existing menus remain visibly sample data; custom item editing/deletion and eligible Chipotle doubling stay intact. No logos/media or new official nutrition tables copied. |
| D70 | Run food/restaurant UI tests with the existing isolated-memory test launch flag. | UI gestures must not populate a person's real diary. Disk persistence is tested separately through storage fixtures. Email setup remains pending at the owner's request. |

## Food reuse and portions — 2026-10-14

| ID | Choice | Reason / consequence |
| --- | --- | --- |
| D71 | Derive recent/frequent foods from existing logs and keep favorites as versioned local keys. | No new persistent model or duplicate history table. Future days are excluded; the newest logged quantity becomes the reuse default. Favorite settings store FDC identifiers or content hashes, not nutrition, notes or photos. |
| D72 | Group personal foods by exact name, serving, source, numeric values and menu identity, not copied FoodItem UUIDs. | Independent log copies can still appear as one food in history. Different preparations, portions and personal edits remain separate. Length-framed SHA256 is an identity key, not encryption or a claim of anonymous data. |
| D73 | Favoriting a personal food also saves it to My Foods; removing a star keeps its saved copy. | Favorites survive removal of the originating log without deleting diary data. A failed save restores only this food's flag. The 500-key bound refuses additions visibly rather than dropping existing favorites. |
| D74 | Support grams, weight ounces and source-defined portions only where their basis is known. | 1 oz = 28.349523125 g. Preserve exact selected grams and macro edits when only the display unit changes. Editing the numeric amount resets an override. Unknown mass supports the stated portion multiplier only; no guessed cup/tablespoon/density conversion. |
| D75 | Review selectable foods before copying a day/meal, defaulting to the previous local calendar day. | Use Calendar day arithmetic across DST. Preserve baseline nutrition, quantity, note and provenance in independent new FoodItems/DiaryEntries; completed same-day previews retain the original source IDs. Validate all selected rows before any insertion; failed save removes only attempted copies. |
| D76 | Carry the selected diary meal and date through search, barcode, saved meals and restaurant reviews. | A breakfast/past-day Add route must not silently default back to today's Snack. Existing stand-alone review initializers retain usable defaults and editable pickers. |
| D77 | Keep all live SwiftData models/schema and hosted settings intact. | Favorites add one separate preference key. Touched legacy screens receive strict formatting and equivalent for-in loops, not a replacement persistence design. History is derived once per search render; visible shortcut lists are bounded. Full large-history/device performance remains a separate verification gate. |
| D78 | Gate fictional UI seeds on DEBUG + an isolated-memory test launch. | Three fictional diary rows exercise recents/copies without populating personal storage. Add a pre-cancellation check before any barcode provider call; provider/menu/email setup decisions remain pending. |

## Expanded source database — 2026-10-14

| ID | Choice | Reason / consequence |
| --- | --- | --- |
| D79 | Ship a separate read-only SQLite food catalog using the existing GRDB package. | Public source tables and FTS search can grow without inserting source rows into a person's SwiftData store or switching the normalized rehearsal locator. ADR-013. |
| D80 | Combine pinned Foundation April 2026 and SR Legacy April 2018 releases; keep their distinct FDC identities and preparation names. | 8,104 complete foods replace 311-food production coverage. SR is historical and not current restaurant coverage. Foundation wins equivalent-relevance search ties; different foods are never merged merely because names resemble each other. |
| D81 | Import household measures only when USDA supplies a positive amount and measured gramWeight. | gramWeight already describes the whole displayed source amount. A listed 2 tbsp serving of 32 g weighs 32 g, not 64 g. No guessed density, household conversion or cooked yield. |
| D82 | Pin input ZIPs and verify a manifest-bound database hash, source/schema/row/index integrity and counts. | Bounded importer rejects missing nutrition and ambiguous portions; both outputs are staged and handled failures restore the previous pair. A process interruption between replacements fails closed on the next hash check. Byte reproduction uses the manifest's SQLite writer version. |
| D83 | Validate the source database off the main actor once; share the resulting read-only connection across food screens. | Full Debug validation takes hundreds of milliseconds; small indexed queries remain synchronous and bounded to 200 results. Loading UI keeps manual entry available. This is not physical-device first-paint certification. |
| D84 | Extend the existing favorites key allowlist with usda-sr-legacy IDs. | Existing Foundation/personal preferences remain intact. Entered source measure and resolved grams are retained in the existing personal serving description, without a model migration. Full structured personal provenance and preference portability remain open. |

## Offline packaged-food coverage — 2026-10-15

| ID | Choice | Reason / consequence |
| --- | --- | --- |
| D85 | Ship a bounded, separate USDA Branded offline barcode collection before activating a remote provider. | 50,000 real reference products require no API key or barcode transmission. This is a documented initial US-market subset, not all products/current-label verification. ADR-014. |
| D86 | Preserve explicit per 100 g vs per 100 mL basis and matching label serving. | USDA's current Branded documentation distinguishes the two; volume never implies gram mass. Unknown units/preparation, missing macros and ambiguous versions are excluded instead of guessed. |
| D87 | Select newest publication then modification per GTIN before eligibility/completeness. | Tied newest versions are excluded; an incomplete latest record never falls back silently to older nutrition. The manifest records editorial brand priority and subset exclusions. |
| D88 | Check local data first and require separate permission before any online fallback. | Local hits work with permission off; cancellation/generation checks before a local miss can reach a provider prevent stale codes leaking online. Existing OFF setup/terms remain pending. |
| D89 | Keep packaged sources independent of generic source tables and private snapshots. | Read-only pin/schema/integrity/GTIN checks, off-main shared loading and independent editable logs preserve existing data. No private schema or hosted migration. |

## Restaurant import preparation — 2026-10-15

| ID | Choice | Reason / consequence |
| --- | --- | --- |
| D90 | Prepare a deterministic permission-gated registry, shipping it empty. | Owner authorized steps 1→2→3; no licensed restaurant source was supplied. ADR-015 avoids inventing current menu coverage or reuse rights. |
| D91 | Read imported menu rows as immutable values; save only reviewed personal food snapshots. | Avoid importing a source graph into private SwiftData through a MenuItem relationship. Source ID/date stay in serving text; personal restaurant additions remain editable. |
| D92 | Keep FUEL-13 off and fictional previews restricted to DEBUG + isolated-memory tests. | Dataset permission declarations are not proof of a rights review. Production rejects fictional registry output, invalid nutrition, ambiguous IDs and unsupported serving bases. |

## Reusable recipes and meals — 2026-10-24

| ID | Choice | Reason / consequence |
| --- | --- | --- |
| D93 | Keep the recipe editor draft-only until Save and snapshot each ingredient into the existing `SavedMeal` / `SavedMealItem` / `FoodItem` graph. | Cancel writes nothing; later source edits do not rewrite a recipe. This reuses the existing local model instead of adding a second recipe table or importing read-only catalog rows into private storage. |
| D94 | Store batch servings and only explicitly measured cooked/raw batch gram values; compute cooked ÷ raw only when both are present. | Weight determines portion allocation and a descriptive yield ratio only. It never changes nutrients or implies cooking retention, density, or a guessed raw/cooked conversion. |
| D95 | Log ordinary recipe portions as independent ingredient diary snapshots; a reviewed macro override logs one personal combined entry. | Saved recipes and previous diary entries remain unchanged when a recipe is edited or deleted. A single context save covers each diary portion; failed saves remove only the attempted rows. |
| D96 | Preserve the exact legacy version-1 saved-meal payload for all default metadata and use a strict version-2 extension only for customized recipe metadata. | Existing archives stay byte-stable. The normalized rehearsal advances additively while completed v4 target digests and source IDs remain unchanged. |

## Train and profile foundation — 2026-10-24

| ID | Choice | Reason / consequence |
| --- | --- | --- |
| D97 | Make Train a primary tab, put Profile in the former Settings position, and keep Food Library reachable from Diary. | The five-tab limit keeps Today, Diary, Train, Progress, and Profile one tap away. Settings and account controls remain under Profile; existing food-library UI tests follow the new route. |
| D98 | Add the first Train records as additive SwiftData entities while the verified GRDB cutover remains pending. | An empty workout, exercise choice, set completion, resume, finish, and history work in the current app without touching the separate normalized rehearsal or hosted service. Each confirmed set explicitly saves its canonical kilograms and entered unit. |
| D99 | Ship only a small original starter exercise list in this slice. | The required 600+ catalog stays incomplete until a specific dataset and media license are pinned and reviewed. Custom exercises work offline; the starter list makes the logger demoable without copying proprietary cues or media. |
| D100 | Expose the Mifflin–St Jeor starting estimate only after explicit coefficient selection and enforce product safety rails in the pure engine and manual goal editor. | The app does not infer the coefficient from identity or appearance. Cut goals are blocked below BMI 18.5, weekly loss above 1% is rejected, and 1,200/1,500 kcal floors are applied. Results remain editable estimates stored locally; clinician override and full onboarding eligibility remain open. |

## Helios app integration — 2026-10-25

| ID | Choice | Reason / consequence |
| --- | --- | --- |
| D101 | Import the owner's HeliosDesign package, token source, look book, and validators from Claude commit `d017a1aaecbad29372bb93ead3ac98cabec153fa`. | This selectively integrates the design work without merging unrelated math engines or replacing working app services. `design/tokens.json` is the runtime color source; the earlier architecture palette remains a historical proposal. |
| D102 | Keep the current five native tabs and native lists/forms; use Helios canvas, opaque list surfaces, glass dashboard cards, semantic colors, and the existing theme preference values. | Retains swipe/edit/accessibility behavior and local settings compatibility. Light is labeled Frost and dark Graphite. OLED retains a black canvas. List rows deliberately use the opaque fallback to avoid repeated blur/shadows while scrolling. |
| D103 | Test themes through isolated DEBUG launch options and in-memory health stores; record screenshot/audit evidence. | Personal logs, account credentials, and camera images are not used for UI verification. Native camera controls retain their preview behavior. No schema, API, hosted setting, or food-data source changes. |
| D104 | Separate default-size clipping checks from the AX5 system audit and measure actual text growth with fresh app launches. | Xcode 27's default-size Dynamic Type run reports several lazy-list nodes as unsupported or unresolvable during resizing. Preserve that failed result as an open verification item; do not suppress individual issues or claim the original audit passes. The growth check provides independent layout evidence. |
| D105 | Keep Python verification import-safe and exclude generated dependency directories from local documentation checks. | Unittest discovery must not launch Xcode; `.build` checkouts are third-party content outside Caliber's Markdown contract. Real repository documentation still receives link checks. |
| D106 | Keep project serialization at Xcode 16 format (77), matching its existing preferred format and the pinned Xcode 16.4 CI toolchain. | The initial GitHub run rejected Xcode 27's format 110 before compiling. Existing object types are supported by format 77; only the serialization version changes. Verify on both local Xcode 27 and CI instead of silently requiring a newer runner. |
| D107 | Spell out the headers of the three nested menu/workout sections with `Section { ... } header: { Text(...) }`. | Xcode 16.4 selected an unavailable ChartContentBuilder overload for the dynamic-title convenience form. Explicit SwiftUI headers preserve the rendered labels and data while removing the ambiguous overload. |
