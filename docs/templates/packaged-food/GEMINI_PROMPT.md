# Copy this request into Gemini

Build a source-backed US packaged-food collection for Caliber. Start with 100
distinct products, then deliver additional batches with a coverage manifest.
Use the supplied label-food-template.csv exactly. Do not modify the app or mark
data reviewed. Research facts; never generate plausible nutrition from memory.

Prioritize Oikos Pro/Triple Zero, Chobani, Fage, Siggi's, fairlife/Core Power,
Premier Protein, Quest, ONE, Barebells, Pure Protein, KIND, RXBAR, Nature Valley,
Quaker, Cheerios, Kellogg's, Jif, Skippy, Barilla, Ben's Original, Campbell's,
Tyson, Oscar Mayer, Coca-Cola, Pepsi, Gatorade, and common Great Value, Good &
Gather, Kirkland and Kroger products. These are priorities, not proof of sales
rank or complete coverage. Include dairy, shakes, bars, cereal, grains, spreads,
canned/frozen foods, drinks, condiments and ordinary grocery staples.

Return UTF-8 CSV with these columns, exactly in this order:

```csv
id,brand,name,aliases,country,barcode,serving_description,serving_grams,serving_ml,calories,protein_g,carbs_g,fat_g,source_url,source_locator,retrieved_on,barcode_source_url
```

- One row means ONE exact flavor/formulation and stated nutrition serving.
  Name the product line, flavor and size. Distinguish cups, tubs, drinks, powders,
  reduced-fat/zero-sugar versions and prepared/unprepared foods.
- Use a stable ID such as brand-line-flavor-size-us. Country is US.
- Use current manufacturer Nutrition Facts or a legible current package label.
  USDA FoodData Central can be a reference, but verify conflicting serving bases
  and package formulations. Prefer current manufacturer facts when sources differ;
  record every conflict in a separate issues.csv rather than combining labels.
- Copy reported kcal, protein, TOTAL carbohydrate and fat for exactly the same
  serving. Preserve decimals. Never calculate calories from macros; never use
  sugar or net carbs as total carbohydrate. A missing number is not zero.
- Keep a single stated serving such as "1 cup (150 g)". Enter source-provided
  mass in serving_grams OR source-provided volume in serving_ml. Leave unknown
  values blank; never equate mL/fluid ounces to grams. Nutrients remain PER THIS
  SERVING, not automatically per 100 g and not per entire multipack.
- Barcode is text, including leading zeros. Use full UPC-A/EAN/GTIN digits with
  evidence of the exact flavor, country and package size. Never invent a code,
  repair a check digit, or attach a case/multipack barcode to a single unit unless
  that exact package/serving relationship is established. Leave an unknown barcode
  blank. Supply barcode_source_url for every nonblank barcode.
- source_url is the exact HTTPS facts page, not a brand homepage. source_locator
  identifies the label section, PDF page, USDA ID or package evidence. retrieved_on
  is the actual retrieval date in YYYY-MM-DD. Use brief original product names;
  do not return logos, photos, marketing paragraphs or copied menu designs.
- If a required macro or serving basis cannot be verified, omit that product
  from the import CSV and list it in issues.csv with a reason. Include source
  access/reuse conditions if applicable; do not invent legal approval.
- Output coverage.csv with brand, product line, distinct SKUs checked, complete
  rows, missing/uncertain rows and next source to inspect. Never claim "all
  mainstream foods" or "all flavors" unless there is an enumerated checked list.

First fill current coverage misses: Core Power chocolate 26 g/14 fl oz
(811620021951), Coca-Cola 2 L (049000050103), Barilla spaghetti 16 oz
(076808280081), and Jif creamy 16 oz (051500255162). Confirm each code from a
primary seller/manufacturer before using it. Oikos vanilla has conflicting
manufacturer/retailer labels; document both and the serving instead of guessing.
