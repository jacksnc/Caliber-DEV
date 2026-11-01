# Importing ordinary branded foods

The name-search screen now searches the existing 50,000 USDA Branded barcode
records as well as generic USDA foods and personal foods. A reviewed per-serving
label supplement adds missing products and supersedes stale barcode records.
Both search and scanning open the existing editable nutrition review before Add.

Give Gemini [this prompt](templates/packaged-food/GEMINI_PROMPT.md) and
[this blank CSV](templates/packaged-food/label-food-template.csv).
The [reviewed example](templates/packaged-food/reviewed-label-foods.csv) is the
source-backed Oikos Pro vanilla 5.3 oz cup, not a template of guessed values for
other flavors. The data format keeps the complete serving, macros, GTIN evidence
and source date together. Unknown grams and unknown barcodes stay blank.

Stage and check a delivered batch:

```sh
python3 scripts/import_label_foods.py --csv /path/from-gemini.csv \
  --output /tmp/caliber-label-review.json
```

The app rejects this unreviewed output. Inspect the facts, exact variant/serving,
GTIN identity, source dates and any source conditions. Resolve conflicts. Then a
maintainer may record the completed review:

```sh
python3 scripts/import_label_foods.py --csv /path/reviewed-complete-collection.csv \
  --reviewed --output 'Caliber (DEV)/Resources/LabelFoods.json'
python3 scripts/import_label_foods.py --csv /path/reviewed-complete-collection.csv \
  --reviewed --output 'Caliber (DEV)/Resources/LabelFoods.json' --check
```

This command replaces the supplement; include existing reviewed rows in the
complete collection. It does not rewrite the 50,000-product database or personal
logs. The first supplement supports up to 1,000 reviewed rows. Deliver research
in small batches and maintain one consolidated reviewed CSV; larger scale belongs
in the public catalog build pipeline. Do not discard the existing rows when
adding a batch. Approval is a factual review record, not an AI truth guarantee.

## Oikos correction

The previous pinned USDA row for UPC 036632042552 stored 140 kcal/20 P/8 C/3 F
as per 100 g with a 240 g serving. Applying that basis produced 336 kcal and
48 g protein. The [current manufacturer page](https://www.oikos.com/all-products/pro-yogurt-cultured-ultra-filtered-milk/product/vanilla/)
states 130 kcal/20 P/6 C/3 F for 1 cup (150 g), confirmed by
[Danone Food Service](https://www.danoneawayfromhome.com/food-service-products/dannon-oikos-pro-greek-yogurt-vanilla/).
[Target](https://www.target.com/p/-/A-81995727) identifies this UPC and still lists
an older 140 kcal/8 C label for 150 g. The supplement uses the manufacturer
facts, records this discrepancy, and asks the person to compare the package.
No other flavor, tub, drink or multipack is silently assigned these numbers.

## Barcode coverage

Camera input supports UPC-A (delivered as leading-zero EAN-13), EAN-13, EAN-8,
GTIN-14 and now UPC-E with explicit symbology-aware expansion. Manual entry
remains full numeric GTIN; an eight-digit manual entry is EAN-8, not a guess at
compressed UPC-E. Invalid checksums/all-zero codes are rejected. Images never
leave the camera. Online fallback remains unconfigured as before.

See [barcode-coverage.json](evidence/packaged-import/barcode-coverage.json).
The audit covers every bundled identifier and its equivalent padded forms. A
six-SKU convenience sample across yogurt, protein shakes, soda, pasta, peanut
butter and cereal has 2 local hits/6. This is not a market coverage estimate.
Code decoding, database matches and nutrition correctness are separate checks.
The next step is to fill the documented misses and collect an independent,
larger SKU basket; a physical iPhone must still test focus, glare, curved packs,
low light, denied camera permission, background/retry and real UPC-E labels.
Simulator/manual-code tests do not certify physical-camera performance.
