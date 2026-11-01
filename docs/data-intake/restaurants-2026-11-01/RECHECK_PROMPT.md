# Prepared Gemini correction request (not dispatched)

Recheck your restaurant-nutrition-data.zip against the attached intake report.
Start with Chipotle and LongHorn only. Work in a separate data folder; do not
modify Caliber's app, flags, importer permission checks, providers or user data.

For each row provide the exact official source URL, document date/version,
page/table row, original serving text and whether sauces/sides are included.
Preserve decimal nutrients and reported calories. Keep unknown serving grams
null; fluid ounces cannot supply grams. Do not substitute sugar for total carbs.
Separate LongHorn base appetizers and dips where the guide lists them separately.
Keep source categories and propose app categories in a separate mapping field.
Distinguish Chipotle components from menu items and document which components
support double portions; do not infer those rules from protein names.

Fix the cross-chain gc-southern-green-beans ID collision by using stable
restaurant namespaces. Do not call a chain's full menu complete just because
some entries exist. Report inspected coverage and missing categories explicitly.

Treat official-public as pending Caliber's rights review. Supply actual reuse
terms or permission evidence if available; do not invent approval or relabel
sources approved. If access is blocked, mark the row unverified instead of
guessing nutrition, mass or provenance. Include a correction log and clearly
identify rows that were not independently checked.
