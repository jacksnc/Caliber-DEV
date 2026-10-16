#!/usr/bin/env python3
"""Build a bounded offline barcode subset from the pinned USDA Branded release.

The archive is streamed, never extracted into the repository. Publication date
selects the newest source record BEFORE nutrition completeness is considered.
This is an editorial, deterministic subset, not full or representative coverage.
USDA Branded nutrients have a 100 g OR 100 mL basis: volume never becomes mass.
"""
import argparse
from collections import Counter
import csv
from datetime import date
import hashlib
import io
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

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "Caliber (DEV)/Resources/PackagedFoodDatabase.sqlite"
DEFAULT_MANIFEST = ROOT / "Caliber (DEV)/Resources/PackagedFoodDatabaseManifest.json"
ARCHIVE_NAME = "FoodData_Central_branded_food_csv_2026-04-30.zip"
ARCHIVE_PREFIX = ARCHIVE_NAME.removesuffix(".zip") + "/"
ARCHIVE_URL = "https://fdc.nal.usda.gov/fdc-datasets/" + ARCHIVE_NAME
ARCHIVE_SHA256 = "26050a5d03197469813754743a21ee0fad4ccf22b6aac2a995846a987719fc49"
SOURCE_ID = "usda-branded:2026-04"
RELEASE = "2026-04"
RELEASE_DAY = "2026-04-30"
SCHEMA_VERSION = 1
APPLICATION_ID = 1128352848
MAX_ARCHIVE_BYTES = 500_000_000
MAX_EXPANDED_BYTES = 3_500_000_000
MAX_DATABASE_BYTES = 40_000_000
MAX_PRODUCT_COUNT = 50_000
MAX_SOURCE_ROWS = 3_000_000
MEMBER_LIMITS = {"food.csv": 450_000_000, "branded_food.csv": 1_100_000_000,
                 "food_nutrient.csv": 1_700_000_000, "nutrient.csv": 100_000}
NUTRIENT_IDS = (2048, 2047, 1008, 1003, 1005, 1004)
ALLOWED_PREPARATIONS = ("", "UNPREPARED", "READY_TO_EAT", "READY_TO_DRINK")
# These owner/brand token phrases are a documented editorial seed choice.
# They are NOT popularity rankings, brand endorsements or market-share claims.
PRIORITY_BRANDS = (
    "general mills", "kellogg", "kellanova", "kraft", "heinz", "pepsico",
    "frito lay", "quaker", "nestle", "conagra", "campbell", "pepperidge farm",
    "danone", "dannon", "chobani", "tyson", "hormel", "smucker",
    "wal mart", "walmart", "great value", "target", "good gather", "kroger",
    "costco", "kirkland", "aldi",
)


def clean_text(value, maximum):
    if not isinstance(value, str):
        return None
    value = " ".join(value.split())
    if not value or len(value) > maximum or any(unicodedata.category(c).startswith("C") for c in value):
        return None
    return value


def tokens(value):
    value = unicodedata.normalize("NFKD", value.casefold())
    return " ".join(re.findall(r"[^\W_]+", "".join(c for c in value if not unicodedata.combining(c))))


def priority_brand(owner, brand):
    value = " " + tokens(owner + " " + brand) + " "
    return any(" " + phrase + " " in value for phrase in PRIORITY_BRANDS)


def canonical_gtin(raw):
    if not isinstance(raw, str):
        return None
    raw = raw.strip()
    if len(raw) not in (8, 12, 13, 14) or not re.fullmatch(r"[0-9]+", raw) or set(raw) == {"0"}:
        return None
    weighted = sum(int(digit) * (3 if position % 2 == 0 else 1)
                   for position, digit in enumerate(reversed(raw[:-1])))
    if (10 - weighted % 10) % 10 != int(raw[-1]):
        return None
    return raw.zfill(14)


def source_date(raw):
    if not isinstance(raw, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", raw):
        return None
    try:
        value = date.fromisoformat(raw)
    except ValueError:
        return None
    return raw if "1900-01-01" <= value.isoformat() <= RELEASE_DAY else None


def source_id(raw):
    if not isinstance(raw, str) or not re.fullmatch(r"[1-9][0-9]{0,17}", raw):
        return None
    value = int(raw)
    return value if value <= 9_223_372_036_854_775_807 else None


def number(raw, minimum, maximum, positive=False):
    if not isinstance(raw, str) or not raw.strip():
        return None
    try:
        value = float(raw)
    except (ValueError, OverflowError):
        return None
    if not math.isfinite(value) or not minimum <= value <= maximum or (positive and value == 0):
        return None
    return value


class HashingReader(io.RawIOBase):
    """Hash decompressed CSV bytes as the CSV parser consumes them."""
    def __init__(self, stream, maximum):
        self.stream, self.maximum = stream, maximum
        self.count, self.hash = 0, hashlib.sha256()

    def readable(self):
        return True

    def readinto(self, buffer):
        data = self.stream.read(len(buffer))
        self.count += len(data)
        if self.count > self.maximum:
            raise ValueError("CSV exceeds the bounded member size")
        self.hash.update(data)
        buffer[:len(data)] = data
        return len(data)


def verify_archive(path, expected_sha=ARCHIVE_SHA256, maximum=MAX_ARCHIVE_BYTES):
    if path.stat().st_size > maximum:
        raise ValueError("USDA archive exceeds the compressed size bound")
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != expected_sha:
        raise ValueError("USDA archive SHA-256 differs from the pinned release")
    with zipfile.ZipFile(path) as archive:
        members = archive.infolist()
        if len({item.filename for item in members}) != len(members):
            raise ValueError("USDA archive has duplicate member names")
        if sum(item.file_size for item in members) > MAX_EXPANDED_BYTES:
            raise ValueError("USDA archive exceeds the expanded size bound")
        for name, maximum_bytes in MEMBER_LIMITS.items():
            info = archive.getinfo(ARCHIVE_PREFIX + name)
            if info.flag_bits & 1 or info.file_size > maximum_bytes:
                raise ValueError("USDA member encrypted or above size bound")


def rows(archive, name, required_fields, audits):
    info = archive.getinfo(ARCHIVE_PREFIX + name)
    with archive.open(info) as raw:
        hashing = HashingReader(raw, MEMBER_LIMITS[name])
        with io.TextIOWrapper(io.BufferedReader(hashing, 1024 * 1024), encoding="utf-8-sig", newline="") as text:
            reader = csv.DictReader(text)
            if not reader.fieldnames or len(set(reader.fieldnames)) != len(reader.fieldnames) or not set(required_fields) <= set(reader.fieldnames):
                raise ValueError(f"CSV header differs from expected USDA fields: {name}")
            count = 0
            for row in reader:
                count += 1
                if name != "food_nutrient.csv" and count > MAX_SOURCE_ROWS:
                    raise ValueError("USDA source row limit exceeded")
                if None in row or any(value is None for value in row.values()):
                    raise ValueError(f"Malformed CSV row in {name}")
                yield row
        if hashing.count != info.file_size:
            raise ValueError("CSV stream did not match its advertised size")
        audits[name] = {"bytes": hashing.count, "sha256": hashing.hash.hexdigest(), "rowCount": count}


def stage_foods(db, food_rows, audit):
    db.execute("CREATE TABLE foods(fdc_id INTEGER PRIMARY KEY, name TEXT, publication TEXT, market TEXT, valid_type INTEGER)")
    batch = []
    for row in food_rows:
        identifier = source_id(row["fdc_id"])
        if identifier is None:
            raise ValueError("Invalid USDA food identifier")
        batch.append((identifier, row["description"], source_date(row["publication_date"]) or "",
                      row["market_country"], row["data_type"] == "branded_food"))
        if len(batch) == 5000:
            db.executemany("INSERT INTO foods VALUES(?,?,?,?,?)", batch)
            batch = []
    db.executemany("INSERT INTO foods VALUES(?,?,?,?,?)", batch)
    db.commit()
    audit["sourceFoodCount"] = db.execute("SELECT COUNT(*) FROM foods").fetchone()[0]


def stage_brands(db, branded_rows, audit):
    db.execute("""CREATE TABLE branded(fdc_id INTEGER PRIMARY KEY, gtin TEXT NOT NULL,
      brand TEXT, owner TEXT, modified TEXT, market TEXT, discontinued TEXT,
      quantity TEXT, unit TEXT, label TEXT, preparation TEXT, priority INTEGER)""")
    rejected, batch, total = Counter(), [], 0
    for row in branded_rows:
        total += 1
        identifier, gtin = source_id(row["fdc_id"]), canonical_gtin(row["gtin_upc"])
        if identifier is None:
            raise ValueError("Invalid USDA branded identifier")
        if gtin is None:
            rejected["invalid_gtin"] += 1
            continue
        owner, brand = row["brand_owner"], row["brand_name"]
        # Keep incomplete metadata here: newest selection must precede filtering.
        raw_modified = row["modified_date"].strip()
        modified = (source_date(raw_modified) or "invalid") if raw_modified else ""
        batch.append((identifier, gtin, brand, owner, modified,
                      row["market_country"], row["discontinued_date"], row["serving_size"],
                      row["serving_size_unit"], row["household_serving_fulltext"], row["preparation_state_code"],
                      int(priority_brand(owner, brand))))
        if len(batch) == 5000:
            db.executemany("INSERT INTO branded VALUES(?,?,?,?,?,?,?,?,?,?,?,?)", batch)
            batch = []
    db.executemany("INSERT INTO branded VALUES(?,?,?,?,?,?,?,?,?,?,?,?)", batch)
    db.commit()
    db.execute("CREATE INDEX branded_gtin ON branded(gtin)")
    audit.update(sourceBrandedCount=total, sourceBrandedRejections=dict(sorted(rejected.items())))


def latest_candidates(db, audit):
    """No older complete record may replace an incomplete newest record."""
    if db.execute("SELECT 1 FROM branded b LEFT JOIN foods f USING(fdc_id) WHERE f.fdc_id IS NULL LIMIT 1").fetchone():
        raise ValueError("Branded food has no source food record")
    # An unorderable version can hide a newer update. Reject its whole GTIN.
    db.execute("""CREATE TEMP TABLE unordered AS SELECT DISTINCT gtin FROM branded b JOIN foods f USING(fdc_id)
      WHERE publication='' OR modified='invalid'
      UNION SELECT gtin FROM branded b JOIN foods f USING(fdc_id) GROUP BY gtin,publication
      HAVING COUNT(*)>1 AND SUM(modified='')>0""")
    db.execute("CREATE UNIQUE INDEX unordered_gtin ON unordered(gtin)")
    db.execute("""CREATE TEMP TABLE ranked AS SELECT b.*, f.name, f.publication,
      f.market AS food_market, f.valid_type,
      RANK() OVER(PARTITION BY b.gtin ORDER BY f.publication DESC,b.modified DESC) AS date_rank
      FROM branded b JOIN foods f USING(fdc_id)""")
    db.execute("CREATE TEMP TABLE top_counts AS SELECT gtin,COUNT(*) AS n FROM ranked WHERE date_rank=1 GROUP BY gtin")
    db.execute("CREATE UNIQUE INDEX top_gtin ON top_counts(gtin)")
    rejected, candidates = Counter(), {}
    query = """SELECT r.*,t.n,u.gtin AS unordered_gtin FROM ranked r JOIN top_counts t USING(gtin)
      LEFT JOIN unordered u USING(gtin) WHERE date_rank=1 ORDER BY r.gtin,r.fdc_id"""
    db.row_factory = sqlite3.Row
    prior_gtin = None
    for record in db.execute(query):
        row = dict(record)
        if row["gtin"] == prior_gtin:
            continue
        prior_gtin = row["gtin"]
        if row["unordered_gtin"] is not None:
            rejected["unorderable_version_date"] += 1
            continue
        if row["n"] != 1:
            rejected["ambiguous_latest_date_tie"] += 1
            continue
        product, reason = product_metadata(row)
        if product is None:
            rejected[reason] += 1
        else:
            candidates[row["fdc_id"]] = product
    db.row_factory = None
    audit.update(uniqueGTINCount=db.execute("SELECT COUNT(*) FROM top_counts").fetchone()[0],
                 latestRecordRejections=dict(sorted(rejected.items())), metadataCandidateCount=len(candidates))
    return candidates


def product_metadata(row):
    us_markets = ("united states", "us")
    if not row["valid_type"]:
        return None, "invalid_source_data_type"
    if row["market"].strip().casefold() not in us_markets or row["food_market"].strip().casefold() not in us_markets:
        return None, "not_explicit_us_market"
    if row["discontinued"].strip():
        return None, "discontinued_record"
    if row["preparation"].strip().upper() not in ALLOWED_PREPARATIONS:
        return None, "unsupported_preparation_state"
    name = clean_text(row["name"], 512)
    raw_brand = row["brand"] if row["brand"].strip() else row["owner"]
    brand = clean_text(raw_brand, 256) if raw_brand.strip() else ""
    if name is None or brand is None:
        return None, "missing_or_invalid_name_or_brand"
    unit = {"g": "g", "ml": "mL"}.get(row["unit"].strip().casefold())
    quantity = number(row["quantity"], 0, 10_000, positive=True)
    if unit is None or quantity is None:
        return None, "unsupported_or_invalid_serving_basis"
    raw_label = row["label"]
    label = clean_text(raw_label, 300) if raw_label.strip() else f"{quantity:.15g} {unit}"
    if label is None:
        return None, "invalid_household_label"
    return {"gtin14": row["gtin"], "fdc_id": row["fdc_id"], "name": name, "brand": brand,
            "publication_date": row["publication"], "modified_date": row["modified"],
            "basis_unit": unit, "serving_quantity": quantity, "serving_unit": unit,
            "serving_label": label, "priority": row["priority"], "preparation": row["preparation"]}, None


def nutrient_units(nutrient_rows):
    units = {}
    for row in nutrient_rows:
        if row["id"] not in {str(value) for value in NUTRIENT_IDS}:
            continue
        identifier = int(row["id"])
        if identifier in units:
            raise ValueError("Duplicate nutrient identifier in source nutrient units")
        units[identifier] = row["unit_name"].strip().casefold()
    for identifier in NUTRIENT_IDS:
        if units.get(identifier) != ("kcal" if identifier in (2048, 2047, 1008) else "g"):
            raise ValueError("Missing nutrient or wrong source nutrient unit")
    return units


def gather_nutrition(nutrient_rows, candidates):
    needed = {str(identifier): position for position, identifier in enumerate(NUTRIENT_IDS)}
    values, duplicates = {}, set()
    for row in nutrient_rows:
        position = needed.get(row["nutrient_id"])
        if position is None:
            continue
        identifier = source_id(row["fdc_id"])
        if identifier not in candidates:
            continue
        key = (identifier, position)
        record = values.setdefault(identifier, [None] * len(NUTRIENT_IDS))
        if key in duplicates or record[position] is not None:
            record[position] = "invalid"
            duplicates.add(key)
            continue
        # Preserve explicit invalid/missing values as invalid, not unseen slots.
        maximum = (2000 if position < 3 else 200) if candidates[identifier]["basis_unit"] == "mL" else (1000 if position < 3 else 100)
        value = number(row["amount"], 0, maximum)
        record[position] = value if value is not None else "invalid"
    return values


def complete_products(candidates, nutrition, audit, limit=MAX_PRODUCT_COUNT):
    if not 1 <= limit <= MAX_PRODUCT_COUNT:
        raise ValueError("Product limit outside supported bounds")
    products, rejected, energy_counts, preparation_counts = [], Counter(), Counter(), Counter()
    for identifier, product in candidates.items():
        values = nutrition.get(identifier, [None] * 6)
        if any(not isinstance(value, float) for value in values[3:]):
            rejected["missing_or_invalid_macros"] += 1
            continue
        energy_position = next((position for position in range(3) if isinstance(values[position], float)), None)
        if energy_position is None:
            rejected["missing_or_invalid_kcal"] += 1
            continue
        result = {**product, "calories": values[energy_position], "protein_g": values[3],
                  "carbohydrate_g": values[4], "fat_g": values[5],
                  "energy_id": NUTRIENT_IDS[energy_position]}
        products.append(result)
    products.sort(key=lambda row: (-row["priority"], -date.fromisoformat(row["publication_date"]).toordinal(),
                                   -date.fromisoformat(row["modified_date"]).toordinal() if row["modified_date"] else 0,
                                   row["gtin14"]))
    selected = products[:limit]
    for product in selected:
        energy_counts[str(product["energy_id"])] += 1
        preparation_counts[product["preparation"] or "not_supplied"] += 1
    audit.update(completeCandidateCount=len(products), completenessRejections=dict(sorted(rejected.items())),
                 omittedBySubsetLimit=max(0, len(products) - limit), selectedPriorityBrandCount=sum(row["priority"] for row in selected),
                 energyNutrientCounts=dict(sorted(energy_counts.items())), preparationStateCounts=dict(sorted(preparation_counts.items())))
    return selected


SCHEMA = """
CREATE TABLE packaged_metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
CREATE TABLE packaged_sources(id TEXT PRIMARY KEY,name TEXT NOT NULL,data_type TEXT NOT NULL,
 release TEXT NOT NULL,archive_url TEXT NOT NULL,archive_sha256 TEXT NOT NULL,license TEXT NOT NULL);
CREATE TABLE packaged_products(
 gtin14 TEXT PRIMARY KEY,fdc_id INTEGER NOT NULL UNIQUE,name TEXT NOT NULL,brand TEXT NOT NULL,
 publication_date TEXT NOT NULL,modified_date TEXT NOT NULL,calories REAL NOT NULL,
 protein_g REAL NOT NULL,carbohydrate_g REAL NOT NULL,fat_g REAL NOT NULL,
 basis_unit TEXT NOT NULL CHECK(basis_unit IN('g','mL')),serving_quantity REAL,
 serving_unit TEXT,serving_label TEXT,source_id TEXT NOT NULL REFERENCES packaged_sources(id));
"""


def build_database(path, products):
    if not products or len(products) > MAX_PRODUCT_COUNT:
        raise ValueError("No products or too many products for bundled database")
    with sqlite3.connect(path) as db:
        db.execute("PRAGMA page_size=4096")
        db.execute("PRAGMA foreign_keys=ON")
        db.execute(f"PRAGMA user_version={SCHEMA_VERSION}")
        db.execute(f"PRAGMA application_id={APPLICATION_ID}")
        db.executescript(SCHEMA)
        db.executemany("INSERT INTO packaged_metadata VALUES(?,?)", sorted({
            "schema_version": str(SCHEMA_VERSION), "product_count": str(len(products)),
            "basis": "100 units of basis_unit (g or mL); never assume mL equals g",
            "selection_policy": "latest-source-first; explicit-US; priority-brand-then-newest; bounded-subset-v1",
        }.items()))
        db.execute("INSERT INTO packaged_sources VALUES(?,?,?,?,?,?,?)", (SOURCE_ID, "USDA FoodData Central",
                   "Branded", RELEASE, ARCHIVE_URL, ARCHIVE_SHA256, "CC0-1.0"))
        fields = ("gtin14", "fdc_id", "name", "brand", "publication_date", "modified_date", "calories",
                  "protein_g", "carbohydrate_g", "fat_g", "basis_unit", "serving_quantity", "serving_unit", "serving_label")
        for product in sorted(products, key=lambda row: row["gtin14"]):
            db.execute("INSERT INTO packaged_products VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                       tuple(product[field] for field in fields) + (SOURCE_ID,))
        db.commit()
        db.execute("VACUUM")
        if db.execute("PRAGMA integrity_check").fetchall() != [("ok",)] or db.execute("PRAGMA foreign_key_check").fetchall():
            raise ValueError("Packaged database failed integrity or relationship validation")
    if path.stat().st_size > MAX_DATABASE_BYTES:
        raise ValueError("Packaged database exceeds the app's bounded size")


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
    if len({path.resolve() for path, _ in outputs}) != len(outputs):
        raise ValueError("Database and manifest paths must differ")
    staged, replaced = [], []
    try:
        for path, data in outputs:
            path.parent.mkdir(parents=True, exist_ok=True)
            previous = path.read_bytes() if path.exists() else None
            descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
            staged.append((path, Path(temporary), previous))
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
            atomic_write(path, previous) if previous is not None else path.unlink(missing_ok=True)
        raise
    finally:
        for _, temporary, _ in staged:
            temporary.unlink(missing_ok=True)


def download(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".usda-branded-", dir=path.parent)
    try:
        digest, count = hashlib.sha256(), 0
        with os.fdopen(descriptor, "wb") as output, urllib.request.urlopen(ARCHIVE_URL, timeout=60) as response:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                count += len(chunk)
                if count > MAX_ARCHIVE_BYTES:
                    raise ValueError("Downloaded archive exceeds compressed size bound")
                output.write(chunk)
                digest.update(chunk)
        if digest.hexdigest() != ARCHIVE_SHA256:
            raise ValueError("Downloaded archive differs from pinned SHA-256")
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True, help="Pinned CSV ZIP outside the source tree")
    parser.add_argument("--download", action="store_true", help="Download the pinned public ZIP first (about449MB)")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--check", action="store_true", help="Rebuild and compare without replacing resources")
    args = parser.parse_args()
    csv.field_size_limit(1_000_000)
    if args.download:
        download(args.archive)
    verify_archive(args.archive)
    audit, member_audits = {}, {}
    with tempfile.TemporaryDirectory(prefix="caliber-packaged-") as directory:
        with sqlite3.connect(Path(directory) / "staging.sqlite") as staging, zipfile.ZipFile(args.archive) as archive:
            staging.execute("PRAGMA journal_mode=OFF")
            staging.execute("PRAGMA synchronous=OFF")
            staging.execute("PRAGMA cache_size=-65536")
            stage_foods(staging, rows(archive, "food.csv", ("fdc_id", "description", "publication_date", "market_country", "data_type"), member_audits), audit)
            stage_brands(staging, rows(archive, "branded_food.csv", ("fdc_id", "gtin_upc", "brand_name", "brand_owner", "modified_date", "market_country", "discontinued_date", "serving_size", "serving_size_unit", "household_serving_fulltext", "preparation_state_code"), member_audits), audit)
            candidates = latest_candidates(staging, audit)
            print(f"Metadata candidates: {len(candidates)}; reading source nutrients", flush=True)
            nutrient_units(rows(archive, "nutrient.csv", ("id", "unit_name"), member_audits))
            nutrition = gather_nutrition(rows(archive, "food_nutrient.csv", ("fdc_id", "nutrient_id", "amount"), member_audits), candidates)
            products = complete_products(candidates, nutrition, audit)
        candidate = Path(directory) / "PackagedFoodDatabase.sqlite"
        build_database(candidate, products)
        database = candidate.read_bytes()
    manifest = {"schemaVersion": SCHEMA_VERSION, "applicationID": APPLICATION_ID,
                "databaseSHA256": hashlib.sha256(database).hexdigest(), "databaseBytes": len(database),
                "productCount": len(products), "sqliteVersion": sqlite3.sqlite_version,
                "source": {"id": SOURCE_ID, "name": "USDA FoodData Central", "dataType": "Branded", "release": RELEASE,
                           "archiveURL": ARCHIVE_URL, "archiveSHA256": ARCHIVE_SHA256,
                           "archiveBytes": args.archive.stat().st_size, "license": "CC0-1.0", "licenseURL": "https://fdc.nal.usda.gov/"},
                "selection": {"maximumProducts": MAX_PRODUCT_COUNT, "priorityBrandTokenPhrases": list(PRIORITY_BRANDS),
                              "order": ["priority brand first", "publication date descending", "modified date descending", "canonical GTIN ascending"],
                              "versionPolicy": "Newest publication then modified date before eligibility/completeness; all top-date ties excluded; no older fallback",
                              "preparationStates": list(ALLOWED_PREPARATIONS),
                              "scope": "Deterministic initial US-market subset; not full, representative or popularity-ranked coverage"},
                "nutrition": {"basis": "100 g or 100 mL, exactly as basis_unit", "energyPriority": [2048, 2047, 1008],
                              "sourceUnitMapping": {"g": "g", "ml": "mL"}, "missingNutrients": "excluded, never zero-filled",
                              "volumePolicy": "No volume-to-mass or density inference"},
                "audit": audit, "csvMembers": member_audits}
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode()
    if args.check:
        if args.output.read_bytes() != database or args.manifest.read_bytes() != manifest_bytes:
            raise ValueError("Packaged database or manifest differs from the pinned import")
    else:
        replace_outputs([(args.output, database), (args.manifest, manifest_bytes)])
    print(f"USDA packaged subset: {len(products)} products, {len(database)} bytes; SHA-256 {hashlib.sha256(database).hexdigest()}")


if __name__ == "__main__":
    main()
