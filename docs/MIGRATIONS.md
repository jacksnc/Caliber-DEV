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
