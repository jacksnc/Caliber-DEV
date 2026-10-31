# Changelog

## 2026-10-29 — Integrated local food-entry update

- Integrated Gemini's food hub with capture/library shortcuts, top recents and
  quick editable portion review. Selected meal/date and independent snapshots
  remain intact; future dates are labeled separately from past dates.
- Manual entry requires explicit macro values, including explicit zero, with
  scalable controls at accessibility text sizes.
- Compiled Claude's motion/glass library and 48 design-system tests. Effects
  remain unadopted in app screens until rendered/gradient-state checks finish.
- Added new food files/suite to shared lint/native runner coverage and corrected
  local documentation links. No model, hosted service or provider change.

## 2026-10-28 — Second visual pass integration

- Integrated Claude's shared segment/empty-state components, Progress hierarchy,
  Today goal shortcut and standalone theme preview picker.
- Connected previews to the existing setting, retained the standard Theme picker,
  and distinguished zero-calorie logged entries from an empty food history.
- Native build/theme/accessibility verification is owned by Codex; Claude's
  original handoff correctly labels its cloud-written Swift as untested.

## 2026-10-28 — Guided starting goals

- Added optional four-step nutrition setup, explicit equation/activity selection,
  optional directional weight target and editable calorie/macro review.
- Save updates local profile targets; cancel leaves them intact. Existing users
  can open setup from Profile without being forced through a new welcome.
- Added additive storage, locale/unit/failure tests and native UI coverage. The
  existing energy formulas and hosted services remain unchanged.
- New guided metadata still needs legacy export/canonical migration adapters.

## 2026-10-25 — Native Graphite and Frost integration

- Integrated the owner's Helios token/package work into the real SwiftUI app, with theme selection in Profile → Settings.
- Added themed canvases and list surfaces across existing routes, glass Today/scanner/timeline cards, responsive nutrition summaries, and consistent chart colors.
- Added native screen screenshots and Dynamic Type checks; improved large-text workout entry and exercise accessibility labels.
- No personal model migration, food source import, health math change, hosted deployment, or authentication-policy change.

## 2026-10-24 — Train and profile foundation

- Added a primary Train tab with a searchable original starter library, offline custom exercises, empty-workout start/resume, immediate set persistence, warm-up exclusion, live totals, finish flow, and local history.
- Replaced the Profile placeholder with account status, local body/activity details, editable calorie/macro goals, and a pure Mifflin–St Jeor starting-target calculator.
- Added BMI, weekly-loss-rate, and calorie-floor rails plus focused math and SwiftData persistence tests. The result is labeled as an estimate and no health values are uploaded by sign-in.
- Kept Food Library available from Diary and Settings/Account available from Profile so the primary navigation remains five tabs.
- The licensed 600+ exercise catalog, full metric-specific set UI, routines, timers, PRs, charts, clinician override, adaptive targets, and cloud sync remain incomplete.

## 2026-10-15 — Restaurant import workflow prepared

- Added strict permission/source-aware JSON imports, deterministic preview/output checks and an honestly empty production registry.
- Added immutable categorized menu browsing with portion/macro review and personal custom-item actions; FUEL-13 remains off pending source/release clearance.
- Production rejects fictional/invalid data. No new real menu dataset, private migration or hosted change occurred.

## 2026-10-15 — Offline packaged-food barcodes

- Added 50,000 USDA Branded barcode records with explicit mass/volume bases, pinned provenance and a reproducible bounded importer.
- Look up local products before any separately permitted online fallback; keep manual label entry and editable independent snapshots.
- Added safe shared loading, GTIN/schema/basis checks, cancellation-before-fallback protection and mass/volume regression cases. Remote provider setup remains pending.


## 2026-10-14 — Expanded indexed food database

- Replaced production JSON scanning with a separate GRDB read-only SQLite catalog containing 8,104 complete USDA foods and 14,792 source-defined gram-weight portions. Original 311 Foundation IDs and nutrients are unchanged.
- Added SR Legacy source-year labels, exact preparation names and equivalent-relevance Foundation preference; historical reference foods are not presented as current menus.
- Added source household measures to portion review, live scaling, entered count/measure text and support for their source favorites. Unit changes preserve exact mass and macro edits.
- Added bounded pinned import, reproducible resource/manifest generation, source/schema/row/FTS checks, background resource validation and regression tests. See FOOD_DATABASE_VERIFICATION.md for executed results and limits.
- No personal model migration, hosted change, current restaurant import or live barcode activation.

## 2026-10-14 — Recent foods, favorites, portions and day/meal copying

- Added offline recent/frequent food groups, key-only favorites and personal favorite preservation in My Foods. Exact variants stay separate; repeating a food defaults to the latest valid quantity.
- Added weight ounces and explicit source portions with live totals. Unit changes preserve the selected mass and macro edits; unknown mass never becomes a guessed volume/density conversion.
- Added reviewed, selectable day/meal copying with calendar-correct yesterday, independent snapshots, preserved notes/provenance and targeted failure cleanup. Completed drafts cannot be added twice by repeated taps.
- Routed Diary Add through food search and preserved its meal/date across catalog, barcode, saved meals and restaurant reviews. Added privacy cancellation protection before starting a barcode lookup.
- Added 35 unit functions and four isolated UI scenarios; see FOOD_REUSE_VERIFICATION.md for final evidence and limits. Existing live models, provider configuration, hosted services and datasets remain unchanged.

## 2026-10-14 — Offline food, barcode review and normalized copy

- Bundled 311 complete, source-traceable USDA Foundation foods from a hash-pinned CC0 release, with reproducible importer and offline ranked search. Added gram-based review, personal macro overrides and independent diary copies without changing SwiftData models.
- Added native/manual GTIN capture, check-digit validation, private request/consent coordination and an optional Open Food Facts v3.6 adapter. Default provider remains pending; fictional fixtures verify total carbohydrate, basis/units, errors, cancellation and limits. No live product requests, API keys, images or private health uploads.
- Added personal restaurant creation, improved menu/name/category search and official nutrition links. Existing custom item Edit/Delete swipes and eligible Chipotle portions stay intact; built-in restaurant values remain samples pending reuse rights and verified coverage.
- Added all-model typed GRDB projection/reconciliation in a separate immutable rehearsal target, with source/archive preservation, stable IDs, exact nutrition/photo checks, transactional retry/reopen and zero migration outbox. Unknown serving grams remain unknown in compatibility tables.
- Added isolated unit/UI/import tests and source/license/migration/security documentation. See FOOD_AND_NORMALIZED_VERIFICATION.md for final execution results and limits. Email setup, cloud activation, protected attachments and live cutover remain pending.

## 2026-10-13 — Local restore mapping rehearsal

- Added complete reconstruction of all 15 current SwiftData model types from the saved legacy archive into a separate memory container, with CloudKit off and no live-store/file destination accepted.
- Preserved photo bytes/order, UUIDs, optional links, saved-meal/restaurant relationships, original pounds and custom diary/menu nutrition. Rejected unknown fields/types, inconsistent relationships, incompatible units and changed totals.
- Added six restore test functions, including thirteen invalid variants, and extended the all-model saved-archive test. App build, 74 Swift Testing functions plus two template cases, strict formatting and diff review pass.
- Replaced an initial disk-copy experiment after it exposed retained-handle cleanup diagnostics. Final evidence proves model restoration in memory from persisted archive input; canonical disk restoration remains a separate gate.
- Followed the owner's instruction to keep email setup pending. No UI, existing schema/model, live store, hosted service or account setting changed.

## 2026-10-12 — Optional account permission, recovery and hosted self-deletion

- Added explicit versioned account permission, local withdrawal, code-based recovery and password-confirmed deletion UI. Sensitive form values are cleared; deletion preserves local diary/progress/photos and resets the permission toggle.
- Added guarded recovery routes, subject-bound acceptance RPC and a narrowly scoped server-only Auth administrative self-delete path. No account target or API key is accepted from the app. Migration 004 preserves existing quotas/counters and live SwiftData storage.
- Deployed the exact tested DEV bundle and applied migration 004 after prerequisite checks. Twenty-nine backend functions, sixty-six package functions, sixty-eight app functions plus two template cases, six verifier tests and three account UI tests pass. Final affected UI tests were rerun after the view review.
- Passed twelve live fictional lifecycle criteria and five catalog cleanup/preservation checks. The newly created disposable account/journal/acceptance record were deleted; four earlier QA accounts remain. Temporary test password discarded; no personal health upload.
- Prepared the recovery email template. Custom SMTP setup and actual delivery/reset verification remain pending; private DEV app activation and broader Foundation/release gates remain open. See ACCOUNT_LIFECYCLE_VERIFICATION.md and ADR-008.

## 2026-10-07 — Phase 0 architecture
- Audited the existing native app against the master brief, retaining its working food, restaurant and Progress flows.
- Proposed native Swift packages, explicit SQLite/GRDB repositories, separate private Stack storage and a conflict-preserving sync protocol.
- Added complete local SQL v1 proposals, disposable migration tests, ERDs, requirements/acceptance mapping, design tokens and registries.
- Added safety, licensing, security, calculation-method and verification documentation; open approvals remain explicit.
- No runtime app change, live database migration, third-party dataset import, cloud deployment or store submission.

Existing source work predates this phase and remains locally staged/uncommitted as it was. The phase commit includes architecture artifacts only.

## 2026-10-08 — Phase 1 local Foundation (activation gates open)

- Preserved and checkpointed the existing nutrition/restaurant/Progress application.
- Added six Swift package targets, pinned GRDB, separate demo databases and migration fixtures.
- Added Today, settings, adult/scope confirmation, number-free photo/notes journal and a 12-month fictional demo.
- Added accessible chart cards with calendar ranges, coverage, gaps, data tables and transparent descriptive math.
- Added lossless SwiftData snapshot rehearsal, immutable conflict-preserving sync journal, Keychain gateway client and PostgreSQL RLS/RPC tests.
- Added CI configuration and verification scripts. No hosted service or live data migration activated.
- Phase 1 remains open; see PHASE_1_VERIFICATION.md rather than treating this entry as release clearance.


## 2026-10-08 — Foundation follow-through, hosted activation prepared

- Selected and inspected the owner's existing Caliber DEV Supabase project in us-east-1; no hosted deployment or personal upload performed.
- Added gated account UI, project-scoped session configuration, restoration/retry and local-first current-session logout.
- Fixed locale-aware decimal input across existing nutrition, restaurant and Progress forms.
- Improved chart link touch regions, wrapping, VoiceOver labels and date-aware data tables.
- Isolated legacy Progress preferences in fixture UI runs and removed nested Settings navigation.
- Added deployment preparation and verification documentation. Phase 1 acceptance remains open.

## 2026-10-10 — Local readiness and largest-text fixes

- Replaced the demo's constrained navigation-toolbar exit with a persistent full-width bottom control.
- Let data-table date headers, values and method paragraphs wrap at accessibility text sizes; moved the full method heading into page content.
- Moved the Sendable account transport protocol into CaliberIntegrations and corrected failed session restoration so it can be retried without restarting.
- Expanded the largest-text UI test to audit chart, table and explanation routes and exit from the explanation page, without suppressing audit issues.
- Recorded current verification evidence separately from the historical Phase 1 baseline. Hosted activation, live synchronization and the remaining Phase 1 quality gates remain open.

## 2026-10-10 — Hosted deployment prepared for confirmation

- Rechecked the selected development project and ran a hosted read-only schema preflight; both table and sync command names are available.
- Staged the exact tested gateway source and transaction-wrapped SQL in the dashboard, verifying both editor copies without deploying.
- Added a read-only hosted permission/RLS catalog query and a PostgreSQL regression test that detects disabled RLS and public RPC execution.
- Saved successful format, lint, strict typecheck and all 11 backend test results. Hosted deployment, positive authentication and app activation remain pending.

## 2026-10-10 — DEV backend deployed (activation gates open)

- Applied the owner-approved atomic Foundation migration and deployed the exact reviewed caliber-gateway source. Saved the approved relay JWT setting off; sync retains upstream authentication and owner checks.
- Verified all six hosted grants/RLS/definer criteria, twelve database behavior assertions and complete rollback of fictional fixtures, plus eleven key-free HTTP rejection paths with sanitized no-store responses.
- Added a private-password two-account authentication verifier and three local harness tests for session scope and credential redaction. Final backend format/lint/typecheck and all twelve Deno tests pass.
- Created the two named fictional DEV users under the owner's explicit authorization, then passed eighteen positive hosted checks for sign-in, authenticated sync, account isolation, refresh and current-session logout. The first attempt failed during sync; its session cleanup passed, and the complete rerun passed without backend changes. Sanitized evidence retains both outcomes.
- Removed the private temporary passwords after verification and logged out issued test sessions. Only the two fictional accounts and their synthetic notes remain; no credential or token is stored in the repository or delivered in artifacts.
- Inspected current provider safeguards and documented signup, CAPTCHA, logging and shared-IP rate-limit limitations. App activation and personal uploads remain off pending these gates.

## 2026-10-11 — Private DEV registration and shared login budgets

- Disabled public signup, preserving email confirmation and existing-account login. Applied additive migration 002 and deployed an exactly compared gateway update with a generated server-only guard.
- Added shared Postgres token buckets for sign-in/refresh, private keyed identifiers, fail-closed guard errors, safe 429 responses and incremental request-size limits. Logout and existing health-journal ownership remain independent of the pre-login quotas.
- Added a localized wait message and typed throttling error without persisting a rejected session. Backend format/lint/typecheck, twenty Deno tests, three verifier tests, sixty package tests and sixty-six app test functions plus two template cases pass.
- Reverified five final guard and six original catalog criteria, eleven HTTP rejection paths, six concurrent/boundary criteria and eighteen genuine-auth criteria. Preserved the failed probe against the previous gateway before its deployment confirmation completed, followed by the successful full probe on the confirmed source. Final review added forward migration 003 and retested route-specific cleanup to avoid cross-route lock cycles after idle periods.
- Created two additional ordinary fictional guard QA accounts with no emails; logged out test sessions and removed temporary passwords/guard copies. Recorded direct-provider, shared-budget, idle-retention and release limits in ADR-007. Consent, recovery/delete and provider release safeguards still precede app activation.

## 2026-10-24 — Recipe and reusable-meal builder

- Added draft-first ingredient selection from the offline USDA catalog and My Foods, plus manual ingredient entry with explicit serving and all four macro values.
- Added whole-batch and per-serving nutrition, optional measured cooked/raw batch weights, cooked-gram portion logging, ingredient editing and deletion, and macro override during diary review.
- Recipe diary logs use independent ingredient snapshots; user-edited combined macros produce a separate personal diary entry. Recipe cancel/edit/delete do not rewrite earlier diary rows.
- Added strict legacy snapshot compatibility and additive normalized-rehearsal v5 metadata. Full verification and limitations are recorded in `docs/RECIPE_VERIFICATION.md`.
- Added repository instructions and a cross-assistant checkpoint in `AGENTS.md`, `CLAUDE.md`, and `docs/AI_HANDOFF.md`; switching assistants remains a manual, Git-based handoff.

## 2026-10-26 — Published foundation and native theme verification

- Published `astra/foundation` through the existing Train/Profile foundation so Claude can access the real app.
- Added native theme screenshot/audit and fresh-launch text-growth checks; retain the unresolved default-size system audit in the verification report.
- Made the iOS CLI runner safe for Python test discovery and excluded generated dependency documentation from the repository link validator.

- Follow-up: use explicit SwiftUI section headers in restaurant menus and workout history for Xcode 16.4 compilation.

## 2026-10-27 — Workout engine on a separate branch

- Added tested pure input rules for nine exercise metrics, explicit units, RPE/RIR, all set kinds and independent counting policies.
- Added optional SwiftData metric/body-weight/effort/distance/duration/rest snapshots; retained legacy completed-set values.
- Added saved previous-set copy, fill, duplication, order and deletion commands; copies clear completion and observed effort/body weight.
- Added durable optional rest deadlines and explicit actual-rest capture, with a Claude integration handoff. No screen, color or hosted changes.

## 2026-10-27 — Custom exercise shortcut and menu CSV

- Added a shared custom-exercise form to the workout picker and library. Missing-search creation prefills the name and adds the saved exercise to the current session.
- Added explicit blank/duplicate validation and stable UI identifiers, retaining Cancel and existing personal-row deletion behavior.
- Added a blank restaurant menu CSV, a complete fictional example, source metadata, preparation CLI and beginner guide. Reused existing nutrient/source/category validation; production data and flags stay unchanged.

## 2026-10-28 — Native look-book alignment

- Closer Graphite/Frost layouts: rounded inline headers/profile, dark token glass,
  stronger dock mask, compact weight/calorie/macro cards and clearer search.
- Expandable exercise cards preserve unfinished typed sets; keyboard Done and
  optional set controls keep the workout grid compact and usable.
- Preserve photo/notes timeline, calorie/macro editing, custom exercises, Stack
  opt-in/lock and menu provenance gates. Added focused UI regression checks.
- Fictional screenshot data now has a full seven-day calorie chart; real stores
  and nutrition/weight/dosing math are unchanged.

## 2026-10-28 — Recording feature and visual review

- Reviewed three owner-supplied recordings against native build `955a91b`.
- Added a timestamped matrix of 28 functional opportunities, 12 visual patterns,
  existing capabilities, implementation evidence and suggested build order.
- Documentation only; no application, calculation, schema, provider or user-data
  changes. Recording media and private details remain outside the repository.

## 2026-10-28 — Parallel pass 2 dispatch

- Combined current native polish/review with Claude's latest scanner and grammar
  fixes; preserved all working branches.
- Added a shared branch/file ownership contract and concrete briefs/handoffs for
  Codex goal setup, Claude visual refinement and Gemini food-entry convenience.
- External work requires its own chat to be started; no external agent execution
  or integration is claimed by preparing these assignments.


## 2026-10-30 — Lookbook V2 design session started

Published separate Codex/Claude/Gemini V2 branches and shared fixture/ownership
contract. Sent and verified both native-app peer assignments. Added first Diary
direction with centered energy, balanced macros and meal cards in the existing
themes. Design preview only; no native code, data migration or installed build
change. Full book, responsive QA and export remain in progress.


## 2026-10-30 - Lookbook V2 design checkpoint delivered

Integrated both peer design branches and completed all seven screens in Graphite
and Frost, state appendices, 15-page rendered/reviewed PDF and native role pack.
322 browser layout/target cases pass; selected-food/meal preview and number-free/
locked/off fixes are verified. No native code or installed app change yet.


## 2026-10-30 - Native centered Diary V2

Centered independently recorded energy and explicit goals, balanced macros,
opaque cards, calendar-day navigation and wrapping meal rows. Existing edit,
delete, copy/repeat and selected meal/date routes retained. 242 native unit cases
and 6 focused UI cases pass on isolated QA; Graphite/Frost/AX5 captures reviewed.
No model migration, goal calculation, providers or personal installation changes.


## 2026-10-30 - Reviewed native V2 food and surface integration

Ported Gemini's preserved native food work after Argon quota exhaustion; reviewed
meal/date propagation, source snapshot isolation and macro reset. Fixed ambiguous
phrase-row calorie display, large-text row width and macro stacking. Opaque food
hub/review and AX action bars are verified in both themes. Progress legend now
wraps without repeated clipping.243unit/48Helios tests pass; native UI evidence
keeps initial failures and passing scoped corrections. Existing keyboard warning
reproduces on baseline. No storage, provider, calculator or personal-build change.


## 2026-10-30 - Native V2 iPhone presentation checkpoint

Merged reviewed Today/Stack text and layout corrections; fixed native AnyLayout
call syntax and wrapping headings. Review actions use a full-width footer at all
text sizes, with separate self-sizing AX nutrition rows. Full7case food suite,
243unit and48theme-package tests pass, with measured native text growth/bounds
and reviewed captures. Deep-scroll system-audit identity failures remain
inconclusive and documented separately; no full accessibility certification or
release-complete claim. No personal build or health-storage/formula change.


## 2026-10-30 - Pushed food action visibility fix

Prevented floating navigation from covering a pushed review's Add action. Footer
presence is transient UI state and releases on dismissal. Pushed save/favorite/
frequent reuse and modal cancel/reuse pass; normal tab stack behavior is retained.
No health calculation, persistence or user-device changes.
