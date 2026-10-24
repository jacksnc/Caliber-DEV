-- Additive rehearsal-only migration. Never applied to the live SwiftData or Foundation locator.
-- Existing v4 manifests retain their exact v1 target digest. No source payload/hash/ID is rewritten.
ALTER TABLE projection_manifest ADD COLUMN digest_version INTEGER NOT NULL DEFAULT 1 CHECK(digest_version IN(1,2));
CREATE TABLE projection_saved_meal_metadata (
    id TEXT PRIMARY KEY NOT NULL REFERENCES meal_templates(id) DEFERRABLE INITIALLY DEFERRED,
    payload_version INTEGER NOT NULL CHECK(payload_version=2),
    servings REAL NOT NULL CHECK(servings>0 AND servings<=1.7976931348623157e308),
    cooked_yield_grams REAL CHECK(cooked_yield_grams>0 AND cooked_yield_grams<=1.7976931348623157e308),
    raw_batch_grams REAL CHECK(raw_batch_grams>0 AND raw_batch_grams<=1.7976931348623157e308)
) STRICT;
