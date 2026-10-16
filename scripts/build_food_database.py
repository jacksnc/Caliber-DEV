#!/usr/bin/env python3
"""Build Caliber's read-only USDA food database from two pinned public releases.

No network access occurs without --download. Archives stay outside the source
tree. Every imported nutrient is an explicit USDA value per 100 g; missing
values are rejected rather than filled with zero. The older Foundation JSON
export remains a compatibility fixture, not a second production database.
"""
import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import tempfile
import unicodedata
import urllib.request
import zipfile

import import_usda_foods as foundation

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATABASE = ROOT / "Caliber (DEV)/Resources/FoodDatabase.sqlite"
DEFAULT_MANIFEST = ROOT / "Caliber (DEV)/Resources/FoodDatabaseManifest.json"
SCHEMA_VERSION = 1
APPLICATION_ID = 1128352838
MAX_DATABASE_BYTES = 20_000_000
MAX_FOOD_COUNT = 50_000
MAX_SERVING_COUNT = 100_000
MAX_GRAMS = 1_000_000
MAX_LABEL = 300


@dataclass(frozen=True)
class Source:
    id: str
    data_type: str
    release: str
    prefix: str
    array: str
    filename: str
    sha256: str
    maximum_archive_bytes: int
    maximum_json_bytes: int

    @property
    def url(self):
        return "https://fdc.nal.usda.gov/fdc-datasets/" + self.filename

    @property
    def member(self):
        return self.filename.removesuffix(".zip") + ".json"


SOURCES = (
    Source("usda-foundation:2026-04-30", "Foundation", "2026-04-30",
           "usda-foundation", "FoundationFoods",
           "FoodData_Central_foundation_food_json_2026-04-30.zip",
           "186e988ec542e913f51ef62b86a47758e8cdd0d1dc3889e7b055581f3c09c77a",
           2_000_000, 10_000_000),
    Source("usda-sr-legacy:2018-04", "SR Legacy", "2018-04",
           "usda-sr-legacy", "SRLegacyFoods",
           "FoodData_Central_sr_legacy_food_json_2018-04.zip",
           "0fe8ae486a2c8eb42cb96413f058deb51863a46c8fb8eeb4b1fb45006dd338ef",
           20_000_000, 250_000_000),
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def text(value, maximum=512):
    if not isinstance(value, str):
        return None
    normalized = " ".join(value.split())
    if not normalized or len(normalized) > maximum:
        return None
    if any(unicodedata.category(character).startswith("C") for character in normalized):
        return None
    return normalized


def search_name(value):
    decomposed = unicodedata.normalize("NFKD", value.casefold())
    plain = "".join(character for character in decomposed if not unicodedata.combining(character))
    return " ".join(re.findall(r"[^\W_]+", plain, re.UNICODE))


def positive_integer(value):
    return isinstance(value, int) and not isinstance(value, bool) and 0 < value <= 9_223_372_036_854_775_807


def positive_number(value, maximum):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and 0 < value <= maximum and math.isfinite(value))


def nutrient_value(food, nutrient, unit, maximum):
    try:
        return foundation.nutrient_value(food, nutrient, unit, maximum)
    except (OverflowError, ValueError, TypeError):
        return None


def convert_food(food, source):
    """Return (validated row, rejection reason). All macro fields are required."""
    if food is None:
        return None, "null_food"
    if not isinstance(food, dict) or food.get("dataType") != source.data_type:
        return None, "invalid_data_type"
    if not positive_integer(food.get("fdcId")):
        return None, "invalid_fdc_id"
    name = text(food.get("description"))
    publication = text(food.get("publicationDate"), 40)
    if name is None or publication is None:
        return None, "invalid_name_or_publication"
    normalized = search_name(name)
    if not normalized or len(normalized) > 1024:
        return None, "invalid_search_name"
    if not isinstance(food.get("foodNutrients"), list):
        return None, "invalid_nutrient_rows"
    values = [nutrient_value(food, nutrient, "g", 100)
              for nutrient in (1003, 1005, 1004)]
    if any(value is None for value in values):
        return None, "missing_or_invalid_macro"
    energy_id = next((nutrient for nutrient in (2048, 2047, 1008)
                      if nutrient_value(food, nutrient, "kcal", 1000) is not None), None)
    if energy_id is None:
        return None, "missing_or_invalid_energy"
    category = food.get("foodCategory")
    category = text(category.get("description")) if isinstance(category, dict) else None
    return {
        "id": f"{source.prefix}:{food['fdcId']}", "source_id": source.id,
        "fdc_id": food["fdcId"], "name": name, "publication_date": publication,
        "energy_nutrient_id": energy_id,
        "calories": nutrient_value(food, energy_id, "kcal", 1000),
        "protein_g": values[0], "carbohydrate_g": values[1], "fat_g": values[2],
        "category": category or "Uncategorized", "search_name": normalized,
    }, None


def convert_portions(food, row):
    """Keep only unambiguous source portions; gramWeight is already the total.

    For example, USDA's amount=2 tablespoons / gramWeight=33.9 means that
    selecting the displayed '2 tablespoon' portion weighs 33.9 g, not 67.8 g.
    A missing source ID uses its original array position, never a new random ID.
    """
    portions = food.get("foodPortions", [])
    rejected = Counter()
    if not isinstance(portions, list):
        return [], Counter({"invalid_portion_array": 1})
    ids = Counter(portion.get("id") for portion in portions
                  if isinstance(portion, dict) and positive_integer(portion.get("id")))
    result = []
    for position, portion in enumerate(portions):
        if not isinstance(portion, dict):
            rejected["invalid_portion_row"] += 1
            continue
        source_id = portion.get("id")
        if source_id is not None and (not positive_integer(source_id) or ids[source_id] != 1):
            rejected["invalid_or_duplicate_portion_id"] += 1
            continue
        amount, grams = portion.get("amount"), portion.get("gramWeight")
        if not positive_number(amount, MAX_GRAMS) or not positive_number(grams, MAX_GRAMS):
            rejected["invalid_portion_amount_or_weight"] += 1
            continue
        measure_unit = portion.get("measureUnit")
        raw_unit = measure_unit.get("name") if isinstance(measure_unit, dict) else None
        raw_modifier = portion.get("modifier")
        unit = text(raw_unit, MAX_LABEL)
        modifier = text(raw_modifier, MAX_LABEL)
        # An invalid qualifier must not silently disappear from a source label.
        if any(raw is not None and raw != "" and normalized is None
               for raw, normalized in ((raw_unit, unit), (raw_modifier, modifier))):
            rejected["invalid_portion_label"] += 1
            continue
        # SR Legacy encodes many household labels in modifier with a placeholder
        # measure unit. Preserve that label without inventing a mass or density.
        if unit is not None and unit.casefold() in ("undetermined", "unknown", "not specified"):
            unit = None
        if unit is None and modifier is None:
            rejected["missing_portion_label"] += 1
            continue
        label = text(" ".join(piece for piece in (format(amount, ".15g"), unit, modifier) if piece), MAX_LABEL)
        if label is None:
            rejected["invalid_portion_label"] += 1
            continue
        identifier = str(source_id) if source_id is not None else f"position-{position + 1}"
        result.append({"id": f"{row['fdc_id']}:{identifier}", "food_id": row["id"],
                       "label": label, "gram_weight": grams, "sort_order": position})
    return result, rejected


def read_archive(path, source):
    """Verify bounded compressed bytes before touching the ZIP or JSON parser."""
    if path.stat().st_size > source.maximum_archive_bytes:
        raise ValueError(f"Archive exceeds size limit: {source.id}")
    data = path.read_bytes()
    if digest(data) != source.sha256:
        raise ValueError(f"Archive SHA-256 does not match pinned release: {source.id}")
    with zipfile.ZipFile(path) as archive:
        members = [info for info in archive.infolist() if info.filename == source.member]
        if len(members) != 1 or members[0].flag_bits & 1:
            raise ValueError("Missing, duplicate or encrypted USDA JSON member")
        info = members[0]
        if info.file_size > source.maximum_json_bytes:
            raise ValueError("USDA JSON exceeds the input limit")
        with archive.open(info) as stream:
            raw = stream.read(source.maximum_json_bytes + 1)
        if len(raw) > source.maximum_json_bytes or len(raw) != info.file_size:
            raise ValueError("USDA JSON size is invalid")
    document = json.loads(raw)
    return document, {"archiveBytes": len(data), "jsonBytes": len(raw), "jsonSHA256": digest(raw)}


def import_document(document, source):
    foods = document.get(source.array) if isinstance(document, dict) else None
    if not isinstance(foods, list) or len(foods) > MAX_FOOD_COUNT:
        raise ValueError(f"Expected a bounded {source.array} array")
    rows, servings, rejected, portion_rejected = [], [], Counter(), Counter()
    seen = set()
    source_portion_count = 0
    for food in foods:
        row, reason = convert_food(food, source)
        if row is None:
            rejected[reason] += 1
            continue
        if row["fdc_id"] in seen:
            raise ValueError("Duplicate USDA food identifier")
        seen.add(row["fdc_id"])
        rows.append(row)
        raw_portions = food.get("foodPortions", [])
        source_portion_count += len(raw_portions) if isinstance(raw_portions, list) else 0
        converted, failures = convert_portions(food, row)
        servings.extend(converted)
        portion_rejected.update(failures)
    rows.sort(key=lambda row: (row["search_name"], row["fdc_id"]))
    servings.sort(key=lambda row: (row["food_id"], row["sort_order"], row["id"]))
    audit = {"sourceFoodCount": len(foods), "foodCount": len(rows),
             "skippedFoodCount": sum(rejected.values()), "skippedFoodReasons": dict(sorted(rejected.items())),
             "sourcePortionCountForIncludedFoods": source_portion_count, "servingCount": len(servings),
             "skippedPortionReasons": dict(sorted(portion_rejected.items()))}
    return rows, servings, audit


SCHEMA = """
CREATE TABLE catalog_metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE catalog_sources(
 id TEXT PRIMARY KEY, name TEXT NOT NULL, data_type TEXT NOT NULL,
 release TEXT NOT NULL, archive_url TEXT NOT NULL, archive_sha256 TEXT NOT NULL, license TEXT NOT NULL);
CREATE TABLE catalog_foods(
 id TEXT PRIMARY KEY, source_id TEXT NOT NULL REFERENCES catalog_sources(id),
 fdc_id INTEGER NOT NULL UNIQUE CHECK(fdc_id > 0), name TEXT NOT NULL,
 publication_date TEXT NOT NULL, energy_nutrient_id INTEGER NOT NULL,
 calories REAL NOT NULL CHECK(calories BETWEEN 0 AND 1000),
 protein_g REAL NOT NULL CHECK(protein_g BETWEEN 0 AND 100),
 carbohydrate_g REAL NOT NULL CHECK(carbohydrate_g BETWEEN 0 AND 100),
 fat_g REAL NOT NULL CHECK(fat_g BETWEEN 0 AND 100), category TEXT NOT NULL, search_name TEXT NOT NULL);
CREATE TABLE catalog_servings(
 id TEXT PRIMARY KEY, food_id TEXT NOT NULL REFERENCES catalog_foods(id), label TEXT NOT NULL,
 gram_weight REAL NOT NULL CHECK(gram_weight > 0 AND gram_weight <= 1000000), sort_order INTEGER NOT NULL);
CREATE INDEX catalog_foods_source ON catalog_foods(source_id);
CREATE INDEX catalog_foods_name ON catalog_foods(search_name, id);
CREATE INDEX catalog_servings_food ON catalog_servings(food_id, sort_order, id);
CREATE VIRTUAL TABLE food_search USING fts5(
 food_id UNINDEXED, name, tokenize='unicode61 remove_diacritics 2', prefix='2 3 4');
"""


def build_database(path, imported):
    """Create in fixed insertion order with no runtime or wall-clock metadata."""
    all_foods = [row for _, foods, _, _ in imported for row in foods]
    all_servings = [row for _, _, servings, _ in imported for row in servings]
    if not all_foods or len(all_foods) > MAX_FOOD_COUNT or len(all_servings) > MAX_SERVING_COUNT:
        raise ValueError("Database count outside supported limits")
    if len({row["fdc_id"] for row in all_foods}) != len(all_foods):
        raise ValueError("Duplicate food identifiers across sources")
    if len({row["id"] for row in all_servings}) != len(all_servings):
        raise ValueError("Duplicate serving identifiers")
    with sqlite3.connect(path) as db:
        db.execute("PRAGMA page_size=4096")
        db.execute("PRAGMA foreign_keys=ON")
        db.execute(f"PRAGMA user_version={SCHEMA_VERSION}")
        db.execute(f"PRAGMA application_id={APPLICATION_ID}")
        db.executescript(SCHEMA)
        metadata = {"schema_version": str(SCHEMA_VERSION), "basis_grams": "100",
                    "food_count": str(len(all_foods)), "serving_count": str(len(all_servings)),
                    "source_count": str(len(imported)), "importer_version": "1",
                    "energy_priority": "2048,2047,1008"}
        db.executemany("INSERT INTO catalog_metadata VALUES(?,?)", sorted(metadata.items()))
        for source, _, _, _ in sorted(imported, key=lambda item: item[0].id):
            db.execute("INSERT INTO catalog_sources VALUES(?,?,?,?,?,?,?)", (
                source.id, "USDA FoodData Central", source.data_type, source.release,
                source.url, source.sha256, "CC0-1.0"))
        for row in sorted(all_foods, key=lambda row: (row["search_name"], row["id"])):
            db.execute("INSERT INTO catalog_foods VALUES(?,?,?,?,?,?,?,?,?,?,?,?)", tuple(row.values()))
            db.execute("INSERT INTO food_search(food_id,name) VALUES(?,?)", (row["id"], row["search_name"]))
        for row in sorted(all_servings, key=lambda row: (row["food_id"], row["sort_order"], row["id"])):
            db.execute("INSERT INTO catalog_servings VALUES(?,?,?,?,?)", tuple(row.values()))
        db.execute("INSERT INTO food_search(food_search) VALUES('integrity-check')")
        db.commit()
        db.execute("VACUUM")
        if db.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
            raise ValueError("Database integrity check failed")
        if db.execute("PRAGMA foreign_key_check").fetchall():
            raise ValueError("Database contains orphan records")
        if db.execute("SELECT COUNT(*) FROM food_search").fetchone()[0] != len(all_foods):
            raise ValueError("FTS index count does not match foods")
        if db.execute("SELECT food_id,name FROM food_search EXCEPT SELECT id,search_name FROM catalog_foods").fetchone():
            raise ValueError("FTS index content does not match foods")
    if path.stat().st_size > MAX_DATABASE_BYTES:
        raise ValueError("Database exceeds the application size limit")
    return {"foodCount": len(all_foods), "servingCount": len(all_servings)}


def verify_foundation_compatibility(rows, fixture=foundation.DEFAULT_OUTPUT):
    expected = json.loads(fixture.read_bytes())["foods"]
    actual = {row["id"]: row for row in rows}
    if len(actual) != len(expected):
        raise ValueError("Foundation compatibility food count changed")
    for entry in expected:
        row = actual.get(entry["id"])
        if row is None or any((row[key] != value) for key, value in {
            "fdc_id": entry["fdcID"], "name": entry["name"], "publication_date": entry["publicationDate"],
            "energy_nutrient_id": entry["energyNutrientID"],
            "calories": entry["nutritionPer100g"]["calories"],
            "protein_g": entry["nutritionPer100g"]["proteinGrams"],
            "carbohydrate_g": entry["nutritionPer100g"]["carbGrams"],
            "fat_g": entry["nutritionPer100g"]["fatGrams"],
        }.items()):
            raise ValueError("An existing Foundation food changed")


def download(path, source):
    with urllib.request.urlopen(source.url, timeout=60) as response:
        data = response.read(source.maximum_archive_bytes + 1)
    if len(data) > source.maximum_archive_bytes or digest(data) != source.sha256:
        raise ValueError("Downloaded USDA archive does not match the pinned release")
    atomic_write(path, data)


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            os.fchmod(stream.fileno(), 0o644)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def replace_outputs(outputs):
    """Validate/stage both resources first, then replace each path atomically.

    A handled write/rename failure restores any already replaced output. A file
    system cannot atomically rename two independent paths: the loader's pinned
    manifest hash therefore also rejects an interrupted, mismatched pair.
    """
    if len({path.resolve() for path, _ in outputs}) != len(outputs):
        raise ValueError("Database and manifest paths must be distinct")
    staged, replaced = [], []
    try:
        for path, data in outputs:
            path.parent.mkdir(parents=True, exist_ok=True)
            previous = path.read_bytes() if path.exists() else None
            descriptor, name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
            staged.append((path, Path(name), previous))
            with os.fdopen(descriptor, "wb") as stream:
                os.fchmod(stream.fileno(), 0o644)
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
        for path, temporary, previous in staged:
            os.replace(temporary, path)
            replaced.append((path, previous))
    except BaseException:
        for path, previous in reversed(replaced):
            if previous is None:
                path.unlink(missing_ok=True)
            else:
                atomic_write(path, previous)
        raise
    finally:
        for _, temporary, _ in staged:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive-dir", type=Path, required=True, help="Pinned ZIP directory outside source tree")
    parser.add_argument("--download", action="store_true", help="Explicitly download both pinned public releases")
    parser.add_argument("--output", type=Path, default=DEFAULT_DATABASE)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--check", action="store_true", help="Compare both outputs without replacing them")
    args = parser.parse_args()
    imported, source_manifest = [], []
    for source in SOURCES:
        archive_path = args.archive_dir / source.filename
        if args.download:
            download(archive_path, source)
        document, archive_audit = read_archive(archive_path, source)
        foods, servings, audit = import_document(document, source)
        if source == SOURCES[0]:
            verify_foundation_compatibility(foods)
        imported.append((source, foods, servings, audit))
        source_manifest.append({"id": source.id, "name": "USDA FoodData Central", "dataType": source.data_type,
                                "release": source.release, "archiveURL": source.url, "archiveSHA256": source.sha256,
                                "license": "CC0-1.0", "licenseURL": "https://fdc.nal.usda.gov/",
                                **archive_audit, **audit})
        del document
    # Both files are fully built and checked before either final path changes.
    with tempfile.TemporaryDirectory(prefix="caliber-food-build-") as directory:
        candidate = Path(directory) / "FoodDatabase.sqlite"
        counts = build_database(candidate, imported)
        database_bytes = candidate.read_bytes()
    manifest = {"schemaVersion": SCHEMA_VERSION, "applicationID": APPLICATION_ID,
                "databaseSHA256": digest(database_bytes), "databaseBytes": len(database_bytes),
                **counts, "basisGrams": 100, "energyPriority": [2048, 2047, 1008],
                "sqliteVersion": sqlite3.sqlite_version, "sources": source_manifest}
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode()
    if args.check:
        if args.output.read_bytes() != database_bytes or args.manifest.read_bytes() != manifest_bytes:
            raise ValueError("Bundled database or manifest differs from the pinned deterministic import")
    else:
        replace_outputs([(args.output, database_bytes), (args.manifest, manifest_bytes)])
    print(f"USDA database: {counts['foodCount']} foods, {counts['servingCount']} portions, "
          f"{len(database_bytes)} bytes; SHA-256 {digest(database_bytes)}")


if __name__ == "__main__":
    main()
