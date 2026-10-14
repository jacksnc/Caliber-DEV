#!/usr/bin/env python3
"""Reproduce Caliber's offline USDA Foundation food catalog, using only stdlib.

Default operation reads a previously downloaded, hash-pinned ZIP. --download
explicitly permits a bounded public USDA download. Nothing contacts an API.
Missing nutrients are excluded, never assumed to be zero. Food names and the
raw/cooked/prepared qualifiers stay exactly as supplied apart from whitespace.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import urllib.request
import zipfile

SOURCE_URL = "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-04-30.zip"
SOURCE_SHA256 = "186e988ec542e913f51ef62b86a47758e8cdd0d1dc3889e7b055581f3c09c77a"
SOURCE_MEMBER = "FoodData_Central_foundation_food_json_2026-04-30.json"
RELEASE = "2026-04-30"
MAX_ARCHIVE_BYTES = 2_000_000
MAX_JSON_BYTES = 10_000_000
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "Caliber (DEV)/Resources/FoodCatalog.json"


def is_number(value):
    return isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value)


def nutrient_value(food, nutrient_id, unit, maximum):
    matches = [n for n in food.get("foodNutrients", []) if isinstance(n, dict)
               and isinstance(n.get("nutrient"), dict) and n["nutrient"].get("id") == nutrient_id]
    if len(matches) != 1:
        return None
    value = matches[0].get("amount")
    supplied_unit = matches[0]["nutrient"].get("unitName")
    if not isinstance(supplied_unit, str) or supplied_unit.casefold() != unit.casefold():
        return None
    return value if is_number(value) and 0 <= value <= maximum else None


def convert_food(food):
    if not isinstance(food, dict) or food.get("dataType") != "Foundation":
        return None
    if not isinstance(food.get("foodNutrients"), list):
        return None
    fdc_id = food.get("fdcId")
    if not isinstance(fdc_id, int) or isinstance(fdc_id, bool) or fdc_id <= 0:
        return None
    name = food.get("description")
    if not isinstance(name, str) or not name.strip():
        return None
    publication = food.get("publicationDate")
    if not isinstance(publication, str) or not publication.strip():
        return None
    protein = nutrient_value(food, 1003, "g", 100)
    fat = nutrient_value(food, 1004, "g", 100)
    carbs = nutrient_value(food, 1005, "g", 100)
    # Specific Atwater factors are more food-specific. General factors and the
    # historical energy field are fallbacks; we do not reconstruct energy from
    # rounded macro values or substitute kJ for kcal.
    energy_id = next((n for n in (2048, 2047, 1008)
                      if nutrient_value(food, n, "kcal", 1000) is not None), None)
    if any(v is None for v in (protein, fat, carbs)) or energy_id is None:
        return None
    return {
        "id": f"usda-foundation:{fdc_id}", "fdcID": fdc_id,
        "name": " ".join(name.split()), "publicationDate": publication,
        "energyNutrientID": energy_id,
        "nutritionPer100g": {"calories": nutrient_value(food, energy_id, "kcal", 1000),
                            "proteinGrams": protein, "carbGrams": carbs, "fatGrams": fat},
    }


def build_catalog(document):
    foods = document.get("FoundationFoods")
    if not isinstance(foods, list):
        raise ValueError("Expected the USDA FoundationFoods array")
    entries = [entry for food in foods if (entry := convert_food(food)) is not None]
    if len({entry["fdcID"] for entry in entries}) != len(entries):
        raise ValueError("Duplicate USDA food identifiers")
    entries.sort(key=lambda entry: (entry["name"].casefold(), entry["fdcID"]))
    return {
        "schemaVersion": 1,
        "source": {"name": "USDA FoodData Central", "dataType": "Foundation",
                   "release": RELEASE, "archiveURL": SOURCE_URL,
                   "archiveSHA256": SOURCE_SHA256,
                   "license": "CC0-1.0", "licenseURL": "https://fdc.nal.usda.gov/",
                   "basisGrams": 100, "sourceFoodCount": len(foods),
                   "skippedNullCount": sum(food is None for food in foods),
                   "skippedIncompleteCount": sum(food is not None and convert_food(food) is None for food in foods),
                   "energyPriority": [2048, 2047, 1008]},
        "foods": entries,
    }


def read_archive(path):
    data = path.read_bytes()
    if len(data) > MAX_ARCHIVE_BYTES or hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        raise ValueError("USDA archive size or SHA-256 does not match the pinned release")
    with zipfile.ZipFile(path) as archive:
        info = archive.getinfo(SOURCE_MEMBER)
        if info.file_size > MAX_JSON_BYTES:
            raise ValueError("USDA JSON exceeds the documented input limit")
        return json.loads(archive.read(info))


def render(catalog):
    return (json.dumps(catalog, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True, help="Pinned USDA ZIP, stored outside the source tree")
    parser.add_argument("--download", action="store_true", help="Download this public release into --archive first")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true", help="Verify that the committed catalog is reproducible")
    args = parser.parse_args()
    if args.download:
        with urllib.request.urlopen(SOURCE_URL, timeout=45) as response:
            data = response.read(MAX_ARCHIVE_BYTES + 1)
        if len(data) > MAX_ARCHIVE_BYTES or hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
            raise ValueError("Downloaded USDA release does not match the pinned archive")
        args.archive.parent.mkdir(parents=True, exist_ok=True)
        args.archive.write_bytes(data)
    catalog = build_catalog(read_archive(args.archive))
    if len(catalog["foods"]) != 311:
        raise ValueError("The pinned release must produce exactly 311 complete foods")
    data = render(catalog)
    if args.check:
        if args.output.read_bytes() != data:
            raise ValueError("Bundled food catalog differs from the pinned USDA import")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(data)
    print(f"USDA Foundation {RELEASE}: {len(catalog['foods'])} foods; output SHA-256 {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
