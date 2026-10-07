# Phase 0 verification report

Date: 2026-10-07. Scope: architecture contracts and a baseline of the existing app, not delivery of the full Caliber brief. Base Git commit: `0a75d86`; branch: `codex/phase0-architecture`. The app baseline was built from the existing working tree, whose source hashes are in [source inventory](../architecture/source-inventory.json), not from that initial commit alone.

## Phase acceptance

| Acceptance criterion | Result | Evidence / practical limit |
|---|---|---|
| Current app audited, working code preserved | PASS | [Gap analysis](GAP_ANALYSIS.md), inventory of 67 source/project files, and original Git index preserved. Of 73 original file hashes, 72 match; only Xcode's private `UserInterfaceState.xcuserstate` changed while Xcode was open. No restoration of that UI state was attempted. |
| Architecture decisions cover stack, DB/sync, charts, AI and Stack distribution | PASS | Five [ADRs](adr/001-native-ios.md), [decisions](DECISIONS.md) and [package layout](PACKAGE_LAYOUT.md). Platform contradiction is called out for approval. |
| Every P0 ID maps to a table, screen and test | PASS | All 80 explicit P0 IDs plus one derived Health integration requirement: [matrix](REQUIREMENTS.md). Validator checks all table names exist and test assertions are present; tests remain marked planned. |
| Runnable SQL v1 + ERD | PASS | 72 core + 35 Stack tables; [ERD](ERD.md), full per-store ERDs, four up/down SQL files and migration contract. Generator reproduces bytes; 43 disposable SQL tests. Does not execute a live-store migration. |
| Tokens/component inventory | PASS | [Design system](DESIGN_SYSTEM.md), token JSON and contrast check: 54 text/essential-mark pairs, minimum5.94:1; borders≥3:1;48pt targets. Device accessibility/color-vision review remains future work. |
| Series/Event registries | PASS | 53 series +20 events; valid current/future table bindings, explicit units, query IDs, aggregation and private-store constraints. Typed query runtime is not implemented. |
| Risks, test plan and ID-mapped backlog | PASS | [Risk register](RISK_REGISTER.md), [test plan](TEST_PLAN.md), [backlog](BACKLOG.md):211 explicit+12 derived requirements,116 P1 flags default off,26 P2 items recorded. |
| Owner can review proposal from one entry point | PASS (package delivered) | [Phase 0 review](PHASE_0.md) links complete artifacts and gives the one Phase1 platform decision. Owner approval itself is pending. |
| Type-check/build, relevant tests and artifact lint | PASS for this scope | Fresh iOS build/test; Python syntax/JSON/traceability/link checks; deterministic SQL; eight fixture arithmetic checks. No SwiftLint configuration or new Swift source exists in Phase0. No whole-app coverage claim. |
| Phase-specific chart demo and timing | N/A in Phase0 | No new chart runtime belongs to this architecture phase. Twelve-month generator and physical-device chart benchmarks are Phase1+ deliverables; performance budgets have NOT passed. |
| Self-review for regressions and §11 | PASS (review performed) | Read source audit, SQL/trigger changes, registries and docs; corrected nullable calibration, revision ownership, BMI bypass, immutable schedule rows and fixture volume semantics; regression tests cover these SQL cases. [Compliance](COMPLIANCE.md) remains unchecked; this is not release clearance. |

## Executed checks

### Existing iOS app baseline

Build and test succeeded on iPhone17 Simulator / iOS27.0 using Xcode27.0. Result:59 Swift Testing tests in10 suites,2 existing template XCTest tests,2 Progress UI tests;63 total, zero failures. The template tests do not establish feature coverage. Progress UI covers same-day edit/delete and notes-only logging without inventing weight. Restaurant UI was not rerun this phase. The log contains one App Intents metadata-extraction warning because that framework is not linked; no build errors.

Exact executed command, from the existing project directory:

```sh
xcodebuild -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,id=384D80B9-60DE-4538-B135-00D31BB69D2E' \
  -derivedDataPath '/Users/jcrock/Documents/Codex/2026-10-07/are-x20/work/ProgressDerivedData' \
  -resultBundlePath '/Users/jcrock/Documents/Codex/2026-10-07/are-x20/work/Phase0Baseline.xcresult' \
  -parallel-testing-enabled NO \
  '-only-testing:Caliber (DEV)Tests' \
  '-only-testing:Caliber (DEV)UITests/ProgressUITests' test
```

[Full build/test log](evidence/ios-baseline.log), with trailing whitespace normalized for Git; the original remains alongside the local result bundle in `work/phase0/baseline-tests.log`. The local `.xcresult` at the path above contains the original result bundle; it is not copied into this portable documentation package. To rerun, omit `-resultBundlePath` or choose a new path, because Xcode refuses to overwrite an existing result bundle.

### Architecture, fixture and SQL checks

Run from the root of the delivered package or the project repository after installing these files:

```sh
python3 scripts/validate_phase0.py
```

The runner parses JSON, compiles Python syntax without emitting bytecode, independently matches all explicit IDs/priorities to the supplied brief, checks planned mappings/flags/privacy-store bindings and local file links, regenerates SQL in a temporary directory and compares every byte, checks the eight supplied arithmetic fixtures, validates color tokens, then executes the43 SQL tests. [Full verification output](evidence/phase0-validation.log).

Individual commands:

```sh
python3 scripts/check_tokens.py
python3 architecture/schema/tests/test_migrations.py
```

Host Python and SQLite versions are recorded in the evidence output. The SQL suite creates only disposable stores. It covers foreign keys/account isolation, metadata/UUID constraints, immutable revisions and schedules, head ownership, fixed-point/calibration constraints, log projections, inventory reversal, independent Stack storage, low-BMI/floor constraints, explicit nutrition completeness, transactional outbox suppression/rollback, reopen and empty up/down/up. Populated-store down migration is rejected. These results do not prove app durability, production sync, clinical safety or encryption.

## Still unverified / gated

- SwiftUI iOS17 compatibility, new GRDB/SQLCipher runtime, live SwiftData copy/recovery, server/RLS and conflict protocol.
- All new math/schedule/insight engines, full branch coverage, 12-month demo, chart golden images, accessibility and physical-device performance.
- Clinical applicability, Stack calculator store eligibility, dataset/media licenses, backup/privacy guarantees, owner/legal/security release sign-off.
- Native-iOS Phase1 versus the brief's simultaneous Android-emulator acceptance requires the owner's decision. No cloud account, API key, paid service, user-data conversion or store submission occurred.
