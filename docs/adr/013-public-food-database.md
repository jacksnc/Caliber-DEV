# ADR-013: Separate indexed public food catalog

Status: accepted for this local checkpoint, 2026-10-15. Imports prepared 2026-10-14.

## Problem and decision

The 311-food Foundation catalog scans a small JSON document on each search and has no household measure weights. Broader food coverage needs indexed lookup, traceable source versions and trustworthy portion metadata. Replacing its production read path is justified by that increase in coverage; existing personal models and calculation behavior remain intact.

Bundle `FoodDatabase.sqlite` and its hash/count manifest. Use the existing GRDB dependency through `CaliberDatabase.ReferenceFoodCatalog`. Its catalog_sources, catalog_foods, catalog_servings, catalog_metadata and FTS5 food_search tables are exclusively public reference data. Foundation April 2026 contributes 311 complete foods and 361 portions. SR Legacy April 2018 contributes 7,793 complete foods and 14,431 portions. Do not call historical reference records current package labels or restaurant menus.

Keep FDC IDs and distinct preparations. Preserve every original Foundation ID, name, publication date, energy-method choice and macro value. Normalize macros per 100 g without filling omissions with zero. A source portion's gramWeight already represents the full displayed amount, including a label such as 2 tbsp. Missing or ambiguous weights never establish density or a conversion for another food.

The bounded importer verifies exact input hashes before parsing. It writes both outputs to temporary files, validates integrity/foreign keys/FTS and restores prior outputs on handled replacement failure. A process interruption between the two atomic replacements can leave a mismatch; the app refuses that mismatch through the manifest hash. Byte reproduction requires the manifest's SQLite writer version. The resource is portable across compatible SQLite readers, not guaranteed byte-identical when rebuilt by a different SQLite version.

The reader verifies file bounds/hash, expected source pins, SQLite schema/index identities, nutrients, portions, relationships and search-document correspondence. It opens read-only, never creates a migration or sidecar, and exposes typed values. Queries use normalized token prefixes, bound parameters and a 200-result maximum. Exact words/phrases outrank prefixes, Foundation wins equivalent-relevance ties, and stable name/ID order resolves the rest.

Food screens share an asynchronous, off-main resource validation and then short synchronous indexed reads. A loading state retains manual entry. An internal synchronous initializer remains for injected tests/compatibility consumers. The unchanged Foundation JSON remains a reproduction/compatibility fixture rather than the production search backend.

## Personal data and consequences

Logging continues to create an independent editable FoodItem/DiaryEntry snapshot. Household count/label and resolved grams fit the existing serving text. Foundation and personal favorites remain compatible; SR Legacy adds a validated namespace to the same bounded preference. No SwiftData model, private canonical database, rehearsal locator, hosted account, barcode provider or licensed restaurant dataset changes.

This establishes a source catalog, not all of FUEL-02/03. Structured personal provenance, micronutrients, corrections/error reports, source update/removal reconciliation, arbitrary household/volume/yield conversion, licensed menus and packaged coverage remain open. Physical-device budgets, minimum-OS runtime and full accessibility checks still require evidence. Checksums and a separate file are not encryption, authentication of arbitrary imports, or legal approval of other datasets.
