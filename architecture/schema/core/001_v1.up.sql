-- Caliber Phase 0: core.sqlite v1. No app database is opened by this file.
-- Requires SQLite >= 3.37, JSON1; configure foreign_keys on EVERY connection.
PRAGMA foreign_keys = ON;
PRAGMA recursive_triggers = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;
PRAGMA application_id = 1128352835;
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
    birth_date TEXT,
    height_cm REAL CHECK(height_cm>0 AND height_cm<300),
    entered_height_value TEXT,
    entered_height_unit TEXT,
    bmr_sex TEXT CHECK(bmr_sex IN ('male','female','unspecified')),
    experience TEXT,
    onboarding_completed_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(birth_date IS NULL OR (length(birth_date)=10 AND date(birth_date,'+0 days') IS NOT NULL AND date(birth_date,'+0 days')=birth_date)),
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
    weight_unit TEXT NOT NULL DEFAULT 'kg' CHECK(weight_unit IN ('kg','lb')),
    length_unit TEXT NOT NULL DEFAULT 'cm' CHECK(length_unit IN ('cm','in')),
    energy_unit TEXT NOT NULL DEFAULT 'kcal' CHECK(energy_unit IN ('kcal','kJ')),
    volume_unit TEXT NOT NULL DEFAULT 'mL' CHECK(volume_unit IN ('mL','fl_oz')),
    temperature_unit TEXT NOT NULL DEFAULT 'C' CHECK(temperature_unit IN ('C','F')),
    count_mode TEXT NOT NULL DEFAULT 'fractional' CHECK(count_mode IN ('direct','fractional','hard')),
    e1rm_formula TEXT NOT NULL DEFAULT 'epley',
    rest_compound_seconds INTEGER NOT NULL DEFAULT 150 CHECK(rest_compound_seconds>=0),
    rest_isolation_seconds INTEGER NOT NULL DEFAULT 75 CHECK(rest_isolation_seconds>=0),
    count_both_hands INTEGER NOT NULL DEFAULT 0 CHECK(count_both_hands IN (0,1)),
    train_enabled INTEGER NOT NULL DEFAULT 1 CHECK(train_enabled IN (0,1)),
    fuel_enabled INTEGER NOT NULL DEFAULT 1 CHECK(fuel_enabled IN (0,1)),
    ai_enabled INTEGER NOT NULL DEFAULT 0 CHECK(ai_enabled IN (0,1)),
    hide_numbers INTEGER NOT NULL DEFAULT 0 CHECK(hide_numbers IN (0,1)),
    streaks_opt_in INTEGER NOT NULL DEFAULT 0 CHECK(streaks_opt_in IN (0,1)),
    fasting_opt_in INTEGER NOT NULL DEFAULT 0 CHECK(fasting_opt_in IN (0,1)),
    ed_risk_flag INTEGER NOT NULL DEFAULT 0 CHECK(ed_risk_flag IN (0,1)),
    default_chart_range TEXT NOT NULL DEFAULT '1M',
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
    domain TEXT NOT NULL CHECK(domain IN ('train','fuel','body','platform')),
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
    domain TEXT NOT NULL CHECK(domain IN ('train','fuel','body','platform')),
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

-- Body-map region taxonomy and original/license metadata.
CREATE TABLE muscles (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    code TEXT NOT NULL,
    display_name TEXT NOT NULL,
    parent_id TEXT,
    body_side TEXT CHECK(body_side IN ('front','back','both')),
    svg_region_key TEXT NOT NULL,
    citation TEXT,
    license_key TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, parent_id) REFERENCES muscles(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(parent_id IS NULL OR (length(parent_id) = 36 AND substr(parent_id,9,1) = '-' AND substr(parent_id,14,1) = '-' AND substr(parent_id,19,1) = '-' AND substr(parent_id,24,1) = '-' AND length(replace(parent_id,'-','')) = 32 AND replace(parent_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(parent_id,15,1) = '7' AND substr(parent_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, code)
) STRICT;
CREATE INDEX muscles_account_live ON muscles(account_id, deleted_at);
CREATE INDEX muscles_parent_id_fk ON muscles(account_id, parent_id);

-- Searchable equipment and bar definition; masses are canonical kg.
CREATE TABLE equipment (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    bar_mass_kg REAL CHECK(bar_mass_kg>0),
    entered_value TEXT,
    entered_unit TEXT,
    is_custom INTEGER NOT NULL DEFAULT 0 CHECK(is_custom IN (0,1)),
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
CREATE INDEX equipment_account_live ON equipment(account_id, deleted_at);

-- Gym profile and active plate calculator context.
CREATE TABLE gyms (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    notes TEXT,
    is_active INTEGER NOT NULL DEFAULT 0 CHECK(is_active IN (0,1)),
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
CREATE INDEX gyms_account_live ON gyms(account_id, deleted_at);

-- Integer plate counts per gym; matched pairs and fractional plates remain exact entered values.
CREATE TABLE plate_inventory (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    gym_id TEXT NOT NULL,
    mass_kg REAL NOT NULL CHECK(mass_kg>0 AND mass_kg<1000),
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL CHECK(entered_unit IN ('kg','lb')),
    count INTEGER NOT NULL CHECK(count>=0),
    color_token TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, gym_id) REFERENCES gyms(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(gym_id IS NULL OR (length(gym_id) = 36 AND substr(gym_id,9,1) = '-' AND substr(gym_id,14,1) = '-' AND substr(gym_id,19,1) = '-' AND substr(gym_id,24,1) = '-' AND length(replace(gym_id,'-','')) = 32 AND replace(gym_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(gym_id,15,1) = '7' AND substr(gym_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX plate_inventory_account_live ON plate_inventory(account_id, deleted_at);
CREATE INDEX plate_inventory_gym_id_fk ON plate_inventory(account_id, gym_id);

-- Original/licensed exercise definitions plus private custom records; merge preserves old IDs.
CREATE TABLE exercises (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    movement_pattern TEXT NOT NULL,
    mechanics TEXT NOT NULL CHECK(mechanics IN ('compound','isolation','other')),
    metric_type TEXT NOT NULL CHECK(metric_type IN ('weight_reps','bodyweight_reps','weighted_bodyweight','assisted_bodyweight','reps','duration','weight_duration','distance','distance_duration')),
    unilateral INTEGER NOT NULL DEFAULT 0 CHECK(unilateral IN (0,1)),
    per_side INTEGER NOT NULL DEFAULT 0 CHECK(per_side IN (0,1)),
    is_custom INTEGER NOT NULL DEFAULT 0 CHECK(is_custom IN (0,1)),
    is_favorite INTEGER NOT NULL DEFAULT 0 CHECK(is_favorite IN (0,1)),
    cues TEXT,
    common_mistakes TEXT,
    pinned_note TEXT,
    increment_kg REAL NOT NULL DEFAULT 2.5 CHECK(increment_kg>0),
    entered_increment_value TEXT,
    entered_increment_unit TEXT,
    default_rest_seconds INTEGER CHECK(default_rest_seconds>=0),
    default_bar_id TEXT,
    merged_into_id TEXT,
    license_key TEXT,
    citation TEXT,
    external_key TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, default_bar_id) REFERENCES equipment(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, merged_into_id) REFERENCES exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(default_bar_id IS NULL OR (length(default_bar_id) = 36 AND substr(default_bar_id,9,1) = '-' AND substr(default_bar_id,14,1) = '-' AND substr(default_bar_id,19,1) = '-' AND substr(default_bar_id,24,1) = '-' AND length(replace(default_bar_id,'-','')) = 32 AND replace(default_bar_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(default_bar_id,15,1) = '7' AND substr(default_bar_id,20,1) IN ('8','9','a','b'))),
    CHECK(merged_into_id IS NULL OR (length(merged_into_id) = 36 AND substr(merged_into_id,9,1) = '-' AND substr(merged_into_id,14,1) = '-' AND substr(merged_into_id,19,1) = '-' AND substr(merged_into_id,24,1) = '-' AND length(replace(merged_into_id,'-','')) = 32 AND replace(merged_into_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(merged_into_id,15,1) = '7' AND substr(merged_into_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(merged_into_id IS NULL OR merged_into_id<>id)
) STRICT;
CREATE INDEX exercises_account_live ON exercises(account_id, deleted_at);
CREATE INDEX exercises_default_bar_id_fk ON exercises(account_id, default_bar_id);
CREATE INDEX exercises_merged_into_id_fk ON exercises(account_id, merged_into_id);

-- Indexed aliases include user names without rewriting historical exercise IDs.
CREATE TABLE exercise_aliases (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    exercise_id TEXT NOT NULL,
    alias TEXT NOT NULL,
    normalized_alias TEXT NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, exercise_id) REFERENCES exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(exercise_id IS NULL OR (length(exercise_id) = 36 AND substr(exercise_id,9,1) = '-' AND substr(exercise_id,14,1) = '-' AND substr(exercise_id,19,1) = '-' AND substr(exercise_id,24,1) = '-' AND length(replace(exercise_id,'-','')) = 32 AND replace(exercise_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(exercise_id,15,1) = '7' AND substr(exercise_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, exercise_id, normalized_alias)
) STRICT;
CREATE INDEX exercise_aliases_account_live ON exercise_aliases(account_id, deleted_at);
CREATE INDEX exercise_aliases_exercise_id_fk ON exercise_aliases(account_id, exercise_id);

-- Fractional muscle attribution used by set counting and swap ranking.
CREATE TABLE exercise_muscles (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    exercise_id TEXT NOT NULL,
    muscle_id TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('primary','secondary')),
    contribution REAL NOT NULL CHECK(contribution>0 AND contribution<=1),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, exercise_id) REFERENCES exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, muscle_id) REFERENCES muscles(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(exercise_id IS NULL OR (length(exercise_id) = 36 AND substr(exercise_id,9,1) = '-' AND substr(exercise_id,14,1) = '-' AND substr(exercise_id,19,1) = '-' AND substr(exercise_id,24,1) = '-' AND length(replace(exercise_id,'-','')) = 32 AND replace(exercise_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(exercise_id,15,1) = '7' AND substr(exercise_id,20,1) IN ('8','9','a','b'))),
    CHECK(muscle_id IS NULL OR (length(muscle_id) = 36 AND substr(muscle_id,9,1) = '-' AND substr(muscle_id,14,1) = '-' AND substr(muscle_id,19,1) = '-' AND substr(muscle_id,24,1) = '-' AND length(replace(muscle_id,'-','')) = 32 AND replace(muscle_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(muscle_id,15,1) = '7' AND substr(muscle_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, exercise_id, muscle_id)
) STRICT;
CREATE INDEX exercise_muscles_account_live ON exercise_muscles(account_id, deleted_at);
CREATE INDEX exercise_muscles_exercise_id_fk ON exercise_muscles(account_id, exercise_id);
CREATE INDEX exercise_muscles_muscle_id_fk ON exercise_muscles(account_id, muscle_id);

-- Equipment requirements and optional per-gym setup notes.
CREATE TABLE exercise_equipment (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    exercise_id TEXT NOT NULL,
    equipment_id TEXT NOT NULL,
    gym_id TEXT,
    setup_note TEXT,
    available INTEGER NOT NULL DEFAULT 1 CHECK(available IN (0,1)),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, exercise_id) REFERENCES exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, equipment_id) REFERENCES equipment(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, gym_id) REFERENCES gyms(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(exercise_id IS NULL OR (length(exercise_id) = 36 AND substr(exercise_id,9,1) = '-' AND substr(exercise_id,14,1) = '-' AND substr(exercise_id,19,1) = '-' AND substr(exercise_id,24,1) = '-' AND length(replace(exercise_id,'-','')) = 32 AND replace(exercise_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(exercise_id,15,1) = '7' AND substr(exercise_id,20,1) IN ('8','9','a','b'))),
    CHECK(equipment_id IS NULL OR (length(equipment_id) = 36 AND substr(equipment_id,9,1) = '-' AND substr(equipment_id,14,1) = '-' AND substr(equipment_id,19,1) = '-' AND substr(equipment_id,24,1) = '-' AND length(replace(equipment_id,'-','')) = 32 AND replace(equipment_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(equipment_id,15,1) = '7' AND substr(equipment_id,20,1) IN ('8','9','a','b'))),
    CHECK(gym_id IS NULL OR (length(gym_id) = 36 AND substr(gym_id,9,1) = '-' AND substr(gym_id,14,1) = '-' AND substr(gym_id,19,1) = '-' AND substr(gym_id,24,1) = '-' AND length(replace(gym_id,'-','')) = 32 AND replace(gym_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(gym_id,15,1) = '7' AND substr(gym_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX exercise_equipment_account_live ON exercise_equipment(account_id, deleted_at);
CREATE INDEX exercise_equipment_exercise_id_fk ON exercise_equipment(account_id, exercise_id);
CREATE INDEX exercise_equipment_equipment_id_fk ON exercise_equipment(account_id, equipment_id);
CREATE INDEX exercise_equipment_gym_id_fk ON exercise_equipment(account_id, gym_id);

-- User-defined set labels and independent volume/hard-set/PR inclusion switches.
CREATE TABLE set_types (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    glyph TEXT NOT NULL,
    color_token TEXT NOT NULL,
    counts_volume INTEGER NOT NULL CHECK(counts_volume IN (0,1)),
    counts_hard_sets INTEGER NOT NULL CHECK(counts_hard_sets IN (0,1)),
    counts_pr INTEGER NOT NULL CHECK(counts_pr IN (0,1)),
    default_rest_seconds INTEGER CHECK(default_rest_seconds>=0),
    is_warmup INTEGER NOT NULL DEFAULT 0 CHECK(is_warmup IN (0,1)),
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
    CHECK(is_warmup=0 OR (counts_volume=0 AND counts_hard_sets=0 AND counts_pr=0))
) STRICT;
CREATE INDEX set_types_account_live ON set_types(account_id, deleted_at);

-- Routine organization without deleting archived history.
CREATE TABLE routine_folders (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
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
CREATE INDEX routine_folders_account_live ON routine_folders(account_id, deleted_at);

-- Reusable routine definition; program position can use these routine days before P1 programming.
CREATE TABLE routines (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    folder_id TEXT,
    notes TEXT,
    archived_at INTEGER,
    share_format_version INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, folder_id) REFERENCES routine_folders(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(folder_id IS NULL OR (length(folder_id) = 36 AND substr(folder_id,9,1) = '-' AND substr(folder_id,14,1) = '-' AND substr(folder_id,19,1) = '-' AND substr(folder_id,24,1) = '-' AND length(replace(folder_id,'-','')) = 32 AND replace(folder_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(folder_id,15,1) = '7' AND substr(folder_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX routines_account_live ON routines(account_id, deleted_at);
CREATE INDEX routines_folder_id_fk ON routines(account_id, folder_id);

-- Ordered routine steps, superset/circuit groups and per-exercise defaults.
CREATE TABLE routine_exercises (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    routine_id TEXT NOT NULL,
    exercise_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    group_key TEXT,
    group_kind TEXT CHECK(group_kind IN ('superset','giant_set','circuit')),
    rest_after_round INTEGER NOT NULL DEFAULT 1 CHECK(rest_after_round IN (0,1)),
    notes TEXT,
    warmup_template_name TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, routine_id) REFERENCES routines(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, exercise_id) REFERENCES exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(routine_id IS NULL OR (length(routine_id) = 36 AND substr(routine_id,9,1) = '-' AND substr(routine_id,14,1) = '-' AND substr(routine_id,19,1) = '-' AND substr(routine_id,24,1) = '-' AND length(replace(routine_id,'-','')) = 32 AND replace(routine_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(routine_id,15,1) = '7' AND substr(routine_id,20,1) IN ('8','9','a','b'))),
    CHECK(exercise_id IS NULL OR (length(exercise_id) = 36 AND substr(exercise_id,9,1) = '-' AND substr(exercise_id,14,1) = '-' AND substr(exercise_id,19,1) = '-' AND substr(exercise_id,24,1) = '-' AND length(replace(exercise_id,'-','')) = 32 AND replace(exercise_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(exercise_id,15,1) = '7' AND substr(exercise_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX routine_exercises_account_live ON routine_exercises(account_id, deleted_at);
CREATE INDEX routine_exercises_routine_id_fk ON routine_exercises(account_id, routine_id);
CREATE INDEX routine_exercises_exercise_id_fk ON routine_exercises(account_id, exercise_id);

-- Editable target sets and warm-up ramps, expressed without programme prose.
CREATE TABLE routine_sets (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    routine_exercise_id TEXT NOT NULL,
    set_type_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    reps_min INTEGER CHECK(reps_min>=0),
    reps_max INTEGER CHECK(reps_max>=reps_min),
    target_load_kg REAL CHECK(target_load_kg>=0),
    entered_value TEXT,
    entered_unit TEXT,
    percent_top_load REAL CHECK(percent_top_load BETWEEN 0 AND 1),
    target_rpe REAL CHECK(target_rpe BETWEEN 1 AND 10),
    target_rir REAL CHECK(target_rir BETWEEN 0 AND 10),
    rest_seconds INTEGER CHECK(rest_seconds>=0),
    tempo TEXT,
    duration_seconds REAL CHECK(duration_seconds>=0),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, routine_exercise_id) REFERENCES routine_exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, set_type_id) REFERENCES set_types(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(routine_exercise_id IS NULL OR (length(routine_exercise_id) = 36 AND substr(routine_exercise_id,9,1) = '-' AND substr(routine_exercise_id,14,1) = '-' AND substr(routine_exercise_id,19,1) = '-' AND substr(routine_exercise_id,24,1) = '-' AND length(replace(routine_exercise_id,'-','')) = 32 AND replace(routine_exercise_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(routine_exercise_id,15,1) = '7' AND substr(routine_exercise_id,20,1) IN ('8','9','a','b'))),
    CHECK(set_type_id IS NULL OR (length(set_type_id) = 36 AND substr(set_type_id,9,1) = '-' AND substr(set_type_id,14,1) = '-' AND substr(set_type_id,19,1) = '-' AND substr(set_type_id,24,1) = '-' AND length(replace(set_type_id,'-','')) = 32 AND replace(set_type_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(set_type_id,15,1) = '7' AND substr(set_type_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(target_rpe IS NULL OR target_rir IS NULL)
) STRICT;
CREATE INDEX routine_sets_account_live ON routine_sets(account_id, deleted_at);
CREATE INDEX routine_sets_routine_exercise_id_fk ON routine_sets(account_id, routine_exercise_id);
CREATE INDEX routine_sets_set_type_id_fk ON routine_sets(account_id, set_type_id);

-- Calendar plan, rest days, RRULE, missed handling and automatic programme position.
CREATE TABLE training_schedule (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    routine_id TEXT,
    schedule_name TEXT NOT NULL,
    rrule TEXT,
    tz TEXT NOT NULL,
    anchor_date TEXT NOT NULL,
    local_time TEXT,
    is_rest_day INTEGER NOT NULL DEFAULT 0 CHECK(is_rest_day IN (0,1)),
    missed_policy TEXT NOT NULL CHECK(missed_policy IN ('shift','skip')),
    program_position INTEGER NOT NULL DEFAULT 0 CHECK(program_position>=0),
    next_local_date TEXT,
    reminder_minutes INTEGER CHECK(reminder_minutes>=0),
    paused_at INTEGER,
    program_day_id TEXT,
    program_id TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, routine_id) REFERENCES routines(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, program_day_id) REFERENCES program_days(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, program_id) REFERENCES programs(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(routine_id IS NULL OR (length(routine_id) = 36 AND substr(routine_id,9,1) = '-' AND substr(routine_id,14,1) = '-' AND substr(routine_id,19,1) = '-' AND substr(routine_id,24,1) = '-' AND length(replace(routine_id,'-','')) = 32 AND replace(routine_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(routine_id,15,1) = '7' AND substr(routine_id,20,1) IN ('8','9','a','b'))),
    CHECK(program_day_id IS NULL OR (length(program_day_id) = 36 AND substr(program_day_id,9,1) = '-' AND substr(program_day_id,14,1) = '-' AND substr(program_day_id,19,1) = '-' AND substr(program_day_id,24,1) = '-' AND length(replace(program_day_id,'-','')) = 32 AND replace(program_day_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(program_day_id,15,1) = '7' AND substr(program_day_id,20,1) IN ('8','9','a','b'))),
    CHECK(program_id IS NULL OR (length(program_id) = 36 AND substr(program_id,9,1) = '-' AND substr(program_id,14,1) = '-' AND substr(program_id,19,1) = '-' AND substr(program_id,24,1) = '-' AND length(replace(program_id,'-','')) = 32 AND replace(program_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(program_id,15,1) = '7' AND substr(program_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(anchor_date IS NULL OR (length(anchor_date)=10 AND date(anchor_date,'+0 days') IS NOT NULL AND date(anchor_date,'+0 days')=anchor_date)),
    CHECK(next_local_date IS NULL OR (length(next_local_date)=10 AND date(next_local_date,'+0 days') IS NOT NULL AND date(next_local_date,'+0 days')=next_local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX training_schedule_account_live ON training_schedule(account_id, deleted_at);
CREATE INDEX training_schedule_routine_id_fk ON training_schedule(account_id, routine_id);
CREATE INDEX training_schedule_program_day_id_fk ON training_schedule(account_id, program_day_id);
CREATE INDEX training_schedule_program_id_fk ON training_schedule(account_id, program_id);

-- Durable resumable session identity and subjective finish summary.
CREATE TABLE workouts (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    routine_id TEXT,
    gym_id TEXT,
    repeated_workout_id TEXT,
    status TEXT NOT NULL CHECK(status IN ('active','finished','abandoned')),
    ended_at INTEGER,
    paused_seconds INTEGER NOT NULL DEFAULT 0 CHECK(paused_seconds>=0),
    bodyweight_kg REAL CHECK(bodyweight_kg>0),
    bodyweight_log_id TEXT,
    notes TEXT,
    soreness INTEGER CHECK(soreness BETWEEN 1 AND 5),
    energy INTEGER CHECK(energy BETWEEN 1 AND 5),
    mood INTEGER CHECK(mood BETWEEN 1 AND 5),
    current_exercise_position INTEGER NOT NULL DEFAULT 0,
    current_round INTEGER NOT NULL DEFAULT 0,
    start_origin TEXT NOT NULL DEFAULT 'empty' CHECK(start_origin IN ('empty','routine','program','history','ai')),
    program_day_id TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, routine_id) REFERENCES routines(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, gym_id) REFERENCES gyms(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, repeated_workout_id) REFERENCES workouts(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, bodyweight_log_id) REFERENCES weigh_ins(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, program_day_id) REFERENCES program_days(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(routine_id IS NULL OR (length(routine_id) = 36 AND substr(routine_id,9,1) = '-' AND substr(routine_id,14,1) = '-' AND substr(routine_id,19,1) = '-' AND substr(routine_id,24,1) = '-' AND length(replace(routine_id,'-','')) = 32 AND replace(routine_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(routine_id,15,1) = '7' AND substr(routine_id,20,1) IN ('8','9','a','b'))),
    CHECK(gym_id IS NULL OR (length(gym_id) = 36 AND substr(gym_id,9,1) = '-' AND substr(gym_id,14,1) = '-' AND substr(gym_id,19,1) = '-' AND substr(gym_id,24,1) = '-' AND length(replace(gym_id,'-','')) = 32 AND replace(gym_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(gym_id,15,1) = '7' AND substr(gym_id,20,1) IN ('8','9','a','b'))),
    CHECK(repeated_workout_id IS NULL OR (length(repeated_workout_id) = 36 AND substr(repeated_workout_id,9,1) = '-' AND substr(repeated_workout_id,14,1) = '-' AND substr(repeated_workout_id,19,1) = '-' AND substr(repeated_workout_id,24,1) = '-' AND length(replace(repeated_workout_id,'-','')) = 32 AND replace(repeated_workout_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(repeated_workout_id,15,1) = '7' AND substr(repeated_workout_id,20,1) IN ('8','9','a','b'))),
    CHECK(bodyweight_log_id IS NULL OR (length(bodyweight_log_id) = 36 AND substr(bodyweight_log_id,9,1) = '-' AND substr(bodyweight_log_id,14,1) = '-' AND substr(bodyweight_log_id,19,1) = '-' AND substr(bodyweight_log_id,24,1) = '-' AND length(replace(bodyweight_log_id,'-','')) = 32 AND replace(bodyweight_log_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(bodyweight_log_id,15,1) = '7' AND substr(bodyweight_log_id,20,1) IN ('8','9','a','b'))),
    CHECK(program_day_id IS NULL OR (length(program_day_id) = 36 AND substr(program_day_id,9,1) = '-' AND substr(program_day_id,14,1) = '-' AND substr(program_day_id,19,1) = '-' AND substr(program_day_id,24,1) = '-' AND length(replace(program_day_id,'-','')) = 32 AND replace(program_day_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(program_day_id,15,1) = '7' AND substr(program_day_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(ended_at IS NULL OR ended_at>=occurred_at)
) STRICT;
CREATE INDEX workouts_account_live ON workouts(account_id, deleted_at);
CREATE INDEX workouts_routine_id_fk ON workouts(account_id, routine_id);
CREATE INDEX workouts_gym_id_fk ON workouts(account_id, gym_id);
CREATE INDEX workouts_repeated_workout_id_fk ON workouts(account_id, repeated_workout_id);
CREATE INDEX workouts_bodyweight_log_id_fk ON workouts(account_id, bodyweight_log_id);
CREATE INDEX workouts_program_day_id_fk ON workouts(account_id, program_day_id);
CREATE INDEX workouts_local_day ON workouts(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Session exercise ordering and grouping; swapping records both original and selected exercise.
CREATE TABLE workout_exercises (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    workout_id TEXT NOT NULL,
    exercise_id TEXT NOT NULL,
    original_exercise_id TEXT,
    position INTEGER NOT NULL,
    group_key TEXT,
    group_kind TEXT CHECK(group_kind IN ('superset','giant_set','circuit')),
    skipped INTEGER NOT NULL DEFAULT 0 CHECK(skipped IN (0,1)),
    notes TEXT,
    equipment_id TEXT,
    rest_after_round INTEGER NOT NULL DEFAULT 1 CHECK(rest_after_round IN (0,1)),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, workout_id) REFERENCES workouts(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, exercise_id) REFERENCES exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, original_exercise_id) REFERENCES exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, equipment_id) REFERENCES equipment(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(workout_id IS NULL OR (length(workout_id) = 36 AND substr(workout_id,9,1) = '-' AND substr(workout_id,14,1) = '-' AND substr(workout_id,19,1) = '-' AND substr(workout_id,24,1) = '-' AND length(replace(workout_id,'-','')) = 32 AND replace(workout_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(workout_id,15,1) = '7' AND substr(workout_id,20,1) IN ('8','9','a','b'))),
    CHECK(exercise_id IS NULL OR (length(exercise_id) = 36 AND substr(exercise_id,9,1) = '-' AND substr(exercise_id,14,1) = '-' AND substr(exercise_id,19,1) = '-' AND substr(exercise_id,24,1) = '-' AND length(replace(exercise_id,'-','')) = 32 AND replace(exercise_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(exercise_id,15,1) = '7' AND substr(exercise_id,20,1) IN ('8','9','a','b'))),
    CHECK(original_exercise_id IS NULL OR (length(original_exercise_id) = 36 AND substr(original_exercise_id,9,1) = '-' AND substr(original_exercise_id,14,1) = '-' AND substr(original_exercise_id,19,1) = '-' AND substr(original_exercise_id,24,1) = '-' AND length(replace(original_exercise_id,'-','')) = 32 AND replace(original_exercise_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(original_exercise_id,15,1) = '7' AND substr(original_exercise_id,20,1) IN ('8','9','a','b'))),
    CHECK(equipment_id IS NULL OR (length(equipment_id) = 36 AND substr(equipment_id,9,1) = '-' AND substr(equipment_id,14,1) = '-' AND substr(equipment_id,19,1) = '-' AND substr(equipment_id,24,1) = '-' AND length(replace(equipment_id,'-','')) = 32 AND replace(equipment_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(equipment_id,15,1) = '7' AND substr(equipment_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX workout_exercises_account_live ON workout_exercises(account_id, deleted_at);
CREATE INDEX workout_exercises_workout_id_fk ON workout_exercises(account_id, workout_id);
CREATE INDEX workout_exercises_exercise_id_fk ON workout_exercises(account_id, exercise_id);
CREATE INDEX workout_exercises_original_exercise_id_fk ON workout_exercises(account_id, original_exercise_id);
CREATE INDEX workout_exercises_equipment_id_fk ON workout_exercises(account_id, equipment_id);

-- Stable set identity; the selected immutable revision is the current projection.
CREATE TABLE workout_sets (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    workout_exercise_id TEXT NOT NULL,
    current_revision_id TEXT,
    position INTEGER NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, workout_exercise_id) REFERENCES workout_exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, current_revision_id) REFERENCES set_revisions(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(workout_exercise_id IS NULL OR (length(workout_exercise_id) = 36 AND substr(workout_exercise_id,9,1) = '-' AND substr(workout_exercise_id,14,1) = '-' AND substr(workout_exercise_id,19,1) = '-' AND substr(workout_exercise_id,24,1) = '-' AND length(replace(workout_exercise_id,'-','')) = 32 AND replace(workout_exercise_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(workout_exercise_id,15,1) = '7' AND substr(workout_exercise_id,20,1) IN ('8','9','a','b'))),
    CHECK(current_revision_id IS NULL OR (length(current_revision_id) = 36 AND substr(current_revision_id,9,1) = '-' AND substr(current_revision_id,14,1) = '-' AND substr(current_revision_id,19,1) = '-' AND substr(current_revision_id,24,1) = '-' AND length(replace(current_revision_id,'-','')) = 32 AND replace(current_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(current_revision_id,15,1) = '7' AND substr(current_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX workout_sets_account_live ON workout_sets(account_id, deleted_at);
CREATE INDEX workout_sets_workout_exercise_id_fk ON workout_sets(account_id, workout_exercise_id);
CREATE INDEX workout_sets_current_revision_id_fk ON workout_sets(account_id, current_revision_id);

-- Append-only complete set snapshots. Branches are preserved rather than silently overwriting.
CREATE TABLE set_revisions (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    set_id TEXT NOT NULL,
    parent_revision_id TEXT,
    writer_device_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('upsert','tombstone','restore')),
    set_type_id TEXT NOT NULL,
    load_kg REAL CHECK(load_kg>=0 AND load_kg<100000),
    entered_load_value TEXT,
    entered_load_unit TEXT,
    reps INTEGER CHECK(reps>=0),
    rpe REAL CHECK(rpe BETWEEN 0 AND 10),
    rir REAL CHECK(rir>=0),
    duration_seconds REAL CHECK(duration_seconds>=0),
    distance_cm REAL CHECK(distance_cm>=0),
    entered_distance_value TEXT,
    entered_distance_unit TEXT,
    bodyweight_kg REAL CHECK(bodyweight_kg>0),
    added_kg REAL CHECK(added_kg>=0),
    assistance_kg REAL CHECK(assistance_kg>=0),
    side TEXT CHECK(side IN ('both','left','right')),
    tempo TEXT,
    rest_actual_seconds REAL CHECK(rest_actual_seconds>=0),
    planned_rest_seconds INTEGER CHECK(planned_rest_seconds>=0),
    percent_1rm REAL CHECK(percent_1rm>=0),
    counts_both_hands INTEGER NOT NULL DEFAULT 0 CHECK(counts_both_hands IN (0,1)),
    completed INTEGER NOT NULL DEFAULT 1 CHECK(completed IN (0,1)),
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
    FOREIGN KEY(account_id, set_id) REFERENCES workout_sets(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, parent_revision_id) REFERENCES set_revisions(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, writer_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, set_type_id) REFERENCES set_types(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(set_id IS NULL OR (length(set_id) = 36 AND substr(set_id,9,1) = '-' AND substr(set_id,14,1) = '-' AND substr(set_id,19,1) = '-' AND substr(set_id,24,1) = '-' AND length(replace(set_id,'-','')) = 32 AND replace(set_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(set_id,15,1) = '7' AND substr(set_id,20,1) IN ('8','9','a','b'))),
    CHECK(parent_revision_id IS NULL OR (length(parent_revision_id) = 36 AND substr(parent_revision_id,9,1) = '-' AND substr(parent_revision_id,14,1) = '-' AND substr(parent_revision_id,19,1) = '-' AND substr(parent_revision_id,24,1) = '-' AND length(replace(parent_revision_id,'-','')) = 32 AND replace(parent_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(parent_revision_id,15,1) = '7' AND substr(parent_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(writer_device_id IS NULL OR (length(writer_device_id) = 36 AND substr(writer_device_id,9,1) = '-' AND substr(writer_device_id,14,1) = '-' AND substr(writer_device_id,19,1) = '-' AND substr(writer_device_id,24,1) = '-' AND length(replace(writer_device_id,'-','')) = 32 AND replace(writer_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(writer_device_id,15,1) = '7' AND substr(writer_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(set_type_id IS NULL OR (length(set_type_id) = 36 AND substr(set_type_id,9,1) = '-' AND substr(set_type_id,14,1) = '-' AND substr(set_type_id,19,1) = '-' AND substr(set_type_id,24,1) = '-' AND length(replace(set_type_id,'-','')) = 32 AND replace(set_type_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(set_type_id,15,1) = '7' AND substr(set_type_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(rpe IS NULL OR rir IS NULL),
    CHECK(assistance_kg IS NULL OR bodyweight_kg IS NULL OR assistance_kg<=bodyweight_kg),
    CHECK(action<>'tombstone' OR deleted_at IS NOT NULL),
    CHECK(updated_at=created_at)
) STRICT;
CREATE INDEX set_revisions_account_live ON set_revisions(account_id, deleted_at);
CREATE INDEX set_revisions_set_id_fk ON set_revisions(account_id, set_id);
CREATE INDEX set_revisions_parent_revision_id_fk ON set_revisions(account_id, parent_revision_id);
CREATE INDEX set_revisions_writer_device_id_fk ON set_revisions(account_id, writer_device_id);
CREATE INDEX set_revisions_set_type_id_fk ON set_revisions(account_id, set_type_id);
CREATE INDEX set_revisions_local_day ON set_revisions(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Persisted timer deadlines survive app termination; notifications schedule from ends_at.
CREATE TABLE rest_timers (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    workout_id TEXT NOT NULL,
    set_id TEXT,
    started_at INTEGER NOT NULL,
    ends_at INTEGER NOT NULL,
    finished_at INTEGER,
    target_seconds INTEGER NOT NULL CHECK(target_seconds>=0),
    actual_seconds REAL CHECK(actual_seconds>=0),
    state TEXT NOT NULL CHECK(state IN ('running','completed','skipped','cancelled')),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, workout_id) REFERENCES workouts(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, set_id) REFERENCES workout_sets(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(workout_id IS NULL OR (length(workout_id) = 36 AND substr(workout_id,9,1) = '-' AND substr(workout_id,14,1) = '-' AND substr(workout_id,19,1) = '-' AND substr(workout_id,24,1) = '-' AND length(replace(workout_id,'-','')) = 32 AND replace(workout_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(workout_id,15,1) = '7' AND substr(workout_id,20,1) IN ('8','9','a','b'))),
    CHECK(set_id IS NULL OR (length(set_id) = 36 AND substr(set_id,9,1) = '-' AND substr(set_id,14,1) = '-' AND substr(set_id,19,1) = '-' AND substr(set_id,24,1) = '-' AND length(replace(set_id,'-','')) = 32 AND replace(set_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(set_id,15,1) = '7' AND substr(set_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(ends_at>=started_at)
) STRICT;
CREATE INDEX rest_timers_account_live ON rest_timers(account_id, deleted_at);
CREATE INDEX rest_timers_workout_id_fk ON rest_timers(account_id, workout_id);
CREATE INDEX rest_timers_set_id_fk ON rest_timers(account_id, set_id);

-- Rebuildable records linked to the exact set revision and documented calculation method.
CREATE TABLE pr_records (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    exercise_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    set_revision_id TEXT,
    record_kind TEXT NOT NULL CHECK(record_kind IN ('weight','e1rm','set_volume','session_volume','rep_record','hold','pace')),
    rep_threshold INTEGER CHECK(rep_threshold BETWEEN 1 AND 12),
    value REAL NOT NULL CHECK(value>=0),
    unit TEXT NOT NULL,
    formula TEXT,
    confidence TEXT,
    computed_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, exercise_id) REFERENCES exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, workout_id) REFERENCES workouts(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, set_revision_id) REFERENCES set_revisions(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(exercise_id IS NULL OR (length(exercise_id) = 36 AND substr(exercise_id,9,1) = '-' AND substr(exercise_id,14,1) = '-' AND substr(exercise_id,19,1) = '-' AND substr(exercise_id,24,1) = '-' AND length(replace(exercise_id,'-','')) = 32 AND replace(exercise_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(exercise_id,15,1) = '7' AND substr(exercise_id,20,1) IN ('8','9','a','b'))),
    CHECK(workout_id IS NULL OR (length(workout_id) = 36 AND substr(workout_id,9,1) = '-' AND substr(workout_id,14,1) = '-' AND substr(workout_id,19,1) = '-' AND substr(workout_id,24,1) = '-' AND length(replace(workout_id,'-','')) = 32 AND replace(workout_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(workout_id,15,1) = '7' AND substr(workout_id,20,1) IN ('8','9','a','b'))),
    CHECK(set_revision_id IS NULL OR (length(set_revision_id) = 36 AND substr(set_revision_id,9,1) = '-' AND substr(set_revision_id,14,1) = '-' AND substr(set_revision_id,19,1) = '-' AND substr(set_revision_id,24,1) = '-' AND length(replace(set_revision_id,'-','')) = 32 AND replace(set_revision_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(set_revision_id,15,1) = '7' AND substr(set_revision_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX pr_records_account_live ON pr_records(account_id, deleted_at);
CREATE INDEX pr_records_exercise_id_fk ON pr_records(account_id, exercise_id);
CREATE INDEX pr_records_workout_id_fk ON pr_records(account_id, workout_id);
CREATE INDEX pr_records_set_revision_id_fk ON pr_records(account_id, set_revision_id);
CREATE INDEX pr_records_local_day ON pr_records(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- User-set weekly neutral target bands, not clinical recommendations.
CREATE TABLE muscle_targets (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    muscle_id TEXT NOT NULL,
    valid_from TEXT NOT NULL,
    min_sets REAL NOT NULL CHECK(min_sets>=0),
    max_sets REAL NOT NULL CHECK(max_sets>=min_sets),
    mev REAL,
    mav REAL,
    mrv REAL,
    method_label TEXT NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, muscle_id) REFERENCES muscles(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(muscle_id IS NULL OR (length(muscle_id) = 36 AND substr(muscle_id,9,1) = '-' AND substr(muscle_id,14,1) = '-' AND substr(muscle_id,19,1) = '-' AND substr(muscle_id,24,1) = '-' AND length(replace(muscle_id,'-','')) = 32 AND replace(muscle_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(muscle_id,15,1) = '7' AND substr(muscle_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(valid_from IS NULL OR (length(valid_from)=10 AND date(valid_from,'+0 days') IS NOT NULL AND date(valid_from,'+0 days')=valid_from)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX muscle_targets_account_live ON muscle_targets(account_id, deleted_at);
CREATE INDEX muscle_targets_muscle_id_fk ON muscle_targets(account_id, muscle_id);

-- Dataset licensing, attribution, provenance and freshness.
CREATE TABLE food_sources (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    source_kind TEXT NOT NULL CHECK(source_kind IN ('usda','off','licensed','restaurant','label','user')),
    license_identifier TEXT NOT NULL,
    attribution TEXT NOT NULL,
    terms_url TEXT,
    version TEXT,
    verified_at INTEGER,
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
CREATE INDEX food_sources_account_live ON food_sources(account_id, deleted_at);

-- Preserves the current restaurant library identity during shadow copy.
CREATE TABLE restaurants (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    citation TEXT,
    verified_at INTEGER,
    is_custom INTEGER NOT NULL DEFAULT 0 CHECK(is_custom IN (0,1)),
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
CREATE INDEX restaurants_account_live ON restaurants(account_id, deleted_at);

-- Canonical per-100g food definitions; private corrections link to the original food.
CREATE TABLE foods (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    brand TEXT,
    source_id TEXT NOT NULL,
    source_external_key TEXT,
    barcode TEXT,
    quality_rank INTEGER NOT NULL CHECK(quality_rank BETWEEN 0 AND 3),
    density_g_per_ml REAL CHECK(density_g_per_ml>0),
    restaurant_id TEXT,
    menu_category TEXT,
    corrected_from_id TEXT,
    correction_reason TEXT,
    error_report_status TEXT,
    is_favorite INTEGER NOT NULL DEFAULT 0 CHECK(is_favorite IN (0,1)),
    is_custom INTEGER NOT NULL DEFAULT 0 CHECK(is_custom IN (0,1)),
    kind TEXT NOT NULL DEFAULT 'food' CHECK(kind IN ('food','recipe','builder','menu_item','supplement')),
    notes TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, source_id) REFERENCES food_sources(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, restaurant_id) REFERENCES restaurants(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, corrected_from_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(source_id IS NULL OR (length(source_id) = 36 AND substr(source_id,9,1) = '-' AND substr(source_id,14,1) = '-' AND substr(source_id,19,1) = '-' AND substr(source_id,24,1) = '-' AND length(replace(source_id,'-','')) = 32 AND replace(source_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(source_id,15,1) = '7' AND substr(source_id,20,1) IN ('8','9','a','b'))),
    CHECK(restaurant_id IS NULL OR (length(restaurant_id) = 36 AND substr(restaurant_id,9,1) = '-' AND substr(restaurant_id,14,1) = '-' AND substr(restaurant_id,19,1) = '-' AND substr(restaurant_id,24,1) = '-' AND length(replace(restaurant_id,'-','')) = 32 AND replace(restaurant_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(restaurant_id,15,1) = '7' AND substr(restaurant_id,20,1) IN ('8','9','a','b'))),
    CHECK(corrected_from_id IS NULL OR (length(corrected_from_id) = 36 AND substr(corrected_from_id,9,1) = '-' AND substr(corrected_from_id,14,1) = '-' AND substr(corrected_from_id,19,1) = '-' AND substr(corrected_from_id,24,1) = '-' AND length(replace(corrected_from_id,'-','')) = 32 AND replace(corrected_from_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(corrected_from_id,15,1) = '7' AND substr(corrected_from_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX foods_account_live ON foods(account_id, deleted_at);
CREATE INDEX foods_source_id_fk ON foods(account_id, source_id);
CREATE INDEX foods_restaurant_id_fk ON foods(account_id, restaurant_id);
CREATE INDEX foods_corrected_from_id_fk ON foods(account_id, corrected_from_id);

-- Household measures, default serving and exact input display units.
CREATE TABLE food_servings (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    food_id TEXT NOT NULL,
    label TEXT NOT NULL,
    grams REAL NOT NULL CHECK(grams>0),
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 0 CHECK(is_default IN (0,1)),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, food_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(food_id IS NULL OR (length(food_id) = 36 AND substr(food_id,9,1) = '-' AND substr(food_id,14,1) = '-' AND substr(food_id,19,1) = '-' AND substr(food_id,24,1) = '-' AND length(replace(food_id,'-','')) = 32 AND replace(food_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(food_id,15,1) = '7' AND substr(food_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX food_servings_account_live ON food_servings(account_id, deleted_at);
CREATE INDEX food_servings_food_id_fk ON food_servings(account_id, food_id);

-- Versioned nutrient identifiers with their actual canonical dimension and reference source.
CREATE TABLE nutrients (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    canonical_unit TEXT NOT NULL CHECK(canonical_unit IN ('g','kcal','mL','IU')),
    citation TEXT,
    reference_version TEXT,
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
    UNIQUE(account_id, code)
) STRICT;
CREATE INDEX nutrients_account_live ON nutrients(account_id, deleted_at);

-- Per-100g values with source units retained; missing is not zero.
CREATE TABLE food_nutrients (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    food_id TEXT NOT NULL,
    nutrient_id TEXT NOT NULL,
    value REAL NOT NULL CHECK(value>=0 AND value<1e12),
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    precision_digits INTEGER CHECK(precision_digits BETWEEN 0 AND 12),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, food_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, nutrient_id) REFERENCES nutrients(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(food_id IS NULL OR (length(food_id) = 36 AND substr(food_id,9,1) = '-' AND substr(food_id,14,1) = '-' AND substr(food_id,19,1) = '-' AND substr(food_id,24,1) = '-' AND length(replace(food_id,'-','')) = 32 AND replace(food_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(food_id,15,1) = '7' AND substr(food_id,20,1) IN ('8','9','a','b'))),
    CHECK(nutrient_id IS NULL OR (length(nutrient_id) = 36 AND substr(nutrient_id,9,1) = '-' AND substr(nutrient_id,14,1) = '-' AND substr(nutrient_id,19,1) = '-' AND substr(nutrient_id,24,1) = '-' AND length(replace(nutrient_id,'-','')) = 32 AND replace(nutrient_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(nutrient_id,15,1) = '7' AND substr(nutrient_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, food_id, nutrient_id)
) STRICT;
CREATE INDEX food_nutrients_account_live ON food_nutrients(account_id, deleted_at);
CREATE INDEX food_nutrients_food_id_fk ON food_nutrients(account_id, food_id);
CREATE INDEX food_nutrients_nutrient_id_fk ON food_nutrients(account_id, nutrient_id);

-- Existing customizable restaurant builder groups; unrelated to dose units.
CREATE TABLE food_component_groups (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    food_id TEXT NOT NULL,
    name TEXT NOT NULL,
    selection_mode TEXT NOT NULL CHECK(selection_mode IN ('single','multiple')),
    required INTEGER NOT NULL CHECK(required IN (0,1)),
    position INTEGER NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, food_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(food_id IS NULL OR (length(food_id) = 36 AND substr(food_id,9,1) = '-' AND substr(food_id,14,1) = '-' AND substr(food_id,19,1) = '-' AND substr(food_id,24,1) = '-' AND length(replace(food_id,'-','')) = 32 AND replace(food_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(food_id,15,1) = '7' AND substr(food_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX food_component_groups_account_live ON food_component_groups(account_id, deleted_at);
CREATE INDEX food_component_groups_food_id_fk ON food_component_groups(account_id, food_id);

-- Restaurant options/modifier references and explicit portion capabilities.
CREATE TABLE food_components (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    parent_food_id TEXT NOT NULL,
    child_food_id TEXT NOT NULL,
    group_id TEXT,
    name TEXT NOT NULL,
    grams REAL NOT NULL CHECK(grams>0),
    is_removal INTEGER NOT NULL DEFAULT 0 CHECK(is_removal IN (0,1)),
    supports_double INTEGER NOT NULL DEFAULT 0 CHECK(supports_double IN (0,1)),
    position INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, parent_food_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, child_food_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, group_id) REFERENCES food_component_groups(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(parent_food_id IS NULL OR (length(parent_food_id) = 36 AND substr(parent_food_id,9,1) = '-' AND substr(parent_food_id,14,1) = '-' AND substr(parent_food_id,19,1) = '-' AND substr(parent_food_id,24,1) = '-' AND length(replace(parent_food_id,'-','')) = 32 AND replace(parent_food_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(parent_food_id,15,1) = '7' AND substr(parent_food_id,20,1) IN ('8','9','a','b'))),
    CHECK(child_food_id IS NULL OR (length(child_food_id) = 36 AND substr(child_food_id,9,1) = '-' AND substr(child_food_id,14,1) = '-' AND substr(child_food_id,19,1) = '-' AND substr(child_food_id,24,1) = '-' AND length(replace(child_food_id,'-','')) = 32 AND replace(child_food_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(child_food_id,15,1) = '7' AND substr(child_food_id,20,1) IN ('8','9','a','b'))),
    CHECK(group_id IS NULL OR (length(group_id) = 36 AND substr(group_id,9,1) = '-' AND substr(group_id,14,1) = '-' AND substr(group_id,19,1) = '-' AND substr(group_id,24,1) = '-' AND length(replace(group_id,'-','')) = 32 AND replace(group_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(group_id,15,1) = '7' AND substr(group_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(parent_food_id<>child_food_id)
) STRICT;
CREATE INDEX food_components_account_live ON food_components(account_id, deleted_at);
CREATE INDEX food_components_parent_food_id_fk ON food_components(account_id, parent_food_id);
CREATE INDEX food_components_child_food_id_fk ON food_components(account_id, child_food_id);
CREATE INDEX food_components_group_id_fk ON food_components(account_id, group_id);

-- Four initial slots plus unlimited private slots and local times.
CREATE TABLE meal_slots (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    position INTEGER NOT NULL,
    default_local_time TEXT,
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
CREATE INDEX meal_slots_account_live ON meal_slots(account_id, deleted_at);

-- Meal-level notes, photos, hunger/mood, planned/eaten state and clone provenance.
CREATE TABLE meal_logs (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    meal_slot_id TEXT NOT NULL,
    state TEXT NOT NULL CHECK(state IN ('planned','eaten')),
    notes TEXT,
    hunger INTEGER CHECK(hunger BETWEEN 1 AND 5),
    mood INTEGER CHECK(mood BETWEEN 1 AND 5),
    copied_from_id TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, meal_slot_id) REFERENCES meal_slots(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, copied_from_id) REFERENCES meal_logs(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(meal_slot_id IS NULL OR (length(meal_slot_id) = 36 AND substr(meal_slot_id,9,1) = '-' AND substr(meal_slot_id,14,1) = '-' AND substr(meal_slot_id,19,1) = '-' AND substr(meal_slot_id,24,1) = '-' AND length(replace(meal_slot_id,'-','')) = 32 AND replace(meal_slot_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(meal_slot_id,15,1) = '7' AND substr(meal_slot_id,20,1) IN ('8','9','a','b'))),
    CHECK(copied_from_id IS NULL OR (length(copied_from_id) = 36 AND substr(copied_from_id,9,1) = '-' AND substr(copied_from_id,14,1) = '-' AND substr(copied_from_id,19,1) = '-' AND substr(copied_from_id,24,1) = '-' AND length(replace(copied_from_id,'-','')) = 32 AND replace(copied_from_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(copied_from_id,15,1) = '7' AND substr(copied_from_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX meal_logs_account_live ON meal_logs(account_id, deleted_at);
CREATE INDEX meal_logs_meal_slot_id_fk ON meal_logs(account_id, meal_slot_id);
CREATE INDEX meal_logs_copied_from_id_fk ON meal_logs(account_id, copied_from_id);
CREATE INDEX meal_logs_local_day ON meal_logs(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Immutable-source nutrition snapshot editable only for this log; preserves exact serving entry.
CREATE TABLE food_logs (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    meal_log_id TEXT NOT NULL,
    food_id TEXT,
    food_name TEXT NOT NULL,
    serving_id TEXT,
    grams REAL NOT NULL CHECK(grams>0),
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    multiplier REAL NOT NULL DEFAULT 1 CHECK(multiplier>0),
    calories_kcal REAL NOT NULL CHECK(calories_kcal>=0),
    protein_g REAL NOT NULL CHECK(protein_g>=0),
    carbs_g REAL NOT NULL CHECK(carbs_g>=0),
    fat_g REAL NOT NULL CHECK(fat_g>=0),
    alcohol_g REAL NOT NULL DEFAULT 0 CHECK(alcohol_g>=0),
    adjusted INTEGER NOT NULL DEFAULT 0 CHECK(adjusted IN (0,1)),
    confirmed_at INTEGER NOT NULL,
    notes TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, meal_log_id) REFERENCES meal_logs(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, food_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, serving_id) REFERENCES food_servings(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(meal_log_id IS NULL OR (length(meal_log_id) = 36 AND substr(meal_log_id,9,1) = '-' AND substr(meal_log_id,14,1) = '-' AND substr(meal_log_id,19,1) = '-' AND substr(meal_log_id,24,1) = '-' AND length(replace(meal_log_id,'-','')) = 32 AND replace(meal_log_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(meal_log_id,15,1) = '7' AND substr(meal_log_id,20,1) IN ('8','9','a','b'))),
    CHECK(food_id IS NULL OR (length(food_id) = 36 AND substr(food_id,9,1) = '-' AND substr(food_id,14,1) = '-' AND substr(food_id,19,1) = '-' AND substr(food_id,24,1) = '-' AND length(replace(food_id,'-','')) = 32 AND replace(food_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(food_id,15,1) = '7' AND substr(food_id,20,1) IN ('8','9','a','b'))),
    CHECK(serving_id IS NULL OR (length(serving_id) = 36 AND substr(serving_id,9,1) = '-' AND substr(serving_id,14,1) = '-' AND substr(serving_id,19,1) = '-' AND substr(serving_id,24,1) = '-' AND length(replace(serving_id,'-','')) = 32 AND replace(serving_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(serving_id,15,1) = '7' AND substr(serving_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX food_logs_account_live ON food_logs(account_id, deleted_at);
CREATE INDEX food_logs_meal_log_id_fk ON food_logs(account_id, meal_log_id);
CREATE INDEX food_logs_food_id_fk ON food_logs(account_id, food_id);
CREATE INDEX food_logs_serving_id_fk ON food_logs(account_id, serving_id);
CREATE INDEX food_logs_local_day ON food_logs(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Micronutrient and supplement snapshots for diary totals independent of future catalog edits.
CREATE TABLE food_log_nutrients (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    food_log_id TEXT NOT NULL,
    nutrient_id TEXT NOT NULL,
    value REAL NOT NULL CHECK(value>=0),
    entered_value TEXT,
    entered_unit TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, food_log_id) REFERENCES food_logs(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, nutrient_id) REFERENCES nutrients(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(food_log_id IS NULL OR (length(food_log_id) = 36 AND substr(food_log_id,9,1) = '-' AND substr(food_log_id,14,1) = '-' AND substr(food_log_id,19,1) = '-' AND substr(food_log_id,24,1) = '-' AND length(replace(food_log_id,'-','')) = 32 AND replace(food_log_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(food_log_id,15,1) = '7' AND substr(food_log_id,20,1) IN ('8','9','a','b'))),
    CHECK(nutrient_id IS NULL OR (length(nutrient_id) = 36 AND substr(nutrient_id,9,1) = '-' AND substr(nutrient_id,14,1) = '-' AND substr(nutrient_id,19,1) = '-' AND substr(nutrient_id,24,1) = '-' AND length(replace(nutrient_id,'-','')) = 32 AND replace(nutrient_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(nutrient_id,15,1) = '7' AND substr(nutrient_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, food_log_id, nutrient_id)
) STRICT;
CREATE INDEX food_log_nutrients_account_live ON food_log_nutrients(account_id, deleted_at);
CREATE INDEX food_log_nutrients_food_log_id_fk ON food_log_nutrients(account_id, food_log_id);
CREATE INDEX food_log_nutrients_nutrient_id_fk ON food_log_nutrients(account_id, nutrient_id);

-- Recipe provenance, portions and explicit raw/cooked mass yield.
CREATE TABLE recipes (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    food_id TEXT NOT NULL,
    name TEXT NOT NULL,
    servings REAL NOT NULL CHECK(servings>0),
    raw_mass_g REAL NOT NULL CHECK(raw_mass_g>0),
    cooked_mass_g REAL NOT NULL CHECK(cooked_mass_g>0),
    yield_factor REAL NOT NULL CHECK(yield_factor>0),
    import_url TEXT,
    instructions TEXT,
    parser_version TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, food_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(food_id IS NULL OR (length(food_id) = 36 AND substr(food_id,9,1) = '-' AND substr(food_id,14,1) = '-' AND substr(food_id,19,1) = '-' AND substr(food_id,24,1) = '-' AND length(replace(food_id,'-','')) = 32 AND replace(food_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(food_id,15,1) = '7' AND substr(food_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(abs(yield_factor-cooked_mass_g/raw_mass_g)<0.000001)
) STRICT;
CREATE INDEX recipes_account_live ON recipes(account_id, deleted_at);
CREATE INDEX recipes_food_id_fk ON recipes(account_id, food_id);

-- Ordered ingredient mass and entered units for deterministic recipe totals.
CREATE TABLE recipe_ingredients (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    recipe_id TEXT NOT NULL,
    food_id TEXT NOT NULL,
    grams REAL NOT NULL CHECK(grams>0),
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    position INTEGER NOT NULL,
    notes TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, recipe_id) REFERENCES recipes(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, food_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(recipe_id IS NULL OR (length(recipe_id) = 36 AND substr(recipe_id,9,1) = '-' AND substr(recipe_id,14,1) = '-' AND substr(recipe_id,19,1) = '-' AND substr(recipe_id,24,1) = '-' AND length(replace(recipe_id,'-','')) = 32 AND replace(recipe_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(recipe_id,15,1) = '7' AND substr(recipe_id,20,1) IN ('8','9','a','b'))),
    CHECK(food_id IS NULL OR (length(food_id) = 36 AND substr(food_id,9,1) = '-' AND substr(food_id,14,1) = '-' AND substr(food_id,19,1) = '-' AND substr(food_id,24,1) = '-' AND length(replace(food_id,'-','')) = 32 AND replace(food_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(food_id,15,1) = '7' AND substr(food_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX recipe_ingredients_account_live ON recipe_ingredients(account_id, deleted_at);
CREATE INDEX recipe_ingredients_recipe_id_fk ON recipe_ingredients(account_id, recipe_id);
CREATE INDEX recipe_ingredients_food_id_fk ON recipe_ingredients(account_id, food_id);

-- Saved meal identity, independent from logs or originals.
CREATE TABLE meal_templates (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    notes TEXT,
    preferred_slot_id TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, preferred_slot_id) REFERENCES meal_slots(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(preferred_slot_id IS NULL OR (length(preferred_slot_id) = 36 AND substr(preferred_slot_id,9,1) = '-' AND substr(preferred_slot_id,14,1) = '-' AND substr(preferred_slot_id,19,1) = '-' AND substr(preferred_slot_id,24,1) = '-' AND length(replace(preferred_slot_id,'-','')) = 32 AND replace(preferred_slot_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(preferred_slot_id,15,1) = '7' AND substr(preferred_slot_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX meal_templates_account_live ON meal_templates(account_id, deleted_at);
CREATE INDEX meal_templates_preferred_slot_id_fk ON meal_templates(account_id, preferred_slot_id);

-- Reusable ordered meal portions.
CREATE TABLE meal_template_items (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    meal_template_id TEXT NOT NULL,
    food_id TEXT NOT NULL,
    grams REAL NOT NULL CHECK(grams>0),
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    position INTEGER NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, meal_template_id) REFERENCES meal_templates(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, food_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(meal_template_id IS NULL OR (length(meal_template_id) = 36 AND substr(meal_template_id,9,1) = '-' AND substr(meal_template_id,14,1) = '-' AND substr(meal_template_id,19,1) = '-' AND substr(meal_template_id,24,1) = '-' AND length(replace(meal_template_id,'-','')) = 32 AND replace(meal_template_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(meal_template_id,15,1) = '7' AND substr(meal_template_id,20,1) IN ('8','9','a','b'))),
    CHECK(food_id IS NULL OR (length(food_id) = 36 AND substr(food_id,9,1) = '-' AND substr(food_id,14,1) = '-' AND substr(food_id,19,1) = '-' AND substr(food_id,24,1) = '-' AND length(replace(food_id,'-','')) = 32 AND replace(food_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(food_id,15,1) = '7' AND substr(food_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX meal_template_items_account_live ON meal_template_items(account_id, deleted_at);
CREATE INDEX meal_template_items_meal_template_id_fk ON meal_template_items(account_id, meal_template_id);
CREATE INDEX meal_template_items_food_id_fk ON meal_template_items(account_id, food_id);

-- Water, caffeine and alcohol quick logs with canonical volume/mass and beverage calories.
CREATE TABLE hydration_logs (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    kind TEXT NOT NULL CHECK(kind IN ('water','caffeine','alcohol')),
    volume_ml REAL CHECK(volume_ml>=0),
    caffeine_g REAL CHECK(caffeine_g>=0),
    alcohol_g REAL CHECK(alcohol_g>=0),
    calories_kcal REAL NOT NULL DEFAULT 0 CHECK(calories_kcal>=0),
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
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
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(volume_ml IS NOT NULL OR caffeine_g IS NOT NULL OR alcohol_g IS NOT NULL)
) STRICT;
CREATE INDEX hydration_logs_account_live ON hydration_logs(account_id, deleted_at);
CREATE INDEX hydration_logs_local_day ON hydration_logs(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Non-peptide supplement log; amounts are food mass and optional nutrients, not injection protocols.
CREATE TABLE supplement_logs (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    food_id TEXT NOT NULL,
    food_log_id TEXT,
    grams REAL NOT NULL CHECK(grams>0),
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    notes TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, food_id) REFERENCES foods(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, food_log_id) REFERENCES food_logs(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(food_id IS NULL OR (length(food_id) = 36 AND substr(food_id,9,1) = '-' AND substr(food_id,14,1) = '-' AND substr(food_id,19,1) = '-' AND substr(food_id,24,1) = '-' AND length(replace(food_id,'-','')) = 32 AND replace(food_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(food_id,15,1) = '7' AND substr(food_id,20,1) IN ('8','9','a','b'))),
    CHECK(food_log_id IS NULL OR (length(food_log_id) = 36 AND substr(food_log_id,9,1) = '-' AND substr(food_log_id,14,1) = '-' AND substr(food_log_id,19,1) = '-' AND substr(food_log_id,24,1) = '-' AND length(replace(food_log_id,'-','')) = 32 AND replace(food_log_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(food_log_id,15,1) = '7' AND substr(food_log_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX supplement_logs_account_live ON supplement_logs(account_id, deleted_at);
CREATE INDEX supplement_logs_food_id_fk ON supplement_logs(account_id, food_id);
CREATE INDEX supplement_logs_food_log_id_fk ON supplement_logs(account_id, food_log_id);
CREATE INDEX supplement_logs_local_day ON supplement_logs(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Immutable explicit acknowledgements; no silent floor overrides.
CREATE TABLE safety_acknowledgements (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    kind TEXT NOT NULL CHECK(kind IN ('clinician_floor_override','risk_resources_shown','risk_review')),
    policy_version TEXT NOT NULL,
    acknowledgement_text TEXT NOT NULL,
    expires_at INTEGER,
    clinician_override_confirmed INTEGER NOT NULL DEFAULT 0 CHECK(clinician_override_confirmed IN (0,1)),
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
CREATE INDEX safety_acknowledgements_account_live ON safety_acknowledgements(account_id, deleted_at);
CREATE INDEX safety_acknowledgements_local_day ON safety_acknowledgements(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Calculated/default target snapshots with safety inputs, BMR method and entered goal rate.
CREATE TABLE nutrition_targets (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    goal_mode TEXT NOT NULL CHECK(goal_mode IN ('cut','maintain','lean_bulk','bulk','recomp','refeed','diet_break')),
    calories_kcal REAL NOT NULL CHECK(calories_kcal>=0),
    protein_g REAL NOT NULL CHECK(protein_g>=0),
    carbs_g REAL NOT NULL CHECK(carbs_g>=0),
    fat_g REAL NOT NULL CHECK(fat_g>=0),
    fiber_g REAL CHECK(fiber_g>=0),
    assessed_bmi REAL CHECK(assessed_bmi>0),
    weekly_loss_fraction REAL NOT NULL DEFAULT 0 CHECK(weekly_loss_fraction BETWEEN 0 AND 0.01),
    safety_floor_kcal REAL NOT NULL CHECK(safety_floor_kcal>=1200),
    clinician_ack_id TEXT,
    method_version TEXT NOT NULL,
    valid_from TEXT NOT NULL,
    valid_until TEXT,
    activity_multiplier REAL CHECK(activity_multiplier>0),
    bmr_kcal REAL CHECK(bmr_kcal>0),
    bmr_method TEXT,
    macro_preset TEXT,
    entered_rate_value TEXT,
    entered_rate_unit TEXT,
    day_type TEXT NOT NULL DEFAULT 'all' CHECK(day_type IN ('all','training','rest')),
    nutrient_id TEXT,
    nutrient_target_value REAL CHECK(nutrient_target_value>=0),
    reference_citation TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, clinician_ack_id) REFERENCES safety_acknowledgements(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, nutrient_id) REFERENCES nutrients(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(clinician_ack_id IS NULL OR (length(clinician_ack_id) = 36 AND substr(clinician_ack_id,9,1) = '-' AND substr(clinician_ack_id,14,1) = '-' AND substr(clinician_ack_id,19,1) = '-' AND substr(clinician_ack_id,24,1) = '-' AND length(replace(clinician_ack_id,'-','')) = 32 AND replace(clinician_ack_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(clinician_ack_id,15,1) = '7' AND substr(clinician_ack_id,20,1) IN ('8','9','a','b'))),
    CHECK(nutrient_id IS NULL OR (length(nutrient_id) = 36 AND substr(nutrient_id,9,1) = '-' AND substr(nutrient_id,14,1) = '-' AND substr(nutrient_id,19,1) = '-' AND substr(nutrient_id,24,1) = '-' AND length(replace(nutrient_id,'-','')) = 32 AND replace(nutrient_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(nutrient_id,15,1) = '7' AND substr(nutrient_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(valid_from IS NULL OR (length(valid_from)=10 AND date(valid_from,'+0 days') IS NOT NULL AND date(valid_from,'+0 days')=valid_from)),
    CHECK(valid_until IS NULL OR (length(valid_until)=10 AND date(valid_until,'+0 days') IS NOT NULL AND date(valid_until,'+0 days')=valid_until)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(calories_kcal>=safety_floor_kcal OR clinician_ack_id IS NOT NULL),
    CHECK((goal_mode<>'cut' AND weekly_loss_fraction=0) OR (assessed_bmi IS NOT NULL AND assessed_bmi>=18.5))
) STRICT;
CREATE INDEX nutrition_targets_account_live ON nutrition_targets(account_id, deleted_at);
CREATE INDEX nutrition_targets_clinician_ack_id_fk ON nutrition_targets(account_id, clinician_ack_id);
CREATE INDEX nutrition_targets_nutrient_id_fk ON nutrition_targets(account_id, nutrient_id);

-- Per-day or weekday targets and weekly flex budget with the same safety gates.
CREATE TABLE target_overrides (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    goal_mode TEXT NOT NULL CHECK(goal_mode IN ('cut','maintain','lean_bulk','bulk','recomp','refeed','diet_break')),
    calories_kcal REAL NOT NULL CHECK(calories_kcal>=0),
    protein_g REAL NOT NULL CHECK(protein_g>=0),
    carbs_g REAL NOT NULL CHECK(carbs_g>=0),
    fat_g REAL NOT NULL CHECK(fat_g>=0),
    fiber_g REAL CHECK(fiber_g>=0),
    assessed_bmi REAL CHECK(assessed_bmi>0),
    weekly_loss_fraction REAL NOT NULL DEFAULT 0 CHECK(weekly_loss_fraction BETWEEN 0 AND 0.01),
    safety_floor_kcal REAL NOT NULL CHECK(safety_floor_kcal>=1200),
    clinician_ack_id TEXT,
    method_version TEXT NOT NULL,
    base_target_id TEXT NOT NULL,
    local_date TEXT,
    weekday INTEGER CHECK(weekday BETWEEN 1 AND 7),
    weekly_budget_kcal REAL CHECK(weekly_budget_kcal>=0),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, base_target_id) REFERENCES nutrition_targets(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, clinician_ack_id) REFERENCES safety_acknowledgements(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(clinician_ack_id IS NULL OR (length(clinician_ack_id) = 36 AND substr(clinician_ack_id,9,1) = '-' AND substr(clinician_ack_id,14,1) = '-' AND substr(clinician_ack_id,19,1) = '-' AND substr(clinician_ack_id,24,1) = '-' AND length(replace(clinician_ack_id,'-','')) = 32 AND replace(clinician_ack_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(clinician_ack_id,15,1) = '7' AND substr(clinician_ack_id,20,1) IN ('8','9','a','b'))),
    CHECK(base_target_id IS NULL OR (length(base_target_id) = 36 AND substr(base_target_id,9,1) = '-' AND substr(base_target_id,14,1) = '-' AND substr(base_target_id,19,1) = '-' AND substr(base_target_id,24,1) = '-' AND length(replace(base_target_id,'-','')) = 32 AND replace(base_target_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(base_target_id,15,1) = '7' AND substr(base_target_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(calories_kcal>=safety_floor_kcal OR clinician_ack_id IS NOT NULL),
    CHECK((goal_mode<>'cut' AND weekly_loss_fraction=0) OR (assessed_bmi IS NOT NULL AND assessed_bmi>=18.5)),
    CHECK((local_date IS NOT NULL)+(weekday IS NOT NULL)=1)
) STRICT;
CREATE INDEX target_overrides_account_live ON target_overrides(account_id, deleted_at);
CREATE INDEX target_overrides_base_target_id_fk ON target_overrides(account_id, base_target_id);
CREATE INDEX target_overrides_clinician_ack_id_fk ON target_overrides(account_id, clinician_ack_id);

-- Cut/bulk/maintenance, refeed and diet-break schedule; no dose references.
CREATE TABLE diet_phases (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('cut','bulk','maintain','recomp','refeed','diet_break')),
    starts_on TEXT NOT NULL,
    ends_on TEXT,
    target_id TEXT,
    notes TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, target_id) REFERENCES nutrition_targets(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(target_id IS NULL OR (length(target_id) = 36 AND substr(target_id,9,1) = '-' AND substr(target_id,14,1) = '-' AND substr(target_id,19,1) = '-' AND substr(target_id,24,1) = '-' AND length(replace(target_id,'-','')) = 32 AND replace(target_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(target_id,15,1) = '7' AND substr(target_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(starts_on IS NULL OR (length(starts_on)=10 AND date(starts_on,'+0 days') IS NOT NULL AND date(starts_on,'+0 days')=starts_on)),
    CHECK(ends_on IS NULL OR (length(ends_on)=10 AND date(ends_on,'+0 days') IS NOT NULL AND date(ends_on,'+0 days')=ends_on)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX diet_phases_account_live ON diet_phases(account_id, deleted_at);
CREATE INDEX diet_phases_target_id_fk ON diet_phases(account_id, target_id);

-- Canonical kg and original entered representation, including Health source identity.
CREATE TABLE weigh_ins (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    weight_kg REAL NOT NULL CHECK(weight_kg>0 AND weight_kg<1000),
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL CHECK(entered_unit IN ('kg','lb')),
    health_external_key TEXT,
    tags TEXT,
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
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX weigh_ins_account_live ON weigh_ins(account_id, deleted_at);
CREATE INDEX weigh_ins_local_day ON weigh_ins(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Named/custom circumference or composition measurement with method and location.
CREATE TABLE measurements (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    kind TEXT NOT NULL CHECK(kind IN ('circumference','body_fat_percent','lean_mass','fat_mass','height')),
    landmark TEXT NOT NULL,
    side TEXT CHECK(side IN ('left','right','both')),
    value REAL NOT NULL CHECK(value>=0),
    canonical_unit TEXT NOT NULL CHECK(canonical_unit IN ('cm','kg','percent')),
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    method TEXT NOT NULL,
    uncertainty REAL CHECK(uncertainty>=0),
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
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK((kind IN ('circumference','height') AND canonical_unit='cm') OR (kind IN ('lean_mass','fat_mass') AND canonical_unit='kg') OR (kind='body_fat_percent' AND canonical_unit='percent' AND value<=100))
) STRICT;
CREATE INDEX measurements_account_live ON measurements(account_id, deleted_at);
CREATE INDEX measurements_local_day ON measurements(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Current progress notes/photos and subjective recovery scores; optional weight linkage.
CREATE TABLE check_ins (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    weigh_in_id TEXT,
    notes TEXT NOT NULL DEFAULT '',
    sleep_quality INTEGER CHECK(sleep_quality BETWEEN 1 AND 5),
    soreness INTEGER CHECK(soreness BETWEEN 1 AND 5),
    stress INTEGER CHECK(stress BETWEEN 1 AND 5),
    motivation INTEGER CHECK(motivation BETWEEN 1 AND 5),
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, weigh_in_id) REFERENCES weigh_ins(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(weigh_in_id IS NULL OR (length(weigh_in_id) = 36 AND substr(weigh_in_id,9,1) = '-' AND substr(weigh_in_id,14,1) = '-' AND substr(weigh_in_id,19,1) = '-' AND substr(weigh_in_id,24,1) = '-' AND length(replace(weigh_in_id,'-','')) = 32 AND replace(weigh_in_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(weigh_in_id,15,1) = '7' AND substr(weigh_in_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX check_ins_account_live ON check_ins(account_id, deleted_at);
CREATE INDEX check_ins_weigh_in_id_fk ON check_ins(account_id, weigh_in_id);
CREATE INDEX check_ins_local_day ON check_ins(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Deduplicated provider observations for weight/steps P0 and recovery P1.
CREATE TABLE health_samples (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    provider TEXT NOT NULL,
    external_key TEXT NOT NULL,
    sample_type TEXT NOT NULL CHECK(sample_type IN ('weight','steps','sleep','hrv','resting_hr','active_energy','body_fat')),
    value REAL NOT NULL,
    unit TEXT NOT NULL,
    end_at INTEGER,
    device_label TEXT,
    provider_modified_at INTEGER,
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
    UNIQUE(account_id, provider, external_key)
) STRICT;
CREATE INDEX health_samples_account_live ON health_samples(account_id, deleted_at);
CREATE INDEX health_samples_local_day ON health_samples(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Per-type incremental Health cursor; saved atomically with samples/deletions.
CREATE TABLE health_anchors (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    provider TEXT NOT NULL,
    sample_type TEXT NOT NULL,
    anchor_blob BLOB NOT NULL,
    last_success_at INTEGER,
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
    UNIQUE(account_id, provider, sample_type)
) STRICT;
CREATE INDEX health_anchors_account_live ON health_anchors(account_id, deleted_at);

-- Cross-domain goal lines and dated targets; core accepts no Stack domain data.
CREATE TABLE goals (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    domain TEXT NOT NULL CHECK(domain IN ('train','fuel','body')),
    metric_key TEXT NOT NULL,
    exercise_id TEXT,
    muscle_id TEXT,
    target_value REAL NOT NULL,
    canonical_unit TEXT NOT NULL,
    entered_value TEXT NOT NULL,
    entered_unit TEXT NOT NULL,
    target_date TEXT,
    starts_on TEXT NOT NULL,
    archived_at INTEGER,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, exercise_id) REFERENCES exercises(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, muscle_id) REFERENCES muscles(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(exercise_id IS NULL OR (length(exercise_id) = 36 AND substr(exercise_id,9,1) = '-' AND substr(exercise_id,14,1) = '-' AND substr(exercise_id,19,1) = '-' AND substr(exercise_id,24,1) = '-' AND length(replace(exercise_id,'-','')) = 32 AND replace(exercise_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(exercise_id,15,1) = '7' AND substr(exercise_id,20,1) IN ('8','9','a','b'))),
    CHECK(muscle_id IS NULL OR (length(muscle_id) = 36 AND substr(muscle_id,9,1) = '-' AND substr(muscle_id,14,1) = '-' AND substr(muscle_id,19,1) = '-' AND substr(muscle_id,24,1) = '-' AND length(replace(muscle_id,'-','')) = 32 AND replace(muscle_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(muscle_id,15,1) = '7' AND substr(muscle_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    CHECK(target_date IS NULL OR (length(target_date)=10 AND date(target_date,'+0 days') IS NOT NULL AND date(target_date,'+0 days')=target_date)),
    CHECK(starts_on IS NULL OR (length(starts_on)=10 AND date(starts_on,'+0 days') IS NOT NULL AND date(starts_on,'+0 days')=starts_on)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE INDEX goals_account_live ON goals(account_id, deleted_at);
CREATE INDEX goals_exercise_id_fk ON goals(account_id, exercise_id);
CREATE INDEX goals_muscle_id_fk ON goals(account_id, muscle_id);

-- Dated private annotations with typed references to core entities only.
CREATE TABLE notes (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128),
    local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date),
    text TEXT NOT NULL,
    owner_table TEXT,
    owner_id TEXT,
    tags TEXT,
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
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK((owner_table IS NULL)=(owner_id IS NULL))
) STRICT;
CREATE INDEX notes_account_live ON notes(account_id, deleted_at);
CREATE INDEX notes_local_day ON notes(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;

-- Dry-run/reconciliation manifest for external formats and non-destructive SwiftData shadow copies.
CREATE TABLE import_batches (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    format TEXT NOT NULL,
    file_digest TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('planned','validated','copied','verified','failed')),
    total_rows INTEGER NOT NULL DEFAULT 0 CHECK(total_rows>=0),
    accepted_rows INTEGER NOT NULL DEFAULT 0 CHECK(accepted_rows>=0),
    rejected_rows INTEGER NOT NULL DEFAULT 0 CHECK(rejected_rows>=0),
    error_report_locator TEXT,
    source_schema_version TEXT,
    validation_digest TEXT,
    completed_at INTEGER,
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
CREATE INDEX import_batches_account_live ON import_batches(account_id, deleted_at);

-- Stable UUIDv4/SwiftData identity to UUIDv7 translation, without changing the source store.
CREATE TABLE legacy_id_map (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    batch_id TEXT NOT NULL,
    source_entity TEXT NOT NULL,
    legacy_identifier TEXT NOT NULL,
    destination_table TEXT NOT NULL,
    destination_id TEXT NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, batch_id) REFERENCES import_batches(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(batch_id IS NULL OR (length(batch_id) = 36 AND substr(batch_id,9,1) = '-' AND substr(batch_id,14,1) = '-' AND substr(batch_id,19,1) = '-' AND substr(batch_id,24,1) = '-' AND length(replace(batch_id,'-','')) = 32 AND replace(batch_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(batch_id,15,1) = '7' AND substr(batch_id,20,1) IN ('8','9','a','b'))),
    CHECK(destination_id IS NULL OR (length(destination_id) = 36 AND substr(destination_id,9,1) = '-' AND substr(destination_id,14,1) = '-' AND substr(destination_id,19,1) = '-' AND substr(destination_id,24,1) = '-' AND length(replace(destination_id,'-','')) = 32 AND replace(destination_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(destination_id,15,1) = '7' AND substr(destination_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, source_entity, legacy_identifier)
) STRICT;
CREATE INDEX legacy_id_map_account_live ON legacy_id_map(account_id, deleted_at);
CREATE INDEX legacy_id_map_batch_id_fk ON legacy_id_map(account_id, batch_id);

-- Private full-fidelity JSON/CSV bundle manifests and deletion-request handoff status.
CREATE TABLE export_jobs (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    format TEXT NOT NULL CHECK(format IN ('json','csv','bundle')),
    status TEXT NOT NULL CHECK(status IN ('pending','writing','complete','failed','expired')),
    output_locator TEXT,
    sha256 TEXT,
    row_count INTEGER CHECK(row_count>=0),
    expires_at INTEGER,
    include_attachments INTEGER NOT NULL DEFAULT 1 CHECK(include_attachments IN (0,1)),
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
CREATE INDEX export_jobs_account_live ON export_jobs(account_id, deleted_at);

-- Program identity needed to start/resume a programme day; generic user-authored structure only.
CREATE TABLE programs (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    name TEXT NOT NULL,
    notes TEXT,
    current_day_position INTEGER NOT NULL DEFAULT 0 CHECK(current_day_position>=0),
    archived_at INTEGER,
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
CREATE INDEX programs_account_live ON programs(account_id, deleted_at);

-- Ordered programme day points to its routine without copying authored programme text.
CREATE TABLE program_days (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    program_id TEXT NOT NULL,
    routine_id TEXT,
    week_number INTEGER NOT NULL CHECK(week_number>0),
    day_number INTEGER NOT NULL CHECK(day_number>0),
    position INTEGER NOT NULL,
    is_rest_day INTEGER NOT NULL DEFAULT 0 CHECK(is_rest_day IN (0,1)),
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at),
    source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai')),
    logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0),
    origin_device_id TEXT,
    UNIQUE(account_id, id),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY(account_id, program_id) REFERENCES programs(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(account_id, routine_id) REFERENCES routines(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(program_id IS NULL OR (length(program_id) = 36 AND substr(program_id,9,1) = '-' AND substr(program_id,14,1) = '-' AND substr(program_id,19,1) = '-' AND substr(program_id,24,1) = '-' AND length(replace(program_id,'-','')) = 32 AND replace(program_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(program_id,15,1) = '7' AND substr(program_id,20,1) IN ('8','9','a','b'))),
    CHECK(routine_id IS NULL OR (length(routine_id) = 36 AND substr(routine_id,9,1) = '-' AND substr(routine_id,14,1) = '-' AND substr(routine_id,19,1) = '-' AND substr(routine_id,24,1) = '-' AND length(replace(routine_id,'-','')) = 32 AND replace(routine_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(routine_id,15,1) = '7' AND substr(routine_id,20,1) IN ('8','9','a','b'))),
    CHECK(origin_device_id IS NULL OR (length(origin_device_id) = 36 AND substr(origin_device_id,9,1) = '-' AND substr(origin_device_id,14,1) = '-' AND substr(origin_device_id,19,1) = '-' AND substr(origin_device_id,24,1) = '-' AND length(replace(origin_device_id,'-','')) = 32 AND replace(origin_device_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(origin_device_id,15,1) = '7' AND substr(origin_device_id,20,1) IN ('8','9','a','b'))),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    UNIQUE(account_id, program_id, position)
) STRICT;
CREATE INDEX program_days_account_live ON program_days(account_id, deleted_at);
CREATE INDEX program_days_program_id_fk ON program_days(account_id, program_id);
CREATE INDEX program_days_routine_id_fk ON program_days(account_id, routine_id);

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

-- Explicit day-completeness status; a food entry alone does not establish a complete day.
CREATE TABLE nutrition_days (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b')),
    account_id TEXT NOT NULL CHECK(length(account_id) = 36 AND substr(account_id,9,1) = '-' AND substr(account_id,14,1) = '-' AND substr(account_id,19,1) = '-' AND substr(account_id,24,1) = '-' AND length(replace(account_id,'-','')) = 32 AND replace(account_id,'-','') NOT GLOB '*[^0-9a-f]*' AND substr(account_id,15,1) = '7' AND substr(account_id,20,1) IN ('8','9','a','b')),
    local_date TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('unknown','partial','complete')),
    confirmed_at INTEGER,
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
    CHECK(local_date IS NULL OR (length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)),
    FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    CHECK(status<>'complete' OR confirmed_at IS NOT NULL),
    UNIQUE(account_id, local_date)
) STRICT;
CREATE INDEX nutrition_days_account_live ON nutrition_days(account_id, deleted_at);

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
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.id,'accounts',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'external_subject',NEW.external_subject,'auth_provider',NEW.auth_provider,'age_verified_at',NEW.age_verified_at,'region',NEW.region,'sync_enabled',NEW.sync_enabled,'deletion_requested_at',NEW.deletion_requested_at,'deletion_due_at',NEW.deletion_due_at,'birth_date',NEW.birth_date,'height_cm',NEW.height_cm,'entered_height_value',NEW.entered_height_value,'entered_height_unit',NEW.entered_height_unit,'bmr_sex',NEW.bmr_sex,'experience',NEW.experience,'onboarding_completed_at',NEW.onboarding_completed_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER accounts_outbox_update AFTER UPDATE ON accounts
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.id,'accounts',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'external_subject',NEW.external_subject,'auth_provider',NEW.auth_provider,'age_verified_at',NEW.age_verified_at,'region',NEW.region,'sync_enabled',NEW.sync_enabled,'deletion_requested_at',NEW.deletion_requested_at,'deletion_due_at',NEW.deletion_due_at,'birth_date',NEW.birth_date,'height_cm',NEW.height_cm,'entered_height_value',NEW.entered_height_value,'entered_height_unit',NEW.entered_height_unit,'bmr_sex',NEW.bmr_sex,'experience',NEW.experience,'onboarding_completed_at',NEW.onboarding_completed_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
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
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'settings',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'language',NEW.language,'locale',NEW.locale,'week_start',NEW.week_start,'theme',NEW.theme,'quiet_start_minute',NEW.quiet_start_minute,'quiet_end_minute',NEW.quiet_end_minute,'notifications_enabled',NEW.notifications_enabled,'reduce_motion',NEW.reduce_motion,'weight_unit',NEW.weight_unit,'length_unit',NEW.length_unit,'energy_unit',NEW.energy_unit,'volume_unit',NEW.volume_unit,'temperature_unit',NEW.temperature_unit,'count_mode',NEW.count_mode,'e1rm_formula',NEW.e1rm_formula,'rest_compound_seconds',NEW.rest_compound_seconds,'rest_isolation_seconds',NEW.rest_isolation_seconds,'count_both_hands',NEW.count_both_hands,'train_enabled',NEW.train_enabled,'fuel_enabled',NEW.fuel_enabled,'ai_enabled',NEW.ai_enabled,'hide_numbers',NEW.hide_numbers,'streaks_opt_in',NEW.streaks_opt_in,'fasting_opt_in',NEW.fasting_opt_in,'ed_risk_flag',NEW.ed_risk_flag,'default_chart_range',NEW.default_chart_range,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER settings_outbox_update AFTER UPDATE ON settings
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'settings',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'language',NEW.language,'locale',NEW.locale,'week_start',NEW.week_start,'theme',NEW.theme,'quiet_start_minute',NEW.quiet_start_minute,'quiet_end_minute',NEW.quiet_end_minute,'notifications_enabled',NEW.notifications_enabled,'reduce_motion',NEW.reduce_motion,'weight_unit',NEW.weight_unit,'length_unit',NEW.length_unit,'energy_unit',NEW.energy_unit,'volume_unit',NEW.volume_unit,'temperature_unit',NEW.temperature_unit,'count_mode',NEW.count_mode,'e1rm_formula',NEW.e1rm_formula,'rest_compound_seconds',NEW.rest_compound_seconds,'rest_isolation_seconds',NEW.rest_isolation_seconds,'count_both_hands',NEW.count_both_hands,'train_enabled',NEW.train_enabled,'fuel_enabled',NEW.fuel_enabled,'ai_enabled',NEW.ai_enabled,'hide_numbers',NEW.hide_numbers,'streaks_opt_in',NEW.streaks_opt_in,'fasting_opt_in',NEW.fasting_opt_in,'ed_risk_flag',NEW.ed_risk_flag,'default_chart_range',NEW.default_chart_range,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
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
CREATE TRIGGER muscles_no_hard_delete BEFORE DELETE ON muscles BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER muscles_identity_immutable BEFORE UPDATE ON muscles WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER muscles_outbox_insert AFTER INSERT ON muscles
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'muscles',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'code',NEW.code,'display_name',NEW.display_name,'parent_id',NEW.parent_id,'body_side',NEW.body_side,'svg_region_key',NEW.svg_region_key,'citation',NEW.citation,'license_key',NEW.license_key,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER muscles_outbox_update AFTER UPDATE ON muscles
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'muscles',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'code',NEW.code,'display_name',NEW.display_name,'parent_id',NEW.parent_id,'body_side',NEW.body_side,'svg_region_key',NEW.svg_region_key,'citation',NEW.citation,'license_key',NEW.license_key,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER equipment_no_hard_delete BEFORE DELETE ON equipment BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER equipment_identity_immutable BEFORE UPDATE ON equipment WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER equipment_outbox_insert AFTER INSERT ON equipment
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'equipment',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'kind',NEW.kind,'bar_mass_kg',NEW.bar_mass_kg,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'is_custom',NEW.is_custom,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER equipment_outbox_update AFTER UPDATE ON equipment
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'equipment',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'kind',NEW.kind,'bar_mass_kg',NEW.bar_mass_kg,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'is_custom',NEW.is_custom,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER gyms_no_hard_delete BEFORE DELETE ON gyms BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER gyms_identity_immutable BEFORE UPDATE ON gyms WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER gyms_outbox_insert AFTER INSERT ON gyms
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'gyms',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'notes',NEW.notes,'is_active',NEW.is_active,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER gyms_outbox_update AFTER UPDATE ON gyms
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'gyms',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'notes',NEW.notes,'is_active',NEW.is_active,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER plate_inventory_no_hard_delete BEFORE DELETE ON plate_inventory BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER plate_inventory_identity_immutable BEFORE UPDATE ON plate_inventory WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER plate_inventory_outbox_insert AFTER INSERT ON plate_inventory
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'plate_inventory',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'gym_id',NEW.gym_id,'mass_kg',NEW.mass_kg,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'count',NEW.count,'color_token',NEW.color_token,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER plate_inventory_outbox_update AFTER UPDATE ON plate_inventory
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'plate_inventory',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'gym_id',NEW.gym_id,'mass_kg',NEW.mass_kg,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'count',NEW.count,'color_token',NEW.color_token,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER exercises_no_hard_delete BEFORE DELETE ON exercises BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER exercises_identity_immutable BEFORE UPDATE ON exercises WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER exercises_outbox_insert AFTER INSERT ON exercises
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'exercises',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'normalized_name',NEW.normalized_name,'movement_pattern',NEW.movement_pattern,'mechanics',NEW.mechanics,'metric_type',NEW.metric_type,'unilateral',NEW.unilateral,'per_side',NEW.per_side,'is_custom',NEW.is_custom,'is_favorite',NEW.is_favorite,'cues',NEW.cues,'common_mistakes',NEW.common_mistakes,'pinned_note',NEW.pinned_note,'increment_kg',NEW.increment_kg,'entered_increment_value',NEW.entered_increment_value,'entered_increment_unit',NEW.entered_increment_unit,'default_rest_seconds',NEW.default_rest_seconds,'default_bar_id',NEW.default_bar_id,'merged_into_id',NEW.merged_into_id,'license_key',NEW.license_key,'citation',NEW.citation,'external_key',NEW.external_key,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER exercises_outbox_update AFTER UPDATE ON exercises
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'exercises',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'normalized_name',NEW.normalized_name,'movement_pattern',NEW.movement_pattern,'mechanics',NEW.mechanics,'metric_type',NEW.metric_type,'unilateral',NEW.unilateral,'per_side',NEW.per_side,'is_custom',NEW.is_custom,'is_favorite',NEW.is_favorite,'cues',NEW.cues,'common_mistakes',NEW.common_mistakes,'pinned_note',NEW.pinned_note,'increment_kg',NEW.increment_kg,'entered_increment_value',NEW.entered_increment_value,'entered_increment_unit',NEW.entered_increment_unit,'default_rest_seconds',NEW.default_rest_seconds,'default_bar_id',NEW.default_bar_id,'merged_into_id',NEW.merged_into_id,'license_key',NEW.license_key,'citation',NEW.citation,'external_key',NEW.external_key,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER exercise_aliases_no_hard_delete BEFORE DELETE ON exercise_aliases BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER exercise_aliases_identity_immutable BEFORE UPDATE ON exercise_aliases WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER exercise_aliases_outbox_insert AFTER INSERT ON exercise_aliases
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'exercise_aliases',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'exercise_id',NEW.exercise_id,'alias',NEW.alias,'normalized_alias',NEW.normalized_alias,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER exercise_aliases_outbox_update AFTER UPDATE ON exercise_aliases
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'exercise_aliases',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'exercise_id',NEW.exercise_id,'alias',NEW.alias,'normalized_alias',NEW.normalized_alias,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER exercise_muscles_no_hard_delete BEFORE DELETE ON exercise_muscles BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER exercise_muscles_identity_immutable BEFORE UPDATE ON exercise_muscles WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER exercise_muscles_outbox_insert AFTER INSERT ON exercise_muscles
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'exercise_muscles',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'exercise_id',NEW.exercise_id,'muscle_id',NEW.muscle_id,'role',NEW.role,'contribution',NEW.contribution,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER exercise_muscles_outbox_update AFTER UPDATE ON exercise_muscles
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'exercise_muscles',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'exercise_id',NEW.exercise_id,'muscle_id',NEW.muscle_id,'role',NEW.role,'contribution',NEW.contribution,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER exercise_equipment_no_hard_delete BEFORE DELETE ON exercise_equipment BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER exercise_equipment_identity_immutable BEFORE UPDATE ON exercise_equipment WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER exercise_equipment_outbox_insert AFTER INSERT ON exercise_equipment
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'exercise_equipment',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'exercise_id',NEW.exercise_id,'equipment_id',NEW.equipment_id,'gym_id',NEW.gym_id,'setup_note',NEW.setup_note,'available',NEW.available,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER exercise_equipment_outbox_update AFTER UPDATE ON exercise_equipment
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'exercise_equipment',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'exercise_id',NEW.exercise_id,'equipment_id',NEW.equipment_id,'gym_id',NEW.gym_id,'setup_note',NEW.setup_note,'available',NEW.available,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER set_types_no_hard_delete BEFORE DELETE ON set_types BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER set_types_identity_immutable BEFORE UPDATE ON set_types WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER set_types_outbox_insert AFTER INSERT ON set_types
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'set_types',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'glyph',NEW.glyph,'color_token',NEW.color_token,'counts_volume',NEW.counts_volume,'counts_hard_sets',NEW.counts_hard_sets,'counts_pr',NEW.counts_pr,'default_rest_seconds',NEW.default_rest_seconds,'is_warmup',NEW.is_warmup,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER set_types_outbox_update AFTER UPDATE ON set_types
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'set_types',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'glyph',NEW.glyph,'color_token',NEW.color_token,'counts_volume',NEW.counts_volume,'counts_hard_sets',NEW.counts_hard_sets,'counts_pr',NEW.counts_pr,'default_rest_seconds',NEW.default_rest_seconds,'is_warmup',NEW.is_warmup,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER routine_folders_no_hard_delete BEFORE DELETE ON routine_folders BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER routine_folders_identity_immutable BEFORE UPDATE ON routine_folders WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER routine_folders_outbox_insert AFTER INSERT ON routine_folders
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'routine_folders',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER routine_folders_outbox_update AFTER UPDATE ON routine_folders
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'routine_folders',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER routines_no_hard_delete BEFORE DELETE ON routines BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER routines_identity_immutable BEFORE UPDATE ON routines WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER routines_outbox_insert AFTER INSERT ON routines
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'routines',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'folder_id',NEW.folder_id,'notes',NEW.notes,'archived_at',NEW.archived_at,'share_format_version',NEW.share_format_version,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER routines_outbox_update AFTER UPDATE ON routines
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'routines',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'folder_id',NEW.folder_id,'notes',NEW.notes,'archived_at',NEW.archived_at,'share_format_version',NEW.share_format_version,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER routine_exercises_no_hard_delete BEFORE DELETE ON routine_exercises BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER routine_exercises_identity_immutable BEFORE UPDATE ON routine_exercises WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER routine_exercises_outbox_insert AFTER INSERT ON routine_exercises
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'routine_exercises',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'routine_id',NEW.routine_id,'exercise_id',NEW.exercise_id,'position',NEW.position,'group_key',NEW.group_key,'group_kind',NEW.group_kind,'rest_after_round',NEW.rest_after_round,'notes',NEW.notes,'warmup_template_name',NEW.warmup_template_name,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER routine_exercises_outbox_update AFTER UPDATE ON routine_exercises
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'routine_exercises',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'routine_id',NEW.routine_id,'exercise_id',NEW.exercise_id,'position',NEW.position,'group_key',NEW.group_key,'group_kind',NEW.group_kind,'rest_after_round',NEW.rest_after_round,'notes',NEW.notes,'warmup_template_name',NEW.warmup_template_name,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER routine_sets_no_hard_delete BEFORE DELETE ON routine_sets BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER routine_sets_identity_immutable BEFORE UPDATE ON routine_sets WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER routine_sets_outbox_insert AFTER INSERT ON routine_sets
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'routine_sets',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'routine_exercise_id',NEW.routine_exercise_id,'set_type_id',NEW.set_type_id,'position',NEW.position,'reps_min',NEW.reps_min,'reps_max',NEW.reps_max,'target_load_kg',NEW.target_load_kg,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'percent_top_load',NEW.percent_top_load,'target_rpe',NEW.target_rpe,'target_rir',NEW.target_rir,'rest_seconds',NEW.rest_seconds,'tempo',NEW.tempo,'duration_seconds',NEW.duration_seconds,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER routine_sets_outbox_update AFTER UPDATE ON routine_sets
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'routine_sets',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'routine_exercise_id',NEW.routine_exercise_id,'set_type_id',NEW.set_type_id,'position',NEW.position,'reps_min',NEW.reps_min,'reps_max',NEW.reps_max,'target_load_kg',NEW.target_load_kg,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'percent_top_load',NEW.percent_top_load,'target_rpe',NEW.target_rpe,'target_rir',NEW.target_rir,'rest_seconds',NEW.rest_seconds,'tempo',NEW.tempo,'duration_seconds',NEW.duration_seconds,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER training_schedule_no_hard_delete BEFORE DELETE ON training_schedule BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER training_schedule_identity_immutable BEFORE UPDATE ON training_schedule WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER training_schedule_outbox_insert AFTER INSERT ON training_schedule
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'training_schedule',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'routine_id',NEW.routine_id,'schedule_name',NEW.schedule_name,'rrule',NEW.rrule,'tz',NEW.tz,'anchor_date',NEW.anchor_date,'local_time',NEW.local_time,'is_rest_day',NEW.is_rest_day,'missed_policy',NEW.missed_policy,'program_position',NEW.program_position,'next_local_date',NEW.next_local_date,'reminder_minutes',NEW.reminder_minutes,'paused_at',NEW.paused_at,'program_day_id',NEW.program_day_id,'program_id',NEW.program_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER training_schedule_outbox_update AFTER UPDATE ON training_schedule
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'training_schedule',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'routine_id',NEW.routine_id,'schedule_name',NEW.schedule_name,'rrule',NEW.rrule,'tz',NEW.tz,'anchor_date',NEW.anchor_date,'local_time',NEW.local_time,'is_rest_day',NEW.is_rest_day,'missed_policy',NEW.missed_policy,'program_position',NEW.program_position,'next_local_date',NEW.next_local_date,'reminder_minutes',NEW.reminder_minutes,'paused_at',NEW.paused_at,'program_day_id',NEW.program_day_id,'program_id',NEW.program_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER workouts_no_hard_delete BEFORE DELETE ON workouts BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER workouts_identity_immutable BEFORE UPDATE ON workouts WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER workouts_outbox_insert AFTER INSERT ON workouts
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'workouts',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'routine_id',NEW.routine_id,'gym_id',NEW.gym_id,'repeated_workout_id',NEW.repeated_workout_id,'status',NEW.status,'ended_at',NEW.ended_at,'paused_seconds',NEW.paused_seconds,'bodyweight_kg',NEW.bodyweight_kg,'bodyweight_log_id',NEW.bodyweight_log_id,'notes',NEW.notes,'soreness',NEW.soreness,'energy',NEW.energy,'mood',NEW.mood,'current_exercise_position',NEW.current_exercise_position,'current_round',NEW.current_round,'start_origin',NEW.start_origin,'program_day_id',NEW.program_day_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER workouts_outbox_update AFTER UPDATE ON workouts
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'workouts',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'routine_id',NEW.routine_id,'gym_id',NEW.gym_id,'repeated_workout_id',NEW.repeated_workout_id,'status',NEW.status,'ended_at',NEW.ended_at,'paused_seconds',NEW.paused_seconds,'bodyweight_kg',NEW.bodyweight_kg,'bodyweight_log_id',NEW.bodyweight_log_id,'notes',NEW.notes,'soreness',NEW.soreness,'energy',NEW.energy,'mood',NEW.mood,'current_exercise_position',NEW.current_exercise_position,'current_round',NEW.current_round,'start_origin',NEW.start_origin,'program_day_id',NEW.program_day_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER workout_exercises_no_hard_delete BEFORE DELETE ON workout_exercises BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER workout_exercises_identity_immutable BEFORE UPDATE ON workout_exercises WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER workout_exercises_outbox_insert AFTER INSERT ON workout_exercises
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'workout_exercises',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'workout_id',NEW.workout_id,'exercise_id',NEW.exercise_id,'original_exercise_id',NEW.original_exercise_id,'position',NEW.position,'group_key',NEW.group_key,'group_kind',NEW.group_kind,'skipped',NEW.skipped,'notes',NEW.notes,'equipment_id',NEW.equipment_id,'rest_after_round',NEW.rest_after_round,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER workout_exercises_outbox_update AFTER UPDATE ON workout_exercises
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'workout_exercises',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'workout_id',NEW.workout_id,'exercise_id',NEW.exercise_id,'original_exercise_id',NEW.original_exercise_id,'position',NEW.position,'group_key',NEW.group_key,'group_kind',NEW.group_kind,'skipped',NEW.skipped,'notes',NEW.notes,'equipment_id',NEW.equipment_id,'rest_after_round',NEW.rest_after_round,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER workout_sets_no_hard_delete BEFORE DELETE ON workout_sets BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER workout_sets_identity_immutable BEFORE UPDATE ON workout_sets WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER workout_sets_outbox_insert AFTER INSERT ON workout_sets
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'workout_sets',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'workout_exercise_id',NEW.workout_exercise_id,'current_revision_id',NEW.current_revision_id,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER workout_sets_outbox_update AFTER UPDATE ON workout_sets
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'workout_sets',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'workout_exercise_id',NEW.workout_exercise_id,'current_revision_id',NEW.current_revision_id,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER set_revisions_no_hard_delete BEFORE DELETE ON set_revisions BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER set_revisions_no_replace BEFORE INSERT ON set_revisions WHEN EXISTS(SELECT 1 FROM set_revisions WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Immutable revision ID already exists'); END;
CREATE TRIGGER set_revisions_append_only BEFORE UPDATE ON set_revisions BEGIN SELECT RAISE(ABORT,'Append a revision instead of editing immutable history'); END;
CREATE TRIGGER set_revisions_outbox_insert AFTER INSERT ON set_revisions
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'set_revisions',NEW.id,NEW.id,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'set_id',NEW.set_id,'parent_revision_id',NEW.parent_revision_id,'writer_device_id',NEW.writer_device_id,'action',NEW.action,'set_type_id',NEW.set_type_id,'load_kg',NEW.load_kg,'entered_load_value',NEW.entered_load_value,'entered_load_unit',NEW.entered_load_unit,'reps',NEW.reps,'rpe',NEW.rpe,'rir',NEW.rir,'duration_seconds',NEW.duration_seconds,'distance_cm',NEW.distance_cm,'entered_distance_value',NEW.entered_distance_value,'entered_distance_unit',NEW.entered_distance_unit,'bodyweight_kg',NEW.bodyweight_kg,'added_kg',NEW.added_kg,'assistance_kg',NEW.assistance_kg,'side',NEW.side,'tempo',NEW.tempo,'rest_actual_seconds',NEW.rest_actual_seconds,'planned_rest_seconds',NEW.planned_rest_seconds,'percent_1rm',NEW.percent_1rm,'counts_both_hands',NEW.counts_both_hands,'completed',NEW.completed,'notes',NEW.notes,'edit_reason',NEW.edit_reason,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER rest_timers_no_hard_delete BEFORE DELETE ON rest_timers BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER rest_timers_identity_immutable BEFORE UPDATE ON rest_timers WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER rest_timers_outbox_insert AFTER INSERT ON rest_timers
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'rest_timers',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'workout_id',NEW.workout_id,'set_id',NEW.set_id,'started_at',NEW.started_at,'ends_at',NEW.ends_at,'finished_at',NEW.finished_at,'target_seconds',NEW.target_seconds,'actual_seconds',NEW.actual_seconds,'state',NEW.state,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER rest_timers_outbox_update AFTER UPDATE ON rest_timers
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'rest_timers',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'workout_id',NEW.workout_id,'set_id',NEW.set_id,'started_at',NEW.started_at,'ends_at',NEW.ends_at,'finished_at',NEW.finished_at,'target_seconds',NEW.target_seconds,'actual_seconds',NEW.actual_seconds,'state',NEW.state,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER pr_records_no_hard_delete BEFORE DELETE ON pr_records BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER pr_records_identity_immutable BEFORE UPDATE ON pr_records WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER muscle_targets_no_hard_delete BEFORE DELETE ON muscle_targets BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER muscle_targets_identity_immutable BEFORE UPDATE ON muscle_targets WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER muscle_targets_outbox_insert AFTER INSERT ON muscle_targets
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'muscle_targets',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'muscle_id',NEW.muscle_id,'valid_from',NEW.valid_from,'min_sets',NEW.min_sets,'max_sets',NEW.max_sets,'mev',NEW.mev,'mav',NEW.mav,'mrv',NEW.mrv,'method_label',NEW.method_label,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER muscle_targets_outbox_update AFTER UPDATE ON muscle_targets
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'muscle_targets',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'muscle_id',NEW.muscle_id,'valid_from',NEW.valid_from,'min_sets',NEW.min_sets,'max_sets',NEW.max_sets,'mev',NEW.mev,'mav',NEW.mav,'mrv',NEW.mrv,'method_label',NEW.method_label,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_sources_no_hard_delete BEFORE DELETE ON food_sources BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER food_sources_identity_immutable BEFORE UPDATE ON food_sources WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER food_sources_outbox_insert AFTER INSERT ON food_sources
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_sources',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'source_kind',NEW.source_kind,'license_identifier',NEW.license_identifier,'attribution',NEW.attribution,'terms_url',NEW.terms_url,'version',NEW.version,'verified_at',NEW.verified_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_sources_outbox_update AFTER UPDATE ON food_sources
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_sources',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'source_kind',NEW.source_kind,'license_identifier',NEW.license_identifier,'attribution',NEW.attribution,'terms_url',NEW.terms_url,'version',NEW.version,'verified_at',NEW.verified_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER restaurants_no_hard_delete BEFORE DELETE ON restaurants BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER restaurants_identity_immutable BEFORE UPDATE ON restaurants WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER restaurants_outbox_insert AFTER INSERT ON restaurants
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'restaurants',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'citation',NEW.citation,'verified_at',NEW.verified_at,'is_custom',NEW.is_custom,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER restaurants_outbox_update AFTER UPDATE ON restaurants
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'restaurants',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'citation',NEW.citation,'verified_at',NEW.verified_at,'is_custom',NEW.is_custom,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER foods_no_hard_delete BEFORE DELETE ON foods BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER foods_identity_immutable BEFORE UPDATE ON foods WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER foods_outbox_insert AFTER INSERT ON foods
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'foods',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'normalized_name',NEW.normalized_name,'brand',NEW.brand,'source_id',NEW.source_id,'source_external_key',NEW.source_external_key,'barcode',NEW.barcode,'quality_rank',NEW.quality_rank,'density_g_per_ml',NEW.density_g_per_ml,'restaurant_id',NEW.restaurant_id,'menu_category',NEW.menu_category,'corrected_from_id',NEW.corrected_from_id,'correction_reason',NEW.correction_reason,'error_report_status',NEW.error_report_status,'is_favorite',NEW.is_favorite,'is_custom',NEW.is_custom,'kind',NEW.kind,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER foods_outbox_update AFTER UPDATE ON foods
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'foods',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'normalized_name',NEW.normalized_name,'brand',NEW.brand,'source_id',NEW.source_id,'source_external_key',NEW.source_external_key,'barcode',NEW.barcode,'quality_rank',NEW.quality_rank,'density_g_per_ml',NEW.density_g_per_ml,'restaurant_id',NEW.restaurant_id,'menu_category',NEW.menu_category,'corrected_from_id',NEW.corrected_from_id,'correction_reason',NEW.correction_reason,'error_report_status',NEW.error_report_status,'is_favorite',NEW.is_favorite,'is_custom',NEW.is_custom,'kind',NEW.kind,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_servings_no_hard_delete BEFORE DELETE ON food_servings BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER food_servings_identity_immutable BEFORE UPDATE ON food_servings WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER food_servings_outbox_insert AFTER INSERT ON food_servings
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_servings',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'food_id',NEW.food_id,'label',NEW.label,'grams',NEW.grams,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'is_default',NEW.is_default,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_servings_outbox_update AFTER UPDATE ON food_servings
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_servings',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'food_id',NEW.food_id,'label',NEW.label,'grams',NEW.grams,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'is_default',NEW.is_default,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER nutrients_no_hard_delete BEFORE DELETE ON nutrients BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER nutrients_identity_immutable BEFORE UPDATE ON nutrients WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER nutrients_outbox_insert AFTER INSERT ON nutrients
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'nutrients',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'code',NEW.code,'name',NEW.name,'canonical_unit',NEW.canonical_unit,'citation',NEW.citation,'reference_version',NEW.reference_version,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER nutrients_outbox_update AFTER UPDATE ON nutrients
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'nutrients',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'code',NEW.code,'name',NEW.name,'canonical_unit',NEW.canonical_unit,'citation',NEW.citation,'reference_version',NEW.reference_version,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_nutrients_no_hard_delete BEFORE DELETE ON food_nutrients BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER food_nutrients_identity_immutable BEFORE UPDATE ON food_nutrients WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER food_nutrients_outbox_insert AFTER INSERT ON food_nutrients
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_nutrients',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'food_id',NEW.food_id,'nutrient_id',NEW.nutrient_id,'value',NEW.value,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'precision_digits',NEW.precision_digits,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_nutrients_outbox_update AFTER UPDATE ON food_nutrients
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_nutrients',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'food_id',NEW.food_id,'nutrient_id',NEW.nutrient_id,'value',NEW.value,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'precision_digits',NEW.precision_digits,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_component_groups_no_hard_delete BEFORE DELETE ON food_component_groups BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER food_component_groups_identity_immutable BEFORE UPDATE ON food_component_groups WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER food_component_groups_outbox_insert AFTER INSERT ON food_component_groups
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_component_groups',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'food_id',NEW.food_id,'name',NEW.name,'selection_mode',NEW.selection_mode,'required',NEW.required,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_component_groups_outbox_update AFTER UPDATE ON food_component_groups
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_component_groups',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'food_id',NEW.food_id,'name',NEW.name,'selection_mode',NEW.selection_mode,'required',NEW.required,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_components_no_hard_delete BEFORE DELETE ON food_components BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER food_components_identity_immutable BEFORE UPDATE ON food_components WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER food_components_outbox_insert AFTER INSERT ON food_components
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_components',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'parent_food_id',NEW.parent_food_id,'child_food_id',NEW.child_food_id,'group_id',NEW.group_id,'name',NEW.name,'grams',NEW.grams,'is_removal',NEW.is_removal,'supports_double',NEW.supports_double,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_components_outbox_update AFTER UPDATE ON food_components
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_components',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'parent_food_id',NEW.parent_food_id,'child_food_id',NEW.child_food_id,'group_id',NEW.group_id,'name',NEW.name,'grams',NEW.grams,'is_removal',NEW.is_removal,'supports_double',NEW.supports_double,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER meal_slots_no_hard_delete BEFORE DELETE ON meal_slots BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER meal_slots_identity_immutable BEFORE UPDATE ON meal_slots WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER meal_slots_outbox_insert AFTER INSERT ON meal_slots
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'meal_slots',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'position',NEW.position,'default_local_time',NEW.default_local_time,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER meal_slots_outbox_update AFTER UPDATE ON meal_slots
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'meal_slots',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'position',NEW.position,'default_local_time',NEW.default_local_time,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER meal_logs_no_hard_delete BEFORE DELETE ON meal_logs BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER meal_logs_identity_immutable BEFORE UPDATE ON meal_logs WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER meal_logs_outbox_insert AFTER INSERT ON meal_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'meal_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'meal_slot_id',NEW.meal_slot_id,'state',NEW.state,'notes',NEW.notes,'hunger',NEW.hunger,'mood',NEW.mood,'copied_from_id',NEW.copied_from_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER meal_logs_outbox_update AFTER UPDATE ON meal_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'meal_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'meal_slot_id',NEW.meal_slot_id,'state',NEW.state,'notes',NEW.notes,'hunger',NEW.hunger,'mood',NEW.mood,'copied_from_id',NEW.copied_from_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_logs_no_hard_delete BEFORE DELETE ON food_logs BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER food_logs_identity_immutable BEFORE UPDATE ON food_logs WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER food_logs_outbox_insert AFTER INSERT ON food_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'meal_log_id',NEW.meal_log_id,'food_id',NEW.food_id,'food_name',NEW.food_name,'serving_id',NEW.serving_id,'grams',NEW.grams,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'multiplier',NEW.multiplier,'calories_kcal',NEW.calories_kcal,'protein_g',NEW.protein_g,'carbs_g',NEW.carbs_g,'fat_g',NEW.fat_g,'alcohol_g',NEW.alcohol_g,'adjusted',NEW.adjusted,'confirmed_at',NEW.confirmed_at,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_logs_outbox_update AFTER UPDATE ON food_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'meal_log_id',NEW.meal_log_id,'food_id',NEW.food_id,'food_name',NEW.food_name,'serving_id',NEW.serving_id,'grams',NEW.grams,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'multiplier',NEW.multiplier,'calories_kcal',NEW.calories_kcal,'protein_g',NEW.protein_g,'carbs_g',NEW.carbs_g,'fat_g',NEW.fat_g,'alcohol_g',NEW.alcohol_g,'adjusted',NEW.adjusted,'confirmed_at',NEW.confirmed_at,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_log_nutrients_no_hard_delete BEFORE DELETE ON food_log_nutrients BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER food_log_nutrients_identity_immutable BEFORE UPDATE ON food_log_nutrients WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER food_log_nutrients_outbox_insert AFTER INSERT ON food_log_nutrients
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_log_nutrients',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'food_log_id',NEW.food_log_id,'nutrient_id',NEW.nutrient_id,'value',NEW.value,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER food_log_nutrients_outbox_update AFTER UPDATE ON food_log_nutrients
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'food_log_nutrients',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'food_log_id',NEW.food_log_id,'nutrient_id',NEW.nutrient_id,'value',NEW.value,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER recipes_no_hard_delete BEFORE DELETE ON recipes BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER recipes_identity_immutable BEFORE UPDATE ON recipes WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER recipes_outbox_insert AFTER INSERT ON recipes
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'recipes',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'food_id',NEW.food_id,'name',NEW.name,'servings',NEW.servings,'raw_mass_g',NEW.raw_mass_g,'cooked_mass_g',NEW.cooked_mass_g,'yield_factor',NEW.yield_factor,'import_url',NEW.import_url,'instructions',NEW.instructions,'parser_version',NEW.parser_version,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER recipes_outbox_update AFTER UPDATE ON recipes
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'recipes',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'food_id',NEW.food_id,'name',NEW.name,'servings',NEW.servings,'raw_mass_g',NEW.raw_mass_g,'cooked_mass_g',NEW.cooked_mass_g,'yield_factor',NEW.yield_factor,'import_url',NEW.import_url,'instructions',NEW.instructions,'parser_version',NEW.parser_version,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER recipe_ingredients_no_hard_delete BEFORE DELETE ON recipe_ingredients BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER recipe_ingredients_identity_immutable BEFORE UPDATE ON recipe_ingredients WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER recipe_ingredients_outbox_insert AFTER INSERT ON recipe_ingredients
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'recipe_ingredients',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'recipe_id',NEW.recipe_id,'food_id',NEW.food_id,'grams',NEW.grams,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'position',NEW.position,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER recipe_ingredients_outbox_update AFTER UPDATE ON recipe_ingredients
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'recipe_ingredients',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'recipe_id',NEW.recipe_id,'food_id',NEW.food_id,'grams',NEW.grams,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'position',NEW.position,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER meal_templates_no_hard_delete BEFORE DELETE ON meal_templates BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER meal_templates_identity_immutable BEFORE UPDATE ON meal_templates WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER meal_templates_outbox_insert AFTER INSERT ON meal_templates
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'meal_templates',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'notes',NEW.notes,'preferred_slot_id',NEW.preferred_slot_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER meal_templates_outbox_update AFTER UPDATE ON meal_templates
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'meal_templates',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'notes',NEW.notes,'preferred_slot_id',NEW.preferred_slot_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER meal_template_items_no_hard_delete BEFORE DELETE ON meal_template_items BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER meal_template_items_identity_immutable BEFORE UPDATE ON meal_template_items WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER meal_template_items_outbox_insert AFTER INSERT ON meal_template_items
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'meal_template_items',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'meal_template_id',NEW.meal_template_id,'food_id',NEW.food_id,'grams',NEW.grams,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER meal_template_items_outbox_update AFTER UPDATE ON meal_template_items
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'meal_template_items',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'meal_template_id',NEW.meal_template_id,'food_id',NEW.food_id,'grams',NEW.grams,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'position',NEW.position,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER hydration_logs_no_hard_delete BEFORE DELETE ON hydration_logs BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER hydration_logs_identity_immutable BEFORE UPDATE ON hydration_logs WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER hydration_logs_outbox_insert AFTER INSERT ON hydration_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'hydration_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'kind',NEW.kind,'volume_ml',NEW.volume_ml,'caffeine_g',NEW.caffeine_g,'alcohol_g',NEW.alcohol_g,'calories_kcal',NEW.calories_kcal,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER hydration_logs_outbox_update AFTER UPDATE ON hydration_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'hydration_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'kind',NEW.kind,'volume_ml',NEW.volume_ml,'caffeine_g',NEW.caffeine_g,'alcohol_g',NEW.alcohol_g,'calories_kcal',NEW.calories_kcal,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER supplement_logs_no_hard_delete BEFORE DELETE ON supplement_logs BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER supplement_logs_identity_immutable BEFORE UPDATE ON supplement_logs WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER supplement_logs_outbox_insert AFTER INSERT ON supplement_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'supplement_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'food_id',NEW.food_id,'food_log_id',NEW.food_log_id,'grams',NEW.grams,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER supplement_logs_outbox_update AFTER UPDATE ON supplement_logs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'supplement_logs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'food_id',NEW.food_id,'food_log_id',NEW.food_log_id,'grams',NEW.grams,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER safety_acknowledgements_no_hard_delete BEFORE DELETE ON safety_acknowledgements BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER safety_acknowledgements_no_replace BEFORE INSERT ON safety_acknowledgements WHEN EXISTS(SELECT 1 FROM safety_acknowledgements WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Immutable revision ID already exists'); END;
CREATE TRIGGER safety_acknowledgements_append_only BEFORE UPDATE ON safety_acknowledgements BEGIN SELECT RAISE(ABORT,'Append a revision instead of editing immutable history'); END;
CREATE TRIGGER safety_acknowledgements_outbox_insert AFTER INSERT ON safety_acknowledgements
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'safety_acknowledgements',NEW.id,NEW.id,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'kind',NEW.kind,'policy_version',NEW.policy_version,'acknowledgement_text',NEW.acknowledgement_text,'expires_at',NEW.expires_at,'clinician_override_confirmed',NEW.clinician_override_confirmed,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER nutrition_targets_no_hard_delete BEFORE DELETE ON nutrition_targets BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER nutrition_targets_identity_immutable BEFORE UPDATE ON nutrition_targets WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER nutrition_targets_outbox_insert AFTER INSERT ON nutrition_targets
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'nutrition_targets',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'goal_mode',NEW.goal_mode,'calories_kcal',NEW.calories_kcal,'protein_g',NEW.protein_g,'carbs_g',NEW.carbs_g,'fat_g',NEW.fat_g,'fiber_g',NEW.fiber_g,'assessed_bmi',NEW.assessed_bmi,'weekly_loss_fraction',NEW.weekly_loss_fraction,'safety_floor_kcal',NEW.safety_floor_kcal,'clinician_ack_id',NEW.clinician_ack_id,'method_version',NEW.method_version,'valid_from',NEW.valid_from,'valid_until',NEW.valid_until,'activity_multiplier',NEW.activity_multiplier,'bmr_kcal',NEW.bmr_kcal,'bmr_method',NEW.bmr_method,'macro_preset',NEW.macro_preset,'entered_rate_value',NEW.entered_rate_value,'entered_rate_unit',NEW.entered_rate_unit,'day_type',NEW.day_type,'nutrient_id',NEW.nutrient_id,'nutrient_target_value',NEW.nutrient_target_value,'reference_citation',NEW.reference_citation,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER nutrition_targets_outbox_update AFTER UPDATE ON nutrition_targets
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'nutrition_targets',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'goal_mode',NEW.goal_mode,'calories_kcal',NEW.calories_kcal,'protein_g',NEW.protein_g,'carbs_g',NEW.carbs_g,'fat_g',NEW.fat_g,'fiber_g',NEW.fiber_g,'assessed_bmi',NEW.assessed_bmi,'weekly_loss_fraction',NEW.weekly_loss_fraction,'safety_floor_kcal',NEW.safety_floor_kcal,'clinician_ack_id',NEW.clinician_ack_id,'method_version',NEW.method_version,'valid_from',NEW.valid_from,'valid_until',NEW.valid_until,'activity_multiplier',NEW.activity_multiplier,'bmr_kcal',NEW.bmr_kcal,'bmr_method',NEW.bmr_method,'macro_preset',NEW.macro_preset,'entered_rate_value',NEW.entered_rate_value,'entered_rate_unit',NEW.entered_rate_unit,'day_type',NEW.day_type,'nutrient_id',NEW.nutrient_id,'nutrient_target_value',NEW.nutrient_target_value,'reference_citation',NEW.reference_citation,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER target_overrides_no_hard_delete BEFORE DELETE ON target_overrides BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER target_overrides_identity_immutable BEFORE UPDATE ON target_overrides WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER target_overrides_outbox_insert AFTER INSERT ON target_overrides
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'target_overrides',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'goal_mode',NEW.goal_mode,'calories_kcal',NEW.calories_kcal,'protein_g',NEW.protein_g,'carbs_g',NEW.carbs_g,'fat_g',NEW.fat_g,'fiber_g',NEW.fiber_g,'assessed_bmi',NEW.assessed_bmi,'weekly_loss_fraction',NEW.weekly_loss_fraction,'safety_floor_kcal',NEW.safety_floor_kcal,'clinician_ack_id',NEW.clinician_ack_id,'method_version',NEW.method_version,'base_target_id',NEW.base_target_id,'local_date',NEW.local_date,'weekday',NEW.weekday,'weekly_budget_kcal',NEW.weekly_budget_kcal,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER target_overrides_outbox_update AFTER UPDATE ON target_overrides
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'target_overrides',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'goal_mode',NEW.goal_mode,'calories_kcal',NEW.calories_kcal,'protein_g',NEW.protein_g,'carbs_g',NEW.carbs_g,'fat_g',NEW.fat_g,'fiber_g',NEW.fiber_g,'assessed_bmi',NEW.assessed_bmi,'weekly_loss_fraction',NEW.weekly_loss_fraction,'safety_floor_kcal',NEW.safety_floor_kcal,'clinician_ack_id',NEW.clinician_ack_id,'method_version',NEW.method_version,'base_target_id',NEW.base_target_id,'local_date',NEW.local_date,'weekday',NEW.weekday,'weekly_budget_kcal',NEW.weekly_budget_kcal,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER diet_phases_no_hard_delete BEFORE DELETE ON diet_phases BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER diet_phases_identity_immutable BEFORE UPDATE ON diet_phases WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER diet_phases_outbox_insert AFTER INSERT ON diet_phases
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'diet_phases',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'kind',NEW.kind,'starts_on',NEW.starts_on,'ends_on',NEW.ends_on,'target_id',NEW.target_id,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER diet_phases_outbox_update AFTER UPDATE ON diet_phases
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'diet_phases',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'kind',NEW.kind,'starts_on',NEW.starts_on,'ends_on',NEW.ends_on,'target_id',NEW.target_id,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER weigh_ins_no_hard_delete BEFORE DELETE ON weigh_ins BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER weigh_ins_identity_immutable BEFORE UPDATE ON weigh_ins WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER weigh_ins_outbox_insert AFTER INSERT ON weigh_ins
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'weigh_ins',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'weight_kg',NEW.weight_kg,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'health_external_key',NEW.health_external_key,'tags',NEW.tags,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER weigh_ins_outbox_update AFTER UPDATE ON weigh_ins
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'weigh_ins',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'weight_kg',NEW.weight_kg,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'health_external_key',NEW.health_external_key,'tags',NEW.tags,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER measurements_no_hard_delete BEFORE DELETE ON measurements BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER measurements_identity_immutable BEFORE UPDATE ON measurements WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER measurements_outbox_insert AFTER INSERT ON measurements
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'measurements',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'kind',NEW.kind,'landmark',NEW.landmark,'side',NEW.side,'value',NEW.value,'canonical_unit',NEW.canonical_unit,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'method',NEW.method,'uncertainty',NEW.uncertainty,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER measurements_outbox_update AFTER UPDATE ON measurements
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'measurements',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'kind',NEW.kind,'landmark',NEW.landmark,'side',NEW.side,'value',NEW.value,'canonical_unit',NEW.canonical_unit,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'method',NEW.method,'uncertainty',NEW.uncertainty,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER check_ins_no_hard_delete BEFORE DELETE ON check_ins BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER check_ins_identity_immutable BEFORE UPDATE ON check_ins WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER check_ins_outbox_insert AFTER INSERT ON check_ins
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'check_ins',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'weigh_in_id',NEW.weigh_in_id,'notes',NEW.notes,'sleep_quality',NEW.sleep_quality,'soreness',NEW.soreness,'stress',NEW.stress,'motivation',NEW.motivation,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER check_ins_outbox_update AFTER UPDATE ON check_ins
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'check_ins',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'weigh_in_id',NEW.weigh_in_id,'notes',NEW.notes,'sleep_quality',NEW.sleep_quality,'soreness',NEW.soreness,'stress',NEW.stress,'motivation',NEW.motivation,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER health_samples_no_hard_delete BEFORE DELETE ON health_samples BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER health_samples_identity_immutable BEFORE UPDATE ON health_samples WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER health_samples_outbox_insert AFTER INSERT ON health_samples
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'health_samples',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'provider',NEW.provider,'external_key',NEW.external_key,'sample_type',NEW.sample_type,'value',NEW.value,'unit',NEW.unit,'end_at',NEW.end_at,'device_label',NEW.device_label,'provider_modified_at',NEW.provider_modified_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER health_samples_outbox_update AFTER UPDATE ON health_samples
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'health_samples',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'provider',NEW.provider,'external_key',NEW.external_key,'sample_type',NEW.sample_type,'value',NEW.value,'unit',NEW.unit,'end_at',NEW.end_at,'device_label',NEW.device_label,'provider_modified_at',NEW.provider_modified_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER health_anchors_no_hard_delete BEFORE DELETE ON health_anchors BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER health_anchors_identity_immutable BEFORE UPDATE ON health_anchors WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER goals_no_hard_delete BEFORE DELETE ON goals BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER goals_identity_immutable BEFORE UPDATE ON goals WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER goals_outbox_insert AFTER INSERT ON goals
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'goals',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'domain',NEW.domain,'metric_key',NEW.metric_key,'exercise_id',NEW.exercise_id,'muscle_id',NEW.muscle_id,'target_value',NEW.target_value,'canonical_unit',NEW.canonical_unit,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'target_date',NEW.target_date,'starts_on',NEW.starts_on,'archived_at',NEW.archived_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER goals_outbox_update AFTER UPDATE ON goals
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'goals',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'domain',NEW.domain,'metric_key',NEW.metric_key,'exercise_id',NEW.exercise_id,'muscle_id',NEW.muscle_id,'target_value',NEW.target_value,'canonical_unit',NEW.canonical_unit,'entered_value',NEW.entered_value,'entered_unit',NEW.entered_unit,'target_date',NEW.target_date,'starts_on',NEW.starts_on,'archived_at',NEW.archived_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER notes_no_hard_delete BEFORE DELETE ON notes BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER notes_identity_immutable BEFORE UPDATE ON notes WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER notes_outbox_insert AFTER INSERT ON notes
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'notes',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'text',NEW.text,'owner_table',NEW.owner_table,'owner_id',NEW.owner_id,'tags',NEW.tags,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER notes_outbox_update AFTER UPDATE ON notes
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'notes',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'occurred_at',NEW.occurred_at,'tz',NEW.tz,'local_date',NEW.local_date,'text',NEW.text,'owner_table',NEW.owner_table,'owner_id',NEW.owner_id,'tags',NEW.tags,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER import_batches_no_hard_delete BEFORE DELETE ON import_batches BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER import_batches_identity_immutable BEFORE UPDATE ON import_batches WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER import_batches_outbox_insert AFTER INSERT ON import_batches
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'import_batches',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'format',NEW.format,'file_digest',NEW.file_digest,'status',NEW.status,'total_rows',NEW.total_rows,'accepted_rows',NEW.accepted_rows,'rejected_rows',NEW.rejected_rows,'error_report_locator',NEW.error_report_locator,'source_schema_version',NEW.source_schema_version,'validation_digest',NEW.validation_digest,'completed_at',NEW.completed_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER import_batches_outbox_update AFTER UPDATE ON import_batches
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'import_batches',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'format',NEW.format,'file_digest',NEW.file_digest,'status',NEW.status,'total_rows',NEW.total_rows,'accepted_rows',NEW.accepted_rows,'rejected_rows',NEW.rejected_rows,'error_report_locator',NEW.error_report_locator,'source_schema_version',NEW.source_schema_version,'validation_digest',NEW.validation_digest,'completed_at',NEW.completed_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER legacy_id_map_no_hard_delete BEFORE DELETE ON legacy_id_map BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER legacy_id_map_identity_immutable BEFORE UPDATE ON legacy_id_map WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER legacy_id_map_outbox_insert AFTER INSERT ON legacy_id_map
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'legacy_id_map',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'batch_id',NEW.batch_id,'source_entity',NEW.source_entity,'legacy_identifier',NEW.legacy_identifier,'destination_table',NEW.destination_table,'destination_id',NEW.destination_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER legacy_id_map_outbox_update AFTER UPDATE ON legacy_id_map
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'legacy_id_map',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'batch_id',NEW.batch_id,'source_entity',NEW.source_entity,'legacy_identifier',NEW.legacy_identifier,'destination_table',NEW.destination_table,'destination_id',NEW.destination_id,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER export_jobs_no_hard_delete BEFORE DELETE ON export_jobs BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER export_jobs_identity_immutable BEFORE UPDATE ON export_jobs WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER programs_no_hard_delete BEFORE DELETE ON programs BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER programs_identity_immutable BEFORE UPDATE ON programs WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER programs_outbox_insert AFTER INSERT ON programs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'programs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'notes',NEW.notes,'current_day_position',NEW.current_day_position,'archived_at',NEW.archived_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER programs_outbox_update AFTER UPDATE ON programs
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'programs',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'name',NEW.name,'notes',NEW.notes,'current_day_position',NEW.current_day_position,'archived_at',NEW.archived_at,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER program_days_no_hard_delete BEFORE DELETE ON program_days BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER program_days_identity_immutable BEFORE UPDATE ON program_days WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER program_days_outbox_insert AFTER INSERT ON program_days
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'program_days',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'program_id',NEW.program_id,'routine_id',NEW.routine_id,'week_number',NEW.week_number,'day_number',NEW.day_number,'position',NEW.position,'is_rest_day',NEW.is_rest_day,'name',NEW.name,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER program_days_outbox_update AFTER UPDATE ON program_days
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'program_days',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'program_id',NEW.program_id,'routine_id',NEW.routine_id,'week_number',NEW.week_number,'day_number',NEW.day_number,'position',NEW.position,'is_rest_day',NEW.is_rest_day,'name',NEW.name,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER cached_insights_no_hard_delete BEFORE DELETE ON cached_insights BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER cached_insights_identity_immutable BEFORE UPDATE ON cached_insights WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER nutrition_days_no_hard_delete BEFORE DELETE ON nutrition_days BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER nutrition_days_identity_immutable BEFORE UPDATE ON nutrition_days WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER nutrition_days_outbox_insert AFTER INSERT ON nutrition_days
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'nutrition_days',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'local_date',NEW.local_date,'status',NEW.status,'confirmed_at',NEW.confirmed_at,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER nutrition_days_outbox_update AFTER UPDATE ON nutrition_days
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id=NEW.account_id AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES((substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6)))),NEW.account_id,'nutrition_days',NEW.id,NULL,CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,json_object('id',NEW.id,'account_id',NEW.account_id,'local_date',NEW.local_date,'status',NEW.status,'confirmed_at',NEW.confirmed_at,'notes',NEW.notes,'created_at',NEW.created_at,'updated_at',NEW.updated_at,'deleted_at',NEW.deleted_at,'source',NEW.source,'logical_clock',NEW.logical_clock,'origin_device_id',NEW.origin_device_id),NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;
CREATE TRIGGER sync_context_no_hard_delete BEFORE DELETE ON sync_context BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;
CREATE TRIGGER sync_context_identity_immutable BEFORE UPDATE ON sync_context WHEN NEW.id<>OLD.id OR NEW.account_id<>OLD.account_id OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;
CREATE TRIGGER set_revisions_parent_guard BEFORE INSERT ON set_revisions
WHEN NEW.parent_revision_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM set_revisions p WHERE p.account_id=NEW.account_id AND p.id=NEW.parent_revision_id AND p.set_id=NEW.set_id AND p.logical_clock<NEW.logical_clock)
BEGIN SELECT RAISE(ABORT,'Revision parent must belong to the same record and precede its logical clock'); END;
CREATE TRIGGER workout_sets_head_guard BEFORE UPDATE OF current_revision_id ON workout_sets
WHEN NEW.current_revision_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM set_revisions r WHERE r.account_id=NEW.account_id AND r.id=NEW.current_revision_id AND r.set_id=NEW.id)
BEGIN SELECT RAISE(ABORT,'Revision head belongs to a different record'); END;
CREATE TRIGGER workout_sets_initial_head BEFORE INSERT ON workout_sets WHEN NEW.current_revision_id IS NOT NULL BEGIN SELECT RAISE(ABORT,'Insert identity before selecting an owned revision'); END;
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
CREATE TRIGGER muscles_clock_guard BEFORE UPDATE ON muscles
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER equipment_clock_guard BEFORE UPDATE ON equipment
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER gyms_clock_guard BEFORE UPDATE ON gyms
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER plate_inventory_clock_guard BEFORE UPDATE ON plate_inventory
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER exercises_clock_guard BEFORE UPDATE ON exercises
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER exercise_aliases_clock_guard BEFORE UPDATE ON exercise_aliases
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER exercise_muscles_clock_guard BEFORE UPDATE ON exercise_muscles
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER exercise_equipment_clock_guard BEFORE UPDATE ON exercise_equipment
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER set_types_clock_guard BEFORE UPDATE ON set_types
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER routine_folders_clock_guard BEFORE UPDATE ON routine_folders
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER routines_clock_guard BEFORE UPDATE ON routines
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER routine_exercises_clock_guard BEFORE UPDATE ON routine_exercises
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER routine_sets_clock_guard BEFORE UPDATE ON routine_sets
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER training_schedule_clock_guard BEFORE UPDATE ON training_schedule
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER workouts_clock_guard BEFORE UPDATE ON workouts
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER workout_exercises_clock_guard BEFORE UPDATE ON workout_exercises
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER workout_sets_clock_guard BEFORE UPDATE ON workout_sets
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER rest_timers_clock_guard BEFORE UPDATE ON rest_timers
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER muscle_targets_clock_guard BEFORE UPDATE ON muscle_targets
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER food_sources_clock_guard BEFORE UPDATE ON food_sources
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER restaurants_clock_guard BEFORE UPDATE ON restaurants
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER foods_clock_guard BEFORE UPDATE ON foods
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER food_servings_clock_guard BEFORE UPDATE ON food_servings
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER nutrients_clock_guard BEFORE UPDATE ON nutrients
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER food_nutrients_clock_guard BEFORE UPDATE ON food_nutrients
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER food_component_groups_clock_guard BEFORE UPDATE ON food_component_groups
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER food_components_clock_guard BEFORE UPDATE ON food_components
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER meal_slots_clock_guard BEFORE UPDATE ON meal_slots
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER meal_logs_clock_guard BEFORE UPDATE ON meal_logs
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER food_logs_clock_guard BEFORE UPDATE ON food_logs
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER food_log_nutrients_clock_guard BEFORE UPDATE ON food_log_nutrients
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER recipes_clock_guard BEFORE UPDATE ON recipes
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER recipe_ingredients_clock_guard BEFORE UPDATE ON recipe_ingredients
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER meal_templates_clock_guard BEFORE UPDATE ON meal_templates
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER meal_template_items_clock_guard BEFORE UPDATE ON meal_template_items
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER hydration_logs_clock_guard BEFORE UPDATE ON hydration_logs
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER supplement_logs_clock_guard BEFORE UPDATE ON supplement_logs
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER nutrition_targets_clock_guard BEFORE UPDATE ON nutrition_targets
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER target_overrides_clock_guard BEFORE UPDATE ON target_overrides
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER diet_phases_clock_guard BEFORE UPDATE ON diet_phases
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER weigh_ins_clock_guard BEFORE UPDATE ON weigh_ins
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER measurements_clock_guard BEFORE UPDATE ON measurements
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER check_ins_clock_guard BEFORE UPDATE ON check_ins
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER health_samples_clock_guard BEFORE UPDATE ON health_samples
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER goals_clock_guard BEFORE UPDATE ON goals
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER notes_clock_guard BEFORE UPDATE ON notes
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER import_batches_clock_guard BEFORE UPDATE ON import_batches
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER legacy_id_map_clock_guard BEFORE UPDATE ON legacy_id_map
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER programs_clock_guard BEFORE UPDATE ON programs
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER program_days_clock_guard BEFORE UPDATE ON program_days
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER nutrition_days_clock_guard BEFORE UPDATE ON nutrition_days
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;
CREATE TRIGGER attachments_owner_insert BEFORE INSERT ON attachments WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscles' AND EXISTS(SELECT 1 FROM muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='equipment' AND EXISTS(SELECT 1 FROM equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='gyms' AND EXISTS(SELECT 1 FROM gyms e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='plate_inventory' AND EXISTS(SELECT 1 FROM plate_inventory e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercises' AND EXISTS(SELECT 1 FROM exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_aliases' AND EXISTS(SELECT 1 FROM exercise_aliases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_muscles' AND EXISTS(SELECT 1 FROM exercise_muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_equipment' AND EXISTS(SELECT 1 FROM exercise_equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_types' AND EXISTS(SELECT 1 FROM set_types e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_folders' AND EXISTS(SELECT 1 FROM routine_folders e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routines' AND EXISTS(SELECT 1 FROM routines e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_exercises' AND EXISTS(SELECT 1 FROM routine_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_sets' AND EXISTS(SELECT 1 FROM routine_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='training_schedule' AND EXISTS(SELECT 1 FROM training_schedule e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workouts' AND EXISTS(SELECT 1 FROM workouts e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_exercises' AND EXISTS(SELECT 1 FROM workout_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_sets' AND EXISTS(SELECT 1 FROM workout_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_revisions' AND EXISTS(SELECT 1 FROM set_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='rest_timers' AND EXISTS(SELECT 1 FROM rest_timers e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='pr_records' AND EXISTS(SELECT 1 FROM pr_records e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscle_targets' AND EXISTS(SELECT 1 FROM muscle_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_sources' AND EXISTS(SELECT 1 FROM food_sources e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='restaurants' AND EXISTS(SELECT 1 FROM restaurants e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='foods' AND EXISTS(SELECT 1 FROM foods e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_servings' AND EXISTS(SELECT 1 FROM food_servings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrients' AND EXISTS(SELECT 1 FROM nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_nutrients' AND EXISTS(SELECT 1 FROM food_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_component_groups' AND EXISTS(SELECT 1 FROM food_component_groups e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_components' AND EXISTS(SELECT 1 FROM food_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_slots' AND EXISTS(SELECT 1 FROM meal_slots e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_logs' AND EXISTS(SELECT 1 FROM meal_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_logs' AND EXISTS(SELECT 1 FROM food_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_log_nutrients' AND EXISTS(SELECT 1 FROM food_log_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipes' AND EXISTS(SELECT 1 FROM recipes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipe_ingredients' AND EXISTS(SELECT 1 FROM recipe_ingredients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_templates' AND EXISTS(SELECT 1 FROM meal_templates e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_template_items' AND EXISTS(SELECT 1 FROM meal_template_items e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='hydration_logs' AND EXISTS(SELECT 1 FROM hydration_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='supplement_logs' AND EXISTS(SELECT 1 FROM supplement_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='safety_acknowledgements' AND EXISTS(SELECT 1 FROM safety_acknowledgements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_targets' AND EXISTS(SELECT 1 FROM nutrition_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='target_overrides' AND EXISTS(SELECT 1 FROM target_overrides e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='diet_phases' AND EXISTS(SELECT 1 FROM diet_phases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='weigh_ins' AND EXISTS(SELECT 1 FROM weigh_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='measurements' AND EXISTS(SELECT 1 FROM measurements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='check_ins' AND EXISTS(SELECT 1 FROM check_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_samples' AND EXISTS(SELECT 1 FROM health_samples e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_anchors' AND EXISTS(SELECT 1 FROM health_anchors e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='goals' AND EXISTS(SELECT 1 FROM goals e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='notes' AND EXISTS(SELECT 1 FROM notes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='import_batches' AND EXISTS(SELECT 1 FROM import_batches e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='legacy_id_map' AND EXISTS(SELECT 1 FROM legacy_id_map e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='programs' AND EXISTS(SELECT 1 FROM programs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='program_days' AND EXISTS(SELECT 1 FROM program_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_days' AND EXISTS(SELECT 1 FROM nutrition_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER attachments_owner_update BEFORE UPDATE ON attachments WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscles' AND EXISTS(SELECT 1 FROM muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='equipment' AND EXISTS(SELECT 1 FROM equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='gyms' AND EXISTS(SELECT 1 FROM gyms e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='plate_inventory' AND EXISTS(SELECT 1 FROM plate_inventory e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercises' AND EXISTS(SELECT 1 FROM exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_aliases' AND EXISTS(SELECT 1 FROM exercise_aliases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_muscles' AND EXISTS(SELECT 1 FROM exercise_muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_equipment' AND EXISTS(SELECT 1 FROM exercise_equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_types' AND EXISTS(SELECT 1 FROM set_types e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_folders' AND EXISTS(SELECT 1 FROM routine_folders e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routines' AND EXISTS(SELECT 1 FROM routines e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_exercises' AND EXISTS(SELECT 1 FROM routine_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_sets' AND EXISTS(SELECT 1 FROM routine_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='training_schedule' AND EXISTS(SELECT 1 FROM training_schedule e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workouts' AND EXISTS(SELECT 1 FROM workouts e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_exercises' AND EXISTS(SELECT 1 FROM workout_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_sets' AND EXISTS(SELECT 1 FROM workout_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_revisions' AND EXISTS(SELECT 1 FROM set_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='rest_timers' AND EXISTS(SELECT 1 FROM rest_timers e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='pr_records' AND EXISTS(SELECT 1 FROM pr_records e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscle_targets' AND EXISTS(SELECT 1 FROM muscle_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_sources' AND EXISTS(SELECT 1 FROM food_sources e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='restaurants' AND EXISTS(SELECT 1 FROM restaurants e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='foods' AND EXISTS(SELECT 1 FROM foods e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_servings' AND EXISTS(SELECT 1 FROM food_servings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrients' AND EXISTS(SELECT 1 FROM nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_nutrients' AND EXISTS(SELECT 1 FROM food_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_component_groups' AND EXISTS(SELECT 1 FROM food_component_groups e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_components' AND EXISTS(SELECT 1 FROM food_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_slots' AND EXISTS(SELECT 1 FROM meal_slots e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_logs' AND EXISTS(SELECT 1 FROM meal_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_logs' AND EXISTS(SELECT 1 FROM food_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_log_nutrients' AND EXISTS(SELECT 1 FROM food_log_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipes' AND EXISTS(SELECT 1 FROM recipes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipe_ingredients' AND EXISTS(SELECT 1 FROM recipe_ingredients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_templates' AND EXISTS(SELECT 1 FROM meal_templates e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_template_items' AND EXISTS(SELECT 1 FROM meal_template_items e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='hydration_logs' AND EXISTS(SELECT 1 FROM hydration_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='supplement_logs' AND EXISTS(SELECT 1 FROM supplement_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='safety_acknowledgements' AND EXISTS(SELECT 1 FROM safety_acknowledgements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_targets' AND EXISTS(SELECT 1 FROM nutrition_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='target_overrides' AND EXISTS(SELECT 1 FROM target_overrides e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='diet_phases' AND EXISTS(SELECT 1 FROM diet_phases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='weigh_ins' AND EXISTS(SELECT 1 FROM weigh_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='measurements' AND EXISTS(SELECT 1 FROM measurements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='check_ins' AND EXISTS(SELECT 1 FROM check_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_samples' AND EXISTS(SELECT 1 FROM health_samples e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_anchors' AND EXISTS(SELECT 1 FROM health_anchors e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='goals' AND EXISTS(SELECT 1 FROM goals e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='notes' AND EXISTS(SELECT 1 FROM notes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='import_batches' AND EXISTS(SELECT 1 FROM import_batches e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='legacy_id_map' AND EXISTS(SELECT 1 FROM legacy_id_map e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='programs' AND EXISTS(SELECT 1 FROM programs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='program_days' AND EXISTS(SELECT 1 FROM program_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_days' AND EXISTS(SELECT 1 FROM nutrition_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER events_owner_insert BEFORE INSERT ON events WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscles' AND EXISTS(SELECT 1 FROM muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='equipment' AND EXISTS(SELECT 1 FROM equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='gyms' AND EXISTS(SELECT 1 FROM gyms e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='plate_inventory' AND EXISTS(SELECT 1 FROM plate_inventory e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercises' AND EXISTS(SELECT 1 FROM exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_aliases' AND EXISTS(SELECT 1 FROM exercise_aliases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_muscles' AND EXISTS(SELECT 1 FROM exercise_muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_equipment' AND EXISTS(SELECT 1 FROM exercise_equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_types' AND EXISTS(SELECT 1 FROM set_types e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_folders' AND EXISTS(SELECT 1 FROM routine_folders e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routines' AND EXISTS(SELECT 1 FROM routines e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_exercises' AND EXISTS(SELECT 1 FROM routine_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_sets' AND EXISTS(SELECT 1 FROM routine_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='training_schedule' AND EXISTS(SELECT 1 FROM training_schedule e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workouts' AND EXISTS(SELECT 1 FROM workouts e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_exercises' AND EXISTS(SELECT 1 FROM workout_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_sets' AND EXISTS(SELECT 1 FROM workout_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_revisions' AND EXISTS(SELECT 1 FROM set_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='rest_timers' AND EXISTS(SELECT 1 FROM rest_timers e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='pr_records' AND EXISTS(SELECT 1 FROM pr_records e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscle_targets' AND EXISTS(SELECT 1 FROM muscle_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_sources' AND EXISTS(SELECT 1 FROM food_sources e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='restaurants' AND EXISTS(SELECT 1 FROM restaurants e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='foods' AND EXISTS(SELECT 1 FROM foods e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_servings' AND EXISTS(SELECT 1 FROM food_servings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrients' AND EXISTS(SELECT 1 FROM nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_nutrients' AND EXISTS(SELECT 1 FROM food_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_component_groups' AND EXISTS(SELECT 1 FROM food_component_groups e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_components' AND EXISTS(SELECT 1 FROM food_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_slots' AND EXISTS(SELECT 1 FROM meal_slots e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_logs' AND EXISTS(SELECT 1 FROM meal_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_logs' AND EXISTS(SELECT 1 FROM food_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_log_nutrients' AND EXISTS(SELECT 1 FROM food_log_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipes' AND EXISTS(SELECT 1 FROM recipes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipe_ingredients' AND EXISTS(SELECT 1 FROM recipe_ingredients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_templates' AND EXISTS(SELECT 1 FROM meal_templates e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_template_items' AND EXISTS(SELECT 1 FROM meal_template_items e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='hydration_logs' AND EXISTS(SELECT 1 FROM hydration_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='supplement_logs' AND EXISTS(SELECT 1 FROM supplement_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='safety_acknowledgements' AND EXISTS(SELECT 1 FROM safety_acknowledgements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_targets' AND EXISTS(SELECT 1 FROM nutrition_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='target_overrides' AND EXISTS(SELECT 1 FROM target_overrides e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='diet_phases' AND EXISTS(SELECT 1 FROM diet_phases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='weigh_ins' AND EXISTS(SELECT 1 FROM weigh_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='measurements' AND EXISTS(SELECT 1 FROM measurements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='check_ins' AND EXISTS(SELECT 1 FROM check_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_samples' AND EXISTS(SELECT 1 FROM health_samples e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_anchors' AND EXISTS(SELECT 1 FROM health_anchors e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='goals' AND EXISTS(SELECT 1 FROM goals e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='notes' AND EXISTS(SELECT 1 FROM notes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='import_batches' AND EXISTS(SELECT 1 FROM import_batches e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='legacy_id_map' AND EXISTS(SELECT 1 FROM legacy_id_map e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='programs' AND EXISTS(SELECT 1 FROM programs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='program_days' AND EXISTS(SELECT 1 FROM program_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_days' AND EXISTS(SELECT 1 FROM nutrition_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER events_owner_update BEFORE UPDATE ON events WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscles' AND EXISTS(SELECT 1 FROM muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='equipment' AND EXISTS(SELECT 1 FROM equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='gyms' AND EXISTS(SELECT 1 FROM gyms e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='plate_inventory' AND EXISTS(SELECT 1 FROM plate_inventory e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercises' AND EXISTS(SELECT 1 FROM exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_aliases' AND EXISTS(SELECT 1 FROM exercise_aliases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_muscles' AND EXISTS(SELECT 1 FROM exercise_muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_equipment' AND EXISTS(SELECT 1 FROM exercise_equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_types' AND EXISTS(SELECT 1 FROM set_types e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_folders' AND EXISTS(SELECT 1 FROM routine_folders e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routines' AND EXISTS(SELECT 1 FROM routines e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_exercises' AND EXISTS(SELECT 1 FROM routine_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_sets' AND EXISTS(SELECT 1 FROM routine_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='training_schedule' AND EXISTS(SELECT 1 FROM training_schedule e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workouts' AND EXISTS(SELECT 1 FROM workouts e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_exercises' AND EXISTS(SELECT 1 FROM workout_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_sets' AND EXISTS(SELECT 1 FROM workout_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_revisions' AND EXISTS(SELECT 1 FROM set_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='rest_timers' AND EXISTS(SELECT 1 FROM rest_timers e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='pr_records' AND EXISTS(SELECT 1 FROM pr_records e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscle_targets' AND EXISTS(SELECT 1 FROM muscle_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_sources' AND EXISTS(SELECT 1 FROM food_sources e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='restaurants' AND EXISTS(SELECT 1 FROM restaurants e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='foods' AND EXISTS(SELECT 1 FROM foods e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_servings' AND EXISTS(SELECT 1 FROM food_servings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrients' AND EXISTS(SELECT 1 FROM nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_nutrients' AND EXISTS(SELECT 1 FROM food_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_component_groups' AND EXISTS(SELECT 1 FROM food_component_groups e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_components' AND EXISTS(SELECT 1 FROM food_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_slots' AND EXISTS(SELECT 1 FROM meal_slots e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_logs' AND EXISTS(SELECT 1 FROM meal_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_logs' AND EXISTS(SELECT 1 FROM food_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_log_nutrients' AND EXISTS(SELECT 1 FROM food_log_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipes' AND EXISTS(SELECT 1 FROM recipes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipe_ingredients' AND EXISTS(SELECT 1 FROM recipe_ingredients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_templates' AND EXISTS(SELECT 1 FROM meal_templates e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_template_items' AND EXISTS(SELECT 1 FROM meal_template_items e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='hydration_logs' AND EXISTS(SELECT 1 FROM hydration_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='supplement_logs' AND EXISTS(SELECT 1 FROM supplement_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='safety_acknowledgements' AND EXISTS(SELECT 1 FROM safety_acknowledgements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_targets' AND EXISTS(SELECT 1 FROM nutrition_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='target_overrides' AND EXISTS(SELECT 1 FROM target_overrides e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='diet_phases' AND EXISTS(SELECT 1 FROM diet_phases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='weigh_ins' AND EXISTS(SELECT 1 FROM weigh_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='measurements' AND EXISTS(SELECT 1 FROM measurements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='check_ins' AND EXISTS(SELECT 1 FROM check_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_samples' AND EXISTS(SELECT 1 FROM health_samples e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_anchors' AND EXISTS(SELECT 1 FROM health_anchors e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='goals' AND EXISTS(SELECT 1 FROM goals e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='notes' AND EXISTS(SELECT 1 FROM notes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='import_batches' AND EXISTS(SELECT 1 FROM import_batches e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='legacy_id_map' AND EXISTS(SELECT 1 FROM legacy_id_map e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='programs' AND EXISTS(SELECT 1 FROM programs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='program_days' AND EXISTS(SELECT 1 FROM program_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_days' AND EXISTS(SELECT 1 FROM nutrition_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER notification_jobs_owner_insert BEFORE INSERT ON notification_jobs WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscles' AND EXISTS(SELECT 1 FROM muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='equipment' AND EXISTS(SELECT 1 FROM equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='gyms' AND EXISTS(SELECT 1 FROM gyms e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='plate_inventory' AND EXISTS(SELECT 1 FROM plate_inventory e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercises' AND EXISTS(SELECT 1 FROM exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_aliases' AND EXISTS(SELECT 1 FROM exercise_aliases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_muscles' AND EXISTS(SELECT 1 FROM exercise_muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_equipment' AND EXISTS(SELECT 1 FROM exercise_equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_types' AND EXISTS(SELECT 1 FROM set_types e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_folders' AND EXISTS(SELECT 1 FROM routine_folders e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routines' AND EXISTS(SELECT 1 FROM routines e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_exercises' AND EXISTS(SELECT 1 FROM routine_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_sets' AND EXISTS(SELECT 1 FROM routine_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='training_schedule' AND EXISTS(SELECT 1 FROM training_schedule e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workouts' AND EXISTS(SELECT 1 FROM workouts e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_exercises' AND EXISTS(SELECT 1 FROM workout_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_sets' AND EXISTS(SELECT 1 FROM workout_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_revisions' AND EXISTS(SELECT 1 FROM set_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='rest_timers' AND EXISTS(SELECT 1 FROM rest_timers e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='pr_records' AND EXISTS(SELECT 1 FROM pr_records e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscle_targets' AND EXISTS(SELECT 1 FROM muscle_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_sources' AND EXISTS(SELECT 1 FROM food_sources e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='restaurants' AND EXISTS(SELECT 1 FROM restaurants e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='foods' AND EXISTS(SELECT 1 FROM foods e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_servings' AND EXISTS(SELECT 1 FROM food_servings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrients' AND EXISTS(SELECT 1 FROM nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_nutrients' AND EXISTS(SELECT 1 FROM food_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_component_groups' AND EXISTS(SELECT 1 FROM food_component_groups e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_components' AND EXISTS(SELECT 1 FROM food_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_slots' AND EXISTS(SELECT 1 FROM meal_slots e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_logs' AND EXISTS(SELECT 1 FROM meal_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_logs' AND EXISTS(SELECT 1 FROM food_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_log_nutrients' AND EXISTS(SELECT 1 FROM food_log_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipes' AND EXISTS(SELECT 1 FROM recipes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipe_ingredients' AND EXISTS(SELECT 1 FROM recipe_ingredients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_templates' AND EXISTS(SELECT 1 FROM meal_templates e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_template_items' AND EXISTS(SELECT 1 FROM meal_template_items e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='hydration_logs' AND EXISTS(SELECT 1 FROM hydration_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='supplement_logs' AND EXISTS(SELECT 1 FROM supplement_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='safety_acknowledgements' AND EXISTS(SELECT 1 FROM safety_acknowledgements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_targets' AND EXISTS(SELECT 1 FROM nutrition_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='target_overrides' AND EXISTS(SELECT 1 FROM target_overrides e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='diet_phases' AND EXISTS(SELECT 1 FROM diet_phases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='weigh_ins' AND EXISTS(SELECT 1 FROM weigh_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='measurements' AND EXISTS(SELECT 1 FROM measurements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='check_ins' AND EXISTS(SELECT 1 FROM check_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_samples' AND EXISTS(SELECT 1 FROM health_samples e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_anchors' AND EXISTS(SELECT 1 FROM health_anchors e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='goals' AND EXISTS(SELECT 1 FROM goals e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='notes' AND EXISTS(SELECT 1 FROM notes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='import_batches' AND EXISTS(SELECT 1 FROM import_batches e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='legacy_id_map' AND EXISTS(SELECT 1 FROM legacy_id_map e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='programs' AND EXISTS(SELECT 1 FROM programs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='program_days' AND EXISTS(SELECT 1 FROM program_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_days' AND EXISTS(SELECT 1 FROM nutrition_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER notification_jobs_owner_update BEFORE UPDATE ON notification_jobs WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscles' AND EXISTS(SELECT 1 FROM muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='equipment' AND EXISTS(SELECT 1 FROM equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='gyms' AND EXISTS(SELECT 1 FROM gyms e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='plate_inventory' AND EXISTS(SELECT 1 FROM plate_inventory e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercises' AND EXISTS(SELECT 1 FROM exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_aliases' AND EXISTS(SELECT 1 FROM exercise_aliases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_muscles' AND EXISTS(SELECT 1 FROM exercise_muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_equipment' AND EXISTS(SELECT 1 FROM exercise_equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_types' AND EXISTS(SELECT 1 FROM set_types e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_folders' AND EXISTS(SELECT 1 FROM routine_folders e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routines' AND EXISTS(SELECT 1 FROM routines e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_exercises' AND EXISTS(SELECT 1 FROM routine_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_sets' AND EXISTS(SELECT 1 FROM routine_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='training_schedule' AND EXISTS(SELECT 1 FROM training_schedule e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workouts' AND EXISTS(SELECT 1 FROM workouts e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_exercises' AND EXISTS(SELECT 1 FROM workout_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_sets' AND EXISTS(SELECT 1 FROM workout_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_revisions' AND EXISTS(SELECT 1 FROM set_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='rest_timers' AND EXISTS(SELECT 1 FROM rest_timers e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='pr_records' AND EXISTS(SELECT 1 FROM pr_records e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscle_targets' AND EXISTS(SELECT 1 FROM muscle_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_sources' AND EXISTS(SELECT 1 FROM food_sources e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='restaurants' AND EXISTS(SELECT 1 FROM restaurants e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='foods' AND EXISTS(SELECT 1 FROM foods e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_servings' AND EXISTS(SELECT 1 FROM food_servings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrients' AND EXISTS(SELECT 1 FROM nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_nutrients' AND EXISTS(SELECT 1 FROM food_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_component_groups' AND EXISTS(SELECT 1 FROM food_component_groups e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_components' AND EXISTS(SELECT 1 FROM food_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_slots' AND EXISTS(SELECT 1 FROM meal_slots e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_logs' AND EXISTS(SELECT 1 FROM meal_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_logs' AND EXISTS(SELECT 1 FROM food_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_log_nutrients' AND EXISTS(SELECT 1 FROM food_log_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipes' AND EXISTS(SELECT 1 FROM recipes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipe_ingredients' AND EXISTS(SELECT 1 FROM recipe_ingredients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_templates' AND EXISTS(SELECT 1 FROM meal_templates e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_template_items' AND EXISTS(SELECT 1 FROM meal_template_items e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='hydration_logs' AND EXISTS(SELECT 1 FROM hydration_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='supplement_logs' AND EXISTS(SELECT 1 FROM supplement_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='safety_acknowledgements' AND EXISTS(SELECT 1 FROM safety_acknowledgements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_targets' AND EXISTS(SELECT 1 FROM nutrition_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='target_overrides' AND EXISTS(SELECT 1 FROM target_overrides e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='diet_phases' AND EXISTS(SELECT 1 FROM diet_phases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='weigh_ins' AND EXISTS(SELECT 1 FROM weigh_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='measurements' AND EXISTS(SELECT 1 FROM measurements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='check_ins' AND EXISTS(SELECT 1 FROM check_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_samples' AND EXISTS(SELECT 1 FROM health_samples e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_anchors' AND EXISTS(SELECT 1 FROM health_anchors e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='goals' AND EXISTS(SELECT 1 FROM goals e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='notes' AND EXISTS(SELECT 1 FROM notes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='import_batches' AND EXISTS(SELECT 1 FROM import_batches e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='legacy_id_map' AND EXISTS(SELECT 1 FROM legacy_id_map e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='programs' AND EXISTS(SELECT 1 FROM programs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='program_days' AND EXISTS(SELECT 1 FROM program_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_days' AND EXISTS(SELECT 1 FROM nutrition_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER notes_owner_insert BEFORE INSERT ON notes WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscles' AND EXISTS(SELECT 1 FROM muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='equipment' AND EXISTS(SELECT 1 FROM equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='gyms' AND EXISTS(SELECT 1 FROM gyms e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='plate_inventory' AND EXISTS(SELECT 1 FROM plate_inventory e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercises' AND EXISTS(SELECT 1 FROM exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_aliases' AND EXISTS(SELECT 1 FROM exercise_aliases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_muscles' AND EXISTS(SELECT 1 FROM exercise_muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_equipment' AND EXISTS(SELECT 1 FROM exercise_equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_types' AND EXISTS(SELECT 1 FROM set_types e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_folders' AND EXISTS(SELECT 1 FROM routine_folders e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routines' AND EXISTS(SELECT 1 FROM routines e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_exercises' AND EXISTS(SELECT 1 FROM routine_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_sets' AND EXISTS(SELECT 1 FROM routine_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='training_schedule' AND EXISTS(SELECT 1 FROM training_schedule e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workouts' AND EXISTS(SELECT 1 FROM workouts e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_exercises' AND EXISTS(SELECT 1 FROM workout_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_sets' AND EXISTS(SELECT 1 FROM workout_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_revisions' AND EXISTS(SELECT 1 FROM set_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='rest_timers' AND EXISTS(SELECT 1 FROM rest_timers e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='pr_records' AND EXISTS(SELECT 1 FROM pr_records e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscle_targets' AND EXISTS(SELECT 1 FROM muscle_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_sources' AND EXISTS(SELECT 1 FROM food_sources e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='restaurants' AND EXISTS(SELECT 1 FROM restaurants e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='foods' AND EXISTS(SELECT 1 FROM foods e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_servings' AND EXISTS(SELECT 1 FROM food_servings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrients' AND EXISTS(SELECT 1 FROM nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_nutrients' AND EXISTS(SELECT 1 FROM food_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_component_groups' AND EXISTS(SELECT 1 FROM food_component_groups e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_components' AND EXISTS(SELECT 1 FROM food_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_slots' AND EXISTS(SELECT 1 FROM meal_slots e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_logs' AND EXISTS(SELECT 1 FROM meal_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_logs' AND EXISTS(SELECT 1 FROM food_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_log_nutrients' AND EXISTS(SELECT 1 FROM food_log_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipes' AND EXISTS(SELECT 1 FROM recipes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipe_ingredients' AND EXISTS(SELECT 1 FROM recipe_ingredients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_templates' AND EXISTS(SELECT 1 FROM meal_templates e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_template_items' AND EXISTS(SELECT 1 FROM meal_template_items e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='hydration_logs' AND EXISTS(SELECT 1 FROM hydration_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='supplement_logs' AND EXISTS(SELECT 1 FROM supplement_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='safety_acknowledgements' AND EXISTS(SELECT 1 FROM safety_acknowledgements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_targets' AND EXISTS(SELECT 1 FROM nutrition_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='target_overrides' AND EXISTS(SELECT 1 FROM target_overrides e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='diet_phases' AND EXISTS(SELECT 1 FROM diet_phases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='weigh_ins' AND EXISTS(SELECT 1 FROM weigh_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='measurements' AND EXISTS(SELECT 1 FROM measurements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='check_ins' AND EXISTS(SELECT 1 FROM check_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_samples' AND EXISTS(SELECT 1 FROM health_samples e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_anchors' AND EXISTS(SELECT 1 FROM health_anchors e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='goals' AND EXISTS(SELECT 1 FROM goals e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='notes' AND EXISTS(SELECT 1 FROM notes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='import_batches' AND EXISTS(SELECT 1 FROM import_batches e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='legacy_id_map' AND EXISTS(SELECT 1 FROM legacy_id_map e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='programs' AND EXISTS(SELECT 1 FROM programs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='program_days' AND EXISTS(SELECT 1 FROM program_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_days' AND EXISTS(SELECT 1 FROM nutrition_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE TRIGGER notes_owner_update BEFORE UPDATE ON notes WHEN NEW.owner_id IS NOT NULL AND NOT ((NEW.owner_table='accounts' AND EXISTS(SELECT 1 FROM accounts e WHERE e.id=NEW.owner_id AND e.id=NEW.account_id)) OR (NEW.owner_table='devices' AND EXISTS(SELECT 1 FROM devices e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='settings' AND EXISTS(SELECT 1 FROM settings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='consents' AND EXISTS(SELECT 1 FROM consents e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='events' AND EXISTS(SELECT 1 FROM events e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='chart_preferences' AND EXISTS(SELECT 1 FROM chart_preferences e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscles' AND EXISTS(SELECT 1 FROM muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='equipment' AND EXISTS(SELECT 1 FROM equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='gyms' AND EXISTS(SELECT 1 FROM gyms e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='plate_inventory' AND EXISTS(SELECT 1 FROM plate_inventory e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercises' AND EXISTS(SELECT 1 FROM exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_aliases' AND EXISTS(SELECT 1 FROM exercise_aliases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_muscles' AND EXISTS(SELECT 1 FROM exercise_muscles e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='exercise_equipment' AND EXISTS(SELECT 1 FROM exercise_equipment e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_types' AND EXISTS(SELECT 1 FROM set_types e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_folders' AND EXISTS(SELECT 1 FROM routine_folders e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routines' AND EXISTS(SELECT 1 FROM routines e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_exercises' AND EXISTS(SELECT 1 FROM routine_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='routine_sets' AND EXISTS(SELECT 1 FROM routine_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='training_schedule' AND EXISTS(SELECT 1 FROM training_schedule e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workouts' AND EXISTS(SELECT 1 FROM workouts e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_exercises' AND EXISTS(SELECT 1 FROM workout_exercises e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='workout_sets' AND EXISTS(SELECT 1 FROM workout_sets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='set_revisions' AND EXISTS(SELECT 1 FROM set_revisions e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='rest_timers' AND EXISTS(SELECT 1 FROM rest_timers e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='pr_records' AND EXISTS(SELECT 1 FROM pr_records e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='muscle_targets' AND EXISTS(SELECT 1 FROM muscle_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_sources' AND EXISTS(SELECT 1 FROM food_sources e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='restaurants' AND EXISTS(SELECT 1 FROM restaurants e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='foods' AND EXISTS(SELECT 1 FROM foods e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_servings' AND EXISTS(SELECT 1 FROM food_servings e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrients' AND EXISTS(SELECT 1 FROM nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_nutrients' AND EXISTS(SELECT 1 FROM food_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_component_groups' AND EXISTS(SELECT 1 FROM food_component_groups e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_components' AND EXISTS(SELECT 1 FROM food_components e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_slots' AND EXISTS(SELECT 1 FROM meal_slots e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_logs' AND EXISTS(SELECT 1 FROM meal_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_logs' AND EXISTS(SELECT 1 FROM food_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='food_log_nutrients' AND EXISTS(SELECT 1 FROM food_log_nutrients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipes' AND EXISTS(SELECT 1 FROM recipes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='recipe_ingredients' AND EXISTS(SELECT 1 FROM recipe_ingredients e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_templates' AND EXISTS(SELECT 1 FROM meal_templates e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='meal_template_items' AND EXISTS(SELECT 1 FROM meal_template_items e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='hydration_logs' AND EXISTS(SELECT 1 FROM hydration_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='supplement_logs' AND EXISTS(SELECT 1 FROM supplement_logs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='safety_acknowledgements' AND EXISTS(SELECT 1 FROM safety_acknowledgements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_targets' AND EXISTS(SELECT 1 FROM nutrition_targets e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='target_overrides' AND EXISTS(SELECT 1 FROM target_overrides e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='diet_phases' AND EXISTS(SELECT 1 FROM diet_phases e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='weigh_ins' AND EXISTS(SELECT 1 FROM weigh_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='measurements' AND EXISTS(SELECT 1 FROM measurements e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='check_ins' AND EXISTS(SELECT 1 FROM check_ins e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_samples' AND EXISTS(SELECT 1 FROM health_samples e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='health_anchors' AND EXISTS(SELECT 1 FROM health_anchors e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='goals' AND EXISTS(SELECT 1 FROM goals e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='notes' AND EXISTS(SELECT 1 FROM notes e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='import_batches' AND EXISTS(SELECT 1 FROM import_batches e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='legacy_id_map' AND EXISTS(SELECT 1 FROM legacy_id_map e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='export_jobs' AND EXISTS(SELECT 1 FROM export_jobs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='programs' AND EXISTS(SELECT 1 FROM programs e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='program_days' AND EXISTS(SELECT 1 FROM program_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='cached_insights' AND EXISTS(SELECT 1 FROM cached_insights e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='nutrition_days' AND EXISTS(SELECT 1 FROM nutrition_days e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id)) OR (NEW.owner_table='sync_context' AND EXISTS(SELECT 1 FROM sync_context e WHERE e.id=NEW.owner_id AND e.account_id=NEW.account_id))) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;
CREATE INDEX exercises_search_name ON exercises(account_id, normalized_name);
CREATE INDEX exercise_aliases_search ON exercise_aliases(account_id, normalized_alias);
CREATE INDEX foods_search_name ON foods(account_id, normalized_name);
CREATE INDEX foods_barcode ON foods(account_id, barcode);
CREATE INDEX workouts_status ON workouts(account_id,status,occurred_at);
CREATE TRIGGER nutrition_targets_safety_insert BEFORE INSERT ON nutrition_targets
WHEN (NEW.calories_kcal<NEW.safety_floor_kcal AND NOT EXISTS(SELECT 1 FROM safety_acknowledgements a WHERE a.id=NEW.clinician_ack_id AND a.account_id=NEW.account_id AND a.kind='clinician_floor_override' AND a.clinician_override_confirmed=1 AND a.deleted_at IS NULL AND (a.expires_at IS NULL OR a.expires_at>NEW.updated_at)))
 OR (NEW.safety_floor_kcal<1500 AND COALESCE((SELECT bmr_sex FROM accounts WHERE id=NEW.account_id),'unspecified')<>'female')
BEGIN SELECT RAISE(ABORT,'Target requires the applicable safety floor or an explicit current clinician acknowledgement'); END;
CREATE TRIGGER nutrition_targets_safety_update BEFORE UPDATE ON nutrition_targets
WHEN (NEW.calories_kcal<NEW.safety_floor_kcal AND NOT EXISTS(SELECT 1 FROM safety_acknowledgements a WHERE a.id=NEW.clinician_ack_id AND a.account_id=NEW.account_id AND a.kind='clinician_floor_override' AND a.clinician_override_confirmed=1 AND a.deleted_at IS NULL AND (a.expires_at IS NULL OR a.expires_at>NEW.updated_at)))
 OR (NEW.safety_floor_kcal<1500 AND COALESCE((SELECT bmr_sex FROM accounts WHERE id=NEW.account_id),'unspecified')<>'female')
BEGIN SELECT RAISE(ABORT,'Target requires the applicable safety floor or an explicit current clinician acknowledgement'); END;
CREATE TRIGGER target_overrides_safety_insert BEFORE INSERT ON target_overrides
WHEN (NEW.calories_kcal<NEW.safety_floor_kcal AND NOT EXISTS(SELECT 1 FROM safety_acknowledgements a WHERE a.id=NEW.clinician_ack_id AND a.account_id=NEW.account_id AND a.kind='clinician_floor_override' AND a.clinician_override_confirmed=1 AND a.deleted_at IS NULL AND (a.expires_at IS NULL OR a.expires_at>NEW.updated_at)))
 OR (NEW.safety_floor_kcal<1500 AND COALESCE((SELECT bmr_sex FROM accounts WHERE id=NEW.account_id),'unspecified')<>'female')
BEGIN SELECT RAISE(ABORT,'Target requires the applicable safety floor or an explicit current clinician acknowledgement'); END;
CREATE TRIGGER target_overrides_safety_update BEFORE UPDATE ON target_overrides
WHEN (NEW.calories_kcal<NEW.safety_floor_kcal AND NOT EXISTS(SELECT 1 FROM safety_acknowledgements a WHERE a.id=NEW.clinician_ack_id AND a.account_id=NEW.account_id AND a.kind='clinician_floor_override' AND a.clinician_override_confirmed=1 AND a.deleted_at IS NULL AND (a.expires_at IS NULL OR a.expires_at>NEW.updated_at)))
 OR (NEW.safety_floor_kcal<1500 AND COALESCE((SELECT bmr_sex FROM accounts WHERE id=NEW.account_id),'unspecified')<>'female')
BEGIN SELECT RAISE(ABORT,'Target requires the applicable safety floor or an explicit current clinician acknowledgement'); END;
CREATE VIEW current_workout_sets AS
SELECT r.*, s.workout_exercise_id, s.position FROM workout_sets s JOIN set_revisions r ON r.account_id=s.account_id AND r.id=s.current_revision_id AND r.set_id=s.id
WHERE s.deleted_at IS NULL AND r.deleted_at IS NULL AND r.action<>'tombstone';
CREATE VIEW nutrition_daily_raw AS
SELECT f.account_id,f.local_date,COUNT(*) AS sample_count,SUM(f.calories_kcal) AS calories_kcal,SUM(f.protein_g) AS protein_g,SUM(f.carbs_g) AS carbs_g,SUM(f.fat_g) AS fat_g
FROM food_logs f JOIN meal_logs m ON m.account_id=f.account_id AND m.id=f.meal_log_id
WHERE f.deleted_at IS NULL AND m.deleted_at IS NULL AND m.state='eaten' GROUP BY f.account_id,f.local_date;
CREATE VIEW training_muscle_daily_raw AS
SELECT r.account_id,r.local_date,em.muscle_id,
 SUM(CASE WHEN st.counts_hard_sets=1 AND (COALESCE(r.rir,10-r.rpe) IS NULL OR COALESCE(r.rir,10-r.rpe)<=4) THEN em.contribution ELSE 0 END) AS fractional_hard_sets,
 SUM(CASE WHEN st.counts_volume=1 THEN COALESCE(r.load_kg,MAX(0,COALESCE(r.bodyweight_kg,0)+COALESCE(r.added_kg,0)-COALESCE(r.assistance_kg,0)),0)*COALESCE(r.reps,0)*em.contribution*(CASE r.counts_both_hands WHEN 1 THEN 2 ELSE 1 END) ELSE 0 END) AS volume_kg,
 COUNT(DISTINCT we.workout_id) AS sessions
FROM current_workout_sets r JOIN workout_exercises we ON we.account_id=r.account_id AND we.id=r.workout_exercise_id
JOIN workouts w ON w.account_id=we.account_id AND w.id=we.workout_id
JOIN set_types st ON st.account_id=r.account_id AND st.id=r.set_type_id
JOIN exercise_muscles em ON em.account_id=we.account_id AND em.exercise_id=we.exercise_id
WHERE r.completed=1 AND we.deleted_at IS NULL AND w.deleted_at IS NULL AND we.skipped=0 AND em.deleted_at IS NULL
GROUP BY r.account_id,r.local_date,em.muscle_id;
CREATE VIEW body_daily_raw AS
SELECT account_id,local_date,COUNT(*) AS sample_count,AVG(weight_kg) AS mean_weight_kg,MIN(weight_kg) AS min_weight_kg,MAX(weight_kg) AS max_weight_kg
FROM weigh_ins WHERE deleted_at IS NULL GROUP BY account_id,local_date;
PRAGMA user_version = 1;
COMMIT;
