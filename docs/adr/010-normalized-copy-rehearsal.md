# ADR-010: Normalize a legacy snapshot without changing the live store

Status: implemented for local rehearsal, 2026-10-14.

The prior lossless archive and SwiftData memory restore prove the public model graph can be reconstructed. Canonical GRDB tables have stronger semantics: food nutrients require a 100 g basis, food logs/templates require grams, and observations require local dates/timezones. The old model often stored only an arbitrary serving and a timestamp. Pretending that serving weighed 100 g would change the meaning of personal data.

`LegacyNormalizedProjection` accepts an already-captured snapshot, explicit historical timezone assumption and import reference date. Its only file name is `normalized-rehearsal-v1/normalized-copy.sqlite` beneath an explicit rehearsal directory. It refuses unrelated existing databases. It never finds SwiftData private files, changes an app locator, opens Stack, or contacts cloud services.

A transaction allocates stable legacy mappings and writes canonical food/restaurant metadata, builder groups, meal logs/templates, weigh-ins, check-ins, notes, linked-photo metadata and eligible single-profile height. Additive typed compatibility tables preserve exact arbitrary portions, immutable diary totals, signed modifiers, quantities, relationships/order, profiles/orphans and original photo BLOBs. Archived payloads remain provenance; reconstruction reads typed columns independently and compares every field/link plus aggregate diary totals and photo hashes. The report's canonical and compatibility source-record counts overlap.

Copy failure rolls back. Reopening/retrying the same snapshot is idempotent; changed source/options require a new target. A target digest detects modification of projected rows. Migration writes run under `remote_apply`, return to local mode before commit and emit no outbox. The rehearsal-only migration is not registered in the live store factory or shared schema resources.

Limitations: no real serving gram/density reconstruction, historical travel timezone recovery, protected portable backup, attachment encryption/EXIF certification, full canonical read-model cutover or cloud sync. Photo bytes are unchanged and local; the directory is excluded from backups and uses complete file protection on iOS. A full private vault and approved migration/recovery process precede live cutover.

Verification: eight new database cases, all-model app adapter integration, failure/retry/reopen/source/tamper checks. See `FOOD_AND_NORMALIZED_VERIFICATION.md`.
