# Packaged search/import and barcode verification — November 1, 2026

Worktree: `/Users/jcrock/Documents/Codex/Caliber-packaged-food-import`.
Branch: `codex/packaged-food-import`, base `8fce224`.

## Scope and acceptance

| Check | Result and limits |
|---|---|
| Existing branded references searchable by name | PASS: bounded local brand/name queries feed a separate Packaged Foods section; existing generic/personal paths remain. Search runs off the UI actor. |
| Import format usable by Gemini | PASS: exact CSV template and prompt, validation/atomic staging CLI, required serving/variant/nutrients/source, checksum-valid optional GTIN and source evidence. Unreviewed output is rejected at runtime. |
| Oikos Pro exact portion and barcode consistency | PASS: native unit and two UI cases use 130 kcal/20 P/6 C/3 F per 150 g from manufacturer. The corresponding stale USDA GTIN is suppressed in search and overridden at lookup. Reviewed screenshot inspected. |
| Editable portions and personal logging | PASS: final scoped mass/liquid UI run passed 2/2, including changed portions, saving, navigating back and exact diary totals. Source math and models did not change. |
| Identifier normalization | PASS: FoodCore BarcodeTests 28/28, plus app camera UPC-E/EAN-8 distinction, UPC-A/EAN-13 equivalence, bad-checksum and all-zero rejection. |
| Every bundled GTIN and equivalent lookup | PASS: Python audit checks 50,000 codes and 149,996 canonical/padded-form lookups. This is identifier/database evidence, not camera or label accuracy proof. |
| Broad market lookup coverage | OPEN: selected convenience basket has 2 hits/6; sample is not statistically representative. Four misses are in Gemini's collection prompt. Online fallback remains unconfigured. |
| Physical camera and minimum iOS | OPEN: tests use isolated iPhone SE simulator, iOS 27, target iOS 17. No optical camera or iOS 17 runtime certification. |
| Private data/provider boundary | PASS: no model/schema/provider/settings change, no owner's checkout or simulator mutation. All native personal-data tests use isolated memory fixtures. |

## Checks and retained failures

- Python label importer: 5/5 tests, including missing nutrition, duplicate IDs/
  GTINs, preserving decimals/zeroes, unknown mass/volume and failed-output atomicity.
- Existing packaged database builder: 24/24 tests.
- Focused CaliberDatabase packaged tests: suite passes, one optional external
  resource timing case skipped. Actual bundled resource validation runs through
  the app unit tests and prepared search/barcode service.
- FoodCore barcode tests: 28/28 passed.
- Corrected Xcode run: all app unit checks and two new Oikos UI cases passed.
  Two older mass/liquid tests reached their correct values and saved successfully
  but used outdated return-navigation helpers. Their final scoped rerun passed
  2/2 after the helpers were corrected. The unchanged new Oikos cases passed 2/2
  in the corrected run; no single all-green full UI-suite run is claimed.
- Initial Xcode run is retained: one old expectation allowed all-zero input to
  reach lookup, and four UI cases assumed the floating tab bar existed while the
  review footer hides it. Tests were corrected without removing value/portion/
  persistence assertions. A second helper correction handles root screens with
  a custom header and no NavigationBar.
- Foundation lint passes. Strict Dynamic Type lint: 226 files, no errors/warnings.
  SwiftFormat and source diff review passed; the final whitespace check is clean.
- Existing keyboard invalid-frame and Xcode scheme/SDK diagnostics remain in
  simulator output; this delivery does not claim a complete accessibility audit.

The pinned public database remains SHA-256
`7874bba39cf9d15b77d82bd73d367bba86a570e909d49695a5bd09ce34422a73`.
The reviewed supplement is generated exactly from its checked-in reviewed CSV;
`--check` verifies that link. Unknown masses are never inferred, volumes never
become grams, and reported calories are not recreated with 4/4/9.

## Reproduce

```sh
python3 -m unittest discover -s scripts -p 'test_import_label_foods.py'
python3 -m unittest discover -s scripts -p 'test_build_packaged_database.py'
python3 scripts/audit_barcode_coverage.py
python3 scripts/import_label_foods.py \
  --csv docs/templates/packaged-food/reviewed-label-foods.csv --reviewed \
  --output 'Caliber (DEV)/Resources/LabelFoods.json' --check
swift test --package-path Packages/CaliberFoundation --filter Packaged
swift test --package-path Packages/FoodCore --filter BarcodeTests
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict
```

Native verification uses `xcodebuild test`, scheme `Caliber (DEV)`, destination
`platform=iOS Simulator,id=2998CE67-7D71-460B-AD69-76DAA4D014F6`, separate DerivedData
`/tmp/caliber-packaged-import-derived`, parallel testing disabled. Selected checks:
`Caliber (DEV)Tests`, plus FoodExperienceUITests' two Oikos cases and the existing
mass/liquid offline cases. Initial/corrected/navigation xcresults remain in /tmp.
The owned QA device is Caliber Compact QA; the personal iPhone 17 is not used.
