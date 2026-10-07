-- Caliber Phase 0: stack.sqlite v1. No app database is opened by this file.
-- Requires SQLite >= 3.37, JSON1; configure foreign_keys on EVERY connection.
PRAGMA foreign_keys = ON;
PRAGMA recursive_triggers = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;
PRAGMA application_id = 1128352851;
BEGIN IMMEDIATE;

-- Local account root; an offline account works without a remote identity.
CREATE TABLE accounts (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    external_subject TEXT,
    auth_provider TEXT CHECK(auth_provider IN ('apple','google','email')),
    age_verified_at INTEGER,
    region TEXT,
    sync_enabled INTEGER NOT NULL DEFAULT 0 CHECK(sync_enabled IN (0,1)),
    deletion_requested_at INTEGER,
    deletion_due_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(deletion_due_at IS NULL OR (deletion_requested_at IS NOT NULL AND deletion_due_at >= deletion_requested_at AND deletion_due_at <= deletion_requested_at + 2592000000))
) STRICT;

-- Per-account sync writer identity; never a hardware advertising identifier.
CREATE TABLE devices (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    label TEXT NOT NULL,
    platform TEXT NOT NULL,
    last_seen_at INTEGER,
    retired_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX devices_account_live ON devices(account_id, deleted_at);

-- Typed preferences; key material belongs in Keychain, never this table.
CREATE TABLE settings (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    language TEXT NOT NULL DEFAULT 'en',
    locale TEXT NOT NULL DEFAULT 'en_US',
    week_start INTEGER NOT NULL DEFAULT 1 CHECK(week_start BETWEEN 1 AND 7),
    theme TEXT NOT NULL DEFAULT 'system' CHECK(theme IN ('system','light','dark','oled')),
    quiet_start_minute INTEGER CHECK(quiet_start_minute BETWEEN 0 AND 1439),
    quiet_end_minute INTEGER CHECK(quiet_end_minute BETWEEN 0 AND 1439),
    notifications_enabled INTEGER NOT NULL DEFAULT 0 CHECK(notifications_enabled IN (0,1)),
    reduce_motion INTEGER NOT NULL DEFAULT 0 CHECK(reduce_motion IN (0,1)),
    module_opt_in_at INTEGER,
    disclaimer_version TEXT,
    discreet_mode INTEGER NOT NULL DEFAULT 1 CHECK(discreet_mode IN (0,1)),
    biometric_lock INTEGER NOT NULL DEFAULT 1 CHECK(biometric_lock IN (0,1)),
    app_switcher_blur INTEGER NOT NULL DEFAULT 1 CHECK(app_switcher_blur IN (0,1)),
    region_gate_version TEXT,
    region_gate_checked_at INTEGER,
    module_disabled_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id)
) STRICT;
CREATE INDEX settings_account_live ON settings(account_id, deleted_at);

-- Append-only grant/revoke acknowledgements and permission history.
CREATE TABLE consents (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    scope TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('grant','revoke')),
    expires_at INTEGER,
    acknowledgement_text TEXT NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(updated_at=created_at)
) STRICT;
CREATE INDEX consents_account_live ON consents(account_id, deleted_at);
CREATE INDEX consents_local_day ON consents(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Atomic, idempotent outbound mutation envelopes; health values stay in this store.
CREATE TABLE sync_outbox (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    entity_table TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    revision_id TEXT,
    operation TEXT NOT NULL CHECK(operation IN ('upsert','tombstone')),
    payload_json TEXT NOT NULL CHECK(json_valid(payload_json)),
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','sending','acknowledged','failed')),
    attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts>=0),
    next_attempt_at INTEGER,
    acknowledged_at INTEGER,
    last_error_code TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(entity_id IS NULL OR (length(entity_id) = 36 AND substr(entity_id,9,1) = '-' AND substr(entity_id,14,1) = '-' AND substr(entity_id,19,1) = '-' AND substr(entity_id,24,1) = '-' AND length(replace(entity_id,'-','')) = 32 AND replace(entity_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(entity_id,15,1) = '7' AND substr(entity_id,20,1) IN ('8','9','a','b'))),
    CHECK(revision_id IS NULL OR (length(revision_id) = 36 AND substr(revision_id,9,1) = '-' AND substr(revision_id,14,1) = '-' AND substr(revision_id,19,1) = '-' AND substr(revision_id,24,1) = '-' AND length(replace(revision_id,'-','')) = 32 AND replace(revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(revision_id,15,1) = '7' AND substr(revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX sync_outbox_account_live ON sync_outbox(account_id, deleted_at);

-- Opaque cursor advances only in the same transaction as all applied pull changes.
CREATE TABLE sync_cursors (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    stream TEXT NOT NULL,
    cursor TEXT NOT NULL DEFAULT '',
    server_sequence INTEGER NOT NULL DEFAULT 0 CHECK(server_sequence>=0),
    last_success_at INTEGER,
    export_checkpoint TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, stream)
) STRICT;
CREATE INDEX sync_cursors_account_live ON sync_cursors(account_id, deleted_at);

-- Keep both remote and local candidates until an explicit deterministic or user resolution.
CREATE TABLE sync_conflicts (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    entity_table TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    local_revision_id TEXT,
    remote_revision_id TEXT,
    local_payload_json TEXT NOT NULL CHECK(json_valid(local_payload_json)),
    remote_payload_json TEXT NOT NULL CHECK(json_valid(remote_payload_json)),
    resolution TEXT CHECK(resolution IN ('local','remote','merge','keep_both')),
    resolution_revision_id TEXT,
    resolved_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(entity_id IS NULL OR (length(entity_id) = 36 AND substr(entity_id,9,1) = '-' AND substr(entity_id,14,1) = '-' AND substr(entity_id,19,1) = '-' AND substr(entity_id,24,1) = '-' AND length(replace(entity_id,'-','')) = 32 AND replace(entity_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(entity_id,15,1) = '7' AND substr(entity_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_revision_id IS NULL OR (length(local_revision_id) = 36 AND substr(local_revision_id,9,1) = '-' AND substr(local_revision_id,14,1) = '-' AND substr(local_revision_id,19,1) = '-' AND substr(local_revision_id,24,1) = '-' AND length(replace(local_revision_id,'-','')) = 32 AND replace(local_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(local_revision_id,15,1) = '7' AND substr(local_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(remote_revision_id IS NULL OR (length(remote_revision_id) = 36 AND substr(remote_revision_id,9,1) = '-' AND substr(remote_revision_id,14,1) = '-' AND substr(remote_revision_id,19,1) = '-' AND substr(remote_revision_id,24,1) = '-' AND length(replace(remote_revision_id,'-','')) = 32 AND replace(remote_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(remote_revision_id,15,1) = '7' AND substr(remote_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(resolution_revision_id IS NULL OR (length(resolution_revision_id) = 36 AND substr(resolution_revision_id,9,1) = '-' AND substr(resolution_revision_id,14,1) = '-' AND substr(resolution_revision_id,19,1) = '-' AND substr(resolution_revision_id,24,1) = '-' AND length(replace(resolution_revision_id,'-','')) = 32 AND replace(resolution_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(resolution_revision_id,15,1) = '7' AND substr(resolution_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK((resolution IS NULL AND resolved_at IS NULL) OR (resolution IS NOT NULL AND resolved_at IS NOT NULL))
) STRICT;
CREATE INDEX sync_conflicts_account_live ON sync_conflicts(account_id, deleted_at);

-- Encrypted-file manifest with a same-store typed owner; no image bytes in sync logs.
CREATE TABLE attachments (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    owner_table TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    local_locator TEXT NOT NULL,
    remote_object_key TEXT,
    media_type TEXT NOT NULL,
    byte_count INTEGER NOT NULL CHECK(byte_count>=0),
    sha256 TEXT NOT NULL CHECK(length(sha256)=64 AND sha256 NOT GLOB '*[^0-9a-f]*'),
    width_px INTEGER CHECK(width_px>0),
    height_px INTEGER CHECK(height_px>0),
    duration_ms INTEGER CHECK(duration_ms>=0),
    pose TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    metadata_stripped INTEGER NOT NULL DEFAULT 1 CHECK(metadata_stripped IN (0,1)),
    biometric_required INTEGER NOT NULL DEFAULT 1 CHECK(biometric_required IN (0,1)),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(owner_id IS NULL OR (length(owner_id) = 36 AND substr(owner_id,9,1) = '-' AND substr(owner_id,14,1) = '-' AND substr(owner_id,19,1) = '-' AND substr(owner_id,24,1) = '-' AND length(replace(owner_id,'-','')) = 32 AND replace(owner_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(owner_id,15,1) = '7' AND substr(owner_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX attachments_account_live ON attachments(account_id, deleted_at);

-- Allowlisted query key and unit contract, never arbitrary executable SQL.
CREATE TABLE series_registry (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    metric_key TEXT NOT NULL,
    domain TEXT NOT NULL CHECK(domain IN ('stack')),
    unit TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('daily','event','instant')),
    aggregation TEXT NOT NULL CHECK(aggregation IN ('sum','mean','last','max')),
    value_storage TEXT NOT NULL CHECK(value_storage IN ('real','fixed')),
    color_token TEXT NOT NULL,
    source_query_key TEXT NOT NULL,
    method_version TEXT NOT NULL,
    is_estimate INTEGER NOT NULL DEFAULT 0 CHECK(is_estimate IN (0,1)),
    priority TEXT NOT NULL DEFAULT 'P0',
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, metric_key)
) STRICT;
CREATE INDEX series_registry_account_live ON series_registry(account_id, deleted_at);

-- Allowlisted event types for charts and the shared in-memory timeline.
CREATE TABLE event_registry (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    event_key TEXT NOT NULL,
    domain TEXT NOT NULL CHECK(domain IN ('stack')),
    label_key TEXT NOT NULL,
    shape_token TEXT NOT NULL,
    color_token TEXT NOT NULL,
    source_query_key TEXT NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, event_key)
) STRICT;
CREATE INDEX event_registry_account_live ON event_registry(account_id, deleted_at);

-- Typed annotations; Stack events are never copied to the core database.
CREATE TABLE events (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    event_type_id TEXT NOT NULL,
    owner_table TEXT,
    owner_id TEXT,
    title TEXT NOT NULL,
    notes TEXT,
    end_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, event_type_id) REFERENCES event_registry(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(event_type_id IS NULL OR (length(event_type_id) = 36 AND substr(event_type_id,9,1) = '-' AND substr(event_type_id,14,1) = '-' AND substr(event_type_id,19,1) = '-' AND substr(event_type_id,24,1) = '-' AND length(replace(event_type_id,'-','')) = 32 AND replace(event_type_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(event_type_id,15,1) = '7' AND substr(event_type_id,20,1) IN ('8','9','a','b'))),
    CHECK(owner_id IS NULL OR (length(owner_id) = 36 AND substr(owner_id,9,1) = '-' AND substr(owner_id,14,1) = '-' AND substr(owner_id,19,1) = '-' AND substr(owner_id,24,1) = '-' AND length(replace(owner_id,'-','')) = 32 AND replace(owner_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(owner_id,15,1) = '7' AND substr(owner_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(end_at IS NULL OR end_at>=occurred_at),
    CHECK((owner_table IS NULL)=(owner_id IS NULL))
) STRICT;
CREATE INDEX events_account_live ON events(account_id, deleted_at);
CREATE INDEX events_event_type_id_fk ON events(account_id, event_type_id);
CREATE INDEX events_local_day ON events(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Rebuildable per-series, local-day, dimension aggregates; missing values remain missing.
CREATE TABLE daily_rollups (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    series_id TEXT NOT NULL,
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days')=local_date),
    dimension_key TEXT NOT NULL DEFAULT '',
    real_value REAL,
    value_coefficient INTEGER,
    value_scale INTEGER,
    sample_count INTEGER NOT NULL CHECK(sample_count>=0),
    expected_count INTEGER CHECK(expected_count>=0),
    coverage REAL CHECK(coverage BETWEEN 0 AND 1),
    input_digest TEXT NOT NULL,
    method_version TEXT NOT NULL,
    rebuilt_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, series_id) REFERENCES series_registry(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(series_id IS NULL OR (length(series_id) = 36 AND substr(series_id,9,1) = '-' AND substr(series_id,14,1) = '-' AND substr(series_id,19,1) = '-' AND substr(series_id,24,1) = '-' AND length(replace(series_id,'-','')) = 32 AND replace(series_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(series_id,15,1) = '7' AND substr(series_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK((real_value IS NULL AND value_coefficient IS NULL AND value_scale IS NULL) OR (real_value IS NOT NULL AND value_coefficient IS NULL AND value_scale IS NULL) OR (real_value IS NULL AND value_coefficient IS NOT NULL AND value_scale BETWEEN 0 AND 6)),
    UNIQUE(account_id, series_id, local_date, dimension_key)
) STRICT;
CREATE INDEX daily_rollups_account_live ON daily_rollups(account_id, deleted_at);
CREATE INDEX daily_rollups_series_id_fk ON daily_rollups(account_id, series_id);

-- Independent per-chart range, transforms, hidden numbers and marker preferences.
CREATE TABLE chart_preferences (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    chart_key TEXT NOT NULL,
    range_key TEXT NOT NULL DEFAULT '1M',
    from_date TEXT,
    to_date TEXT,
    comparison_enabled INTEGER NOT NULL DEFAULT 0 CHECK(comparison_enabled IN (0,1)),
    trend TEXT NOT NULL DEFAULT 'raw' CHECK(trend IN ('raw','ewma','moving_average','theil_sen')),
    show_absolute_values INTEGER NOT NULL DEFAULT 1 CHECK(show_absolute_values IN (0,1)),
    marker_keys_json TEXT NOT NULL DEFAULT '[]' CHECK(json_valid(marker_keys_json)),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(from_date IS NULL OR (length(from_date)=10 AND date(from_date,'+0 days') IS NOT NULL AND date(from_date,'+0 days')=from_date)),
    CHECK(to_date IS NULL OR (length(to_date)=10 AND date(to_date,'+0 days') IS NOT NULL AND date(to_date,'+0 days')=to_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, chart_key)
) STRICT;
CREATE INDEX chart_preferences_account_live ON chart_preferences(account_id, deleted_at);

-- Local schedule state; fixed IDs allow cancel/reschedule without duplicate alerts.
CREATE TABLE notification_jobs (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    kind TEXT NOT NULL,
    owner_table TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    due_at INTEGER NOT NULL,
    tz TEXT NOT NULL,
    request_identifier TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('pending','scheduled','delivered','cancelled')),
    repeat_seconds INTEGER CHECK(repeat_seconds>0),
    snoozed_until INTEGER,
    neutral_text_key TEXT NOT NULL,
    last_action TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(owner_id IS NULL OR (length(owner_id) = 36 AND substr(owner_id,9,1) = '-' AND substr(owner_id,14,1) = '-' AND substr(owner_id,19,1) = '-' AND substr(owner_id,24,1) = '-' AND length(replace(owner_id,'-','')) = 32 AND replace(owner_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(owner_id,15,1) = '7' AND substr(owner_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, request_identifier)
) STRICT;
CREATE INDEX notification_jobs_account_live ON notification_jobs(account_id, deleted_at);

-- Private user-created compound identity; no benefit, suggested dose or sourcing fields.
CREATE TABLE compounds (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    aliases TEXT,
    class_label TEXT,
    permitted_routes TEXT,
    dosage_form TEXT NOT NULL CHECK(dosage_form IN ('vial','pen','tablet','nasal','topical','other')),
    default_dimension TEXT NOT NULL CHECK(default_dimension IN ('mass','volume','activity','clicks')),
    notes TEXT,
    storage_label_text TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX compounds_account_live ON compounds(account_id, deleted_at);

-- Optional cited neutral reference facts. This migration inserts none.
CREATE TABLE compound_references (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    compound_id TEXT NOT NULL,
    fact_kind TEXT NOT NULL CHECK(fact_kind IN ('half_life','regulatory_status','wada_status','label_storage')),
    value_text TEXT NOT NULL,
    unit TEXT,
    region TEXT,
    citation_url TEXT NOT NULL,
    citation_date TEXT NOT NULL,
    reviewed_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, compound_id) REFERENCES compounds(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(compound_id IS NULL OR (length(compound_id) = 36 AND substr(compound_id,9,1) = '-' AND substr(compound_id,14,1) = '-' AND substr(compound_id,19,1) = '-' AND substr(compound_id,24,1) = '-' AND length(replace(compound_id,'-','')) = 32 AND replace(compound_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(compound_id,15,1) = '7' AND substr(compound_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(citation_date IS NULL OR (length(citation_date)=10 AND date(citation_date,'+0 days') IS NOT NULL AND date(citation_date,'+0 days')=citation_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX compound_references_account_live ON compound_references(account_id, deleted_at);
CREATE INDEX compound_references_compound_id_fk ON compound_references(account_id, compound_id);

-- Protocol/template identity with an explicit selected immutable revision.
CREATE TABLE protocols (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    is_template INTEGER NOT NULL DEFAULT 0 CHECK(is_template IN (0,1)),
    reminder_group_key TEXT,
    color_token TEXT NOT NULL,
    current_revision_id TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, current_revision_id) REFERENCES protocol_revisions(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(current_revision_id IS NULL OR (length(current_revision_id) = 36 AND substr(current_revision_id,9,1) = '-' AND substr(current_revision_id,14,1) = '-' AND substr(current_revision_id,19,1) = '-' AND substr(current_revision_id,24,1) = '-' AND length(replace(current_revision_id,'-','')) = 32 AND replace(current_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(current_revision_id,15,1) = '7' AND substr(current_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX protocols_account_live ON protocols(account_id, deleted_at);
CREATE INDEX protocols_current_revision_id_fk ON protocols(account_id, current_revision_id);

-- Append-only history of protocol edits, pause/resume and user-authored step plans.
CREATE TABLE protocol_revisions (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    protocol_id TEXT NOT NULL,
    parent_revision_id TEXT,
    writer_device_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('draft','active','paused','ended','archived')),
    starts_on TEXT NOT NULL,
    ends_on TEXT,
    notes TEXT,
    edit_reason TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, protocol_id) REFERENCES protocols(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, parent_revision_id) REFERENCES protocol_revisions(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, writer_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(protocol_id IS NULL OR (length(protocol_id) = 36 AND substr(protocol_id,9,1) = '-' AND substr(protocol_id,14,1) = '-' AND substr(protocol_id,19,1) = '-' AND substr(protocol_id,24,1) = '-' AND length(replace(protocol_id,'-','')) = 32 AND replace(protocol_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(protocol_id,15,1) = '7' AND substr(protocol_id,20,1) IN ('8','9','a','b'))),
    CHECK(parent_revision_id IS NULL OR (length(parent_revision_id) = 36 AND substr(parent_revision_id,9,1) = '-' AND substr(parent_revision_id,14,1) = '-' AND substr(parent_revision_id,19,1) = '-' AND substr(parent_revision_id,24,1) = '-' AND length(replace(parent_revision_id,'-','')) = 32 AND replace(parent_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(parent_revision_id,15,1) = '7' AND substr(parent_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(writer_device_id IS NULL OR (length(writer_device_id) = 36 AND substr(writer_device_id,9,1) = '-' AND substr(writer_device_id,14,1) = '-' AND substr(writer_device_id,19,1) = '-' AND substr(writer_device_id,24,1) = '-' AND length(replace(writer_device_id,'-','')) = 32 AND replace(writer_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(writer_device_id,15,1) = '7' AND substr(writer_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    CHECK(starts_on IS NULL OR (length(starts_on)=10 AND date(starts_on,'+0 days') IS NOT NULL AND date(starts_on,'+0 days')=starts_on)),
    CHECK(ends_on IS NULL OR (length(ends_on)=10 AND date(ends_on,'+0 days') IS NOT NULL AND date(ends_on,'+0 days')=ends_on)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(updated_at=created_at)
) STRICT;
CREATE INDEX protocol_revisions_account_live ON protocol_revisions(account_id, deleted_at);
CREATE INDEX protocol_revisions_protocol_id_fk ON protocol_revisions(account_id, protocol_id);
CREATE INDEX protocol_revisions_parent_revision_id_fk ON protocol_revisions(account_id, parent_revision_id);
CREATE INDEX protocol_revisions_writer_device_id_fk ON protocol_revisions(account_id, writer_device_id);
CREATE INDEX protocol_revisions_local_day ON protocol_revisions(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- User-entered compound amount and route at a date/position in a protocol revision.
CREATE TABLE protocol_steps (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    amount_value INTEGER NOT NULL CHECK(amount_value>0),
    amount_unit TEXT NOT NULL CHECK(amount_unit IN ('ug','uL','IU','click')),
    amount_scale INTEGER NOT NULL,
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    protocol_revision_id TEXT NOT NULL,
    compound_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    effective_on TEXT NOT NULL,
    route TEXT NOT NULL,
    food_note TEXT CHECK(food_note IN ('with_food','fasted','unspecified')),
    notes TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, protocol_revision_id) REFERENCES protocol_revisions(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, compound_id) REFERENCES compounds(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(protocol_revision_id IS NULL OR (length(protocol_revision_id) = 36 AND substr(protocol_revision_id,9,1) = '-' AND substr(protocol_revision_id,14,1) = '-' AND substr(protocol_revision_id,19,1) = '-' AND substr(protocol_revision_id,24,1) = '-' AND length(replace(protocol_revision_id,'-','')) = 32 AND replace(protocol_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(protocol_revision_id,15,1) = '7' AND substr(protocol_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(compound_id IS NULL OR (length(compound_id) = 36 AND substr(compound_id,9,1) = '-' AND substr(compound_id,14,1) = '-' AND substr(compound_id,19,1) = '-' AND substr(compound_id,24,1) = '-' AND length(replace(compound_id,'-','')) = 32 AND replace(compound_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(compound_id,15,1) = '7' AND substr(compound_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(effective_on IS NULL OR (length(effective_on)=10 AND date(effective_on,'+0 days') IS NOT NULL AND date(effective_on,'+0 days')=effective_on)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK((amount_unit IN ('ug','uL') AND amount_scale=0) OR (amount_unit IN ('IU','click') AND amount_scale=6)),
    CHECK(updated_at=created_at)
) STRICT;
CREATE INDEX protocol_steps_account_live ON protocol_steps(account_id, deleted_at);
CREATE INDEX protocol_steps_protocol_revision_id_fk ON protocol_steps(account_id, protocol_revision_id);
CREATE INDEX protocol_steps_compound_id_fk ON protocol_steps(account_id, compound_id);

-- User schedules and DST/travel policy; rule generation belongs to the tested schedule engine.
CREATE TABLE schedule_rules (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    protocol_step_id TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('daily','every_n_days','weekdays','n_per_week','weekly','biweekly','monthly','cycle','prn','rrule')),
    rrule TEXT,
    interval_days INTEGER CHECK(interval_days>0),
    times_per_week INTEGER CHECK(times_per_week BETWEEN 1 AND 7),
    weekdays_mask INTEGER CHECK(weekdays_mask BETWEEN 1 AND 127),
    on_days INTEGER CHECK(on_days>0),
    off_days INTEGER CHECK(off_days>=0),
    month_day INTEGER CHECK(month_day BETWEEN 1 AND 31),
    anchor_date TEXT NOT NULL,
    end_date TEXT,
    tz TEXT NOT NULL,
    time_policy TEXT NOT NULL CHECK(time_policy IN ('floating','fixed')),
    dst_gap_policy TEXT NOT NULL CHECK(dst_gap_policy IN ('next_valid','skip')),
    dst_fold_policy TEXT NOT NULL CHECK(dst_fold_policy IN ('first','second')),
    late_window_seconds INTEGER NOT NULL CHECK(late_window_seconds>=0),
    paused_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, protocol_step_id) REFERENCES protocol_steps(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(protocol_step_id IS NULL OR (length(protocol_step_id) = 36 AND substr(protocol_step_id,9,1) = '-' AND substr(protocol_step_id,14,1) = '-' AND substr(protocol_step_id,19,1) = '-' AND substr(protocol_step_id,24,1) = '-' AND length(replace(protocol_step_id,'-','')) = 32 AND replace(protocol_step_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(protocol_step_id,15,1) = '7' AND substr(protocol_step_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(anchor_date IS NULL OR (length(anchor_date)=10 AND date(anchor_date,'+0 days') IS NOT NULL AND date(anchor_date,'+0 days')=anchor_date)),
    CHECK(end_date IS NULL OR (length(end_date)=10 AND date(end_date,'+0 days') IS NOT NULL AND date(end_date,'+0 days')=end_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(kind<>'rrule' OR (rrule IS NOT NULL AND length(rrule)>0)),
    CHECK(kind<>'cycle' OR (on_days IS NOT NULL AND off_days IS NOT NULL)),
    CHECK(updated_at=created_at)
) STRICT;
CREATE INDEX schedule_rules_account_live ON schedule_rules(account_id, deleted_at);
CREATE INDEX schedule_rules_protocol_step_id_fk ON schedule_rules(account_id, protocol_step_id);

-- Multiple chosen local times per schedule, independent of UTC offsets.
CREATE TABLE schedule_times (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    schedule_rule_id TEXT NOT NULL,
    hour INTEGER NOT NULL CHECK(hour BETWEEN 0 AND 23),
    minute INTEGER NOT NULL CHECK(minute BETWEEN 0 AND 59),
    position INTEGER NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, schedule_rule_id) REFERENCES schedule_rules(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(schedule_rule_id IS NULL OR (length(schedule_rule_id) = 36 AND substr(schedule_rule_id,9,1) = '-' AND substr(schedule_rule_id,14,1) = '-' AND substr(schedule_rule_id,19,1) = '-' AND substr(schedule_rule_id,24,1) = '-' AND length(replace(schedule_rule_id,'-','')) = 32 AND replace(schedule_rule_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(schedule_rule_id,15,1) = '7' AND substr(schedule_rule_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(updated_at=created_at),
    UNIQUE(account_id, schedule_rule_id, hour, minute)
) STRICT;
CREATE INDEX schedule_times_account_live ON schedule_times(account_id, deleted_at);
CREATE INDEX schedule_times_schedule_rule_id_fk ON schedule_times(account_id, schedule_rule_id);

-- Materialized expected occurrence and notification state; no inferred recommended amount.
CREATE TABLE dose_occurrences (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    protocol_step_id TEXT NOT NULL,
    schedule_rule_id TEXT NOT NULL,
    occurrence_key TEXT NOT NULL,
    due_at INTEGER NOT NULL,
    late_after_at INTEGER NOT NULL,
    expires_at INTEGER,
    tz TEXT NOT NULL,
    local_date TEXT NOT NULL,
    state TEXT NOT NULL CHECK(state IN ('due','taken','late','skipped','missed')),
    snoozed_until INTEGER,
    state_reason TEXT,
    resolved_dose_id TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, protocol_step_id) REFERENCES protocol_steps(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, schedule_rule_id) REFERENCES schedule_rules(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, resolved_dose_id) REFERENCES dose_logs(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(protocol_step_id IS NULL OR (length(protocol_step_id) = 36 AND substr(protocol_step_id,9,1) = '-' AND substr(protocol_step_id,14,1) = '-' AND substr(protocol_step_id,19,1) = '-' AND substr(protocol_step_id,24,1) = '-' AND length(replace(protocol_step_id,'-','')) = 32 AND replace(protocol_step_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(protocol_step_id,15,1) = '7' AND substr(protocol_step_id,20,1) IN ('8','9','a','b'))),
    CHECK(schedule_rule_id IS NULL OR (length(schedule_rule_id) = 36 AND substr(schedule_rule_id,9,1) = '-' AND substr(schedule_rule_id,14,1) = '-' AND substr(schedule_rule_id,19,1) = '-' AND substr(schedule_rule_id,24,1) = '-' AND length(replace(schedule_rule_id,'-','')) = 32 AND replace(schedule_rule_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(schedule_rule_id,15,1) = '7' AND substr(schedule_rule_id,20,1) IN ('8','9','a','b'))),
    CHECK(resolved_dose_id IS NULL OR (length(resolved_dose_id) = 36 AND substr(resolved_dose_id,9,1) = '-' AND substr(resolved_dose_id,14,1) = '-' AND substr(resolved_dose_id,19,1) = '-' AND substr(resolved_dose_id,24,1) = '-' AND length(replace(resolved_dose_id,'-','')) = 32 AND replace(resolved_dose_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(resolved_dose_id,15,1) = '7' AND substr(resolved_dose_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(late_after_at>=due_at),
    UNIQUE(account_id, occurrence_key)
) STRICT;
CREATE INDEX dose_occurrences_account_live ON dose_occurrences(account_id, deleted_at);
CREATE INDEX dose_occurrences_protocol_step_id_fk ON dose_occurrences(account_id, protocol_step_id);
CREATE INDEX dose_occurrences_schedule_rule_id_fk ON dose_occurrences(account_id, schedule_rule_id);
CREATE INDEX dose_occurrences_resolved_dose_id_fk ON dose_occurrences(account_id, resolved_dose_id);

-- Stable logged-dose identity; all edits/deletions are new immutable revisions.
CREATE TABLE dose_logs (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    compound_id TEXT NOT NULL,
    occurrence_id TEXT,
    current_revision_id TEXT,
    duplicate_guard_ack_at INTEGER,
    duplicate_guard_reason TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, compound_id) REFERENCES compounds(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, occurrence_id) REFERENCES dose_occurrences(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, current_revision_id) REFERENCES dose_revisions(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(compound_id IS NULL OR (length(compound_id) = 36 AND substr(compound_id,9,1) = '-' AND substr(compound_id,14,1) = '-' AND substr(compound_id,19,1) = '-' AND substr(compound_id,24,1) = '-' AND length(replace(compound_id,'-','')) = 32 AND replace(compound_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(compound_id,15,1) = '7' AND substr(compound_id,20,1) IN ('8','9','a','b'))),
    CHECK(occurrence_id IS NULL OR (length(occurrence_id) = 36 AND substr(occurrence_id,9,1) = '-' AND substr(occurrence_id,14,1) = '-' AND substr(occurrence_id,19,1) = '-' AND substr(occurrence_id,24,1) = '-' AND length(replace(occurrence_id,'-','')) = 32 AND replace(occurrence_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(occurrence_id,15,1) = '7' AND substr(occurrence_id,20,1) IN ('8','9','a','b'))),
    CHECK(current_revision_id IS NULL OR (length(current_revision_id) = 36 AND substr(current_revision_id,9,1) = '-' AND substr(current_revision_id,14,1) = '-' AND substr(current_revision_id,19,1) = '-' AND substr(current_revision_id,24,1) = '-' AND length(replace(current_revision_id,'-','')) = 32 AND replace(current_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(current_revision_id,15,1) = '7' AND substr(current_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX dose_logs_account_live ON dose_logs(account_id, deleted_at);
CREATE INDEX dose_logs_compound_id_fk ON dose_logs(account_id, compound_id);
CREATE INDEX dose_logs_occurrence_id_fk ON dose_logs(account_id, occurrence_id);
CREATE INDEX dose_logs_current_revision_id_fk ON dose_logs(account_id, current_revision_id);

-- Exact user-confirmed dose snapshots, site/reaction/check-in and audit history.
CREATE TABLE dose_revisions (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    amount_value INTEGER NOT NULL CHECK(amount_value>0),
    amount_unit TEXT NOT NULL CHECK(amount_unit IN ('ug','uL','IU','click')),
    amount_scale INTEGER NOT NULL,
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    dose_log_id TEXT NOT NULL,
    parent_revision_id TEXT,
    writer_device_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('upsert','tombstone','restore')),
    route TEXT NOT NULL,
    vial_id TEXT,
    site_id TEXT,
    syringe_id TEXT,
    draw_volume_ul INTEGER CHECK(draw_volume_ul>0),
    needle_description TEXT,
    lot_snapshot TEXT,
    notes TEXT,
    edit_reason TEXT,
    energy INTEGER CHECK(energy BETWEEN 1 AND 5),
    appetite INTEGER CHECK(appetite BETWEEN 1 AND 5),
    mood INTEGER CHECK(mood BETWEEN 1 AND 5),
    sleep INTEGER CHECK(sleep BETWEEN 1 AND 5),
    pain INTEGER CHECK(pain BETWEEN 0 AND 5),
    redness INTEGER CHECK(redness BETWEEN 0 AND 5),
    bruise INTEGER CHECK(bruise BETWEEN 0 AND 5),
    user_confirmed_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, dose_log_id) REFERENCES dose_logs(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, parent_revision_id) REFERENCES dose_revisions(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, writer_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, vial_id) REFERENCES vials(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, site_id) REFERENCES injection_sites(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, syringe_id) REFERENCES syringes(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(dose_log_id IS NULL OR (length(dose_log_id) = 36 AND substr(dose_log_id,9,1) = '-' AND substr(dose_log_id,14,1) = '-' AND substr(dose_log_id,19,1) = '-' AND substr(dose_log_id,24,1) = '-' AND length(replace(dose_log_id,'-','')) = 32 AND replace(dose_log_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(dose_log_id,15,1) = '7' AND substr(dose_log_id,20,1) IN ('8','9','a','b'))),
    CHECK(parent_revision_id IS NULL OR (length(parent_revision_id) = 36 AND substr(parent_revision_id,9,1) = '-' AND substr(parent_revision_id,14,1) = '-' AND substr(parent_revision_id,19,1) = '-' AND substr(parent_revision_id,24,1) = '-' AND length(replace(parent_revision_id,'-','')) = 32 AND replace(parent_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(parent_revision_id,15,1) = '7' AND substr(parent_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(writer_device_id IS NULL OR (length(writer_device_id) = 36 AND substr(writer_device_id,9,1) = '-' AND substr(writer_device_id,14,1) = '-' AND substr(writer_device_id,19,1) = '-' AND substr(writer_device_id,24,1) = '-' AND length(replace(writer_device_id,'-','')) = 32 AND replace(writer_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(writer_device_id,15,1) = '7' AND substr(writer_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(vial_id IS NULL OR (length(vial_id) = 36 AND substr(vial_id,9,1) = '-' AND substr(vial_id,14,1) = '-' AND substr(vial_id,19,1) = '-' AND substr(vial_id,24,1) = '-' AND length(replace(vial_id,'-','')) = 32 AND replace(vial_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(vial_id,15,1) = '7' AND substr(vial_id,20,1) IN ('8','9','a','b'))),
    CHECK(site_id IS NULL OR (length(site_id) = 36 AND substr(site_id,9,1) = '-' AND substr(site_id,14,1) = '-' AND substr(site_id,19,1) = '-' AND substr(site_id,24,1) = '-' AND length(replace(site_id,'-','')) = 32 AND replace(site_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(site_id,15,1) = '7' AND substr(site_id,20,1) IN ('8','9','a','b'))),
    CHECK(syringe_id IS NULL OR (length(syringe_id) = 36 AND substr(syringe_id,9,1) = '-' AND substr(syringe_id,14,1) = '-' AND substr(syringe_id,19,1) = '-' AND substr(syringe_id,24,1) = '-' AND length(replace(syringe_id,'-','')) = 32 AND replace(syringe_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(syringe_id,15,1) = '7' AND substr(syringe_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK((amount_unit IN ('ug','uL') AND amount_scale=0) OR (amount_unit IN ('IU','click') AND amount_scale=6)),
    CHECK(action<>'tombstone' OR deleted_at IS NOT NULL),
    CHECK(updated_at=created_at)
) STRICT;
CREATE INDEX dose_revisions_account_live ON dose_revisions(account_id, deleted_at);
CREATE INDEX dose_revisions_dose_log_id_fk ON dose_revisions(account_id, dose_log_id);
CREATE INDEX dose_revisions_parent_revision_id_fk ON dose_revisions(account_id, parent_revision_id);
CREATE INDEX dose_revisions_writer_device_id_fk ON dose_revisions(account_id, writer_device_id);
CREATE INDEX dose_revisions_vial_id_fk ON dose_revisions(account_id, vial_id);
CREATE INDEX dose_revisions_site_id_fk ON dose_revisions(account_id, site_id);
CREATE INDEX dose_revisions_syringe_id_fk ON dose_revisions(account_id, syringe_id);
CREATE INDEX dose_revisions_local_day ON dose_revisions(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Vial/pen/container lifecycle and label-entered dates. Remaining inventory is ledger-derived.
CREATE TABLE vials (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    label TEXT NOT NULL,
    form TEXT NOT NULL CHECK(form IN ('vial','pen','tablet','nasal','topical','other')),
    lifecycle TEXT NOT NULL CHECK(lifecycle IN ('sealed','opened','in_use','empty','expired','discarded')),
    lot TEXT,
    supplier_note TEXT,
    price_minor INTEGER CHECK(price_minor>=0),
    currency TEXT CHECK(length(currency)=3),
    storage TEXT CHECK(storage IN ('fridge','freezer','room','other')),
    received_at INTEGER,
    opened_at INTEGER,
    reconstituted_at INTEGER,
    beyond_use_at INTEGER,
    label_expiry_at INTEGER,
    diluent_ul INTEGER CHECK(diluent_ul>0),
    final_solution_ul INTEGER CHECK(final_solution_ul>0),
    volume_basis TEXT CHECK(volume_basis IN ('label_final_volume','label_confirms_added_equals_final')),
    volume_label_evidence TEXT,
    notes TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX vials_account_live ON vials(account_id, deleted_at);

-- Per-component initial exact amount supports blends without converting IU into mass.
CREATE TABLE vial_components (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    amount_value INTEGER NOT NULL CHECK(amount_value>0),
    amount_unit TEXT NOT NULL CHECK(amount_unit IN ('ug','uL','IU','click')),
    amount_scale INTEGER NOT NULL,
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    vial_id TEXT NOT NULL,
    compound_id TEXT NOT NULL,
    ratio_value INTEGER CHECK(ratio_value>0),
    ratio_scale INTEGER CHECK(ratio_scale BETWEEN 0 AND 6),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, vial_id) REFERENCES vials(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, compound_id) REFERENCES compounds(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(vial_id IS NULL OR (length(vial_id) = 36 AND substr(vial_id,9,1) = '-' AND substr(vial_id,14,1) = '-' AND substr(vial_id,19,1) = '-' AND substr(vial_id,24,1) = '-' AND length(replace(vial_id,'-','')) = 32 AND replace(vial_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(vial_id,15,1) = '7' AND substr(vial_id,20,1) IN ('8','9','a','b'))),
    CHECK(compound_id IS NULL OR (length(compound_id) = 36 AND substr(compound_id,9,1) = '-' AND substr(compound_id,14,1) = '-' AND substr(compound_id,19,1) = '-' AND substr(compound_id,24,1) = '-' AND length(replace(compound_id,'-','')) = 32 AND replace(compound_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(compound_id,15,1) = '7' AND substr(compound_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK((amount_unit IN ('ug','uL') AND amount_scale=0) OR (amount_unit IN ('IU','click') AND amount_scale=6)),
    UNIQUE(account_id, vial_id, compound_id)
) STRICT;
CREATE INDEX vial_components_account_live ON vial_components(account_id, deleted_at);
CREATE INDEX vial_components_vial_id_fk ON vial_components(account_id, vial_id);
CREATE INDEX vial_components_compound_id_fk ON vial_components(account_id, compound_id);

-- Immutable signed inventory movements; corrections reverse old movements then append replacements.
CREATE TABLE inventory_ledger (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    vial_id TEXT NOT NULL,
    compound_id TEXT,
    dose_revision_id TEXT,
    reverses_entry_id TEXT,
    transaction_id TEXT NOT NULL,
    movement TEXT NOT NULL CHECK(movement IN ('opening','dose','priming','waste','correction','reversal')),
    amount_value INTEGER NOT NULL CHECK(amount_value<>0),
    amount_unit TEXT NOT NULL CHECK(amount_unit IN ('ug','uL','IU','click')),
    amount_scale INTEGER NOT NULL,
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    reason TEXT,
    writer_device_id TEXT NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, vial_id) REFERENCES vials(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, compound_id) REFERENCES compounds(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, dose_revision_id) REFERENCES dose_revisions(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, reverses_entry_id) REFERENCES inventory_ledger(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, writer_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(vial_id IS NULL OR (length(vial_id) = 36 AND substr(vial_id,9,1) = '-' AND substr(vial_id,14,1) = '-' AND substr(vial_id,19,1) = '-' AND substr(vial_id,24,1) = '-' AND length(replace(vial_id,'-','')) = 32 AND replace(vial_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(vial_id,15,1) = '7' AND substr(vial_id,20,1) IN ('8','9','a','b'))),
    CHECK(compound_id IS NULL OR (length(compound_id) = 36 AND substr(compound_id,9,1) = '-' AND substr(compound_id,14,1) = '-' AND substr(compound_id,19,1) = '-' AND substr(compound_id,24,1) = '-' AND length(replace(compound_id,'-','')) = 32 AND replace(compound_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(compound_id,15,1) = '7' AND substr(compound_id,20,1) IN ('8','9','a','b'))),
    CHECK(dose_revision_id IS NULL OR (length(dose_revision_id) = 36 AND substr(dose_revision_id,9,1) = '-' AND substr(dose_revision_id,14,1) = '-' AND substr(dose_revision_id,19,1) = '-' AND substr(dose_revision_id,24,1) = '-' AND length(replace(dose_revision_id,'-','')) = 32 AND replace(dose_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(dose_revision_id,15,1) = '7' AND substr(dose_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(reverses_entry_id IS NULL OR (length(reverses_entry_id) = 36 AND substr(reverses_entry_id,9,1) = '-' AND substr(reverses_entry_id,14,1) = '-' AND substr(reverses_entry_id,19,1) = '-' AND substr(reverses_entry_id,24,1) = '-' AND length(replace(reverses_entry_id,'-','')) = 32 AND replace(reverses_entry_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(reverses_entry_id,15,1) = '7' AND substr(reverses_entry_id,20,1) IN ('8','9','a','b'))),
    CHECK(transaction_id IS NULL OR (length(transaction_id) = 36 AND substr(transaction_id,9,1) = '-' AND substr(transaction_id,14,1) = '-' AND substr(transaction_id,19,1) = '-' AND substr(transaction_id,24,1) = '-' AND length(replace(transaction_id,'-','')) = 32 AND replace(transaction_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(transaction_id,15,1) = '7' AND substr(transaction_id,20,1) IN ('8','9','a','b'))),
    CHECK(writer_device_id IS NULL OR (length(writer_device_id) = 36 AND substr(writer_device_id,9,1) = '-' AND substr(writer_device_id,14,1) = '-' AND substr(writer_device_id,19,1) = '-' AND substr(writer_device_id,24,1) = '-' AND length(replace(writer_device_id,'-','')) = 32 AND replace(writer_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(writer_device_id,15,1) = '7' AND substr(writer_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK((amount_unit IN ('ug','uL') AND amount_scale=0) OR (amount_unit IN ('IU','click') AND amount_scale=6)),
    CHECK(movement<>'opening' OR amount_value>0),
    CHECK(movement NOT IN ('dose','priming','waste') OR amount_value<0),
    CHECK((movement='reversal')=(reverses_entry_id IS NOT NULL)),
    CHECK(updated_at=created_at),
    UNIQUE(account_id, reverses_entry_id)
) STRICT;
CREATE INDEX inventory_ledger_account_live ON inventory_ledger(account_id, deleted_at);
CREATE INDEX inventory_ledger_vial_id_fk ON inventory_ledger(account_id, vial_id);
CREATE INDEX inventory_ledger_compound_id_fk ON inventory_ledger(account_id, compound_id);
CREATE INDEX inventory_ledger_dose_revision_id_fk ON inventory_ledger(account_id, dose_revision_id);
CREATE INDEX inventory_ledger_reverses_entry_id_fk ON inventory_ledger(account_id, reverses_entry_id);
CREATE INDEX inventory_ledger_writer_device_id_fk ON inventory_ledger(account_id, writer_device_id);
CREATE INDEX inventory_ledger_local_day ON inventory_ledger(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- User-managed body-map zones, side, route tags and avoid-zone notes.
CREATE TABLE injection_sites (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    body_region TEXT NOT NULL,
    side TEXT CHECK(side IN ('left','right','midline')),
    surface TEXT NOT NULL CHECK(surface IN ('front','back')),
    route_tag TEXT CHECK(route_tag IN ('SC','IM','other')),
    avoid INTEGER NOT NULL DEFAULT 0 CHECK(avoid IN (0,1)),
    notes TEXT,
    map_x REAL CHECK(map_x BETWEEN 0 AND 1),
    map_y REAL CHECK(map_y BETWEEN 0 AND 1),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX injection_sites_account_live ON injection_sites(account_id, deleted_at);

-- Symptom severity/onset and optional dose relationship; descriptive log only.
CREATE TABLE symptom_logs (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    name TEXT NOT NULL,
    severity INTEGER NOT NULL CHECK(severity BETWEEN 1 AND 5),
    dose_log_id TEXT,
    ended_at INTEGER,
    notes TEXT,
    user_red_flag_ack_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, dose_log_id) REFERENCES dose_logs(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(dose_log_id IS NULL OR (length(dose_log_id) = 36 AND substr(dose_log_id,9,1) = '-' AND substr(dose_log_id,14,1) = '-' AND substr(dose_log_id,19,1) = '-' AND substr(dose_log_id,24,1) = '-' AND length(replace(dose_log_id,'-','')) = 32 AND replace(dose_log_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(dose_log_id,15,1) = '7' AND substr(dose_log_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(ended_at IS NULL OR ended_at>=occurred_at)
) STRICT;
CREATE INDEX symptom_logs_account_live ON symptom_logs(account_id, deleted_at);
CREATE INDEX symptom_logs_dose_log_id_fk ON symptom_logs(account_id, dose_log_id);
CREATE INDEX symptom_logs_local_day ON symptom_logs(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Many-to-many symptom/protocol association.
CREATE TABLE symptom_protocols (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    symptom_id TEXT NOT NULL,
    protocol_id TEXT NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, symptom_id) REFERENCES symptom_logs(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, protocol_id) REFERENCES protocols(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(symptom_id IS NULL OR (length(symptom_id) = 36 AND substr(symptom_id,9,1) = '-' AND substr(symptom_id,14,1) = '-' AND substr(symptom_id,19,1) = '-' AND substr(symptom_id,24,1) = '-' AND length(replace(symptom_id,'-','')) = 32 AND replace(symptom_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(symptom_id,15,1) = '7' AND substr(symptom_id,20,1) IN ('8','9','a','b'))),
    CHECK(protocol_id IS NULL OR (length(protocol_id) = 36 AND substr(protocol_id,9,1) = '-' AND substr(protocol_id,14,1) = '-' AND substr(protocol_id,19,1) = '-' AND substr(protocol_id,24,1) = '-' AND length(replace(protocol_id,'-','')) = 32 AND replace(protocol_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(protocol_id,15,1) = '7' AND substr(protocol_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, symptom_id, protocol_id)
) STRICT;
CREATE INDEX symptom_protocols_account_live ON symptom_protocols(account_id, deleted_at);
CREATE INDEX symptom_protocols_symptom_id_fk ON symptom_protocols(account_id, symptom_id);
CREATE INDEX symptom_protocols_protocol_id_fk ON symptom_protocols(account_id, protocol_id);

-- User-confirmed syringe/pen calibration; no assumed activity-to-mass equivalence.
CREATE TABLE syringes (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('syringe','pen','other')),
    capacity_ul INTEGER CHECK(capacity_ul>0),
    units_per_ml_coefficient INTEGER CHECK(units_per_ml_coefficient>0),
    units_per_ml_scale INTEGER CHECK(units_per_ml_scale BETWEEN 0 AND 6),
    per_click_value INTEGER CHECK(per_click_value>0),
    per_click_unit TEXT CHECK(per_click_unit IN ('ug','uL','IU')),
    per_click_scale INTEGER,
    label_confirmation_at INTEGER NOT NULL,
    citation_or_label TEXT NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(kind<>'syringe' OR (capacity_ul IS NOT NULL AND units_per_ml_coefficient IS NOT NULL AND units_per_ml_scale IS NOT NULL)),
    CHECK(kind<>'pen' OR (per_click_value IS NOT NULL AND per_click_unit IS NOT NULL AND per_click_scale IS NOT NULL AND ((per_click_unit IN ('ug','uL') AND per_click_scale=0) OR (per_click_unit='IU' AND per_click_scale=6))))
) STRICT;
CREATE INDEX syringes_account_live ON syringes(account_id, deleted_at);

-- User-saved math inputs linked to one vial; calculation is rerun rather than storing authoritative advice.
CREATE TABLE calculator_presets (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    amount_value INTEGER NOT NULL CHECK(amount_value>0),
    amount_unit TEXT NOT NULL CHECK(amount_unit IN ('ug','uL','IU','click')),
    amount_scale INTEGER NOT NULL,
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    vial_id TEXT NOT NULL,
    syringe_id TEXT,
    compound_id TEXT,
    diluent_ul INTEGER CHECK(diluent_ul>0),
    final_solution_ul INTEGER NOT NULL CHECK(final_solution_ul>0),
    volume_basis TEXT NOT NULL CHECK(volume_basis IN ('label_final_volume','label_confirms_added_equals_final')),
    volume_label_evidence TEXT NOT NULL CHECK(length(volume_label_evidence)>0),
    method_version TEXT NOT NULL,
    label_verified_at INTEGER NOT NULL,
    notes TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, vial_id) REFERENCES vials(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, syringe_id) REFERENCES syringes(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, compound_id) REFERENCES compounds(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(vial_id IS NULL OR (length(vial_id) = 36 AND substr(vial_id,9,1) = '-' AND substr(vial_id,14,1) = '-' AND substr(vial_id,19,1) = '-' AND substr(vial_id,24,1) = '-' AND length(replace(vial_id,'-','')) = 32 AND replace(vial_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(vial_id,15,1) = '7' AND substr(vial_id,20,1) IN ('8','9','a','b'))),
    CHECK(syringe_id IS NULL OR (length(syringe_id) = 36 AND substr(syringe_id,9,1) = '-' AND substr(syringe_id,14,1) = '-' AND substr(syringe_id,19,1) = '-' AND substr(syringe_id,24,1) = '-' AND length(replace(syringe_id,'-','')) = 32 AND replace(syringe_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(syringe_id,15,1) = '7' AND substr(syringe_id,20,1) IN ('8','9','a','b'))),
    CHECK(compound_id IS NULL OR (length(compound_id) = 36 AND substr(compound_id,9,1) = '-' AND substr(compound_id,14,1) = '-' AND substr(compound_id,19,1) = '-' AND substr(compound_id,24,1) = '-' AND length(replace(compound_id,'-','')) = 32 AND replace(compound_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(compound_id,15,1) = '7' AND substr(compound_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK((amount_unit IN ('ug','uL') AND amount_scale=0) OR (amount_unit IN ('IU','click') AND amount_scale=6))
) STRICT;
CREATE INDEX calculator_presets_account_live ON calculator_presets(account_id, deleted_at);
CREATE INDEX calculator_presets_vial_id_fk ON calculator_presets(account_id, vial_id);
CREATE INDEX calculator_presets_syringe_id_fk ON calculator_presets(account_id, syringe_id);
CREATE INDEX calculator_presets_compound_id_fk ON calculator_presets(account_id, compound_id);

-- Separately consented private Stack export; never included implicitly in a core export.
CREATE TABLE export_jobs (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    format TEXT NOT NULL CHECK(format IN ('json','csv','bundle')),
    status TEXT NOT NULL CHECK(status IN ('pending','writing','complete','failed','expired')),
    output_locator TEXT,
    sha256 TEXT,
    row_count INTEGER CHECK(row_count>=0),
    expires_at INTEGER,
    consent_id TEXT NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, consent_id) REFERENCES consents(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(consent_id IS NULL OR (length(consent_id) = 36 AND substr(consent_id,9,1) = '-' AND substr(consent_id,14,1) = '-' AND substr(consent_id,19,1) = '-' AND substr(consent_id,24,1) = '-' AND length(replace(consent_id,'-','')) = 32 AND replace(consent_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(consent_id,15,1) = '7' AND substr(consent_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX export_jobs_account_live ON export_jobs(account_id, deleted_at);
CREATE INDEX export_jobs_consent_id_fk ON export_jobs(account_id, consent_id);

-- Rebuildable deterministic insight facts with exact input provenance for the Why sheet.
CREATE TABLE cached_insights (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    metric_key TEXT NOT NULL,
    template_key TEXT NOT NULL,
    method_version TEXT NOT NULL,
    window_start TEXT NOT NULL,
    window_end TEXT NOT NULL,
    sample_count INTEGER NOT NULL CHECK(sample_count>=0),
    coverage REAL NOT NULL CHECK(coverage BETWEEN 0 AND 1),
    slope REAL,
    delta REAL,
    noise_mad REAL CHECK(noise_mad>=0),
    gate_passed INTEGER NOT NULL CHECK(gate_passed IN (0,1)),
    input_digest TEXT NOT NULL,
    input_refs_json TEXT NOT NULL CHECK(json_valid(input_refs_json)),
    rendered_text TEXT NOT NULL,
    computed_at INTEGER NOT NULL,
    expires_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX cached_insights_account_live ON cached_insights(account_id, deleted_at);

-- Private transaction-scoped remote-apply suppression; must reset before commit.
CREATE TABLE sync_context (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    mode TEXT NOT NULL DEFAULT 'local' CHECK(mode IN ('local','remote_apply')),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id)
) STRICT;
CREATE INDEX sync_context_account_live ON sync_context(account_id, deleted_at);
CREATE TRIGGER accounts_no_hard_delete BEFORE DELETE ON accounts BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER accounts_identity_immutable BEFORE UPDATE ON accounts WHEN NEW.id<>OLD.id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER accounts_outbox_insert AFTER INSERT ON accounts
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.id,'accounts',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'external_subject',NEW.external_subject,'auth_provider',NEW.auth_provider,'age_verified_at',NEW.age_verified_at,'region',NEW.region,'sync_enabled',NEW.sync_enabled,'deletion_requested_at',NEW.deletion_requested_at,'deletion_due_at',NEW.deletion_due_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER accounts_outbox_update AFTER UPDATE ON accounts
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.id,'accounts',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'external_subject',NEW.external_subject,'auth_provider',NEW.auth_provider,'age_verified_at',NEW.age_verified_at,'region',NEW.region,'sync_enabled',NEW.sync_enabled,'deletion_requested_at',NEW.deletion_requested_at,'deletion_due_at',NEW.deletion_due_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER devices_no_hard_delete BEFORE DELETE ON devices BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER devices_identity_immutable BEFORE UPDATE ON devices WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER devices_outbox_insert AFTER INSERT ON devices
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'devices',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'label',NEW.label,'platform',NEW.platform,'last_seen_at',NEW.last_seen_at,'retired_at',NEW.retired_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER devices_outbox_update AFTER UPDATE ON devices
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'devices',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'label',NEW.label,'platform',NEW.platform,'last_seen_at',NEW.last_seen_at,'retired_at',NEW.retired_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER settings_no_hard_delete BEFORE DELETE ON settings BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER settings_identity_immutable BEFORE UPDATE ON settings WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER settings_outbox_insert AFTER INSERT ON settings
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'settings',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'language',NEW.language,'locale',NEW.locale,'week_start',NEW.week_start,'theme',NEW.theme,'quiet_start_minute',NEW.quiet_start_minute,'quiet_end_minute',NEW.quiet_end_minute,'notifications_enabled',NEW.notifications_enabled,'reduce_motion',NEW.reduce_motion,'module_opt_in_at',NEW.module_opt_in_at,'disclaimer_version',NEW.disclaimer_version,'discreet_mode',NEW.discreet_mode,'biometric_lock',NEW.biometric_lock,'app_switcher_blur',NEW.app_switcher_blur,'region_gate_version',NEW.region_gate_version,'region_gate_checked_at',NEW.region_gate_checked_at,'module_disabled_at',NEW.module_disabled_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER settings_outbox_update AFTER UPDATE ON settings
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'settings',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'language',NEW.language,'locale',NEW.locale,'week_start',NEW.week_start,'theme',NEW.theme,'quiet_start_minute',NEW.quiet_start_minute,'quiet_end_minute',NEW.quiet_end_minute,'notifications_enabled',NEW.notifications_enabled,'reduce_motion',NEW.reduce_motion,'module_opt_in_at',NEW.module_opt_in_at,'disclaimer_version',NEW.disclaimer_version,'discreet_mode',NEW.discreet_mode,'biometric_lock',NEW.biometric_lock,'app_switcher_blur',NEW.app_switcher_blur,'region_gate_version',NEW.region_gate_version,'region_gate_checked_at',NEW.region_gate_checked_at,'module_disabled_at',NEW.module_disabled_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER consents_no_hard_delete BEFORE DELETE ON consents BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER consents_no_replace BEFORE INSERT ON consents WHEN EXISTS(SELECT 1 FROM consents WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Immutable revision ID already exists'); END;
CREATE TRIGGER consents_append_only BEFORE UPDATE ON consents BEGIN SELECT RAISE(ABORT,'Append a revision instead of editing immutable history'); END;
CREATE TRIGGER consents_outbox_insert AFTER INSERT ON consents
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'consents',NEW.id,NEW.id,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'scope',NEW.scope,'policy_version',NEW.policy_version,'action',NEW.action,'expires_at',NEW.expires_at,'acknowledgement_text',NEW.acknowledgement_text,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER sync_outbox_no_hard_delete BEFORE DELETE ON sync_outbox BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER sync_outbox_identity_immutable BEFORE UPDATE ON sync_outbox WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER sync_cursors_no_hard_delete BEFORE DELETE ON sync_cursors BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER sync_cursors_identity_immutable BEFORE UPDATE ON sync_cursors WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER sync_conflicts_no_hard_delete BEFORE DELETE ON sync_conflicts BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER sync_conflicts_identity_immutable BEFORE UPDATE ON sync_conflicts WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER attachments_no_hard_delete BEFORE DELETE ON attachments BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER attachments_identity_immutable BEFORE UPDATE ON attachments WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER attachments_outbox_insert AFTER INSERT ON attachments
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'attachments',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'owner_table',NEW.owner_table,'owner_id',NEW.owner_id,'local_locator',NEW.local_locator,'remote_object_key',NEW.remote_object_key,'media_type',NEW.media_type,'byte_count',NEW.byte_count,'sha256',NEW.sha256,'width_px',NEW.width_px,'height_px',NEW.height_px,'duration_ms',NEW.duration_ms,'pose',NEW.pose,'sort_order',NEW.sort_order,'metadata_stripped',NEW.metadata_stripped,'biometric_required',NEW.biometric_required,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER attachments_outbox_update AFTER UPDATE ON attachments
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'attachments',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'owner_table',NEW.owner_table,'owner_id',NEW.owner_id,'local_locator',NEW.local_locator,'remote_object_key',NEW.remote_object_key,'media_type',NEW.media_type,'byte_count',NEW.byte_count,'sha256',NEW.sha256,'width_px',NEW.width_px,'height_px',NEW.height_px,'duration_ms',NEW.duration_ms,'pose',NEW.pose,'sort_order',NEW.sort_order,'metadata_stripped',NEW.metadata_stripped,'biometric_required',NEW.biometric_required,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER series_registry_no_hard_delete BEFORE DELETE ON series_registry BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER series_registry_identity_immutable BEFORE UPDATE ON series_registry WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER series_registry_outbox_insert AFTER INSERT ON series_registry
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'series_registry',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'metric_key',NEW.metric_key,'domain',NEW.domain,'unit',NEW.unit,'kind',NEW.kind,'aggregation',NEW.aggregation,'value_storage',NEW.value_storage,'color_token',NEW.color_token,'source_query_key',NEW.source_query_key,'method_version',NEW.method_version,'is_estimate',NEW.is_estimate,'priority',NEW.priority,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER series_registry_outbox_update AFTER UPDATE ON series_registry
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'series_registry',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'metric_key',NEW.metric_key,'domain',NEW.domain,'unit',NEW.unit,'kind',NEW.kind,'aggregation',NEW.aggregation,'value_storage',NEW.value_storage,'color_token',NEW.color_token,'source_query_key',NEW.source_query_key,'method_version',NEW.method_version,'is_estimate',NEW.is_estimate,'priority',NEW.priority,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER event_registry_no_hard_delete BEFORE DELETE ON event_registry BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER event_registry_identity_immutable BEFORE UPDATE ON event_registry WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER event_registry_outbox_insert AFTER INSERT ON event_registry
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'event_registry',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'event_key',NEW.event_key,'domain',NEW.domain,'label_key',NEW.label_key,'shape_token',NEW.shape_token,'color_token',NEW.color_token,'source_query_key',NEW.source_query_key,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER event_registry_outbox_update AFTER UPDATE ON event_registry
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'event_registry',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'event_key',NEW.event_key,'domain',NEW.domain,'label_key',NEW.label_key,'shape_token',NEW.shape_token,'color_token',NEW.color_token,'source_query_key',NEW.source_query_key,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER events_no_hard_delete BEFORE DELETE ON events BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER events_identity_immutable BEFORE UPDATE ON events WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER events_outbox_insert AFTER INSERT ON events
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'events',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'event_type_id',NEW.event_type_id,'owner_table',NEW.owner_table,'owner_id',NEW.owner_id,'title',NEW.title,'notes',NEW.notes,'end_at',NEW.end_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER events_outbox_update AFTER UPDATE ON events
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'events',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'event_type_id',NEW.event_type_id,'owner_table',NEW.owner_table,'owner_id',NEW.owner_id,'title',NEW.title,'notes',NEW.notes,'end_at',NEW.end_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER daily_rollups_no_hard_delete BEFORE DELETE ON daily_rollups BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER daily_rollups_identity_immutable BEFORE UPDATE ON daily_rollups WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER chart_preferences_no_hard_delete BEFORE DELETE ON chart_preferences BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER chart_preferences_identity_immutable BEFORE UPDATE ON chart_preferences WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER chart_preferences_outbox_insert AFTER INSERT ON chart_preferences
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'chart_preferences',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'chart_key',NEW.chart_key,'range_key',NEW.range_key,'from_date',NEW.from_date,'to_date',NEW.to_date,'comparison_enabled',NEW.comparison_enabled,'trend',NEW.trend,'show_absolute_values',NEW.show_absolute_values,'marker_keys_json',NEW.marker_keys_json,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER chart_preferences_outbox_update AFTER UPDATE ON chart_preferences
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'chart_preferences',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'chart_key',NEW.chart_key,'range_key',NEW.range_key,'from_date',NEW.from_date,'to_date',NEW.to_date,'comparison_enabled',NEW.comparison_enabled,'trend',NEW.trend,'show_absolute_values',NEW.show_absolute_values,'marker_keys_json',NEW.marker_keys_json,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER notification_jobs_no_hard_delete BEFORE DELETE ON notification_jobs BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER notification_jobs_identity_immutable BEFORE UPDATE ON notification_jobs WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER compounds_no_hard_delete BEFORE DELETE ON compounds BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER compounds_identity_immutable BEFORE UPDATE ON compounds WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER compounds_outbox_insert AFTER INSERT ON compounds
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'compounds',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'aliases',NEW.aliases,'class_label',NEW.class_label,'permitted_routes',NEW.permitted_routes,'dosage_form',NEW.dosage_form,'default_dimension',NEW.default_dimension,'notes',NEW.notes,'storage_label_text',NEW.storage_label_text,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER compounds_outbox_update AFTER UPDATE ON compounds
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'compounds',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'aliases',NEW.aliases,'class_label',NEW.class_label,'permitted_routes',NEW.permitted_routes,'dosage_form',NEW.dosage_form,'default_dimension',NEW.default_dimension,'notes',NEW.notes,'storage_label_text',NEW.storage_label_text,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER compound_references_no_hard_delete BEFORE DELETE ON compound_references BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER compound_references_identity_immutable BEFORE UPDATE ON compound_references WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER compound_references_outbox_insert AFTER INSERT ON compound_references
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'compound_references',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'compound_id',NEW.compound_id,'fact_kind',NEW.fact_kind,'value_text',NEW.value_text,'unit',NEW.unit,'region',NEW.region,'citation_url',NEW.citation_url,'citation_date',NEW.citation_date,'reviewed_at',NEW.reviewed_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER compound_references_outbox_update AFTER UPDATE ON compound_references
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'compound_references',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'compound_id',NEW.compound_id,'fact_kind',NEW.fact_kind,'value_text',NEW.value_text,'unit',NEW.unit,'region',NEW.region,'citation_url',NEW.citation_url,'citation_date',NEW.citation_date,'reviewed_at',NEW.reviewed_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER protocols_no_hard_delete BEFORE DELETE ON protocols BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER protocols_identity_immutable BEFORE UPDATE ON protocols WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER protocols_outbox_insert AFTER INSERT ON protocols
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'protocols',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'is_template',NEW.is_template,'reminder_group_key',NEW.reminder_group_key,'color_token',NEW.color_token,'current_revision_id',NEW.current_revision_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER protocols_outbox_update AFTER UPDATE ON protocols
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'protocols',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'is_template',NEW.is_template,'reminder_group_key',NEW.reminder_group_key,'color_token',NEW.color_token,'current_revision_id',NEW.current_revision_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER protocol_revisions_no_hard_delete BEFORE DELETE ON protocol_revisions BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER protocol_revisions_no_replace BEFORE INSERT ON protocol_revisions WHEN EXISTS(SELECT 1 FROM protocol_revisions WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Immutable revision ID already exists'); END;
CREATE TRIGGER protocol_revisions_append_only BEFORE UPDATE ON protocol_revisions BEGIN SELECT RAISE(ABORT,'Append a revision instead of editing immutable history'); END;
CREATE TRIGGER protocol_revisions_outbox_insert AFTER INSERT ON protocol_revisions
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'protocol_revisions',NEW.id,NEW.id,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'protocol_id',NEW.protocol_id,'parent_revision_id',NEW.parent_revision_id,'writer_device_id',NEW.writer_device_id,'status',NEW.status,'starts_on',NEW.starts_on,'ends_on',NEW.ends_on,'notes',NEW.notes,'edit_reason',NEW.edit_reason,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER protocol_steps_no_hard_delete BEFORE DELETE ON protocol_steps BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER protocol_steps_no_replace BEFORE INSERT ON protocol_steps WHEN EXISTS(SELECT 1 FROM protocol_steps WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Immutable revision ID already exists'); END;
CREATE TRIGGER protocol_steps_append_only BEFORE UPDATE ON protocol_steps BEGIN SELECT RAISE(ABORT,'Append a revision instead of editing immutable history'); END;
CREATE TRIGGER protocol_steps_outbox_insert AFTER INSERT ON protocol_steps
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'protocol_steps',NEW.id,NEW.id,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'amount_value',NEW.amount_value,'amount_unit',NEW.amount_unit,'amount_scale',NEW.amount_scale,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'protocol_revision_id',NEW.protocol_revision_id,'compound_id',NEW.compound_id,'position',NEW.position,'effective_on',NEW.effective_on,'route',NEW.route,'food_note',NEW.food_note,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER schedule_rules_no_hard_delete BEFORE DELETE ON schedule_rules BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER schedule_rules_no_replace BEFORE INSERT ON schedule_rules WHEN EXISTS(SELECT 1 FROM schedule_rules WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Immutable revision ID already exists'); END;
CREATE TRIGGER schedule_rules_append_only BEFORE UPDATE ON schedule_rules BEGIN SELECT RAISE(ABORT,'Append a revision instead of editing immutable history'); END;
CREATE TRIGGER schedule_rules_outbox_insert AFTER INSERT ON schedule_rules
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'schedule_rules',NEW.id,NEW.id,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'protocol_step_id',NEW.protocol_step_id,'kind',NEW.kind,'rrule',NEW.rrule,'interval_days',NEW.interval_days,'times_per_week',NEW.times_per_week,'weekdays_mask',NEW.weekdays_mask,'on_days',NEW.on_days,'off_days',NEW.off_days,'month_day',NEW.month_day,'anchor_date',NEW.anchor_date,'end_date',NEW.end_date,'tz',NEW.tz,'time_policy',NEW.time_policy,'dst_gap_policy',NEW.dst_gap_policy,'dst_fold_policy',NEW.dst_fold_policy,'late_window_seconds',NEW.late_window_seconds,'paused_at',NEW.paused_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER schedule_times_no_hard_delete BEFORE DELETE ON schedule_times BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER schedule_times_no_replace BEFORE INSERT ON schedule_times WHEN EXISTS(SELECT 1 FROM schedule_times WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Immutable revision ID already exists'); END;
CREATE TRIGGER schedule_times_append_only BEFORE UPDATE ON schedule_times BEGIN SELECT RAISE(ABORT,'Append a revision instead of editing immutable history'); END;
CREATE TRIGGER schedule_times_outbox_insert AFTER INSERT ON schedule_times
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'schedule_times',NEW.id,NEW.id,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'schedule_rule_id',NEW.schedule_rule_id,'hour',NEW.hour,'minute',NEW.minute,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER dose_occurrences_no_hard_delete BEFORE DELETE ON dose_occurrences BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER dose_occurrences_identity_immutable BEFORE UPDATE ON dose_occurrences WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER dose_occurrences_outbox_insert AFTER INSERT ON dose_occurrences
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'dose_occurrences',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'protocol_step_id',NEW.protocol_step_id,'schedule_rule_id',NEW.schedule_rule_id,'occurrence_key',NEW.occurrence_key,'due_at',NEW.due_at,'late_after_at',NEW.late_after_at,'expires_at',NEW.expires_at,'tz',NEW.tz,'local_date',NEW.local_date,'state',NEW.state,'snoozed_until',NEW.snoozed_until,'state_reason',NEW.state_reason,'resolved_dose_id',NEW.resolved_dose_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER dose_occurrences_outbox_update AFTER UPDATE ON dose_occurrences
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'dose_occurrences',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'protocol_step_id',NEW.protocol_step_id,'schedule_rule_id',NEW.schedule_rule_id,'occurrence_key',NEW.occurrence_key,'due_at',NEW.due_at,'late_after_at',NEW.late_after_at,'expires_at',NEW.expires_at,'tz',NEW.tz,'local_date',NEW.local_date,'state',NEW.state,'snoozed_until',NEW.snoozed_until,'state_reason',NEW.state_reason,'resolved_dose_id',NEW.resolved_dose_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER dose_logs_no_hard_delete BEFORE DELETE ON dose_logs BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER dose_logs_identity_immutable BEFORE UPDATE ON dose_logs WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER dose_logs_outbox_insert AFTER INSERT ON dose_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'dose_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'compound_id',NEW.compound_id,'occurrence_id',NEW.occurrence_id,'current_revision_id',NEW.current_revision_id,'duplicate_guard_ack_at',NEW.duplicate_guard_ack_at,'duplicate_guard_reason',NEW.duplicate_guard_reason,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER dose_logs_outbox_update AFTER UPDATE ON dose_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'dose_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'compound_id',NEW.compound_id,'occurrence_id',NEW.occurrence_id,'current_revision_id',NEW.current_revision_id,'duplicate_guard_ack_at',NEW.duplicate_guard_ack_at,'duplicate_guard_reason',NEW.duplicate_guard_reason,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER dose_revisions_no_hard_delete BEFORE DELETE ON dose_revisions BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER dose_revisions_no_replace BEFORE INSERT ON dose_revisions WHEN EXISTS(SELECT 1 FROM dose_revisions WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Immutable revision ID already exists'); END;
CREATE TRIGGER dose_revisions_append_only BEFORE UPDATE ON dose_revisions BEGIN SELECT RAISE(ABORT,'Append a revision instead of editing immutable history'); END;
CREATE TRIGGER dose_revisions_outbox_insert AFTER INSERT ON dose_revisions
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'dose_revisions',NEW.id,NEW.id,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'amount_value',NEW.amount_value,'amount_unit',NEW.amount_unit,'amount_scale',NEW.amount_scale,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'dose_log_id',NEW.dose_log_id,'parent_revision_id',NEW.parent_revision_id,'writer_device_id',NEW.writer_device_id,'action',NEW.action,'route',NEW.route,'vial_id',NEW.vial_id,'site_id',NEW.site_id,'syringe_id',NEW.syringe_id,'draw_volume_ul',NEW.draw_volume_ul,'needle_description',NEW.needle_description,'lot_snapshot',NEW.lot_snapshot,'notes',NEW.notes,'edit_reason',NEW.edit_reason,'energy',NEW.energy,'appetite',NEW.appetite,'mood',NEW.mood,'sleep',NEW.sleep,'pain',NEW.pain,'redness',NEW.redness,'bruise',NEW.bruise,'user_confirmed_at',NEW.user_confirmed_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER vials_no_hard_delete BEFORE DELETE ON vials BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER vials_identity_immutable BEFORE UPDATE ON vials WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER vials_outbox_insert AFTER INSERT ON vials
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'vials',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'label',NEW.label,'form',NEW.form,'lifecycle',NEW.lifecycle,'lot',NEW.lot,'supplier_note',NEW.supplier_note,'price_minor',NEW.price_minor,'currency',NEW.currency,'storage',NEW.storage,'received_at',NEW.received_at,'opened_at',NEW.opened_at,'reconstituted_at',NEW.reconstituted_at,'beyond_use_at',NEW.beyond_use_at,'label_expiry_at',NEW.label_expiry_at,'diluent_ul',NEW.diluent_ul,'final_solution_ul',NEW.final_solution_ul,'volume_basis',NEW.volume_basis,'volume_label_evidence',NEW.volume_label_evidence,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER vials_outbox_update AFTER UPDATE ON vials
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'vials',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'label',NEW.label,'form',NEW.form,'lifecycle',NEW.lifecycle,'lot',NEW.lot,'supplier_note',NEW.supplier_note,'price_minor',NEW.price_minor,'currency',NEW.currency,'storage',NEW.storage,'received_at',NEW.received_at,'opened_at',NEW.opened_at,'reconstituted_at',NEW.reconstituted_at,'beyond_use_at',NEW.beyond_use_at,'label_expiry_at',NEW.label_expiry_at,'diluent_ul',NEW.diluent_ul,'final_solution_ul',NEW.final_solution_ul,'volume_basis',NEW.volume_basis,'volume_label_evidence',NEW.volume_label_evidence,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER vial_components_no_hard_delete BEFORE DELETE ON vial_components BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER vial_components_identity_immutable BEFORE UPDATE ON vial_components WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER vial_components_outbox_insert AFTER INSERT ON vial_components
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'vial_components',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'amount_value',NEW.amount_value,'amount_unit',NEW.amount_unit,'amount_scale',NEW.amount_scale,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'vial_id',NEW.vial_id,'compound_id',NEW.compound_id,'ratio_value',NEW.ratio_value,'ratio_scale',NEW.ratio_scale,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER vial_components_outbox_update AFTER UPDATE ON vial_components
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'vial_components',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'amount_value',NEW.amount_value,'amount_unit',NEW.amount_unit,'amount_scale',NEW.amount_scale,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'vial_id',NEW.vial_id,'compound_id',NEW.compound_id,'ratio_value',NEW.ratio_value,'ratio_scale',NEW.ratio_scale,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER inventory_ledger_no_hard_delete BEFORE DELETE ON inventory_ledger BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER inventory_ledger_no_replace BEFORE INSERT ON inventory_ledger WHEN EXISTS(SELECT 1 FROM inventory_ledger WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Immutable revision ID already exists'); END;
CREATE TRIGGER inventory_ledger_append_only BEFORE UPDATE ON inventory_ledger BEGIN SELECT RAISE(ABORT,'Append a revision instead of editing immutable history'); END;
CREATE TRIGGER inventory_ledger_outbox_insert AFTER INSERT ON inventory_ledger
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'inventory_ledger',NEW.id,NEW.id,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'vial_id',NEW.vial_id,'compound_id',NEW.compound_id,'dose_revision_id',NEW.dose_revision_id,'reverses_entry_id',NEW.reverses_entry_id,'transaction_id',NEW.transaction_id,'movement',NEW.movement,'amount_value',NEW.amount_value,'amount_unit',NEW.amount_unit,'amount_scale',NEW.amount_scale,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'reason',NEW.reason,'writer_device_id',NEW.writer_device_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER injection_sites_no_hard_delete BEFORE DELETE ON injection_sites BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER injection_sites_identity_immutable BEFORE UPDATE ON injection_sites WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER injection_sites_outbox_insert AFTER INSERT ON injection_sites
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'injection_sites',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'body_region',NEW.body_region,'side',NEW.side,'surface',NEW.surface,'route_tag',NEW.route_tag,'avoid',NEW.avoid,'notes',NEW.notes,'map_x',NEW.map_x,'map_y',NEW.map_y,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER injection_sites_outbox_update AFTER UPDATE ON injection_sites
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'injection_sites',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'body_region',NEW.body_region,'side',NEW.side,'surface',NEW.surface,'route_tag',NEW.route_tag,'avoid',NEW.avoid,'notes',NEW.notes,'map_x',NEW.map_x,'map_y',NEW.map_y,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER symptom_logs_no_hard_delete BEFORE DELETE ON symptom_logs BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER symptom_logs_identity_immutable BEFORE UPDATE ON symptom_logs WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER symptom_logs_outbox_insert AFTER INSERT ON symptom_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'symptom_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'name',NEW.name,'severity',NEW.severity,'dose_log_id',NEW.dose_log_id,'ended_at',NEW.ended_at,'notes',NEW.notes,'user_red_flag_ack_at',NEW.user_red_flag_ack_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER symptom_logs_outbox_update AFTER UPDATE ON symptom_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'symptom_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'name',NEW.name,'severity',NEW.severity,'dose_log_id',NEW.dose_log_id,'ended_at',NEW.ended_at,'notes',NEW.notes,'user_red_flag_ack_at',NEW.user_red_flag_ack_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER symptom_protocols_no_hard_delete BEFORE DELETE ON symptom_protocols BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER symptom_protocols_identity_immutable BEFORE UPDATE ON symptom_protocols WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER symptom_protocols_outbox_insert AFTER INSERT ON symptom_protocols
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'symptom_protocols',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'symptom_id',NEW.symptom_id,'protocol_id',NEW.protocol_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER symptom_protocols_outbox_update AFTER UPDATE ON symptom_protocols
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'symptom_protocols',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'symptom_id',NEW.symptom_id,'protocol_id',NEW.protocol_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER syringes_no_hard_delete BEFORE DELETE ON syringes BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER syringes_identity_immutable BEFORE UPDATE ON syringes WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER syringes_outbox_insert AFTER INSERT ON syringes
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'syringes',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'kind',NEW.kind,'capacity_ul',NEW.capacity_ul,'units_per_ml_coefficient',NEW.units_per_ml_coefficient,'units_per_ml_scale',NEW.units_per_ml_scale,'per_click_value',NEW.per_click_value,'per_click_unit',NEW.per_click_unit,'per_click_scale',NEW.per_click_scale,'label_confirmation_at',NEW.label_confirmation_at,'citation_or_label',NEW.citation_or_label,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER syringes_outbox_update AFTER UPDATE ON syringes
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'syringes',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'kind',NEW.kind,'capacity_ul',NEW.capacity_ul,'units_per_ml_coefficient',NEW.units_per_ml_coefficient,'units_per_ml_scale',NEW.units_per_ml_scale,'per_click_value',NEW.per_click_value,'per_click_unit',NEW.per_click_unit,'per_click_scale',NEW.per_click_scale,'label_confirmation_at',NEW.label_confirmation_at,'citation_or_label',NEW.citation_or_label,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER calculator_presets_no_hard_delete BEFORE DELETE ON calculator_presets BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER calculator_presets_identity_immutable BEFORE UPDATE ON calculator_presets WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER calculator_presets_outbox_insert AFTER INSERT ON calculator_presets
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'calculator_presets',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'amount_value',NEW.amount_value,'amount_unit',NEW.amount_unit,'amount_scale',NEW.amount_scale,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'vial_id',NEW.vial_id,'syringe_id',NEW.syringe_id,'compound_id',NEW.compound_id,'diluent_ul',NEW.diluent_ul,'final_solution_ul',NEW.final_solution_ul,'volume_basis',NEW.volume_basis,'volume_label_evidence',NEW.volume_label_evidence,'method_version',NEW.method_version,'label_verified_at',NEW.label_verified_at,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER calculator_presets_outbox_update AFTER UPDATE ON calculator_presets
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'calculator_presets',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'amount_value',NEW.amount_value,'amount_unit',NEW.amount_unit,'amount_scale',NEW.amount_scale,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'vial_id',NEW.vial_id,'syringe_id',NEW.syringe_id,'compound_id',NEW.compound_id,'diluent_ul',NEW.diluent_ul,'final_solution_ul',NEW.final_solution_ul,'volume_basis',NEW.volume_basis,'volume_label_evidence',NEW.volume_label_evidence,'method_version',NEW.method_version,'label_verified_at',NEW.label_verified_at,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER export_jobs_no_hard_delete BEFORE DELETE ON export_jobs BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER export_jobs_identity_immutable BEFORE UPDATE ON export_jobs WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER cached_insights_no_hard_delete BEFORE DELETE ON cached_insights BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER cached_insights_identity_immutable BEFORE UPDATE ON cached_insights WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER sync_context_no_hard_delete BEFORE DELETE ON sync_context BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER sync_context_identity_immutable BEFORE UPDATE ON sync_context WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER dose_revisions_parent_guard BEFORE INSERT ON dose_revisions
WHEN NEW.parent_revision_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dose_revisions p WHERE p.account_id=NEW.account_id AND p.id=NEW.parent_revision_id AND p.dose_log_id=NEW.dose_log_id AND p.logical_clock<NEW.logical_clock)
BEGIN SELECT RAISE(ABORT,'Revision parent must belong to the same record and precede its logical clock'); END;
CREATE TRIGGER dose_logs_head_guard BEFORE UPDATE OF current_revision_id ON dose_logs
WHEN NEW.current_revision_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dose_revisions r WHERE r.account_id=NEW.account_id AND r.id=NEW.current_revision_id AND r.dose_log_id=NEW.id)
BEGIN SELECT RAISE(ABORT,'Revision head belongs to a different record'); END;
CREATE TRIGGER protocol_revisions_parent_guard BEFORE INSERT ON protocol_revisions
WHEN NEW.parent_revision_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM protocol_revisions p WHERE p.account_id=NEW.account_id AND p.id=NEW.parent_revision_id AND p.protocol_id=NEW.protocol_id AND p.logical_clock<NEW.logical_clock)
BEGIN SELECT RAISE(ABORT,'Revision parent must belong to the same record and precede its logical clock'); END;
CREATE TRIGGER protocols_head_guard BEFORE UPDATE OF current_revision_id ON protocols
WHEN NEW.current_revision_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM protocol_revisions r WHERE r.account_id=NEW.account_id AND r.id=NEW.current_revision_id AND r.protocol_id=NEW.id)
BEGIN SELECT RAISE(ABORT,'Revision head belongs to a different record'); END;
CREATE TRIGGER dose_logs_initial_head BEFORE INSERT ON dose_logs WHEN NEW.current_revision_id IS NOT NULL BEGIN SELECT RAISE(ABORT,'Insert identity before selecting an owned revision'); END;
CREATE TRIGGER protocols_initial_head BEFORE INSERT ON protocols WHEN NEW.current_revision_id IS NOT NULL BEGIN SELECT RAISE(ABORT,'Insert identity before selecting an owned revision'); END;
CREATE TRIGGER dose_identity_fields BEFORE UPDATE OF compound_id,occurrence_id ON dose_logs WHEN NEW.compound_id IS NOT OLD.compound_id OR NEW.occurrence_id IS NOT OLD.occurrence_id BEGIN SELECT RAISE(ABORT,'Correct compound or occurrence through a tombstone and replacement log transaction'); END;
CREATE TRIGGER accounts_clock_guard BEFORE UPDATE ON accounts
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER devices_clock_guard BEFORE UPDATE ON devices
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER settings_clock_guard BEFORE UPDATE ON settings
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER attachments_clock_guard BEFORE UPDATE ON attachments
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER series_registry_clock_guard BEFORE UPDATE ON series_registry
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER event_registry_clock_guard BEFORE UPDATE ON event_registry
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER events_clock_guard BEFORE UPDATE ON events
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER chart_preferences_clock_guard BEFORE UPDATE ON chart_preferences
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER compounds_clock_guard BEFORE UPDATE ON compounds
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER compound_references_clock_guard BEFORE UPDATE ON compound_references
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER protocols_clock_guard BEFORE UPDATE ON protocols
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER dose_occurrences_clock_guard BEFORE UPDATE ON dose_occurrences
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER dose_logs_clock_guard BEFORE UPDATE ON dose_logs
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER vials_clock_guard BEFORE UPDATE ON vials
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER vial_components_clock_guard BEFORE UPDATE ON vial_components
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER injection_sites_clock_guard BEFORE UPDATE ON injection_sites
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER symptom_logs_clock_guard BEFORE UPDATE ON symptom_logs
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER symptom_protocols_clock_guard BEFORE UPDATE ON symptom_protocols
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER syringes_clock_guard BEFORE UPDATE ON syringes
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER calculator_presets_clock_guard BEFORE UPDATE ON calculator_presets
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER attachments_owner_insert BEFORE INSERT ON attachments WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compounds' AND EXISTS(SELECT 1 FROM compounds e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compound_references' AND EXISTS(SELECT 1 FROM compound_references e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocols' AND EXISTS(SELECT 1 FROM protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_revisions' AND EXISTS(SELECT 1 FROM protocol_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_steps' AND EXISTS(SELECT 1 FROM protocol_steps e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_rules' AND EXISTS(SELECT 1 FROM schedule_rules e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_times' AND EXISTS(SELECT 1 FROM schedule_times e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_occurrences' AND EXISTS(SELECT 1 FROM dose_occurrences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_logs' AND EXISTS(SELECT 1 FROM dose_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_revisions' AND EXISTS(SELECT 1 FROM dose_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vials' AND EXISTS(SELECT 1 FROM vials e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vial_components' AND EXISTS(SELECT 1 FROM vial_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='inventory_ledger' AND EXISTS(SELECT 1 FROM inventory_ledger e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='injection_sites' AND EXISTS(SELECT 1 FROM injection_sites e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_logs' AND EXISTS(SELECT 1 FROM symptom_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_protocols' AND EXISTS(SELECT 1 FROM symptom_protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='syringes' AND EXISTS(SELECT 1 FROM syringes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='calculator_presets' AND EXISTS(SELECT 1 FROM calculator_presets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER attachments_owner_update BEFORE UPDATE ON attachments WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compounds' AND EXISTS(SELECT 1 FROM compounds e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compound_references' AND EXISTS(SELECT 1 FROM compound_references e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocols' AND EXISTS(SELECT 1 FROM protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_revisions' AND EXISTS(SELECT 1 FROM protocol_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_steps' AND EXISTS(SELECT 1 FROM protocol_steps e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_rules' AND EXISTS(SELECT 1 FROM schedule_rules e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_times' AND EXISTS(SELECT 1 FROM schedule_times e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_occurrences' AND EXISTS(SELECT 1 FROM dose_occurrences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_logs' AND EXISTS(SELECT 1 FROM dose_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_revisions' AND EXISTS(SELECT 1 FROM dose_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vials' AND EXISTS(SELECT 1 FROM vials e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vial_components' AND EXISTS(SELECT 1 FROM vial_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='inventory_ledger' AND EXISTS(SELECT 1 FROM inventory_ledger e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='injection_sites' AND EXISTS(SELECT 1 FROM injection_sites e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_logs' AND EXISTS(SELECT 1 FROM symptom_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_protocols' AND EXISTS(SELECT 1 FROM symptom_protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='syringes' AND EXISTS(SELECT 1 FROM syringes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='calculator_presets' AND EXISTS(SELECT 1 FROM calculator_presets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER events_owner_insert BEFORE INSERT ON events WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compounds' AND EXISTS(SELECT 1 FROM compounds e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compound_references' AND EXISTS(SELECT 1 FROM compound_references e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocols' AND EXISTS(SELECT 1 FROM protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_revisions' AND EXISTS(SELECT 1 FROM protocol_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_steps' AND EXISTS(SELECT 1 FROM protocol_steps e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_rules' AND EXISTS(SELECT 1 FROM schedule_rules e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_times' AND EXISTS(SELECT 1 FROM schedule_times e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_occurrences' AND EXISTS(SELECT 1 FROM dose_occurrences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_logs' AND EXISTS(SELECT 1 FROM dose_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_revisions' AND EXISTS(SELECT 1 FROM dose_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vials' AND EXISTS(SELECT 1 FROM vials e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vial_components' AND EXISTS(SELECT 1 FROM vial_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='inventory_ledger' AND EXISTS(SELECT 1 FROM inventory_ledger e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='injection_sites' AND EXISTS(SELECT 1 FROM injection_sites e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_logs' AND EXISTS(SELECT 1 FROM symptom_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_protocols' AND EXISTS(SELECT 1 FROM symptom_protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='syringes' AND EXISTS(SELECT 1 FROM syringes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='calculator_presets' AND EXISTS(SELECT 1 FROM calculator_presets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER events_owner_update BEFORE UPDATE ON events WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compounds' AND EXISTS(SELECT 1 FROM compounds e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compound_references' AND EXISTS(SELECT 1 FROM compound_references e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocols' AND EXISTS(SELECT 1 FROM protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_revisions' AND EXISTS(SELECT 1 FROM protocol_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_steps' AND EXISTS(SELECT 1 FROM protocol_steps e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_rules' AND EXISTS(SELECT 1 FROM schedule_rules e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_times' AND EXISTS(SELECT 1 FROM schedule_times e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_occurrences' AND EXISTS(SELECT 1 FROM dose_occurrences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_logs' AND EXISTS(SELECT 1 FROM dose_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_revisions' AND EXISTS(SELECT 1 FROM dose_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vials' AND EXISTS(SELECT 1 FROM vials e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vial_components' AND EXISTS(SELECT 1 FROM vial_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='inventory_ledger' AND EXISTS(SELECT 1 FROM inventory_ledger e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='injection_sites' AND EXISTS(SELECT 1 FROM injection_sites e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_logs' AND EXISTS(SELECT 1 FROM symptom_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_protocols' AND EXISTS(SELECT 1 FROM symptom_protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='syringes' AND EXISTS(SELECT 1 FROM syringes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='calculator_presets' AND EXISTS(SELECT 1 FROM calculator_presets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER notification_jobs_owner_insert BEFORE INSERT ON notification_jobs WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compounds' AND EXISTS(SELECT 1 FROM compounds e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compound_references' AND EXISTS(SELECT 1 FROM compound_references e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocols' AND EXISTS(SELECT 1 FROM protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_revisions' AND EXISTS(SELECT 1 FROM protocol_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_steps' AND EXISTS(SELECT 1 FROM protocol_steps e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_rules' AND EXISTS(SELECT 1 FROM schedule_rules e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_times' AND EXISTS(SELECT 1 FROM schedule_times e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_occurrences' AND EXISTS(SELECT 1 FROM dose_occurrences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_logs' AND EXISTS(SELECT 1 FROM dose_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_revisions' AND EXISTS(SELECT 1 FROM dose_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vials' AND EXISTS(SELECT 1 FROM vials e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vial_components' AND EXISTS(SELECT 1 FROM vial_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='inventory_ledger' AND EXISTS(SELECT 1 FROM inventory_ledger e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='injection_sites' AND EXISTS(SELECT 1 FROM injection_sites e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_logs' AND EXISTS(SELECT 1 FROM symptom_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_protocols' AND EXISTS(SELECT 1 FROM symptom_protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='syringes' AND EXISTS(SELECT 1 FROM syringes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='calculator_presets' AND EXISTS(SELECT 1 FROM calculator_presets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER notification_jobs_owner_update BEFORE UPDATE ON notification_jobs WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compounds' AND EXISTS(SELECT 1 FROM compounds e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='compound_references' AND EXISTS(SELECT 1 FROM compound_references e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocols' AND EXISTS(SELECT 1 FROM protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_revisions' AND EXISTS(SELECT 1 FROM protocol_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='protocol_steps' AND EXISTS(SELECT 1 FROM protocol_steps e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_rules' AND EXISTS(SELECT 1 FROM schedule_rules e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='schedule_times' AND EXISTS(SELECT 1 FROM schedule_times e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_occurrences' AND EXISTS(SELECT 1 FROM dose_occurrences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_logs' AND EXISTS(SELECT 1 FROM dose_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='dose_revisions' AND EXISTS(SELECT 1 FROM dose_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vials' AND EXISTS(SELECT 1 FROM vials e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='vial_components' AND EXISTS(SELECT 1 FROM vial_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='inventory_ledger' AND EXISTS(SELECT 1 FROM inventory_ledger e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='injection_sites' AND EXISTS(SELECT 1 FROM injection_sites e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_logs' AND EXISTS(SELECT 1 FROM symptom_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='symptom_protocols' AND EXISTS(SELECT 1 FROM symptom_protocols e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='syringes' AND EXISTS(SELECT 1 FROM syringes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='calculator_presets' AND EXISTS(SELECT 1 FROM calculator_presets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER inventory_reversal_guard BEFORE INSERT ON inventory_ledger
WHEN NEW.reverses_entry_id IS NOT NULL AND NOT EXISTS(
 SELECT 1 FROM inventory_ledger p WHERE p.account_id=NEW.account_id AND p.id=NEW.reverses_entry_id AND p.vial_id=NEW.vial_id
 AND p.compound_id IS NEW.compound_id AND p.amount_unit=NEW.amount_unit AND p.amount_scale=NEW.amount_scale AND p.amount_value=-NEW.amount_value)
BEGIN SELECT RAISE(ABORT,'A reversal must exactly compensate the same inventory dimension'); END;
CREATE VIEW current_doses AS
SELECT r.*,d.compound_id,d.occurrence_id FROM dose_logs d JOIN dose_revisions r ON r.account_id=d.account_id AND r.id=d.current_revision_id AND r.dose_log_id=d.id
WHERE d.deleted_at IS NULL AND r.deleted_at IS NULL AND r.action<>'tombstone';
CREATE VIEW inventory_balances AS
SELECT account_id,vial_id,compound_id,amount_unit,amount_scale,SUM(amount_value) AS remaining_coefficient
FROM inventory_ledger GROUP BY account_id,vial_id,compound_id,amount_unit,amount_scale;
CREATE VIEW stack_dose_daily_raw AS
SELECT account_id,local_date,compound_id,amount_unit,amount_scale,SUM(amount_value) AS dose_coefficient,COUNT(*) AS sample_count
FROM current_doses GROUP BY account_id,local_date,compound_id,amount_unit,amount_scale;
CREATE VIEW stack_adherence_daily_raw AS
SELECT account_id,local_date,COUNT(*) AS expected_count,SUM(CASE WHEN state IN ('taken','late') THEN 1 ELSE 0 END) AS taken_count,
 SUM(CASE WHEN state='skipped' THEN 1 ELSE 0 END) AS skipped_count,SUM(CASE WHEN state='missed' THEN 1 ELSE 0 END) AS missed_count
FROM dose_occurrences WHERE deleted_at IS NULL GROUP BY account_id,local_date;
CREATE VIEW stack_symptom_daily_raw AS
SELECT account_id,local_date,name,COUNT(*) AS sample_count,MAX(severity) AS maximum_severity,AVG(severity) AS mean_severity
FROM symptom_logs WHERE deleted_at IS NULL GROUP BY account_id,local_date,name;
PRAGMA user_version = 1;
COMMIT;
