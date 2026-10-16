#!/usr/bin/env python3
"""Offline restaurant importer checks; fixtures never grant real menu rights."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import import_restaurant_menus as importer

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "docs/examples/restaurant-menu-input.json"


def fixture():
    return json.loads(FIXTURE.read_bytes())


def normalize(document=None):
    return importer.normalize(document if document is not None else fixture(), "0" * 64, allow_fixture=True)


class SourceAndRightsTests(unittest.TestCase):
    def test_fictional_input_requires_explicit_fixture_and_stays_flagged(self):
        with self.assertRaisesRegex(importer.MenuValidationError, "--fixture"):
            importer.load_input(FIXTURE)
        result = importer.load_input(FIXTURE, allow_fixture=True)
        self.assertTrue(result["fictional"])
        self.assertEqual(result["sources"][0]["license"]["status"], "fixture")
        self.assertIn("not an approval", result["sources"][0]["license"]["permissionReference"])

    def test_empty_production_registry_is_valid_with_actual_input_hash(self):
        data = b'{"schemaVersion":1,"fictional":false,"sources":[],"restaurants":[]}\n'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "empty-input.json"
            path.write_bytes(data)
            result = importer.load_input(path)
        self.assertEqual(result, {"schemaVersion": 1, "fictional": False,
                                  "inputSHA256": hashlib.sha256(data).hexdigest(), "sources": [], "restaurants": []})

    def test_approved_registry_source_can_precede_restaurant_records(self):
        # This is the already public CC0 USDA reference, not invented restaurant
        # permission. No restaurant data or nutritional facts are attributed to it.
        document = {"schemaVersion": 1, "sources": [{
            "id": "usda-public-reference", "name": "USDA FoodData Central", "url": "https://fdc.nal.usda.gov/",
            "retrievedOn": "2026-10-15", "license": {"status": "approved",
                "permissionReference": "USDA FoodData Central public CC0-1.0 statement at https://fdc.nal.usda.gov/",
                "attribution": "USDA FoodData Central"}}], "restaurants": []}
        result = importer.normalize(document, "0" * 64)
        self.assertFalse(result["fictional"])
        self.assertEqual(result["sources"][0]["license"]["status"], "approved")

    def test_unapproved_or_fixture_license_cannot_be_production(self):
        for status in ("pending", "denied", "fixture", "", True, None):
            document = fixture()
            document["fictional"] = False
            document["sources"][0]["license"]["status"] = status
            with self.assertRaisesRegex(importer.MenuValidationError, "license.status"):
                importer.normalize(document, "0" * 64)

    def test_fixture_cannot_misrepresent_an_approval_or_omit_declarations(self):
        document = fixture()
        document["sources"][0]["license"]["status"] = "approved"
        with self.assertRaisesRegex(importer.MenuValidationError, "license.status"):
            normalize(document)
        for key in ("permissionReference", "attribution"):
            document = fixture()
            document["sources"][0]["license"][key] = "   "
            with self.assertRaises(importer.MenuValidationError):
                normalize(document)

    def test_https_sources_reject_credentials_controls_bad_hosts_and_example_production(self):
        for url in ("http://restaurant.example/menu", "https://name:password@restaurant.example/menu",
                    "https://bad..host/menu", "https://restaurant.example\\menu", "https://restaurant.example/menu\n",
                    "https:///menu", "https://restaurant.example:99999/menu", "https://restaurant.example/has space"):
            with self.subTest(url=url), self.assertRaises(importer.MenuValidationError):
                importer.source_url(url, True, "source.url")
        self.assertEqual(importer.source_url("https://example.invalid/menu", True, "source.url"), "https://example.invalid/menu")
        with self.assertRaisesRegex(importer.MenuValidationError, "fictional"):
            importer.source_url("https://example.invalid/menu", False, "source.url")

    def test_dates_are_real_canonical_calendar_dates(self):
        self.assertEqual(importer.calendar_date("2024-02-29", "retrievedOn"), "2024-02-29")
        for value in ("2025-02-29", "2026-2-01", "02/01/2026", "2026-13-01", None, True):
            with self.assertRaises(importer.MenuValidationError):
                importer.calendar_date(value, "retrievedOn")


class NutritionAndSchemaTests(unittest.TestCase):
    def test_source_portion_values_are_not_rounded_or_recalculated(self):
        document = fixture()
        item = document["restaurants"][0]["items"][0]
        item.update(calories=541.12345, proteinGrams=38.0001, carbGrams=49.25, fatGrams=21.125)
        result = normalize(document)
        stored = next(row for row in result["restaurants"][0]["items"] if row["id"] == item["id"])
        self.assertEqual((stored["calories"], stored["proteinGrams"], stored["carbGrams"], stored["fatGrams"]),
                         (541.12345, 38.0001, 49.25, 21.125))
        self.assertEqual(stored["servingGrams"], 420)

    def test_unknown_mass_stays_null_and_explicit_zero_nutrients_survive(self):
        result = normalize()
        water = next(item for item in result["restaurants"][0]["items"] if item["category"] == "drink")
        self.assertIsNone(water["servingGrams"])
        self.assertEqual((water["calories"], water["proteinGrams"], water["carbGrams"], water["fatGrams"]), (0, 0, 0, 0))
        document = fixture()
        del document["restaurants"][0]["items"][0]["servingGrams"]
        result = normalize(document)
        self.assertIsNone(next(item for item in result["restaurants"][0]["items"] if item["category"] == "entree")["servingGrams"])

    def test_missing_nutrients_are_never_zero_filled(self):
        for field in ("calories", "proteinGrams", "carbGrams", "fatGrams"):
            document = fixture()
            del document["restaurants"][0]["items"][0][field]
            with self.assertRaisesRegex(importer.MenuValidationError, "missing fields"):
                normalize(document)

    def test_invalid_nutrient_values_and_nonpositive_known_masses_fail(self):
        for field in ("calories", "proteinGrams", "carbGrams", "fatGrams"):
            for value in (-1, float("nan"), float("inf"), True, "0", None, 10 ** 999):
                document = fixture()
                document["restaurants"][0]["items"][0][field] = value
                with self.assertRaises(importer.MenuValidationError):
                    normalize(document)
        for grams in (0, -1, float("inf"), True, "420", importer.MAX_GRAMS + 1):
            document = fixture()
            document["restaurants"][0]["items"][0]["servingGrams"] = grams
            with self.assertRaises(importer.MenuValidationError):
                normalize(document)

    def test_categories_match_exact_app_enum(self):
        for category in importer.CATEGORIES:
            document = fixture()
            document["restaurants"][0]["items"][0]["category"] = category
            normalize(document)
        for category in ("other", "entrees", "Entrée", "", None):
            document = fixture()
            document["restaurants"][0]["items"][0]["category"] = category
            with self.assertRaisesRegex(importer.MenuValidationError, "category"):
                normalize(document)

    def test_unknown_fields_are_rejected_at_all_levels(self):
        for level in ("input", "source", "license", "restaurant", "item"):
            document = fixture()
            target = {"input": document, "source": document["sources"][0], "license": document["sources"][0]["license"],
                      "restaurant": document["restaurants"][0], "item": document["restaurants"][0]["items"][0]}[level]
            target["unexpected"] = "not accepted"
            with self.assertRaisesRegex(importer.MenuValidationError, "unknown fields"):
                normalize(document)
        document = fixture()
        document["inputSHA256"] = "0" * 64
        with self.assertRaisesRegex(importer.MenuValidationError, "unknown fields"):
            normalize(document)

    def test_item_ids_are_unique_across_restaurants_and_source_references_resolve(self):
        document = fixture()
        second = copy.deepcopy(document["restaurants"][0])
        second["id"] = "fictional-second-bistro"
        document["restaurants"].append(second)
        with self.assertRaisesRegex(importer.MenuValidationError, "duplicate identifier"):
            normalize(document)
        document = fixture()
        document["restaurants"][0]["sourceID"] = "missing-source"
        with self.assertRaisesRegex(importer.MenuValidationError, "missing source"):
            normalize(document)

    def test_duplicate_sources_restaurants_and_invalid_ids_fail(self):
        for collection in ("sources", "restaurants"):
            document = fixture()
            document[collection].append(copy.deepcopy(document[collection][0]))
            with self.assertRaisesRegex(importer.MenuValidationError, "duplicate identifier"):
                normalize(document)
        for bad_id in ("UPPERCASE", "contains space", "", "a" * 97, "../../path", None):
            document = fixture()
            document["restaurants"][0]["id"] = bad_id
            with self.assertRaises(importer.MenuValidationError):
                normalize(document)

    def test_input_and_text_count_bounds_are_enforced(self):
        document = fixture()
        document["sources"] *= importer.MAX_SOURCES + 1
        with self.assertRaisesRegex(importer.MenuValidationError, "at most"):
            normalize(document)
        document = fixture()
        document["restaurants"][0]["items"] *= importer.MAX_ITEMS_PER_RESTAURANT + 1
        with self.assertRaisesRegex(importer.MenuValidationError, "at most"):
            normalize(document)
        for name in ("", "a" * 201, "bad\x00name"):
            document = fixture()
            document["restaurants"][0]["name"] = name
            with self.assertRaises(importer.MenuValidationError):
                normalize(document)


class FileAndCommandTests(unittest.TestCase):
    def test_duplicate_json_keys_and_nonfinite_constants_fail_before_normalization(self):
        for data in (b'{"schemaVersion":1,"schemaVersion":1,"sources":[],"restaurants":[]}',
                     b'{"schemaVersion":NaN,"sources":[],"restaurants":[]}', b'\xff'):
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "bad.json"
                path.write_bytes(data)
                with self.assertRaises(importer.MenuValidationError):
                    importer.load_input(path)

    def test_input_bytes_are_bounded_before_parsing(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "huge.json"
            path.write_bytes(b" " * (importer.MAX_BYTES + 1))
            with self.assertRaisesRegex(importer.MenuValidationError, "5 MB"):
                importer.load_input(path)

    def test_oversized_numeric_tokens_fail_without_large_integer_conversion(self):
        for token in ("9" * 10_000, "0." + "1" * 10_000):
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "huge-number.json"
                path.write_text('{"schemaVersion":' + token + ',"sources":[],"restaurants":[]}')
                with self.assertRaisesRegex(importer.MenuValidationError, "precision"):
                    importer.load_input(path)

    def test_normalized_order_is_deterministic_and_complete(self):
        document = fixture()
        before = importer.render(normalize(document))
        document["sources"].reverse()
        document["restaurants"].reverse()
        for restaurant in document["restaurants"]:
            restaurant["items"].reverse()
        self.assertEqual(before, importer.render(normalize(document)))
        decoded = json.loads(before)
        self.assertEqual(set(decoded), {"schemaVersion", "fictional", "inputSHA256", "sources", "restaurants"})
        self.assertTrue(before.endswith(b"\n"))

    def test_atomic_failure_preserves_existing_output_and_removes_temporary_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "output.json"
            path.write_bytes(b"previous")
            with mock.patch.object(importer.os, "replace", side_effect=OSError("simulated rename failure")):
                with self.assertRaises(OSError):
                    importer.atomic_write(path, b"replacement")
            self.assertEqual(path.read_bytes(), b"previous")
            self.assertEqual([item.name for item in Path(directory).iterdir()], ["output.json"])
            importer.atomic_write(path, b"replacement")
            self.assertEqual(path.stat().st_mode & 0o777, 0o644)

    def run_cli(self, *arguments):
        return subprocess.run([sys.executable, str(Path(importer.__file__)), *map(str, arguments)],
                              capture_output=True, timeout=20)

    def test_cli_fixture_requires_opt_in_then_preview_output_and_check_reproduce(self):
        rejected = self.run_cli("--input", FIXTURE)
        self.assertEqual(rejected.returncode, 1)
        self.assertIn(b"requires --fixture", rejected.stderr)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "fixture-output.json"
            created = self.run_cli("--input", FIXTURE, "--fixture", "--output", output)
            self.assertEqual(created.returncode, 0, created.stderr)
            preview = self.run_cli("--input", FIXTURE, "--fixture", "--preview")
            self.assertEqual(preview.returncode, 0, preview.stderr)
            self.assertEqual(preview.stdout, output.read_bytes())
            checked = self.run_cli("--input", FIXTURE, "--fixture", "--output", output, "--check")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            original = output.read_bytes()
            output.write_bytes(original + b" ")
            rejected = self.run_cli("--input", FIXTURE, "--fixture", "--output", output, "--check")
            self.assertEqual(rejected.returncode, 1)
            self.assertEqual(output.read_bytes(), original + b" ")

    def test_cli_rejects_output_clobbering_input_and_keeps_invalid_output_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.json"
            path.write_bytes(FIXTURE.read_bytes())
            before = path.read_bytes()
            rejected = self.run_cli("--input", path, "--fixture", "--output", path)
            self.assertEqual(rejected.returncode, 2)
            self.assertEqual(path.read_bytes(), before)
            output = Path(directory) / "output.json"
            output.write_bytes(b"keep")
            rejected = self.run_cli("--input", path, "--output", output)
            self.assertEqual(rejected.returncode, 1)
            self.assertEqual(output.read_bytes(), b"keep")


if __name__ == "__main__":
    unittest.main()
