# Restaurant library

The engines behind the built-in restaurant menus: data schema, a licence-gated CSV importer, search, meal builder, a
"what fits my macros here" finder, library updates that never lose a user's corrections, and an estimator for places
with no published nutrition. All of it lives in `Packages/RestaurantCore` (pure Swift, depends only on `FoodCore`).

> **No real restaurant data is included, on purpose.** Every fixture in the tests is fictional ("Burger Barn", "Taco
> Tangent", "Bean There Coffee") and carries `ProvenanceKind.demoFictional`, so it can never be mistaken for a chain's
> actual nutrition. Real menus must come from a source you are allowed to ship (section 3), and the importer refuses
> rows without a recognised licence. `LibraryAttribution.warnings` flags any demo data still present before release.

## 1. Data model

```
RestaurantLibrary(version)
 └─ Restaurant(id slug, name, aliases, category, region, provenance)
     ├─ ModifierGroup(rule: single(required) | multiple(max))
     │   └─ ModifierOption(delta: NutrientSet, isDefault)
     └─ MenuItem(id "restaurant/item", section, aliases, servingGrams, nutrients, allergens, dietTags)
         └─ ItemVariant(size or flavour: own NutrientSet, or a scale factor)
Provenance(kind, sourceName, sourceURL, license, asOf)   // restaurant level, overridable per item
```

- **`MenuItem.nutrients` is the listed build**, i.e. it already includes every default modifier option.
- **Option `delta` is what the option contributes when present.** Removing a default option subtracts its delta
  ("no cheese" = listed build minus cheese); adding a non-default option adds it; swapping in a single-choice group does
  both. Deltas only apply to nutrients the item reports, so an unknown stays unknown rather than becoming a wrong number.
- **Sizes** are variants. The first size row is also the listed build.
- IDs are stable slugs (`Slug.make`: accent-folded, lower-case ASCII), so a menu update keeps the same IDs and a user's
  favourites, history and corrections stay attached.
- Diet tags (`vegetarian`, `vegan`, `glutenFree`, `dairyFree`, `nutFree`) are the restaurant's claims and must be shown as such.

## 2. CSV import

```
LibraryImporter.importMenu(csv:, modifiersCSV:, policy:) -> ImportReport(restaurants, issues, rowsRead, rowsImported)
```

Column names are case-insensitive and tolerant (`protein_g`, `protein`; `carbs_g`, `carbohydrates`...). One row per
item, or one per size (same restaurant, section and item, different `variant`).

| Column | Notes |
| --- | --- |
| `restaurant`, `item` | required |
| `calories` | required (kcal) |
| `section`, `variant`, `serving`, `serving_g`, `aliases`, `description` | optional; aliases separated by `;` |
| `protein_g carbs_g fat_g sat_fat_g trans_fat_g fiber_g sugars_g added_sugars_g sodium_mg cholesterol_mg potassium_mg calcium_mg iron_mg caffeine_mg alcohol_g` | optional; `<1` is stored as 0.5 with an info note; `8g`, `160 mg`, `1,050` accepted; a decimal comma (`12,5`) is rejected as ambiguous |
| `allergens`, `diet_tags` | `;`-separated; unknown words become warnings |
| `modifier_groups` | `;`-separated names, resolved against the modifiers file |
| `restaurant_category`, `region` | first row of a restaurant wins |
| `source_kind`, `source_name`, `source_url`, `license`, `as_of` | provenance; a row that differs from its restaurant keeps its own |

Modifiers file: `restaurant, group, option, rule, default, <nutrient deltas>` with `rule` one of `single`,
`single_required`, `multiple`, `multiple_max3`.

**Errors (row skipped):** missing names or calories, negative or non-numeric values, duplicate item or size, more fields
than the header (an unquoted comma), unterminated quote, **unknown or missing licence** (default policy).

**Warnings (row kept):** calories differ from 4P+4C+9F by more than 25% / 25 kcal; sodium under 5 mg on a 100+ kcal item
(grams typed as mg); saturated fat above total fat, sugars or fibre above carbohydrate; macros heavier than the serving
weight; above 4,000 kcal for one item; unknown allergen, diet tag, modifier group or column.

`LicenseTag`: `publicDomain, cc0, ccBy, ccBySa, odbl, permissionGranted, licensedCommercial, userOwned, unknown`.
`unknown` is never bundled. Attribution-bearing and share-alike licences are surfaced by `LibraryAttribution.credits`
(the "Data sources" screen) and `.warnings`.

## 3. Where real data can come from

This is a plan, not legal advice; check each source's current terms before shipping anything.

1. **The chains themselves.** US chains with 20 or more locations must show calories on menus and give full nutrition on
   request (FDA menu labelling), so the numbers exist and are public. Many chains publish a PDF or calculator. Nutrition
   values are facts, but a site's terms may forbid scraping, and a compiled database can carry its own rights, so get
   written permission for bulk use and record it (`permissionGranted`, with the reference in `sourceURL`). Entering a
   few chains by hand from their published PDFs is the lowest-risk start.
2. **A licensed data provider** (commercial nutrition APIs exist; compare Nutritionix, FatSecret, Edamam and similar on
   price, offline-storage rights, display attribution and exit terms. I could not verify their current terms from here).
3. **MenuStat** (NYC Health open data of large-chain menu items). It looked useful, but its licence was unspecified on the
   portal and the data is dated (collected through about 2018, record last modified 2022), so treat it as `unknown`
   until the licence is confirmed and expect stale numbers.
4. **User contributions** with moderation and `userContributed` / `userOwned` provenance, kept in `UserOverlay`.
5. **Generic components** from USDA FoodData Central (public domain) as inputs to the dish estimator, never as a stand-in
   for a chain's published numbers.

Whatever the source, put its name, URL, licence and "as of" date in the CSV; menus change and staleness is measured
(`LibraryAttribution.warnings` flags menus older than 12 months).

## 4. Search

`LibrarySearchIndex(library:)`, then `search(_:limit:context:restaurantID:includeRestaurants:)`.

- Every query word must match (AND). A word matches by exact token, synonym, prefix (last word gets full credit, as
  the user is still typing), or typo (one edit for words of 4+ letters, two for 8+; transpositions count as one).
- Items are searchable by the restaurant's name, so "burger barn fries" finds the fries and nothing else; "large fries"
  returns the item with `variantID == "large"`.
- Boosts: exact name +0.5, name starts with query +0.25, favourite +0.15, recent up to +0.10, nearest chain +0.10.
- Default synonyms live in `SearchDefaults.synonyms` and can be replaced per locale.
- Measured on the dev container (Linux x86-64, release build, 20,200 generated items): index build 0.5 s, queries 0-4 ms.
  Phone numbers are unmeasured. Build the index off the main thread at launch; beyond roughly 50,000 items move search
  into SQLite FTS5.

## 5. Meal builder, finder and tweaks

- `MealBuilder.build([OrderLine], in:)` applies size, modifier choices and quantity (fractions allowed). It reports unknown
  items/options, broken selection rules and clamped negatives as `MealWarning`s, and lists `incomplete` nutrients (where
  at least one line does not publish a value, so the total is a lower bound and the UI should say so).
- `MacroFitFinder.find(in:goal:filter:structure:limit:)` searches up to N items (repeats become quantities) or one item per
  slot (`[["Burgers","Chicken"],["Sides"],["Drinks"]]`). Calorie ceilings prune the search exactly (tests compare it with
  brute force). The score punishes overshooting calories, carbs, fat and sodium more than falling short, punishes a
  protein shortfall most, and uses protein density and item count only as tie-breakers. A 100-item menu with up to three
  items takes about 19 ms in a release build; `evaluationBudget` bounds the worst case and `truncated` says if it was hit.
  Items without calories and all three macros are skipped and counted.
- `TweakSuggester` proposes single option changes ("Remove Cheese", "Swap 2% Milk for Nonfat Milk") that move an order
  towards the goal; it never empties a required choice.
- `MenuBrowser.rows(...)` filters and sorts by numbers (protein per 100 kcal, calories, carbs, fat, sodium) with allergen,
  diet and section filters; sizes appear as their own rows.

## 6. Keeping the library current without losing user edits

- `LibraryDiff.diff(old:new:)` lists added/removed restaurants and added/removed/changed items with per-nutrient changes
  (below 1 kcal / 1 mg / 0.1 g is treated as noise), size changes, renames and **allergen changes** (show those first).
- `UserOverlay` stores corrections (`ItemOverride`, fingerprinted against the item as it was), custom items added to a
  chain, and whole user-made restaurants. After an update, `states(in:)` reports `.current`, `.baseChanged` (ask: keep
  mine / use the library's) or `.orphaned`. Until the user decides, their numbers stay in force. `applied(to:)` produces the
  effective library; the shipped data is never mutated.
- The fingerprint covers published nutrition only (listed build and sizes), so renaming an item does not invalidate a
  correction.

## 7. Estimating places with no published nutrition

`DishEstimator.estimate(components:cooking:portionScale:venue:)` returns low / typical / high from component weights and
per-100 g nutrition (supplied by the caller), added cooking fat (9 kcal/g) and a venue width: chain-published 8%,
fast-casual 15%, independent 25%, buffet 35%. Those widths are judgement calls, not measurements. Under-logging
restaurant food is the common error, so `DishEstimate.logged(.conservative(share:))` records part-way to the high end.
Estimates carry `ProvenanceKind.estimated` and must be shown as ranges.

## 8. Not done yet

- A bundled real library (needs a licensed source, section 3).
- Menu photo OCR to propose items for a restaurant that is not in the library.
- Localisation of synonyms and `TweakAction` wording (the engine returns structured values; the UI formats them).
- GRDB tables and migrations (the app layer: restaurants, items, variants, groups, options, overrides, FTS5 for large libraries).
