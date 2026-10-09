# Phase 1 verification — 2026-10-08

**Local checks pass; Phase 1 is not fully accepted yet.** Hosted setup/CI, live domain synchronization, minimum-OS execution, coverage/image baselines and physical-device budgets remain open. Android is deferred by the owner's accepted native-iOS amendment.

## Executed evidence

| Check | Result | Evidence / scope |
|---|---|---|
| Swift package | PASS — 44 test functions, including parameterized cases | `evidence/phase1/swift-test-final.log`; Core 8, Database 14, SeedData 3, Integrations 10, Charts 9. Tests run on macOS against the actual GRDB/SQLite implementation. |
| App build and selected simulator tests | PASS — 60 Swift Testing functions + 2 existing template XCTest + 4 UI tests | `evidence/phase1/ios-final.log`; iPhone17 / iOS27, Xcode27. All fixture-only suites listed below. |
| Final app rebuild after storage/auth review | PASS | `evidence/phase1/ios-build-final.log`. UI behavior tested before these package-only changes; no later UI change. |
| Backend strict typecheck/lint | PASS | `evidence/phase1/backend-final.log`; Deno2.9.7, strict TypeScript. |
| Backend tests | PASS — 6 tests | 5 gateway tests and 1 PostgreSQL integration test with ownership, conflict, causal ancestry, rollback, idempotency, paging and permission assertions. PGlite0.3.14 uses actual PostgreSQL WASM. |
| Swift strict formatting / backend format | PASS | `evidence/phase1/lint.log`; Foundation scope only, no cosmetic rewrite of older app files. |
| Static contracts, token contrast and SQL proposal tests | PASS | `evidence/phase1/contracts.log`; existing 43 disposable SQL tests, architecture links/fixtures plus Foundation bundle/Core/diagnostic checks. |
| Review / visual inspection | PASS for reviewed scope | Re-read Foundation diff; inspected the captured demo chart screenshot. This is visual review, not an automated golden-image comparison or full accessibility audit. |

A “test function” count does not inflate parameterized cases into separate features. The two pre-existing template XCTest cases are included explicitly, not represented as product coverage. No overall or branch-coverage percentage is asserted.

## Phase acceptance ledger

| Phase1 requirement | Pass/fail | Evidence and remaining work |
|---|---|---|
| Native modular repository | PASS | One Swift package, six products; pure Core boundary; Xcode links products; dependency locks checked in. |
| CI definition | PASS — definition; FAIL — hosted green run | Workflow and reproducible local commands delivered. No configured remote or hosted run; CI toolchain is Xcode16.4 and must be independently proven. |
| Design system/chart skeleton | PASS — Foundation; FAIL — full quality gate | Semantic resources, locale-aware copy, calendar ranges/gaps/coverage, accessible summaries/tables, unit labels, hidden-number protection. Nine calendar tests; screenshot reviewed. All component inventory, chart image baselines, interactive performance and full Dynamic Type/VoiceOver audit remain incomplete. |
| Navigation / simulator boot | PASS | Adult/scope gate and usable tabs; demo opens/exits; diary remains empty in personal fixture store; existing Progress flows pass. |
| Android boot | Deferred by approved amendment | No Android code/emulator evidence claimed. |
| Local DB + migrations | PASS for demo/journal; FAIL for live cutover | v1 core/Stack SQL; v2 Foundation; v3 indexes. Populated 12-month demo survives v2→v3/reopen with identical serialized observations and counts. Failure migration rolls back. Existing users remain on SwiftData. |
| Auth | PASS — client/gateway fixtures; FAIL — hosted activation | HTTPS/no redirect, no cookies/cache, Keychain interface, sanitized failures, token rotation and logout-race tests. No hosted login/refresh/revocation/account lifecycle/consent flow configured. |
| Offline-first sync/conflicts (PLAT-03) | PASS — journal protocol; FAIL — live domain sync | Durable operation retries, lost-ack echoes, edit/delete conflicts, historical resolutions, full-DAG ancestry, atomic cursor checks, exact integer limits and account ownership tested. No silent winner for unresolved branches. No live diary/photo domain adapters or real two-device/cloud test. |
| Settings/units/i18n (PLAT-02) | PASS — Foundation; FAIL — complete parity | Preferences persist; original pounds preserved; strict localized package parser; conversion tests; English catalogs and formatting locales. Existing numeric-entry formatting audit, translations and comprehensive string/accessibility audit remain open. |
| Feature flags | PASS for Foundation defaults | All116 P1 IDs bundled uniquely and disabled, including unknown IDs. No feature is advertised as implemented merely because a flag exists. |
| Error boundary / safe logs | PASS for new Foundation paths | Explicit startup retry keeps files; generic errors; closed diagnostic vocabulary. Production observability, existing-flow audit and no-health-data crash SDK verification remain future release work. |
| Demo generator/toggle | PASS with §11-safe substitution | 12 calendar months, seed determinism, DST/leap-year cases, cut/deloads/missing/noisy observations; separate core/simulation files; idempotent/reopen/checkpoint tests. Arbitrary-unit simulation replaces real titrating drug instructions. |
| Lossless legacy migration rehearsal | PASS — archive; FAIL — normalized cutover | Fixture covers all15 SwiftData models, exact photo bytes, relationships, entered pounds, stable ID map, reopen and failure rollback. No private SwiftData SQLite access; canonical mapping/restore/user migration still required. |
| §10.2 timing/coverage budgets | FAIL / unmeasured | No physical-device cold start, first-paint, p95 queries, 60fps, five-year dataset benchmark or overall80%/Core100% branch evidence. Simulator wall times do not establish these budgets. |
| §11 release/privacy gates | FAIL / intentionally open | Age/scope and number hiding implemented. Real encrypted Stack/photo vault, legal/policy sign-off, clinical references, hosted privacy lifecycle and release checklist remain open. No submission/real Stack capture enabled. |

## Selected app suites

The final simulator run executes all `Caliber (DEV)Tests`, `FoundationUITests` and `ProgressUITests`. UI launches use isolated in-memory data and a separate settings suite. It verifies age/scope confirmations, demo/table/exit, number hiding and note persistence, plus add/edit/delete and notes-only Progress flows. Unit suites cover existing restaurant/custom-food behavior, macro snapshots, photo handling, weights and lossless copy.

The older `RestaurantCustomizationUITests` were not run because they have no isolated-store launch arguments and may open a personal persistent store. Adapt them to fixtures before expanding the UI run. No personal diary/photo was read for test assertions or copied into the delivery package.

## Reproduction and remaining activation

See [Phase1 delivery](PHASE_1.md) for exact commands and Xcode clicks. New iOS result directories are required for each run. Local compiler/service permissions are needed on this Mac; hosted CI is separate evidence.

The unanswered setup question is whether to keep cloud off, use an existing Supabase project, or prepare a new project with owner-approved region. Keep it off until that answer and concrete configuration arrive. After setup, verify hosted auth/RLS and two clients, normalized domain adapters, account lifecycle and backup recovery. Finish minimum-OS/device/a11y/coverage evidence before declaring Phase1 complete or beginning release claims.
