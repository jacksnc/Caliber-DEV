# Phase 1 — Local Foundation delivery

Status: local implementation ready for review; **Phase 1 remains open** for hosted auth/sync activation, hosted CI, minimum-OS runtime testing and device performance evidence. Existing diary, restaurant and Progress data stays in SwiftData. No user data was migrated or uploaded.

## Plan

1. Preserve the existing app and commit an exact pre-Foundation checkpoint.
2. Add six native package targets with pinned dependencies.
3. Add Today, settings, onboarding, number hiding and a separate fictional demo.
4. Verify local migrations and a lossless legacy-copy rehearsal using fixtures.
5. Test an immutable sync journal and owner-isolated PostgreSQL gateway locally.
6. Add CI, calculation notes, run commands and an explicit verification ledger.
7. Activate hosted services only after provider/region/account configuration is supplied.

## What you can use now

- **Today:** daily energy/protein and quick access to food and Progress logging.
- **Progress:** your existing photo, notes, weight, graph and timeline flows remain available.
- **Settings:** appearance, units, decimal/date formatting, week start, number hiding, notices and scope information. The interface is English; formatting choices are not translations.
- **Number-free journal:** keeps photos and notes available, removes numeric editors/chart routes and preserves existing weight when editing a note.
- **Explore Demo:** a deterministic 12-month fictional year with missing days, noisy weights, a cut phase, deloads, workouts and an optional arbitrary-unit simulation track. It uses separate files and cannot overwrite your diary. The simulation is not a real compound, dosing schedule, preset or recommendation.
- **Chart foundation:** calendar ranges, missing-day gaps, unit labels, descriptive first-to-last change, coverage, method sheets and accessible tables. This is the shared starting point for later module charts.

The final Today/Train/Fuel/Stack/Progress navigation arrives as the corresponding modules work. For now the usable tabs are Today, Diary, Food Library, Progress and Settings; food search remains reachable from Today and Diary.

## Files

Complete files are in the repository and delivery archive, including the existing application required to build. No generated build cache, app database, credentials or personal photos are included. See `PHASE_1_FILES.txt` for every delivered path.

```text
.github/workflows/foundation.yml
.gitignore
Caliber (DEV).xcodeproj/
Caliber (DEV)/
  App/FoundationRuntime.swift
  App/Caliber__DEV_App.swift
  Resources/Localizable.xcstrings
  Resources/ThirdPartyNotices.txt
  Services/LegacySnapshotAdapter.swift
  Views/Foundation/FoundationSettingsView.swift
  Views/Foundation/TodayFoundationView.swift
  Views/Progress/ProgressEntryForm.swift
  Views/RootTabView.swift
Caliber (DEV)Tests/LegacySnapshotTests.swift
Caliber (DEV)UITests/FoundationUITests.swift
Packages/CaliberFoundation/
  Package.swift
  Package.resolved
  Sources/CaliberCore/
  Sources/CaliberDatabase/
  Sources/CaliberDesignSystem/
  Sources/CaliberCharts/
  Sources/CaliberSeedData/
  Sources/CaliberIntegrations/
  Tests/
backend/
  deno.json
  deno.lock
  supabase/config.toml
  supabase/migrations/001_foundation.sql
  supabase/functions/caliber-gateway/
  tests/
scripts/verify_phase1.py
scripts/lint_foundation.py
scripts/test_ios.py
docs/PHASE_1.md
docs/PHASE_1_VERIFICATION.md
```

## Migrations and durability

The GRDB store applies `v1_core`/`v1_stack`, then `v2_foundation` with demo manifests and the revision journal, and `v3_journal_indexes` for entity-history/cursor lookups. It tests populated v2→v3 preservation, reopen, interruption/retry and migration failure rollback. Core and simulation files stay separate. Separation alone is **not encryption**; real Stack collection remains unavailable.

`LegacySnapshotAdapter` reads public SwiftData model properties for all 15 existing model types. `LegacyShadowArchive` verifies byte-preserved JSON/photo content, relationships, entered pounds plus canonical kilograms, stable old-ID→UUIDv7 mapping, reopening and transactional failure recovery. This is a **rehearsal archive**, not a normalized production conversion. No application path switches existing users to this store. A future cutover still requires projection adapters, restore rehearsal, photo-vault protections and approval for any irreversible step.

The sync journal keeps immutable operations, tombstones and every competing branch. Historical conflict resolutions cannot erase newer offline branches. It uses authenticated ownership, idempotent operation IDs, causal parents, explicit resolution and ordered cursors. The PostgreSQL migration creates the journal/account RPC boundary with RLS; it does not yet implement a hosted replica of every canonical table. Tests run against real PostgreSQL compiled to WebAssembly (PGlite), not a hosted Supabase instance or multi-process production load.

Hosted sign-in and synchronization are not wired into live diary records. The client defaults to unconfigured and makes no request. Tokens use Keychain when enabled; the gateway uses HTTPS without client API keys. Local sign-out is implemented; hosted token revocation and consent/account lifecycle remain activation gates. See [storage decision](adr/006-foundation-implementation.md).

## Run in Xcode

1. Open **Caliber (DEV).xcodeproj** in the existing project folder.
2. In the top toolbar choose the **Caliber (DEV)** scheme and an installed **iPhone** simulator.
3. Select **Product → Run**, or press **⌘R**. Let Xcode resolve GRDB the first time.
4. On first launch, confirm age and app scope, then tap **Continue**.
5. Open **Today → Explore Demo** to inspect the fictional graphs. **Exit Demo** returns to your own logs.
6. Use **Settings → Hide Calories and Weight** for the photo/notes-only journal.

The deployment minimum is iOS 17. The actual simulator verification here uses iOS 27 on iPhone 17. An iOS 17 runtime was not installed, so minimum-version runtime compatibility is still unverified. No Apple account is needed for the simulator.

## Verify from Terminal

Run these commands from the project folder, using Xcode's developer tools and Deno 2.9.7. All databases created by these tests are fixtures.

```sh
python3 scripts/verify_phase1.py
python3 scripts/lint_foundation.py
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-foundation-swift
python3 scripts/test_ios.py --output /tmp/caliber-foundation-ios
```

Use a new output directory for each iOS run; Xcode will not overwrite an existing result bundle. For the backend:

```sh
cd backend
deno fmt --check
deno lint
deno task check
deno task test
```

CI runs the same checks, with Xcode 16.4 on the declared macOS 15 runner and pinned Deno. Its toolchain differs from the local Xcode 27 run and must be proven by the first hosted run. No remote exists in this checkout, so no workflow was submitted or reported green. Runner availability is documented by [GitHub](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md); Deno setup follows its [official CI guide](https://docs.deno.com/runtime/reference/continuous_integration/).

## Verification and next step

The [verification ledger](PHASE_1_VERIFICATION.md) records pass/fail and evidence for each Foundation acceptance area, including unmet gates. Pure math engines from §9.3 belong to subsequent phases and are not claimed complete by Foundation conversion tests.

Recommended next step: finish Foundation's hosted setup and minimum-device verification, then build Train core. Continue preserving the current SwiftData app until a reversible normalized-copy migration is independently verified. Do not enable cloud upload or real Stack capture merely because the underlying scaffolding compiles.
