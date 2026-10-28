#!/usr/bin/env python3
"""Turn a spreadsheet-friendly menu CSV into validated restaurant-import input.

Source/restaurant names and reviewed permission evidence live in the metadata
JSON. Rows contain explicitly supplied per-serving nutrition; no food values,
portion mass or rights are inferred. This writes staging input, not the app's
catalog. Run import_restaurant_menus.py separately to prepare a catalog.
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import unicodedata

import import_restaurant_menus as menus

ROOT = Path(__file__).resolve().parents[1]
COLUMNS = (
    "restaurant_id", "item_id", "name", "category", "serving_description",
    "serving_grams", "calories", "protein_g", "carbs_g", "fat_g",
)
NUTRIENTS = {
    "calories": "calories", "protein_g": "proteinGrams",
    "carbs_g": "carbGrams", "fat_g": "fatGrams",
}
CATEGORY_LABELS = {
    "appetizer": "appetizer", "appetizers": "appetizer",
    "entree": "entree", "entrees": "entree",
    "side": "side", "sides": "side",
    "drink": "drink", "drinks": "drink",
    "dessert": "dessert", "desserts": "dessert",
}


def category(value, path):
    key = "".join(c for c in unicodedata.normalize("NFKD", value.casefold())
                  if not unicodedata.combining(c)).strip()
    if key not in CATEGORY_LABELS:
        menus.fail(path, "use Appetizers, Entrées, Sides, Drinks or Desserts")
    return CATEGORY_LABELS[key]


def number(value, column, row):
    value = value.strip()
    path = f"CSV row {row}, {column}"
    if not value:
        menus.fail(path, "missing nutrition is not zero; enter an explicit source value")
    if len(value) > 128 or re.fullmatch(r"[0-9]+(?:\.[0-9]+)?", value) is None:
        menus.fail(path, "use a plain nonnegative number with a decimal point, without units or separators")
    return menus.numeric(float(value), menus.MAX_GRAMS if column == "serving_grams" else menus.MAX_NUTRIENT,
                         path, positive=column == "serving_grams")


def prepare(csv_path, metadata_path, allow_fixture=False):
    metadata = menus.load_input(metadata_path, allow_fixture)
    if any(restaurant["items"] for restaurant in metadata["restaurants"]):
        menus.fail("metadata.restaurants", "items must be empty; all menu rows belong in the CSV")
    if csv_path.stat().st_size > menus.MAX_BYTES:
        menus.fail("CSV", "file exceeds the 5 MB input limit")
    raw = csv_path.read_bytes()
    if len(raw) > menus.MAX_BYTES:
        menus.fail("CSV", "file exceeds the 5 MB input limit")
    try:
        text = raw.decode("utf-8-sig")  # Excel's UTF-8 BOM is accepted.
    except UnicodeDecodeError:
        menus.fail("CSV", "save as UTF-8 comma-separated CSV")
    restaurants = {restaurant["id"]: restaurant for restaurant in metadata["restaurants"]}
    try:
        reader = csv.DictReader(io.StringIO(text, newline=""), strict=True)
        fields = reader.fieldnames
        if fields is None or len(fields) != len(set(fields)) or set(fields) != set(COLUMNS):
            menus.fail("CSV header", "use each template column exactly once: " + ", ".join(COLUMNS))
        count = 0
        for row in reader:
            line = reader.line_num
            if None in row or any(value is None for value in row.values()):
                menus.fail(f"CSV row {line}", "wrong number of cells; quote names containing commas")
            restaurant_id = row["restaurant_id"].strip()
            if restaurant_id not in restaurants:
                menus.fail(f"CSV row {line}, restaurant_id", "ID is not declared in the metadata")
            item = {
                "id": menus.identifier(row["item_id"].strip(), f"CSV row {line}, item_id"),
                "name": row["name"],
                "category": category(row["category"], f"CSV row {line}, category"),
                "servingDescription": row["serving_description"],
                "servingGrams": number(row["serving_grams"], "serving_grams", line)
                    if row["serving_grams"].strip() else None,
                **{target: number(row[column], column, line) for column, target in NUTRIENTS.items()},
            }
            restaurants[restaurant_id]["items"].append(item)
            count += 1
            if count > menus.MAX_ITEMS:
                menus.fail("CSV", f"catalog exceeds {menus.MAX_ITEMS} rows")
    except csv.Error as error:
        menus.fail("CSV", "malformed quoted data: " + str(error))

    # Reuse ALL existing source, permission, text, ID and nutrition validation.
    # This internal hash is discarded. The final importer hashes the actual
    # prepared JSON bytes, so no CSV hash is mislabeled as a catalog input hash.
    metadata.pop("inputSHA256")
    input_bytes = menus.render(metadata)
    result = menus.normalize(metadata, hashlib.sha256(input_bytes).hexdigest(), allow_fixture)
    result.pop("inputSHA256")
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, required=True, dest="csv_path")
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--output", type=Path, help="Prepared JSON input for the existing importer")
    parser.add_argument("--fixture", action="store_true", help="Explicitly allow visibly fictional examples")
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--check", action="store_true", help="Compare --output without writing")
    args = parser.parse_args(argv)
    if args.check and args.output is None:
        parser.error("--check requires --output")
    if args.output is not None:
        if args.output.resolve() in (args.csv_path.resolve(), args.metadata.resolve()):
            parser.error("output must differ from both input files")
        if args.output.resolve() == (ROOT / "Caliber (DEV)/Resources/RestaurantMenuCatalog.json").resolve():
            parser.error("write staging JSON elsewhere, then run import_restaurant_menus.py for the app catalog")
    try:
        document = prepare(args.csv_path, args.metadata, args.fixture)
        data = menus.render(document)
        if args.output is not None:
            if args.check:
                if args.output.read_bytes() != data:
                    menus.fail("output", "file differs from the deterministic preparation")
            else:
                menus.atomic_write(args.output, data)
        if args.preview:
            sys.stdout.buffer.write(data)
        else:
            count = sum(len(restaurant["items"]) for restaurant in document["restaurants"])
            label = "fictional fixture" if document["fictional"] else "reviewed source input"
            print(f"Prepared {label}: {len(document['restaurants'])} restaurants, {count} items. "
                  "Run import_restaurant_menus.py for the final catalog.")
    except (menus.MenuValidationError, OSError) as error:
        print("Menu CSV rejected: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
