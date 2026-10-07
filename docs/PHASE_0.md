# Caliber — Phase 0 review

**The architecture package is ready for review. Your working SwiftUI app is preserved.** This delivery adds planning, contracts, SQL proposals and verification tools; it does not replace screens or migrate your data.

## Plan

1. Keep the current diary, restaurant customization and Progress flows working.
2. Retain native SwiftUI and move shared logic into pure Swift packages.
3. Introduce explicit local repositories through a verified copy of existing data.
4. Isolate Stack behind its own private store, consent and build/release gates.
5. Share chart contracts, canonical units and deterministic calculation fixtures.
6. Keep P1 flags off and P2 in the backlog; build phase by phase.
7. Begin Foundation only after the platform amendment below is approved.

## What exists and what comes next

Today: food search/manual logging, editable diary macros, sample restaurant menus/Chipotle customization, custom menu items, and daily Progress photos/notes/weight with a timeline and raw weight graph. Train, Stack, Health integration, accounts and sync are not in this checkout. A separate peptide project mentioned in the brief was not found in the inspected tree.

The full [gap analysis](GAP_ANALYSIS.md) identifies partial features and missing requirements. Existing code is evolved feature by feature; the native choice is explained in [ADR-001](adr/001-native-ios.md). The app currently targets iOS27; restoring the original iOS17+ support needs an explicit compatibility check.

## Proposed foundation

| Area | Recommendation | Review detail |
|---|---|---|
| App | SwiftUI, Swift Charts, pure Swift modules; Android later | [Package boundaries](PACKAGE_LAYOUT.md), [decisions](DECISIONS.md) |
| Persistence/sync | GRDB/SQLite, staged SwiftData copy; Supabase with transactional outbox/cursor and visible conflicts | [Storage ADR](adr/002-storage-sync.md), [migration contract](MIGRATIONS.md), [ERD](ERD.md) |
| Shared visuals | Canonical series/event contracts, full-resolution calculations, separate render downsampling, accessible tables | [Charts ADR](adr/003-chart-kit.md), [registries](SERIES_AND_EVENTS.md), [design system](DESIGN_SYSTEM.md) |
| AI | Backend-only, provider-swappable; database supplies nutrition; confirmation before critical writes | [AI ADR](adr/004-ai-gateway.md) |
| Stack | Separate encrypted store/key/attachments, optional build, adult opt-in and store/region gates | [Stack ADR](adr/005-stack-boundary.md), [risk register](RISK_REGISTER.md) |
| Correctness | Preserve entered values; canonical kg, distinct mass/volume/IU/device dimensions; no missing-as-zero | [How we calculate](HOW_WE_CALCULATE.md), [test plan](TEST_PLAN.md) |

Every P0 requirement has a proposed table, screen and specific acceptance assertion in the [P0 matrix](REQUIREMENTS.md). The [backlog](BACKLOG.md) preserves all211 explicit IDs and12 derived subclauses/integrations:81 P0,116 P1,26 P2. P0 means planned to ship, not already built. A JSON flag is not a runtime implementation.

## Migration and files

The target schema contains72 core and35 Stack tables in separate databases. SQL is runnable on disposable databases; no live app store is opened. Production cutover requires copy/validate/reopen/recovery tests and preserves the original source. The down scripts refuse populated stores. Complete SQL, tests, contracts and source files accompany this document; no application dependencies need installing to review them.

See the full file tree below. The current application source is intentionally not duplicated in this package.

```text
architecture/command-envelope.schema.json
architecture/design-tokens.json
architecture/event-registry.json
architecture/feature-flags.json
architecture/golden-vectors.json
architecture/requirements.json
architecture/schema/TABLES.json
architecture/schema/core/001_v1.down.sql
architecture/schema/core/001_v1.up.sql
architecture/schema/generate_schema.py
architecture/schema/stack/001_v1.down.sql
architecture/schema/stack/001_v1.up.sql
architecture/schema/tests/test_migrations.py
architecture/series-registry.json
architecture/source-inventory.json
docs/BACKLOG.md
docs/CHANGELOG.md
docs/COMPLIANCE.md
docs/DECISIONS.md
docs/DESIGN_SYSTEM.md
docs/ERD.md
docs/ERD_CORE.md
docs/ERD_STACK.md
docs/GAP_ANALYSIS.md
docs/HOW_WE_CALCULATE.md
docs/LICENSES.md
docs/MASTER_BUILD_BRIEF.md
docs/MIGRATIONS.md
docs/PACKAGE_LAYOUT.md
docs/PHASE_0.md
docs/REQUIREMENTS.md
docs/RISK_REGISTER.md
docs/SECURITY.md
docs/SERIES_AND_EVENTS.md
docs/TEST_PLAN.md
docs/VERIFICATION.md
docs/adr/001-native-ios.md
docs/adr/002-storage-sync.md
docs/adr/003-chart-kit.md
docs/adr/004-ai-gateway.md
docs/adr/005-stack-boundary.md
docs/evidence/ios-baseline.log
docs/evidence/phase0-validation.log
docs/evidence/preservation-baseline.json
scripts/check_tokens.py
scripts/validate_phase0.py
```

## Verification and running

The current app built and passed its selected baseline (63 tests, including2 pre-existing template tests). The proposed SQL passes43 tests. Static traceability/registry checks, eight fixture checks and token contrast also pass. See [VERIFICATION.md](VERIFICATION.md) for commands, logs, exact scope and remaining gates; future Train/Stack engines and chart performance are not claimed as tested.

To check this package, open Terminal at the package root and run:

```sh
python3 scripts/validate_phase0.py
```

To run your existing app in Xcode:

1. Open `Caliber (DEV).xcodeproj` in your existing project folder.
2. In Xcode's top toolbar, select the **Caliber (DEV)** scheme and **iPhone17** simulator (iOS27).
3. Click the triangular **Run** button, or press **⌘R**.
4. Open **Progress** to use the existing check-in timeline and weight graph. No new Foundation features are installed by this phase.

## One decision before Phase 1

**Approve native SwiftUI with Phase1 verified on iOS, and Android deferred to the later Kotlin/Compose client? Recommended: go.** §10.1 permits this native route and PLAT-10 labels Android P2, while §12 asks for both emulators in Phase1. Your [operating contract §0.4(d)](MASTER_BUILD_BRIEF.md) says to ask when two requirements contradict. “Go” accepts this explicit Phase1 acceptance amendment.

The Stack calculator's store/legal eligibility, real clinical reference data and paid/region-bound services remain later gates before their dependent work; they do not block the architecture review. All release checkboxes remain open in [COMPLIANCE.md](COMPLIANCE.md).

Recommended next step: Foundation—package boundaries and repository adapters first, followed by navigation/design tokens, safe local migration fixtures, flags/settings and the fictional demo generator. Keep existing logging usable throughout. Provisioning sync services will require a concrete provider/region decision when needed.

Ready for Phase 1 — say go.
