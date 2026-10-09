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
