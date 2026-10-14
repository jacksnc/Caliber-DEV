#!/usr/bin/env python3
"""Offline tests for USDA import policy; no HTTP, credentials or huge fixtures."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import import_usda_foods as importer


def food():
    return {
        "fdcId": 123, "description": "Chicken, cooked", "dataType": "Foundation",
        "publicationDate": "4/30/2026",
        "foodNutrients": [
            {"nutrient": {"id": nutrient, "unitName": unit}, "amount": amount}
            for nutrient, unit, amount in [(1003, "g", 32.1), (1004, "g", 3.24),
                                           (1005, "g", 0), (1008, "kcal", 166)]
        ],
    }


class ImportPolicyTests(unittest.TestCase):
    def test_realistic_macro_values_and_explicit_zero_survive(self):
        result = importer.convert_food(food())
        self.assertEqual(result["nutritionPer100g"], {
            "calories": 166, "proteinGrams": 32.1, "carbGrams": 0, "fatGrams": 3.24})
        self.assertEqual(result["energyNutrientID"], 1008)
        self.assertEqual(result["id"], "usda-foundation:123")

    def test_prefer_specific_then_general_then_legacy_energy(self):
        source = food()
        source["foodNutrients"] += [
            {"nutrient": {"id": 2047, "unitName": "kcal"}, "amount": 168},
            {"nutrient": {"id": 2048, "unitName": "kcal"}, "amount": 170},
        ]
        self.assertEqual(importer.convert_food(source)["nutritionPer100g"]["calories"], 170)
        source["foodNutrients"].pop()
        self.assertEqual(importer.convert_food(source)["nutritionPer100g"]["calories"], 168)

    def test_missing_negative_nonfinite_and_invalid_units_are_not_zero(self):
        for change in ["missing", "negative", "nan", "infinity", "bool", "string", "unit", "duplicate"]:
            with self.subTest(change=change):
                source = food()
                if change == "missing":
                    source["foodNutrients"].pop(2)
                elif change == "unit":
                    source["foodNutrients"][2]["nutrient"]["unitName"] = "mg"
                elif change == "duplicate":
                    source["foodNutrients"].append(copy.deepcopy(source["foodNutrients"][2]))
                else:
                    source["foodNutrients"][2]["amount"] = {
                        "negative": -0.1, "nan": float("nan"), "infinity": float("inf"),
                        "bool": False, "string": "0"}[change]
                self.assertIsNone(importer.convert_food(source))

    def test_malformed_nutrient_rows_are_not_usable_data(self):
        source = food()
        source["foodNutrients"] = None
        self.assertIsNone(importer.convert_food(source))
        source = food()
        source["foodNutrients"][2]["nutrient"]["unitName"] = 123
        self.assertIsNone(importer.convert_food(source))

    def test_kilojoules_alone_do_not_become_calories(self):
        source = food()
        source["foodNutrients"][3]["nutrient"] = {"id": 1062, "unitName": "kJ"}
        self.assertIsNone(importer.convert_food(source))
        source["foodNutrients"][3]["nutrient"] = {"id": 1008, "unitName": "kJ"}
        self.assertIsNone(importer.convert_food(source))

    def test_null_rows_are_skipped_and_duplicate_food_ids_fail(self):
        document = importer.build_catalog({"FoundationFoods": [None, food()]})
        self.assertEqual(len(document["foods"]), 1)
        self.assertEqual(document["source"]["skippedNullCount"], 1)
        with self.assertRaises(ValueError):
            importer.build_catalog({"FoundationFoods": [food(), food()]})

    def test_output_is_deterministic_and_bundled_manifest_is_correct(self):
        source = food()
        other = copy.deepcopy(source)
        other.update(fdcId=999, description="Avocado, raw")
        a = importer.render(importer.build_catalog({"FoundationFoods": [source, other]}))
        b = importer.render(importer.build_catalog({"FoundationFoods": [other, source]}))
        self.assertEqual(a, b)
        bundle = json.loads(importer.DEFAULT_OUTPUT.read_bytes())
        self.assertEqual(len(bundle["foods"]), 311)
        self.assertEqual(bundle["source"]["basisGrams"], 100)
        self.assertEqual(bundle["source"]["sourceFoodCount"], 395)
        self.assertEqual(bundle["source"]["skippedNullCount"], 32)
        self.assertEqual(bundle["source"]["skippedIncompleteCount"], 52)
        self.assertEqual(bundle["source"]["license"], "CC0-1.0")
        self.assertTrue(all(entry["nutritionPer100g"]["carbGrams"] >= 0 for entry in bundle["foods"]))

    def test_nonmatching_archive_is_rejected_before_parsing(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "not-the-pinned-release.zip"
            path.write_bytes(b"not a USDA archive")
            with self.assertRaises(ValueError):
                importer.read_archive(path)


if __name__ == "__main__":
    unittest.main()
