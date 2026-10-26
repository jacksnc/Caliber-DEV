# Migration contract v1

## What is delivered

Complete SQLite SQL proposals in `architecture/schema/core/001_v1.up.sql` and `stack/001_v1.up.sql`, empty-schema inverses, a deterministic schema generator, table manifest and executable Python standard-library tests. These files are not linked into the existing app and never open an app data container. Schema version1 is a fresh target-store version, not an in-place SwiftData migration number. Requires SQLite≥3.37 with JSON1; the executed host tests used SQLite3.54.0. Actual GRDB/iOS/SQLCipher combinations must be verified in Phase1.

No clinical reference records, exercise dataset, user account or sample dose regimen is seeded by SQL. P0 structures are present; the SQL does not implement Swift engines, RRULE evaluation, key management, a sync server or the complete read-model rebuild service.

## Conventions

- UUIDv7 lowercase identifiers, account-scoped composite foreign keys, UTC epoch milliseconds, IANA timezone and captured local-date buckets; entered text/unit retained beside canonical values.
- Every table has creation/update/tombstone/source metadata. Confirmed set, dose, protocol and inventory revisions are append-only. Ordinary deletion is a tombstone/revision, never a cascade.
- Identity rows start with a null head; append a revision, then point the identity to its own revision atomically. Competing revision branches stay stored. Correcting a dose's compound/occurrence requires an audited tombstone+replacement command.
- Core and Stack have separate accounts, outbox, cursors, conflicts, attachments, registries and rollups. Database tests cannot prove encryption or server authorization; those are explicit later gates.
- Fixed-point dose mass/volume uses integer µg/µL (scale0); IU/click coefficients use explicit scale6 and remain distinct dimensions. Pen calibration requires value, unit, scale and label evidence. Calculator inputs require label-confirmed final volume; added diluent is a separate optional field.
- Nutrition-day completeness is explicit; no row is not a zero day. Target constraints are defense-in-depth proposed policy fixtures, not medically approved safe intakes; automatic target creation remains disabled until input/clinical rules are reviewed.
- Local-write triggers append outbox envelopes. Remote pull must run on the serialized writer in one transaction: set that account's sync_context to remote_apply, apply already-authorized/version-checked deltas+cursor, restore mode local, then commit. Crash rolls back the flag and writes. The runtime must reject commit with remote mode still set and assert local on every new user command. Never toggle this outside the transaction.

## Copy migration from current SwiftData — Phase1, not executed

1. Inventory model version, counts, ownership and external photo files through supported SwiftData APIs. Freeze a consistent source snapshot and prepare a protected rollback copy plus manifest. No private CoreData/SwiftData SQL manipulation.
2. Allocate a separate shadow target; never point fresh SQL at the source database. Keep the old store readable. Create stable legacy_id_map entries so retrying resumes rather than duplicating records.
3. Transform FoodItem/menu/modifiers/builder groups into foods, servings, nutrients and component groups; preserve supported-double rules and user-created ownership. Copy diary totals as immutable nutrition snapshots independent of later catalog edits.
4. Copy old WeightEntry pounds using exact factor0.45359237 to kg; keep original stored value with lb label. Copy ProgressEntry date/notes/photo order and optional weight links. Use source IDs to preserve standalone weights and avoid duplicate linked entries.
5. Original entry timezone/entered units were not always stored. Do not claim they can be recovered exactly: record the migration assumption, preserve original timestamps and source values, show an import review for ambiguous day boundaries, and keep the original snapshot. No guessed historical travel timezone.
6. Copy attachment bytes to protected target staging, verify hashes and references, then atomically finalize. Test interrupted copies, missing files, low disk, locked storage and relationship failures.
7. Rebuild rollups and verify counts, totals, original values, IDs, photographs/order, relationships, expected deletion behavior, and restart after a hard kill. Compare representative days to the old app's result; unresolved differences block cutover.
8. Atomically switch the app's store locator only after verification. Retain the protected original snapshot through a defined recovery period; deletion needs a concrete retention/owner decision. A failure before cutover leaves the old app active. A failure after new writes requires reconciling those writes before restoring; do not discard new data.

## Rollback and portability

The down scripts refuse a populated store and are exclusively for disposable schema tests. Production rollback restores a verified snapshot/replays acknowledged operations; it is not DROP TABLE. Account erasure is a separate authenticated workflow that purges both local stores, keys, files, server records and retention-controlled backups; append-only audit is not an exception to an approved erasure request. No account is erased by Phase0.

Full JSON/CSV export retains schema/source/method versions and original units; attachments are a referenced protected bundle. Stack needs separate unlock and explicit inclusion. Import validates in a scratch store and shows a dry-run before a transaction touches real records.

## Phase 1 implementation status

GRDB executes bundled v1 core/Stack SQL plus `v2_foundation` and `v3_journal_indexes` on explicitly supplied fixture/demo paths. Reopen and populated v2→v3 tests pass; migration failure is transactional. The demo seed uses a checkpoint across the two stores and emits no sync outbox entries.

A public-property SwiftData adapter covers the existing 15 model types. The lossless rehearsal archive stores stable ID mappings, bytes/checksums, relationships, exact photo bytes and original entered pounds. Copy/read/reopen/retry/failure tests run on fixtures. This archive is not a normalized canonical mapping or a live cutover. The original ModelContainer/schema stays active and no private SwiftData SQLite internals are accessed. Production rollback still means restoring a verified snapshot, not dropping populated tables.

## Hosted DEV migrations

Applied `backend/supabase/migrations/001_foundation.sql` on October 10, additive `002_auth_guard.sql` and forward correction `003_auth_guard_route_cleanup.sql` on October 11, each in an explicit transaction. The additive migrations followed read-only name/prerequisite checks. Do not reapply them. The first adds the owner-bound journal/RPCs; the second adds isolated security-budget tables and a secret-guarded RPC; the third scopes retention under its existing route lock to avoid cross-route lock cycles. None converts the personal SwiftData store.

Migration 002 initializes disabled configuration. Its private setup transaction records only a generated secret digest and enables the guard; the reusable guard stays in the function-secret store. No digest/secret rotation or account erasure is automated. Tests use disposable databases and check grants, capacities/refill and failure behavior. Redeploy a reviewed compatible gateway/configuration for service recovery; dropping populated tables is not a rollback procedure. See AUTH_HARDENING_VERIFICATION.md and ADR-007.

Applied additive `004_account_lifecycle.sql` on October 12 after five read-only prerequisite checks, in an explicit transaction. It adds subject-bound account acceptance and separate recovery budget routes, retaining existing sign-in/refresh grants, counters, guard configuration and route-specific cleanup. Six hosted postflight checks pass. Do not reapply migrations 001–004 in this DEV project. No local SwiftData conversion occurred.

Hosted account self-deletion uses the supported Auth Admin API after verified bearer/password matching, not direct Auth SQL deletion. Existing foreign keys cascade that subject's journal and acceptance rows. A new disposable test account was deleted and five hosted cleanup/preservation checks passed. Local logs/photos remain intact. This hosted-only action is distinct from the future full-data erasure/export workflow and does not certify provider backup/log or Storage-object cleanup. See ADR-008 and ACCOUNT_LIFECYCLE_VERIFICATION.md.

## Local restore rehearsal — October 13

No new migration is applied. LegacyRestoreRehearsal reconstructs all 15 current SwiftData types from the version-1 saved archive into a new memory container, verifies exact recaptured rows and destroys only that memory container. The source context and archive remain unchanged. It accepts no existing context or file destination. This is a graph-compatibility check; normalized GRDB mapping, restored disk restart, protected attachments and live cutover are still required. See ADR-009 and LOCAL_RESTORE_VERIFICATION.md.

## Normalized rehearsal — October 14

`LegacyNormalizedProjection` adds a **rehearsal-only** v4 migration beneath its fixed, separately named target path. The live `FoundationStore`, shared v1–v3 schema resources, SwiftData models and app locator remain unchanged. No hosted SQL applied. Typed compatibility tables preserve arbitrary serving nutrition, quantities, original fields/photo bytes and unlinked objects that the stronger canonical gram/date schema cannot truthfully represent yet.

One immutable snapshot/timezone/reference-date boundary is supported per target; a changed snapshot needs another directory. Failure rolls back; retry/reopen preserves stable ID mappings. Reconciliation reconstructs typed fields independently of archived payload JSON and checks graph/totals/photo bytes plus the target digest. Zero migration outbox records are required. This is local copy/restart evidence only, not completed production migration, canonical repository cutover, photo vault or protected portable backup. See ADR-010.

## Food reuse and portion controls — October 14

No SwiftData model/schema, normalized rehearsal schema, live locator or hosted migration changes. A separate `food.library.favorites.v1` preference stores bounded source/content keys only. Recents and frequency are reconstructed from current logs; they are not another migrated history. Favoriting a personal food updates its existing `isSavedToLibrary` flag through the app context. Day/meal copying is an explicit user command that inserts independent snapshots, not a background migration. Existing archive versions still cover the same 15 models and do not claim to include device preference keys.

## Expanded public food catalog — October 14

No personal-data migration, live SwiftData schema change, normalized rehearsal change or hosted SQL is applied. `FoodDatabase.sqlite` is a newly bundled **public reference resource**, application_id 1128352838 and user_version 1. Its catalog_sources, catalog_foods, catalog_servings, catalog_metadata and food_search FTS5 tables are separate from private logs and canonical account tables. An app resource update supplies the new catalog; it never rewrites logged nutrition. Existing 311 Foundation IDs/values and favorite keys are preserved; SR Legacy adds its own namespace. The original FoodCatalog.json remains an unchanged reproduction/compatibility fixture and is no longer the production search backend. See ADR-013.

## Packaged barcode collection — October 15

No private SwiftData model, account database, rehearsal locator or hosted migration changes. New PackagedFoodDatabase.sqlite is a public reference resource(application_id1128352848,user_version1) with packaged_metadata/sources/products tables and canonical GTIN keys. It is separate from the generic source catalog and all personal data. Source-serving nutrition is copied into existing FoodItem/DiaryEntry fields only after Add. The optional online configuration/permission keys remain unchanged.

## Restaurant registry preparation — 2026-10-15

No private/SwiftData/hosted schema migration. RestaurantMenuCatalog.json has schemaVersion 1, a source-input SHA256 and separate public source/restaurant/item arrays. The shipped empty registry is reproducible from docs/examples/restaurant-menu-empty.json. Changing a public registry cannot rewrite diary snapshots. Runtime validation is read-only and does not insert source MenuItems. A custom item continues using the existing personal Restaurant/MenuItem models.

## Recipe metadata and normalized rehearsal v5 — 2026-10-24

`SavedMeal` adds `servings` with a default of 1 and optional, explicitly measured
`cookedYieldGrams` and `rawBatchGrams`. Existing `SavedMealItem` and `FoodItem`
relationships continue to store the ingredient snapshots. A default meal emits
the exact former version-1 archive payload; customized metadata uses a strict
version-2 payload extension with all three fields. Archive restore rejects
partial, unknown, nonpositive, nonfinite, or incorrectly typed metadata before
changing the source graph.

The separate, non-live GRDB rehearsal adds `legacy_projection_v5.sql`, a typed
metadata table and digest-version tracking. Existing completed v4 rehearsal
targets keep their v1 digest and identifiers. This is not applied to the live
SwiftData store, the Foundation locator, hosted SQL, or a user's data. See
`docs/RECIPE_VERIFICATION.md` for old-save/open, archive-roundtrip, and rehearsal
evidence. No destructive migration is performed.

## Train SwiftData entities — 2026-10-24

Four additive local entities are registered in the live SwiftData container:
`TrainingExercise`, `TrainingWorkout`, `TrainingWorkoutExercise`, and
`TrainingWorkoutSet`. They have no relationship to the existing 15 legacy model
types, so existing food, profile, diary, Progress, photo, and restaurant rows are
not rewritten. Workout-to-exercise and exercise-to-set children use cascade
deletion; an exercise referenced by history is nullified rather than cascading
through saved workouts. The bundled starter exercise rows are inserted only when
no bundled rows exist.

This is the first Train runtime slice, not the canonical GRDB cutover. The legacy
snapshot/restore rehearsal intentionally remains a compatibility proof for the
original 15 types; training data must be added to the future supported export and
copy migration before any store-locator switch. No hosted schema or Supabase
deployment changed.

## Helios app integration — 2026-10-25

No SwiftData, GRDB, hosted, or user-data migration. Existing `system`, `light`, `dark`, and `oled` preference values remain valid; only the displayed light/dark names become Frost/Graphite. Test appearance overrides run only in DEBUG when an isolated UI-testing mode is active.
