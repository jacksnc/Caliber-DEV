# ADR-002 — Explicit SQLite repositories and conflict-preserving sync

Status: proposed; v1 local SQL is runnable architecture, not wired into the app.

## Storage
Adopt GRDB/SQLite for explicit constraints, indexes, atomic commands, migrations and rollups. Preserve SwiftData until a copy migration passes. Core and Stack each have a private store, outbox and cursor; no `ATTACH` and no cross-store foreign key. SQLCipher/keychain integration is a Phase-1 security spike; plain sqlite migration tests prove schema behavior, not encryption. Never enable Stack private capture until encryption/key lifecycle tests pass.

The new schema stores canonical quantities and entered values. Use UUIDv7 generation from an injected clock/random source, not wall-clock order as the sync authority. Tables carry timestamps, tombstones and provenance. Persisted datetimes are UTC epoch milliseconds; API envelopes use RFC3339 UTC text through an explicit adapter; timezone is an IANA identifier; local_date is the stored logging-day bucket. Application validators verify real dates/zones beyond SQL shape checks. Versioned legacy-ID mapping prevents reimport duplicates.

## Command transaction
1. Validate account, units, permissions, occurrence/version and idempotency key.
2. Append a log revision (or update a mutable draft) and any inventory ledger adjustment.
3. Recompute affected daily rollups, PRs and insight invalidations from canonical active records.
4. Enqueue a durable outbox operation in the same transaction.
5. Commit before the UI confirms. A failure rolls back all five effects; no optimistic success for a durable health log.

Photo bytes stage in a protected temporary location, move atomically with an attachment manifest, and survive crash reconciliation. References cannot point to a missing final file. Reconciliation removes only verified abandoned staging files; never infer that an inaccessible locked file is missing.

## Backend choice
Supabase (region-pinned Postgres/Auth/private Storage/Edge Functions) with a custom push/pull endpoint. No project is provisioned in Phase 0. Each exposed table and storage path needs owner-scoped RLS, explicit grants and cross-account tests; service credentials stay server-side. Local SQL is not deployable PostgreSQL. The Postgres translation, endpoints and RLS tests are Phase-1 implementation deliverables.

## Sync protocol and conflicts
Each operation carries operation ID, entity ID, account ID, device ID, base revision, schema version and logical clock. The server authenticates ownership, checks the base revision and assigns an increasing change cursor within the account. It ACKs duplicate operations without reapplying their inventory/rollup effects. Pull returns bounded ordered deltas and a cursor committed locally with the deltas. During the serialized pull transaction, use account-scoped sync_context remote_apply to suppress echo envelopes, reset local before commit, and assert local before each user write (MIGRATIONS.md). Interrupted uploads retry by operation ID; attachments use content hashes scoped to owner.

- Sets/doses: edits append revisions; a delete appends a tombstone revision. Two edits to the same base form competing branches. Preserve both and surface a conflict; do not silently add both to tonnage or deduct a vial twice. Keep the last unambiguous projection and mark statistics pending resolution.
- Independent logs merge by unique operation ID. Never deduplicate different user-confirmed doses just because times/amounts match.
- Mutable metadata can merge non-overlapping fields; overlapping edits retain both candidates for user resolution. Device wall time never breaks ties.
- Tombstones prevent resurrection on reconnect. Retain until all active devices acknowledge the deletion cursor; expired-device restore requires a new full snapshot. Account erasure overrides audit retention and purges attachments/backups according to the approved retention policy.
- Outbox hydration after logout is account-bound. Another login cannot upload previous-owner rows.
- Stack sync requires module opt-in and its privacy consent; no secret timeline cache in the core account.

## Alternatives and evidence
A PowerSync/Electric-class engine remains possible if the custom protocol fails the conflict/performance spike. Decision favors one explicit operation model for append-only health logs and separate stores, with the cost of owning protocol correctness.

Primary references checked 2026-10-07: [GRDB project](https://github.com/groue/GRDB.swift) and [Supabase RLS guide](https://supabase.com/docs/guides/database/postgres/row-level-security). These references do not prove our future implementation secure. RLS allow/deny and retry/conflict suites are release gates.
