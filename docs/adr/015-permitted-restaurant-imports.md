# ADR-015: Permission-gated restaurant menu imports

Accepted 2026-10-15. Incremental FUEL-13 infrastructure; real menu coverage and release flag remain off.

## Decision

Use a strict, bounded, versioned JSON registry for maintainer-supplied menu data. Require explicit source URL, retrieval date, attribution and a permission reference tied to an actual rights review. The parser checks declarations, not the truth of legal approval. Unknown fields, duplicate keys/IDs, orphan sources, unsupported categories and missing/nonfinite nutrition fail closed. Each item's complete kcal/protein/total carbohydrate/fat describes exactly its named serving; grams are optional and never inferred.

A deterministic, network-free CLI validates, previews, hashes input bytes and atomically stages normalized output. Fictional examples require --fixture and keep their fixture status in output. Production readers reject fictional data; DEBUG fixtures additionally require the isolated-memory testing flag. The shipped production registry is honestly empty. FUEL-13 stays off in FeatureCatalog until source and release readiness are reviewed.

Browse imported values without copying them into SwiftData. A review creates only an editable personal FoodItem/DiaryEntry with source identity/date in the existing serving text and restaurant source type. User-created items stay in the current personal restaurant store and retain Edit/Delete actions. Starting the first custom item may create an empty personal restaurant identity; canceling its item draft leaves that identity available.

## Consequences

No new real menu tables, artwork or proprietary dataset are imported. Existing sample menus/builders remain labeled samples and are not upgraded silently. New chain nutrition is not claimed current or complete. This initial import format supports flat categorized items; licensed component/modifier menus and source-update reconciliation remain backlog work. Public source updates cannot change earlier private logs. No hosted API, account, camera upload or paid provider is needed for the prepared importer.
