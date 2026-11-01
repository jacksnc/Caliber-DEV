#!/usr/bin/env python3
"""Inventory the supplied ZIP without extracting or executing its programs.

This report is an intake review, never a production import or rights approval.
Run from any directory with the original ZIP as the sole positional argument.
"""
import argparse
import collections
import csv
import hashlib
import importlib.util
import io
import json
import math
from pathlib import Path, PurePosixPath
import zipfile


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def audit(path, output):
    raw = path.read_bytes()
    if len(raw) > 20_000_000:
        raise ValueError("Archive exceeds the intake size limit")
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        infos = archive.infolist()
        names = [entry.filename for entry in infos]
        if len(infos) > 1000 or len(names) != len(set(names)):
            raise ValueError("Too many or duplicate archive entries")
        if sum(entry.file_size for entry in infos) > 20_000_000:
            raise ValueError("Uncompressed archive exceeds the intake size limit")
        for entry in infos:
            name = PurePosixPath(entry.filename)
            if name.is_absolute() or ".." in name.parts or "\\" in entry.filename:
                raise ValueError("Unsafe archive entry name")
            if entry.file_size > 5_000_000 or entry.flag_bits & 1:
                raise ValueError("Oversized or encrypted entry")

        def read_json(name):
            return json.loads(archive.read(name), object_pairs_hook=unique_object)

        dataset = read_json("nutrition_dataset.json")
        handoff = read_json("handoff.json")
        sources = dataset["sources"]
        restaurants = dataset["restaurants"]
        items = [item for restaurant in restaurants for item in restaurant["items"]]
        ids = collections.Counter(item["id"] for item in items)
        source_ids = collections.Counter(source["id"] for source in sources)
        restaurant_ids = collections.Counter(row["id"] for row in restaurants)
        categories = collections.Counter(item["category"] for item in items)
        errors = []
        for restaurant in restaurants:
            chain = read_json(f"data/chains/{restaurant['id']}.json")
            if chain["items"] != restaurant["items"]:
                errors.append({"restaurant": restaurant["id"], "reason": "chain/aggregate mismatch"})
            for item in restaurant["items"]:
                for field in ("calories", "protein_g", "carbs_g", "fat_g"):
                    value = item.get(field)
                    if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
                        errors.append({"item": item["id"], "field": field, "reason": "invalid nutrient"})

        root = Path(__file__).resolve().parents[3]
        spec = importlib.util.spec_from_file_location("menu_importer", root / "scripts/import_restaurant_menus.py")
        importer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(importer)

        def rejection(document):
            try:
                importer.normalize(document, hashlib.sha256(archive.read("nutrition_dataset.json")).hexdigest())
            except importer.MenuValidationError as error:
                return str(error)
            return None

        single = {**dataset, "sources": sources[:1], "restaurants": restaurants[:1]}
        report = {
            "reviewDate": "2026-11-01", "productionReady": False,
            "archiveSHA256": hashlib.sha256(raw).hexdigest(),
            "datasetSHA256": hashlib.sha256(archive.read("nutrition_dataset.json")).hexdigest(),
            "archiveEntries": len(infos), "uncompressedBytes": sum(entry.file_size for entry in infos),
            "sourceCount": len(sources), "restaurantCount": len(restaurants), "itemCount": len(items),
            "handoffClaimedItems": handoff["metadata"]["totalMenuItemsLogged"],
            "chainsWithFewerThan10Items": sum(len(row["items"]) < 10 for row in restaurants),
            "minimumItemsPerChain": min(len(row["items"]) for row in restaurants),
            "maximumItemsPerChain": max(len(row["items"]) for row in restaurants),
            "declaredLicenseStatuses": dict(collections.Counter(s["license"]["status"] for s in sources)),
            "duplicateItemIDs": sorted(key for key, count in ids.items() if count > 1),
            "duplicateSourceIDs": sorted(key for key, count in source_ids.items() if count > 1),
            "duplicateRestaurantIDs": sorted(key for key, count in restaurant_ids.items() if count > 1),
            "structuralErrors": errors, "rawCategories": dict(sorted(categories.items())),
            "importerRejectionFullArchive": rejection(dataset),
            "importerRejectionSingleChain": rejection(single),
            "sourceDocumentFiles": [name for name in names if name.lower().endswith((".pdf", ".html", ".htm"))],
            "limitations": [
                "Positive structural results do not verify nutrition or menu completeness.",
                "official-public is a supplied declaration, not Caliber's completed rights review.",
                "Item fields use snake_case; the app importer requires its documented camelCase fields.",
                "Categories require reviewed mapping; component builders cannot be inferred from flat rows.",
                "Serving grams are supplied claims and have not been source-verified.",
            ],
        }
    output.mkdir(parents=True, exist_ok=True)
    (output / "audit.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    by_source = {source["id"]: source for source in sources}
    with (output / "chain-inventory.csv").open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["restaurant_id", "name", "item_count", "source_url", "declared_license", "review_status"])
        for row in restaurants:
            source = by_source[row["sourceID"]]
            writer.writerow([row["id"], row["name"], len(row["items"]), source["url"], source["license"]["status"], "pending source and rights review"])
    print(f"Audited {len(restaurants)} restaurants / {len(items)} items; productionReady=false")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent)
    arguments = parser.parse_args()
    audit(arguments.archive, arguments.output)
