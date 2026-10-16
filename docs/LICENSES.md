# Data, code and media license ledger

Phase 0 · checked 2026-10-07. No new dataset, exercise image, restaurant artwork or competitor asset was downloaded or bundled. Candidate eligibility is separate from a completed rights review. Existing project data still needs a record-by-record provenance audit.

| Candidate / primary source | What was verified | Approval status and remaining work |
| --- | --- | --- |
| [USDA FoodData Central API guide](https://fdc.nal.usda.gov/api-guide/) | USDA describes FDC data as public domain and released under CC0 1.0; attribution is requested. | Candidate for nutrition lookup. Record FDC IDs, data type, release/retrieval date and serving basis; include USDA attribution. API access conditions and data quality are separate checks. |
| [Open Food Facts API specification](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/ref/api.yaml) | Official API metadata declares data ODbL-1.0. [API introduction](https://openfoodfacts.github.io/openfoodfacts-server/api/) points to reuse terms and licensing guidance. | Conditional: attribution/share-alike and combined/derivative database design require review before ingestion/distribution. Keep source namespace and manifests; never assume private user diaries should be published. |
| [OFF dataset documentation](https://github.com/openfoodfacts/openfoodfacts-ai/blob/develop/data-sets.md) | Official documentation distinguishes ODbL data from CC-BY-SA images, but does not specify an image-license version on this page. | Images **not approved**. Resolve exact version, attribution, modifications, packaging/trademark rights and individual asset provenance. Direct OFF terms/wiki pages were blocked during this review; full terms still need human verification. |
| [free-exercise-db license](https://github.com/yuhonas/free-exercise-db/blob/main/LICENSE.md) | Repository's license file declares the Unlicense/public-domain dedication for software. | Candidate only. A repository-level declaration does not establish every exercise image's upstream chain of rights. Pin commit and audit metadata/media origin; otherwise use original text/art. No import approved. |
| Official restaurant nutrition/menu references | No restaurant-wide redistribution license was verified in this Phase 0 review. | Nutrition facts, menu descriptions, photos, logos and site terms are different issues. Keep factual provenance; do not scrape or copy menu artwork/text wholesale without rights review. |
| Standards / reference coefficients | DOTS, IPF GL, Wilks, Sinclair, nutrient reference tables and compound sources were not licensed/validated here. | Pin official edition and worked examples, inspect reuse terms, record reviewer. Public access is not a license. |
| Future dependencies including GRDB | No new dependency version selected or installed by this review. | Before adoption, record exact version/commit, SPDX identifier, license text, transitive dependencies and required notices. Encryption packages need separate inventory. |

## Import approval record

Every import needs: source URL and publisher; exact release/commit/hash; retrieval and effective dates; jurisdiction if relevant; license identifier/version/text; rights holder and attribution wording; redistribution/modification/share-alike conditions; upstream/media exceptions; fields imported and transformations; reviewer/date; update and removal process. Mutable branch links above are research pointers, not pinned release evidence.

Food-source records remain distinct from editable personal log snapshots. Design adapters so a source can be replaced without changing diary values. Review whether an assembled cache or distributed database is a derivative/collective database with the chosen license; segregation is a design aid, not a legal conclusion.

## Original content and demo rules

- Author original app copy, icons, diagrams, exercise cues and generic parametric programs. Product comparisons do not authorize copying competitor branding, assets, paywalled plans or proprietary text.
- Use synthetic nutrition, noisy weight and training fixtures without personal records. A fictional Stack timeline must have no identifiable compound, benefit claim or actionable regimen; do not ship test numbers as recommendations or presets.
- A user-provided photo is not licensed for marketing, model training or a public dataset. Obtain only purpose-specific rights/consent needed for the feature.
- Keep attribution accessible in-app and in exports where applicable. Include license notices in release packaging; verify obligations for modified media and data separately.

Release evidence: approved manifest, generated acknowledgements, package lockfile/license scan, asset audit, source update test and owner/legal sign-off. All are planned; none is certified complete here. See [COMPLIANCE](COMPLIANCE.md), gate 11.10.

## Adopted Foundation dependencies — 2026-10-08

- GRDB.swift **7.9.0**, exact version and commit locked in both Package.resolved files; MIT. The checked-out release's full license is bundled as `Resources/ThirdPartyNotices.txt` and accessible from Settings. Source: https://github.com/groue/GRDB.swift/tree/v7.9.0 . No encryption capability is implied by plain GRDB/SQLite.
- PGlite **0.3.14**, development-only npm dependency pinned by deno.lock. Its package metadata declares Apache-2.0; its embedded PostgreSQL components carry their own upstream notices. We redistribute no PGlite binary in the mobile app or delivery source archive. Official documentation: https://pglite.dev/docs/ . Review transitive notices if redistributing the test runtime.
- Deno **2.9.7** is a local/CI development tool, not an app dependency. No runtime binary is included in the source delivery.
- The new demo generator and UI/chart copy are original; no third-party restaurant/exercise/compound dataset was added. Existing restaurant provenance gates remain open.

## Offline food import — 2026-10-14

USDA FoodData Central Foundation Foods, release **2026-04-30**, checked by this engineering implementation. [USDA](https://fdc.nal.usda.gov/) declares FoodData Central data CC0 1.0/public domain; attribution is retained in review/source links, personal serving descriptions, manifest and Settings notices. [Foundation documentation](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/) describes preparation and energy methods. This is an engineering source check, not a general legal sign-off.

- Source: `https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-04-30.zip`.
- Archive SHA256: `186e988ec542e913f51ef62b86a47758e8cdd0d1dc3889e7b055581f3c09c77a` (469,303 bytes).
- Generated resource SHA256: `febcf09814868e18c6a84a737a246bd9c15fb9812b6682c9470652bc1b67460e` (106,628 bytes).
- Fields: original description/preparation, FDC ID, publication date, energy method and kcal/protein/total carbohydrate/fat per100g. No images or branding. 395 source slots → 311 foods; 32 null, 42 missing nutrients and 10 negative carbohydrate-by-difference values excluded. Source order is normalized deterministically. No inferred zeros or new nutrition estimates.
- `scripts/import_usda_foods.py` verifies the pinned ZIP before extraction; `--check` reproduces the checked-in bytes. Default use is offline; `--download` explicitly opts into the bounded public download. Future releases need a new reviewed pin and diff; remove a source entry by regenerating the catalog without changing prior personal diary snapshots.

## Optional barcode and restaurant sources — pending

The optional Open Food Facts adapter uses no bundled product data/images and made no live product requests. Current [official API documentation](https://openfoodfacts.github.io/openfoodfacts-server/api/) recommends v3.6 and a contact-email User-Agent, development staging and usage setup. [Reuse guidance](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/license-be-on-the-legal-side/) identifies ODbL database and DbCL contents duties. A separate factory/configuration and attribution are prepared; provider choice, actual contact and applicable terms/setup remain owner decisions. No setup form was submitted. Do not infer that separating user copies settles all share-alike questions, or that private diaries should be published.

Existing restaurant values remain unverified samples. Source links are navigational references, not an import license. [LongHorn legal notices](https://www.longhornsteakhouse.com/legal-notices) and [Chipotle terms](https://www.chipotle.com/terms-of-use) restrict content reuse; new official menu imports are pending a licensed source or permission under §0.4(e). No new menu tables, photos/logos or competitor dataset were ingested.

## Expanded USDA reference catalog — imported 2026-10-14

[USDA's licensing statement](https://fdc.nal.usda.gov/) identifies FoodData Central as public-domain data under CC0-1.0 and requests attribution. [Official downloads](https://fdc.nal.usda.gov/download-datasets/) and [data-type documentation](https://fdc.nal.usda.gov/data-documentation/) were checked on October 14, 2026. Attribution: U.S. Department of Agriculture, Agricultural Research Service, Beltsville Human Nutrition Research Center. FoodData Central. Accessed 2026-10-14.

| Source | Exact input ZIP SHA256 | Included data |
| --- | --- | --- |
| [Foundation April 2026](https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-04-30.zip) | `186e988ec542e913f51ef62b86a47758e8cdd0d1dc3889e7b055581f3c09c77a` | 311 complete foods, 361 source portions; 32 null and 52 incomplete foods omitted. |
| [SR Legacy April 2018](https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_json_2018-04.zip) | `0fe8ae486a2c8eb42cb96413f058deb51863a46c8fb8eeb4b1fb45006dd338ef` | 7,793 complete foods, 14,431 source portions; 18 invalid amount/weight portions omitted. |

The generated FoodDatabase.sqlite is 7,000,064 bytes, SHA256 `3ff4994f61ddb212fda6323cf623ca1eb5a2728ff1323e197083ef461a7a0968`. FoodDatabaseManifest.json records exact input/output hashes, releases, imported/excluded counts, basis and writer version. Imported fields are FDC ID, source/preparation name/publication/category, reported kcal/protein/total-carbohydrate/fat per100g and explicit household gram weights. Energy preference remains 2048→2047→1008; missing/invalid macros are omitted, never guessed. Search normalization affects index words only. No photos, logos, copied menu artwork, OFF or commercial dataset is included.

`build_food_database.py` reproduces both outputs from pinned archives. Byte checks require the manifest's recorded SQLite writer version (3.54.0); logical SQLite reading is portable. Future data updates must use a reviewed new source manifest and compatible schema. Existing personal snapshots are independent; source updates do not recalculate a diary. Source removal/reconciliation across personal favorite exports remains backlog work. ThirdPartyNotices.txt includes both USDA releases; commercial/menu/media approvals remain separate and unresolved.

## USDA Branded offline subset — imported 2026-10-15

Source: [USDA Branded April 2026 CSV](https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_branded_food_csv_2026-04-30.zip), 448,767,220 bytes, SHA256 `26050a5d03197469813754743a21ee0fad4ccf22b6aac2a995846a987719fc49`. USDA's FoodData Central public-domain/CC0-1.0 statement applies; source/record dates and attribution are retained. Data providers supply label information; USDA publication is not a product endorsement or current-label verification. [Current documentation](https://fdc.nal.usda.gov/GBFPD_Documentation/) explicitly distinguishes 100 g/100 mL and missing values.

Imported fields: GTIN, FDC ID, name/brand, publication/modification, explicit standardized basis/source serving, kcal/protein/total carbohydrate/fat and optional household text. Ingredients, package images/logos and marketing copy are not bundled. Exact archive/member/output hashes, version/preparation exclusions, US-market policy and editorial brand priority are recorded in PackagedFoodDatabaseManifest.json. No OFF or commercial dataset is imported. The 50,000-product SQLite resource is 10,428,416 bytes, SHA256 `7874bba39cf9d15b77d82bd73d367bba86a570e909d49695a5bd09ce34422a73`; byte reproduction uses SQLite 3.54.0. Snapshot updates require a new reviewed manifest; personal logs never recalculate automatically.

## Restaurant importer — prepared 2026-10-15

No new real restaurant data or media was ingested. The production registry contains zero sources/items. The example JSON and DEBUG/UI fixtures are original fictional test data, explicitly marked fictional with license.status fixture; they grant no rights to any actual menu. For real data, approved status and permissionReference must describe an actual completed rights review. A parser cannot establish or grant permission. Existing source links/sample limitations above remain applicable.
