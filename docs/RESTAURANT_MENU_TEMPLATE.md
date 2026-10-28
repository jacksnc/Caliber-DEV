# Adding restaurant menus with a spreadsheet

Use [menu-template.csv](templates/restaurant-menu/menu-template.csv) as the blank
starting file. Open it in Excel, Numbers, or a text editor. **One row is one menu
item with nutrition for the serving described in that row.** Source details go
in a small metadata file once per restaurant, rather than on every food row.

[menu-example.csv](templates/restaurant-menu/menu-example.csv) and
[metadata-example.json](templates/restaurant-menu/metadata-example.json) are a
complete, runnable example with invented software-test food. They are not real
menu nutrition and are never shipped as a production restaurant database.

## Columns

| Column | Enter |
| --- | --- |
| `restaurant_id` | The matching restaurant ID in the metadata, e.g. `fictional-example-bistro` in the demo |
| `item_id` | A unique, permanent lowercase ID; keep it when the display name changes |
| `name` | Item name as listed by the permitted source |
| `category` | Appetizers, Entrées, Sides, Drinks, or Desserts; singular lowercase IDs work too |
| `serving_description` | Exactly what the numbers include, such as one portion with the named sauce or side |
| `serving_grams` | Source-provided grams for that complete serving; leave blank if unknown |
| `calories` | Explicit kcal per described serving |
| `protein_g` | Explicit protein grams per described serving |
| `carbs_g` | Explicit **total** carbohydrate grams per described serving |
| `fat_g` | Explicit fat grams per described serving |

Use a decimal point and numbers without units: `12.5`, not `12.5 g`.
A known zero is `0`; blank macros are rejected. Calories are preserved from the
source rather than recalculated from macros. Unknown serving grams stay unknown;
volume or portion names never imply a gram weight. Save as **CSV UTF-8 with comma
separators**. Excel's UTF-8 BOM and quoted names containing commas are supported.

Enter an entrée and a separately sold side on separate rows. If an entrée's
nutrition already includes a side or dressing, say so in `serving_description`;
do not add the same side a second time to that item's numbers. This template
supports flat items. Component builders, variant/modifier rules and per-ingredient
double portions continue through their separate app model rather than invented
CSV fields.

## Metadata

Copy the example metadata and replace its source and restaurant information for
your reviewed dataset. Keep each restaurant's `items` array empty; the CSV fills
it. The source holds its URL, retrieval date, permission evidence and attribution.
Each restaurant references that source's ID. Multiple restaurants can share one
CSV and metadata document.

Real imports require documented reuse permission and the existing completed
rights review. A public nutrition page alone does not establish reuse permission.
The `approved` status records that review; changing a status string cannot grant
rights. Fictional demo metadata uses `fictional: true` and `fixture` status and
requires the explicit fixture flag. The shipped production registry and FUEL-13
flag remain unchanged by preparing a spreadsheet.

## Try the complete example

From the repository directory:

```sh
python3 scripts/prepare_restaurant_menu_csv.py \
  --csv docs/templates/restaurant-menu/menu-example.csv \
  --metadata docs/templates/restaurant-menu/metadata-example.json \
  --fixture --output /tmp/caliber-menu-input.json

python3 scripts/import_restaurant_menus.py \
  --input /tmp/caliber-menu-input.json --fixture \
  --output /tmp/caliber-menu-catalog.json
```

The first command validates the spreadsheet and writes the existing importer's
input format. The second creates a catalog in a temporary location. Neither
changes the app database or adds these fictional foods to your diary.

For reviewed real data, use your CSV/metadata paths and omit `--fixture` from
both commands. Review the temporary catalog before a maintainer updates
`Caliber (DEV)/Resources/RestaurantMenuCatalog.json` through the existing importer
and completes the separate FUEL-13 readiness step. Source menu updates do not
rewrite previously logged diary snapshots; users can still edit their own macros
when logging.

Add `--check` with an existing `--output` to either command to verify that the
output matches without modifying it. Invalid input leaves the previous output
untouched. The CSV tool refuses to overwrite either input file or write staging
JSON directly over the app catalog.

## Inside the app

This spreadsheet is for maintaining Caliber's premade restaurant library.
A person adding a local restaurant variation can continue using the restaurant's
existing **Add Custom Item** flow, with personal edit/delete controls. Their
private items do not change the shared source catalog.
