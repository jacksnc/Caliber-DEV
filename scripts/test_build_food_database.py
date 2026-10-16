#!/usr/bin/env python3
"""Offline tests for USDA database policy and the shipped deterministic resource."""
import copy
from dataclasses import replace
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest import mock
import warnings
import zipfile

import build_food_database as importer
import test_import_usda_foods


def food(source=importer.SOURCES[0]):
    result = test_import_usda_foods.food()
    result["dataType"] = source.data_type
    result["foodCategory"] = {"description": "Poultry Products"}
    result["foodPortions"] = [portion()]
    return result


def portion():
    return {"id": 111, "amount": 2, "gramWeight": 33.9,
            "measureUnit": {"name": "tablespoon"}, "modifier": "chopped"}


def imported(source=importer.SOURCES[0], items=None):
    rows, servings, audit = importer.import_document({source.array: items or [food(source)]}, source)
    return source, rows, servings, audit


class NutrientPolicyTests(unittest.TestCase):
    def test_both_sources_keep_prepared_names_and_explicit_zero(self):
        for source in importer.SOURCES:
            row, reason = importer.convert_food(food(source), source)
            self.assertIsNone(reason)
            self.assertEqual(row["id"], f"{source.prefix}:123")
            self.assertEqual(row["name"], "Chicken, cooked")
            self.assertEqual(row["carbohydrate_g"], 0)
            self.assertEqual(row["category"], "Poultry Products")

    def test_macros_need_one_explicit_finite_gram_value(self):
        for replacement in (None, -1, float("nan"), float("inf"), False, "0", 101, 10 ** 999):
            with self.subTest(value=replacement):
                source = food()
                source["foodNutrients"][2]["amount"] = replacement
                row, reason = importer.convert_food(source, importer.SOURCES[0])
                self.assertIsNone(row)
                self.assertEqual(reason, "missing_or_invalid_macro")
        for action in ("remove", "unit", "duplicate"):
            source = food()
            if action == "remove":
                source["foodNutrients"].pop(2)
            elif action == "unit":
                source["foodNutrients"][2]["nutrient"]["unitName"] = "mg"
            else:
                source["foodNutrients"].append(copy.deepcopy(source["foodNutrients"][2]))
            self.assertIsNone(importer.convert_food(source, importer.SOURCES[0])[0])

    def test_energy_priority_and_kilojoule_rejection(self):
        source = food()
        source["foodNutrients"] += [
            {"nutrient": {"id": 2047, "unitName": "kcal"}, "amount": 167},
            {"nutrient": {"id": 2048, "unitName": "kcal"}, "amount": 169},
        ]
        row, _ = importer.convert_food(source, importer.SOURCES[0])
        self.assertEqual((row["energy_nutrient_id"], row["calories"]), (2048, 169))
        source["foodNutrients"].pop()
        self.assertEqual(importer.convert_food(source, importer.SOURCES[0])[0]["calories"], 167)
        source["foodNutrients"].pop()
        self.assertEqual(importer.convert_food(source, importer.SOURCES[0])[0]["calories"], 166)
        source["foodNutrients"][3]["nutrient"]["unitName"] = "kJ"
        self.assertIsNone(importer.convert_food(source, importer.SOURCES[0])[0])

    def test_rejections_have_auditable_counts(self):
        invalid = food()
        invalid["foodNutrients"] = []
        rows, _, audit = importer.import_document({"FoundationFoods": [None, invalid, food()]}, importer.SOURCES[0])
        self.assertEqual(len(rows), 1)
        self.assertEqual(audit["skippedFoodCount"], 2)
        self.assertEqual(audit["skippedFoodReasons"], {"missing_or_invalid_macro": 1, "null_food": 1})

    def test_duplicate_food_ids_stop_build(self):
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            imported(items=[food(), food()])

    def test_normalization_preserves_display_name(self):
        source = food()
        source["description"] = "  Café, Ｃｏｏｋｅｄ — rice_raw  "
        row, _ = importer.convert_food(source, importer.SOURCES[0])
        self.assertEqual(row["name"], "Café, Ｃｏｏｋｅｄ — rice_raw")
        self.assertEqual(row["search_name"], "cafe cooked rice raw")
        for invalid in ("___", "a" * 513, "food\x00name"):
            source["description"] = invalid
            self.assertIsNone(importer.convert_food(source, importer.SOURCES[0])[0])


class PortionPolicyTests(unittest.TestCase):
    def convert(self, portions):
        source = food()
        source["foodPortions"] = portions
        row, _ = importer.convert_food(source, importer.SOURCES[0])
        return importer.convert_portions(source, row)

    def test_source_amount_is_label_not_second_mass_multiplier(self):
        rows, rejected = self.convert([portion()])
        self.assertFalse(rejected)
        self.assertEqual(rows, [{"id": "123:111", "food_id": "usda-foundation:123",
                                 "label": "2 tablespoon chopped", "gram_weight": 33.9, "sort_order": 0}])

    def test_legacy_modifier_supplies_label_when_unit_is_placeholder(self):
        source = portion()
        source.update(amount=1, modifier="cup, chopped", measureUnit={"name": "undetermined"})
        rows, _ = self.convert([source])
        self.assertEqual(rows[0]["label"], "1 cup, chopped")
        self.assertEqual(rows[0]["gram_weight"], 33.9)

    def test_unknown_weights_and_amounts_are_never_invented(self):
        for key in ("amount", "gramWeight"):
            for value in (None, 0, -1, float("inf"), float("nan"), True, "10", 1_000_001, 10 ** 999):
                with self.subTest(key=key, value=value):
                    source = portion()
                    source[key] = value
                    rows, audit = self.convert([source])
                    self.assertEqual(rows, [])
                    self.assertEqual(audit["invalid_portion_amount_or_weight"], 1)

    def test_ambiguous_duplicate_portion_ids_are_all_skipped(self):
        rows, audit = self.convert([portion(), portion()])
        self.assertFalse(rows)
        self.assertEqual(audit["invalid_or_duplicate_portion_id"], 2)

    def test_missing_id_uses_original_stable_position(self):
        source = portion()
        source.pop("id")
        rows, _ = self.convert([None, source])
        self.assertEqual(rows[0]["id"], "123:position-2")
        self.assertEqual(rows[0]["sort_order"], 1)

    def test_missing_or_oversized_labels_are_skipped(self):
        source = portion()
        source.update(measureUnit={"name": "undetermined"}, modifier="")
        self.assertEqual(self.convert([source])[0], [])
        source.update(measureUnit={"name": "cup"}, modifier="x" * 300)
        rows, audit = self.convert([source])
        self.assertEqual(rows, [])
        self.assertEqual(audit["invalid_portion_label"], 1)
        source["modifier"] = "x" * 301
        self.assertEqual(self.convert([source])[0], [])


class ArchiveAndDatabaseTests(unittest.TestCase):
    def test_pin_mismatch_is_rejected_before_zip_parser(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.zip"
            path.write_bytes(b"not a ZIP")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                importer.read_archive(path, importer.SOURCES[0])
            small = replace(importer.SOURCES[0], maximum_archive_bytes=1)
            with self.assertRaisesRegex(ValueError, "size"):
                importer.read_archive(path, small)

    def test_json_bound_and_duplicate_member_are_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.zip"
            source = importer.SOURCES[0]
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(source.member, b"{}")
            source = replace(source, sha256=importer.digest(path.read_bytes()), maximum_json_bytes=1)
            with self.assertRaisesRegex(ValueError, "input limit"):
                importer.read_archive(path, source)
            source = replace(source, maximum_json_bytes=10)
            self.assertEqual(importer.read_archive(path, source)[0], {})
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                with zipfile.ZipFile(path, "a") as archive:
                    archive.writestr(source.member, b"{}")
            source = replace(source, sha256=importer.digest(path.read_bytes()))
            with self.assertRaisesRegex(ValueError, "duplicate"):
                importer.read_archive(path, source)

    def test_output_pair_restores_existing_bytes_if_second_rename_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            a, b = Path(directory) / "a.sqlite", Path(directory) / "b.json"
            a.write_bytes(b"old database")
            b.write_bytes(b"old manifest")
            real_replace = importer.os.replace
            attempts = 0

            def fail_second(source, destination):
                nonlocal attempts
                attempts += 1
                if attempts == 2:
                    raise OSError("simulated interrupted output update")
                return real_replace(source, destination)

            with mock.patch.object(importer.os, "replace", side_effect=fail_second):
                with self.assertRaisesRegex(OSError, "simulated"):
                    importer.replace_outputs([(a, b"new database"), (b, b"new manifest")])
            self.assertEqual(a.read_bytes(), b"old database")
            self.assertEqual(b.read_bytes(), b"old manifest")
            self.assertEqual(sorted(path.name for path in Path(directory).iterdir()), ["a.sqlite", "b.json"])
            importer.replace_outputs([(a, b"new database"), (b, b"new manifest")])
            self.assertEqual(a.stat().st_mode & 0o777, 0o644)
            self.assertEqual(b.stat().st_mode & 0o777, 0o644)

    def test_output_paths_must_be_distinct(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "one-file"
            with self.assertRaisesRegex(ValueError, "distinct"):
                importer.replace_outputs([(path, b"database"), (path, b"manifest")])
            self.assertFalse(path.exists())

    def test_deterministic_database_has_fts_and_valid_relationships(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = Path(directory) / "a.sqlite", Path(directory) / "b.sqlite"
            a, b = food(), food()
            b.update(fdcId=999, description="Rice, cooked")
            importer.build_database(first, [imported(items=[a, b])])
            importer.build_database(second, [imported(items=[b, a])])
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with sqlite3.connect(first) as db:
                self.assertEqual(db.execute("PRAGMA integrity_check").fetchall(), [("ok",)])
                self.assertEqual(db.execute("PRAGMA foreign_key_check").fetchall(), [])
                self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 1)
                self.assertEqual(db.execute("PRAGMA application_id").fetchone()[0], importer.APPLICATION_ID)
                self.assertEqual(db.execute("SELECT food_id FROM food_search WHERE food_search MATCH ?", ('"chick"*',)).fetchall(), [("usda-foundation:123",)])
                self.assertEqual(db.execute("SELECT gram_weight FROM catalog_servings WHERE food_id=?", ("usda-foundation:123",)).fetchone()[0], 33.9)
                db.execute("PRAGMA foreign_keys=ON")
                with self.assertRaises(sqlite3.IntegrityError):
                    db.execute("INSERT INTO catalog_servings VALUES('orphan','missing','1 cup',20,0)")

    def test_cross_source_duplicate_food_ids_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "Duplicate food"):
                importer.build_database(Path(directory) / "a.sqlite", [imported(), imported(importer.SOURCES[1])])

    def test_foundation_compatibility_checks_identity_and_macros(self):
        fixture = json.loads(importer.foundation.DEFAULT_OUTPUT.read_bytes())
        rows = []
        for entry in fixture["foods"]:
            rows.append({"id": entry["id"], "fdc_id": entry["fdcID"], "name": entry["name"],
                         "publication_date": entry["publicationDate"], "energy_nutrient_id": entry["energyNutrientID"],
                         "calories": entry["nutritionPer100g"]["calories"],
                         "protein_g": entry["nutritionPer100g"]["proteinGrams"],
                         "carbohydrate_g": entry["nutritionPer100g"]["carbGrams"],
                         "fat_g": entry["nutritionPer100g"]["fatGrams"]})
        importer.verify_foundation_compatibility(rows)
        rows[0]["calories"] += 0.1
        with self.assertRaisesRegex(ValueError, "changed"):
            importer.verify_foundation_compatibility(rows)

    def test_shipped_database_and_manifest_match_every_legacy_foundation_row(self):
        manifest = json.loads(importer.DEFAULT_MANIFEST.read_bytes())
        self.assertEqual(manifest["databaseSHA256"], importer.digest(importer.DEFAULT_DATABASE.read_bytes()))
        self.assertEqual(manifest["databaseBytes"], importer.DEFAULT_DATABASE.stat().st_size)
        self.assertLess(manifest["databaseBytes"], importer.MAX_DATABASE_BYTES)
        with sqlite3.connect(importer.DEFAULT_DATABASE) as db:
            db.row_factory = sqlite3.Row
            self.assertEqual(db.execute("SELECT COUNT(*) FROM catalog_foods").fetchone()[0], manifest["foodCount"])
            self.assertEqual(db.execute("SELECT COUNT(*) FROM catalog_servings").fetchone()[0], manifest["servingCount"])
            rows = [dict(row) for row in db.execute("SELECT * FROM catalog_foods WHERE source_id=?", (importer.SOURCES[0].id,))]
            self.assertEqual(len(rows), 311)
            importer.verify_foundation_compatibility(rows)
            self.assertEqual(db.execute("PRAGMA foreign_key_check").fetchall(), [])
        self.assertEqual(len(manifest["sources"]), 2)
        self.assertEqual(manifest["sources"][1]["release"], "2018-04")
        self.assertEqual(manifest["sources"][1]["license"], "CC0-1.0")
        self.assertGreater(manifest["foodCount"], 7500)
        self.assertGreater(manifest["servingCount"], 10000)


if __name__ == "__main__":
    unittest.main()
