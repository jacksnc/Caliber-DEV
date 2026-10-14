# ADR-011: Offline USDA food search and separately gated barcode lookup

Status: local food/tools implemented; online provider and restaurant imports pending, 2026-10-14.

Bundle a small, reproducible public-domain catalog rather than a mock nutrition search. The importer verifies the USDA Foundation April 30, 2026 archive SHA256, validates units/basis/values and emits 311 complete foods. Descriptions retain preparation qualifiers. Energy preference is USDA Atwater specific (2048), general (2047), then reported kcal (1008); no calculation silently replaces source calories. The resource includes a release/source manifest, FDC IDs and explicit per-100g values.

`FoodCatalogProviding` keeps immutable metadata separate from editable SwiftData models. Search is local, word-based and ranked; `FoodNutritionReference` gives USDA and barcode results the same review form. A successful log creates a personal food and a diary snapshot, preserving basis/source in the existing serving description. Manual macro edits never mutate source data. No persistent model change is required.

AVFoundation captures EAN-8, UPC-A via EAN-13, EAN-13 and GTIN-14 on-device. Shared validation checks digit/length/checksum without converting codes to integers. The scanner stops on dismissal/background/interruption or manual focus and returns once. Manual code and label entry remain available. UPC-E is unsupported.

An optional Open Food Facts v3.6 adapter is compiled but absent from the default factory (`FoodLookupConfiguration.json` has `provider: pending`). It requires owner-selected provider/reuse approval, a real contact email and current usage setup before activation. No live product requests or bundled OFF data/images were used. Fictional fixtures test the pipeline independently.

Online barcode permission is independent of account consent and can be withdrawn. The adapter requests only fixed product fields from an allowlisted HTTPS host, uses a contact User-Agent, no redirects/cookies/disk cache, 512 KiB response limit, short timeouts and a conservative per-instance rate limit. It never receives camera frames, diary records or account credentials. Product identity must match the validated GTIN. Complete as-sold packaging/manufacturer nutrients from a single explicit basis are required. Net carbohydrate does not substitute for total; ml does not become g without mass information.

Public restaurant information can be linked, but new menu imports are pending a licensed source or clear reuse permission. Existing sample menus retain labels and edit/delete rules. Personal restaurants and menu items can be added without copying proprietary datasets.

Consequences: useful offline generic-food search and review now, limited coverage rather than a full commercial database. Structured source provenance, broader serving units, authorized menu refresh, packaged-food cache, OCR and provider activation remain separate backlog items. See `LICENSES.md` and the verification report.
