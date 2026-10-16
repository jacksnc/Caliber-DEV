# ADR-014: Offline packaged-food reference collection

Accepted 2026-10-15. Scope: barcode reference lookup; no private or hosted migration.

## Decision

Bundle a separate read-only USDA Branded April 2026 SQLite catalog with 50,000 checksum-valid, US-market source products. Preserve a provider-explicit 100 g or 100 mL nutrient basis and matching label serving. Select latest publication/modification before eligibility; exclude ties, incomplete nutrition and unsupported units/preparations. Never fall back to older nutrition when the latest source record is incomplete. Document bounded editorial selection and exclusions in the manifest.

Reuse GRDB and the existing BarcodeService/review interfaces. Validate hash/schema/source/counts off the main actor once. Read local products first; an absent product may reach a configured provider only with its separate current permission and an uncanceled request generation. No camera image or personal diary is sent.

## Consequences

Local hits need no account, API key, provider contact or network permission. Initial coverage is deliberately incomplete and source labels can be old. The review shows source/release and asks the user to compare the present package. Source kcal are retained; no missing nutrient becomes zero, no density is inferred, and mL never supplies gram mass. Each saved log is an independent personal snapshot with editable values. Public source updates never recalculate existing logs.

The optional Open Food Facts adapter remains disabled pending provider/contact/terms setup. Source text fields are CC0 FoodData Central data; no package images, logos or marketing/ingredient database is redistributed. Hashes detect resource mismatch; they are not encryption or a guarantee of present label correctness.
