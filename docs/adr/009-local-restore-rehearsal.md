# ADR-009 — Local restore mapping from the existing archive

Date: 2026-10-13. Status: accepted for local verification; no live cutover.

## Decision

Follow the owner's choice to leave email setup pending and continue locally. Restore all 15 current model types from LegacySnapshotAdapter's version-1 saved rows into a new, explicit in-memory SwiftData container with CloudKit disabled. Return only recaptured values and count metadata, never models attached to the source or a source store locator.

Reject unknown fields/types/enums, duplicate IDs, missing or contradictory references, invalid photo encoding, incompatible entered units and inconsistent derived totals. Create objects before setting relationships. Preserve source UUIDs, original pounds, photos/order and custom menu/diary values exactly. Validate through a second ModelContext and tear down only the new memory container using the supported iOS 17 API.

No key, service, third-party library or new schema version is added. No existing model or UI is rewritten. This is a compatibility rehearsal for the existing archive, not normalized GRDB storage, an encrypted backup format, external-file import or a production restore button.

## Durability boundary

The saved archive's reopen/checksum tests supply persisted input. Restored SwiftData graph verification is in memory. It does not prove a restored disk store survives process termination.

An initial disk-based experiment exposed SQLite diagnostics when temporary copies were removed while SwiftData retained handles. Scoping autoreleased objects and reopening for teardown did not eliminate those diagnostics. Creating an additional legacy SwiftData disk store is unnecessary for this mapping check: the planned normalized target is GRDB. Keep disk restoration/canonical projection as its own future gate; do not unlink active SQLite files or manipulate SwiftData's private SQL internals.

## Evidence and remaining work

Six new test functions (including 13 invalid-input cases) and an extended all-15-model archive test pass, alongside the existing app regressions. Photos include a 196,608-byte fixture, sort-order ties and optional orphans. Injected failure preserves the source/archive and unrelated files, with successful retry. Integer boundary cases preserve Int.min and Int.max without conversion through Double.

Canonical projection, encrypted photo/Stack vaults, protected backup/export, explicit live cutover approval, minimum-OS/device execution and full Phase 1 acceptance remain open. See LOCAL_RESTORE_VERIFICATION.md.
