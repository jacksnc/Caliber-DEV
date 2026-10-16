#!/usr/bin/env python3
"""Validate and normalize a maintainer-supplied, licensed restaurant menu.

No source is fetched. Every nutrient is supplied explicitly for the stated menu
serving. This tool does not estimate nutrition, infer a serving mass or verify
legal rights: license.status and permissionReference are maintainer declarations
that must correspond to an actual completed rights review before production.

Default operation validates and prints a short summary. --preview prints the
complete normalized JSON; --output saves it atomically. --check compares a
previous output without modifying it. Fictional examples require --fixture and
remain visibly flagged in the output; they cannot become production catalogs.
"""
import argparse
from datetime import date
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys
import tempfile
import unicodedata
from urllib.parse import urlsplit

SCHEMA_VERSION = 1
MAX_BYTES = 5_000_000
MAX_SOURCES = 100
MAX_RESTAURANTS = 100
MAX_ITEMS_PER_RESTAURANT = 1000
MAX_ITEMS = 10_000
MAX_NUTRIENT = 1_000_000
MAX_GRAMS = 1_000_000
IDENTIFIER = re.compile(r"[a-z0-9][a-z0-9._:-]{0,95}\Z")
CATEGORIES = ("appetizer", "entree", "side", "drink", "dessert")


class MenuValidationError(ValueError):
    """An input is incomplete, ambiguous, unapproved or outside safe bounds."""


def fail(path, message):
    raise MenuValidationError(f"{path}: {message}")


def object_fields(value, required, optional, path):
    if not isinstance(value, dict):
        fail(path, "expected an object")
    missing = set(required) - set(value)
    unknown = set(value) - set(required) - set(optional)
    if missing:
        fail(path, "missing fields: " + ", ".join(sorted(missing)))
    if unknown:
        fail(path, "unknown fields: " + ", ".join(sorted(unknown)))


def bounded_array(value, maximum, path):
    if not isinstance(value, list) or len(value) > maximum:
        fail(path, f"expected an array of at most {maximum} entries")
    return value


def text(value, maximum, path):
    if not isinstance(value, str):
        fail(path, "expected a nonempty string")
    normalized = " ".join(value.split())
    if not normalized or len(normalized) > maximum:
        fail(path, f"expected 1 to {maximum} characters")
    if any(unicodedata.category(character).startswith("C") for character in normalized):
        fail(path, "control characters are not permitted")
    return normalized


def identifier(value, path):
    if not isinstance(value, str) or IDENTIFIER.fullmatch(value) is None:
        fail(path, "expected a stable lowercase ID of 1 to 96 letters, digits, dots, underscores, colons or hyphens")
    return value


def calendar_date(value, path):
    if not isinstance(value, str) or re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value) is None:
        fail(path, "expected a canonical YYYY-MM-DD date")
    try:
        parsed = date.fromisoformat(value)
    except ValueError:
        fail(path, "date does not exist in the calendar")
    if parsed.isoformat() != value:
        fail(path, "expected a canonical YYYY-MM-DD date")
    return value


def source_url(value, fictional, path):
    if not isinstance(value, str) or not value.startswith("https://") or len(value) > 2000:
        fail(path, "expected an HTTPS URL of at most 2000 characters")
    if "\\" in value or any(character.isspace() or unicodedata.category(character).startswith("C") for character in value):
        fail(path, "URL contains whitespace, controls or a backslash")
    try:
        parsed = urlsplit(value)
        host = parsed.hostname
        port = parsed.port
    except ValueError:
        fail(path, "URL cannot be parsed")
    if parsed.scheme != "https" or not host or parsed.username is not None or parsed.password is not None:
        fail(path, "URL must have an HTTPS host and no embedded credentials")
    if port is not None and not 1 <= port <= 65535:
        fail(path, "URL port is invalid")
    if not re.fullmatch(r"[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?", host) or "." not in host:
        fail(path, "URL must have a valid public domain name")
    if any(not label or len(label) > 63 or label.startswith("-") or label.endswith("-") for label in host.split(".")):
        fail(path, "URL domain labels are invalid")
    reserved = host.casefold().endswith((".invalid", ".test", ".example")) or host.casefold() in ("example.com", "example.org", "example.net")
    if reserved and not fictional:
        fail(path, "reserved example domains are allowed only in an explicitly fictional fixture")
    return value


def numeric(value, maximum, path, positive=False):
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        fail(path, "expected an explicit numeric value; missing values are not zero")
    if not 0 <= value <= maximum or (positive and value == 0) or not math.isfinite(value):
        fail(path, f"expected a finite {'positive' if positive else 'nonnegative'} value no greater than {maximum}")
    # Normalize integer/float representations without rounding source nutrients.
    return float(value) if value != 0 else 0.0


def unique_id(value, seen, path):
    result = identifier(value, path)
    if result in seen:
        fail(path, "duplicate identifier")
    seen.add(result)
    return result


def normalize(document, input_sha256, allow_fixture=False):
    object_fields(document, ("schemaVersion", "sources", "restaurants"), ("fictional",), "input")
    if type(document["schemaVersion"]) is not int or document["schemaVersion"] != SCHEMA_VERSION:
        fail("schemaVersion", "unsupported schema version")
    fictional = document.get("fictional", False)
    if type(fictional) is not bool:
        fail("fictional", "expected true or false")
    if fictional and not allow_fixture:
        fail("fictional", "fictional data requires --fixture and cannot produce a production catalog")
    if not isinstance(input_sha256, str) or re.fullmatch(r"[a-f0-9]{64}", input_sha256) is None:
        fail("inputSHA256", "expected the actual SHA-256 of the input file bytes")

    sources, restaurants = [], []
    source_ids, restaurant_ids, item_ids = set(), set(), set()
    for index, source in enumerate(bounded_array(document["sources"], MAX_SOURCES, "sources")):
        path = f"sources[{index}]"
        object_fields(source, ("id", "name", "url", "retrievedOn", "license"), (), path)
        license_value = source["license"]
        object_fields(license_value, ("status", "permissionReference", "attribution"), (), path + ".license")
        expected_status = "fixture" if fictional else "approved"
        if license_value["status"] != expected_status:
            fail(path + ".license.status", f"expected {expected_status!r}; an actual rights review is required for production")
        sources.append({
            "id": unique_id(source["id"], source_ids, path + ".id"),
            "name": text(source["name"], 200, path + ".name"),
            "url": source_url(source["url"], fictional, path + ".url"),
            "retrievedOn": calendar_date(source["retrievedOn"], path + ".retrievedOn"),
            "license": {"status": expected_status,
                        "permissionReference": text(license_value["permissionReference"], 1000, path + ".license.permissionReference"),
                        "attribution": text(license_value["attribution"], 1000, path + ".license.attribution")},
        })

    for index, restaurant in enumerate(bounded_array(document["restaurants"], MAX_RESTAURANTS, "restaurants")):
        path = f"restaurants[{index}]"
        object_fields(restaurant, ("id", "name", "sourceID", "items"), (), path)
        restaurant_id = unique_id(restaurant["id"], restaurant_ids, path + ".id")
        reference = identifier(restaurant["sourceID"], path + ".sourceID")
        if reference not in source_ids:
            fail(path + ".sourceID", "restaurant references a missing source")
        items = []
        for item_index, item in enumerate(bounded_array(restaurant["items"], MAX_ITEMS_PER_RESTAURANT, path + ".items")):
            item_path = f"{path}.items[{item_index}]"
            object_fields(item, ("id", "name", "category", "servingDescription", "calories", "proteinGrams", "carbGrams", "fatGrams"), ("servingGrams",), item_path)
            item_id = unique_id(item["id"], item_ids, item_path + ".id")
            if len(item_ids) > MAX_ITEMS:
                fail("restaurants", f"catalog exceeds {MAX_ITEMS} total items")
            if not isinstance(item["category"], str) or item["category"] not in CATEGORIES:
                fail(item_path + ".category", "expected one of: " + ", ".join(CATEGORIES))
            grams = item.get("servingGrams")
            items.append({
                "id": item_id, "name": text(item["name"], 200, item_path + ".name"),
                "category": item["category"],
                "servingDescription": text(item["servingDescription"], 300, item_path + ".servingDescription"),
                "servingGrams": None if grams is None else numeric(grams, MAX_GRAMS, item_path + ".servingGrams", positive=True),
                **{field: numeric(item[field], MAX_NUTRIENT, item_path + "." + field)
                   for field in ("calories", "proteinGrams", "carbGrams", "fatGrams")},
            })
        restaurants.append({"id": restaurant_id, "name": text(restaurant["name"], 200, path + ".name"),
                            "sourceID": reference, "items": sorted(items, key=lambda item: item["id"])})
    return {"schemaVersion": SCHEMA_VERSION, "fictional": fictional, "inputSHA256": input_sha256,
            "sources": sorted(sources, key=lambda source: source["id"]),
            "restaurants": sorted(restaurants, key=lambda restaurant: restaurant["id"])}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            fail("JSON", "duplicate object key: " + key)
        result[key] = value
    return result


def reject_constant(value):
    fail("JSON", "nonfinite numeric constant: " + value)


def json_integer(value):
    if len(value) > 32:
        fail("JSON", "integer token exceeds the supported precision")
    return int(value)


def json_float(value):
    if len(value) > 128:
        fail("JSON", "numeric token exceeds the supported precision")
    return float(value)


def load_input(path, allow_fixture=False):
    if path.stat().st_size > MAX_BYTES:
        fail("input", "file exceeds the 5 MB input limit")
    data = path.read_bytes()
    if len(data) > MAX_BYTES:
        fail("input", "file exceeds the 5 MB input limit")
    try:
        document = json.loads(data.decode("utf-8"), object_pairs_hook=unique_object, parse_constant=reject_constant,
                              parse_int=json_integer, parse_float=json_float)
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError) as error:
        fail("input", "expected bounded UTF-8 JSON: " + str(error))
    return normalize(document, hashlib.sha256(data).hexdigest(), allow_fixture)


def render(document):
    data = (json.dumps(document, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
    if len(data) > MAX_BYTES:
        fail("output", "normalized document exceeds the 5 MB output limit")
    return data


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


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Maintainer-supplied source JSON; never fetched")
    parser.add_argument("--fixture", action="store_true", help="Explicitly permit visibly fictional test data")
    parser.add_argument("--preview", action="store_true", help="Print complete normalized JSON")
    parser.add_argument("--output", type=Path, help="Optional normalized output path")
    parser.add_argument("--check", action="store_true", help="Compare --output without replacing it")
    args = parser.parse_args(argv)
    if args.check and args.output is None:
        parser.error("--check requires --output")
    if args.output is not None and args.input.resolve() == args.output.resolve():
        parser.error("input and output must be different files")
    try:
        normalized = load_input(args.input, args.fixture)
        data = render(normalized)
        if args.output is not None:
            if args.check:
                if args.output.read_bytes() != data:
                    fail("output", "file differs from the deterministic import")
            else:
                atomic_write(args.output, data)
        if args.preview:
            sys.stdout.buffer.write(data)
        else:
            count = sum(len(restaurant["items"]) for restaurant in normalized["restaurants"])
            kind = "fictional fixture" if normalized["fictional"] else "production registry"
            print(f"Validated {kind}: {len(normalized['sources'])} sources, {len(normalized['restaurants'])} restaurants, "
                  f"{count} menu items; input SHA-256 {normalized['inputSHA256']}")
    except (MenuValidationError, OSError) as error:
        print("Restaurant import rejected: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
