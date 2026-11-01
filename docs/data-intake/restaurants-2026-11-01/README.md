# Gemini restaurant archive intake — November 1, 2026

Disposition: **review material; not approved for production import**.
Original archive stays at `/Users/jcrock/Desktop/restaurant-nutrition-data.zip`.
SHA-256: `f88087d8376759bc2073c4f3ef6b106a9c16243b1fac9a73ac54a619c2058958`.
No archive Python program was executed. No app resource, feature flag, personal
store, provider, or schema was changed. Raw nutrition data is not committed here.

## What it contains

The JSON contains 200 sources, 200 restaurants and 1,839 items. The per-chain
JSON files match the aggregate item arrays, all four nutrient fields are finite
nonnegative numbers, and the reported item count agrees with the handoff.
There are 4–34 entries per restaurant; 144 restaurants have fewer than 10.
The handoff's 100% status describes populated chain records, not verified full
menu coverage. No captured official PDF or HTML documents are in this archive.
The retrieval dates and verification claims are supplied assertions, not an
independently reproduced acquisition trail.

See [audit.json](audit.json) for reproducible findings and
[chain-inventory.csv](chain-inventory.csv) for every chain, source URL and count.

## Import blockers

1. All 200 source statuses are `official-public`, with publication descriptions
   rather than completed reuse-rights reviews. Caliber's existing AGENTS.md and
   [ADR-015](../../adr/015-permitted-restaurant-imports.md) require documented
   permission and review. This is an unmet project gate, not a legal determination
   about the underlying facts. Never fix it by changing a status to `approved`.

   Clarification after the owner's question: factual nutrient numbers are not
   themselves protected by U.S. copyright; a brand permission letter is not
   automatically required for every fact. The [U.S. Copyright Office explains
   that facts are unprotected](https://www.copyright.gov/help/faq/faq-protect.html),
   while original expression can be protected. A documented source review may
   establish a facts-only basis rather than an explicit license. Source access
   conditions and any copied descriptions, artwork or creative compilation
   still require their own review. This intake does not claim legal clearance
   for 200 uninspected sources or grant exclusive rights over the numbers.
2. The existing importer caps one catalog at 100 sources/restaurants. The raw
   archive fails that bound. A single-chain probe then correctly fails the
   unapproved source status. Do not raise the bounds just to admit unreviewed data.
3. Item field names use snake_case; Caliber's JSON importer expects its documented
   camelCase keys. The CSV path already supports snake_case, but it still needs
   separately reviewed source metadata and category mapping.
4. Raw categories such as Proteins, Grains & Beans, Side Menu Dips and Side Menu
   Items need explicit app mappings. Chipotle ingredients are components, not
   ordinary entrées. Flat rows have no permitted-double-portion/modifier rules;
   the ingredient builder cannot be inferred from category text.
5. `gc-southern-green-beans` occurs in both Golden Chick and Golden Corral with
   different names, servings and macros. Global IDs must be namespaced per chain.
6. A serving description or ounce value is not evidence of the supplied grams.
   Reverify mass independently, especially fluid ounces and bone-in cuts; preserve
   unknown grams as null. Never convert volume to mass without source evidence.

## Official-source spot check

These are review discrepancies, not an automatic replacement dataset. Nutrition
can change; every row still needs the current source, serving inclusion and date.
No full-menu accuracy percentage is claimed from this small spot check.

| Archive item | Supplied record | Official published reference | Required follow-up |
|---|---|---|---|
| Chipotle Black Beans | Fat 2 g | Fat 1.5 g | Preserve the published decimal instead of rounding to an integer. |
| Chipotle Queso Blanco (Side) | Protein 6 g; carbs 4 g | Protein 10 g; carbs 7 g, for the 4 oz side | Resolve the nutrition row/portion mismatch. |
| Chipotle Honey Vinaigrette | Protein 0 g; carbs 12 g | Protein 1 g; carbs 18 g, for 2 fl oz | Total carbohydrate appears confused with the guide's sugar value. Recheck, including unsupported mass. |
| LongHorn Texas Tonion with dip | 1,180 kcal; name includes dip | Tonion 1,180 kcal; dip separately 500 kcal | Clarify included components; do not label the base as including the dip. |
| LongHorn Wild West Shrimp with dip | 970 kcal; name includes dip | Shrimp 970 kcal; ranch separately 230 kcal | Clarify the item and sauce separately. |

Chipotle reference: [official US nutrition PDF, March 2025 filename, nutrition
table on page 2](https://www.chipotle.com/content/dam/chipotle/menu/nutrition/US-Nutrition-Facts-Paper-Menu-3-2025.pdf).
This is a published reference; it is not proof that every row equals today's
location-specific calculator. LongHorn reference: [official guide, valid August
10, 2026, appetizers on page 6](https://media.longhornsteakhouse.com/en_us/pdf/nutrition_allergen_guide.pdf),
linked from its [nutrition page](https://www.longhornsteakhouse.com/nutrition).
Both were inspected on November 1, 2026.

## Next usable delivery

Start with Chipotle and LongHorn. Supply one exact official document/version per
chain, row/page references, explicit inclusion of sides/dips, preserved decimals,
and a documented rights review. Independently verify the rows, then adapt a
reviewed subset through the existing CSV importer. Keep the 200-chain list as a
coverage queue. The next source pass is prepared in [RECHECK_PROMPT.md](RECHECK_PROMPT.md);
it has not been sent to another app.

## Reproduce

```sh
python3 docs/data-intake/restaurants-2026-11-01/audit_archive.py \
  /Users/jcrock/Desktop/restaurant-nutrition-data.zip \
  --output /tmp/caliber-restaurant-audit
python3 -m unittest discover -s scripts -p 'test_import_restaurant_menus.py'
python3 -m unittest discover -s scripts -p 'test_prepare_restaurant_menu_csv.py'
python3 scripts/lint_foundation.py
```

The auditor reads only ZIP/JSON members, writes reports outside app resources,
and deliberately exercises the existing permission/bounds checks without
modifying the source declarations. Successful structural checks do not certify
source nutrition or permissions. No Xcode run is relevant to this docs/intake
change; application code and assets are unchanged.
