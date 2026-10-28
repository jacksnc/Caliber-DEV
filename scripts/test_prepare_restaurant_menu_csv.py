import copy
import csv
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import import_restaurant_menus as menus
import prepare_restaurant_menu_csv as prepare

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "docs/templates/restaurant-menu"


class RestaurantMenuCSVTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.csv = self.directory / "menu.csv"
        self.metadata = self.directory / "metadata.json"
        self.csv.write_bytes((TEMPLATE / "menu-example.csv").read_bytes())
        self.metadata.write_bytes((TEMPLATE / "metadata-example.json").read_bytes())

    def rows(self):
        return list(csv.DictReader(io.StringIO(self.csv.read_text())))

    def write_rows(self, rows, fields=prepare.COLUMNS):
        with self.csv.open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)

    def result(self):
        return prepare.prepare(self.csv, self.metadata, allow_fixture=True)

    def test_examples_round_trip_through_existing_importer_and_all_categories(self):
        document = self.result()
        self.assertTrue(document["fictional"])
        self.assertNotIn("inputSHA256", document)
        items = document["restaurants"][0]["items"]
        self.assertEqual({item["category"] for item in items}, set(menus.CATEGORIES))
        prepared = self.directory / "prepared.json"
        prepared.write_bytes(menus.render(document))
        final = menus.load_input(prepared, allow_fixture=True)
        self.assertEqual(final["restaurants"], document["restaurants"])
        self.assertEqual(final["sources"][0]["license"]["status"], "fixture")

    def test_empty_template_is_a_header_only_starting_point(self):
        self.csv.write_bytes((TEMPLATE / "menu-template.csv").read_bytes())
        self.assertEqual(self.result()["restaurants"][0]["items"], [])

    def test_fixture_requires_explicit_opt_in_and_cannot_become_production(self):
        with self.assertRaisesRegex(menus.MenuValidationError, "--fixture"):
            prepare.prepare(self.csv, self.metadata)
        doc = json.loads(self.metadata.read_text())
        doc["fictional"] = False
        self.metadata.write_text(json.dumps(doc))
        with self.assertRaises(menus.MenuValidationError):
            prepare.prepare(self.csv, self.metadata)

    def test_missing_nutrients_fail_while_unknown_mass_and_explicit_zero_stay_distinct(self):
        rows = self.rows()
        rows[0]["serving_grams"] = ""
        rows[0]["calories"] = "0"
        self.write_rows(rows)
        item = next(item for item in self.result()["restaurants"][0]["items"] if item["id"] == rows[0]["item_id"])
        self.assertIsNone(item["servingGrams"])
        self.assertEqual(item["calories"], 0)
        for field in prepare.NUTRIENTS:
            changed = copy.deepcopy(rows)
            changed[0][field] = ""
            self.write_rows(changed)
            with self.subTest(field=field), self.assertRaisesRegex(menus.MenuValidationError, "missing nutrition"):
                self.result()

    def test_invalid_numeric_strings_and_zero_mass_fail_without_guessing(self):
        original = self.rows()
        for value in ["-1", "NaN", "Infinity", "1,000", "1e2", "20g", "1.2.3", "1" * 129, "1000001"]:
            rows = copy.deepcopy(original)
            rows[0]["calories"] = value
            self.write_rows(rows)
            with self.subTest(value=value), self.assertRaises(menus.MenuValidationError):
                self.result()
        rows = copy.deepcopy(original)
        rows[0]["serving_grams"] = "0"
        self.write_rows(rows)
        with self.assertRaises(menus.MenuValidationError):
            self.result()

    def test_human_category_labels_accept_accents_and_case_but_not_unknown_categories(self):
        for value, expected in [("Entrées", "entree"), ("  SIDES ", "side"), ("Drinks", "drink"), ("Desserts", "dessert")]:
            self.assertEqual(prepare.category(value, "category"), expected)
        for value in ["", "combos", "protein", "sides/drinks"]:
            with self.assertRaises(menus.MenuValidationError):
                prepare.category(value, "category")

    def test_quoted_commas_utf8_bom_and_decimal_nutrition_are_preserved(self):
        rows = self.rows()
        rows[0]["name"] = 'Fictional rice, "large"'
        rows[0]["serving_description"] = "1 fictional portion, sauce included"
        rows[0]["calories"] = "123.456789"
        self.write_rows(rows)
        self.csv.write_bytes(b"\xef\xbb\xbf" + self.csv.read_bytes())
        item = next(item for item in self.result()["restaurants"][0]["items"] if item["id"] == rows[0]["item_id"])
        self.assertEqual(item["name"], rows[0]["name"])
        self.assertEqual(item["calories"], 123.456789)

    def test_bad_headers_row_width_and_quotes_fail(self):
        rows = self.rows()
        for header in ["name,name", ",".join(prepare.COLUMNS[:-1]), ",".join(prepare.COLUMNS) + ",surprise"]:
            self.csv.write_text(header + "\n")
            with self.assertRaisesRegex(menus.MenuValidationError, "header"):
                self.result()
        for row in ["only,two", ",".join(["x"] * 11), '"never closed']:
            self.csv.write_text(",".join(prepare.COLUMNS) + "\n" + row + "\n")
            with self.assertRaises(menus.MenuValidationError):
                self.result()

    def test_unknown_restaurants_duplicate_items_and_inline_metadata_items_fail(self):
        original = self.rows()
        rows = copy.deepcopy(original)
        rows[0]["restaurant_id"] = "not-declared"
        self.write_rows(rows)
        with self.assertRaisesRegex(menus.MenuValidationError, "metadata"):
            self.result()
        self.write_rows(original + [original[0]])
        with self.assertRaisesRegex(menus.MenuValidationError, "duplicate identifier"):
            self.result()
        self.write_rows(original)
        metadata = json.loads(self.metadata.read_text())
        fixture = json.loads((ROOT / "docs/examples/restaurant-menu-input.json").read_text())
        metadata["restaurants"][0]["items"] = fixture["restaurants"][0]["items"]
        self.metadata.write_text(json.dumps(metadata))
        with self.assertRaisesRegex(menus.MenuValidationError, "items must be empty"):
            self.result()

    def test_multiple_restaurants_stable_order_and_row_reordering(self):
        original = self.rows()
        metadata = json.loads(self.metadata.read_text())
        other = copy.deepcopy(metadata["restaurants"][0])
        other["id"] = "fictional-second-restaurant"
        other["name"] = "Fictional Second Restaurant"
        metadata["restaurants"].append(other)
        self.metadata.write_text(json.dumps(metadata))
        extra = copy.deepcopy(original[0])
        extra["restaurant_id"] = other["id"]
        extra["item_id"] = "fictional-second-item"
        self.write_rows(original + [extra])
        expected = menus.render(self.result())
        self.write_rows(list(reversed(original + [extra])))
        self.assertEqual(menus.render(self.result()), expected)

    def test_cli_check_is_deterministic_and_rejected_input_keeps_previous_output(self):
        output = self.directory / "prepared.json"
        command = [sys.executable, str(ROOT / "scripts/prepare_restaurant_menu_csv.py"),
                   "--csv", str(self.csv), "--metadata", str(self.metadata), "--fixture", "--output", str(output)]
        first = subprocess.run(command, capture_output=True)
        self.assertEqual(first.returncode, 0, first.stderr)
        expected = output.read_bytes()
        self.assertEqual(subprocess.run(command + ["--check"], capture_output=True).returncode, 0)
        output.write_bytes(expected + b" ")
        self.assertNotEqual(subprocess.run(command + ["--check"], capture_output=True).returncode, 0)
        output.write_bytes(expected)
        rows = self.rows()
        rows[0]["calories"] = ""
        self.write_rows(rows)
        self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
        self.assertEqual(output.read_bytes(), expected)
        for forbidden in [self.csv, self.metadata, ROOT / "Caliber (DEV)/Resources/RestaurantMenuCatalog.json"]:
            result = subprocess.run(command[:-1] + [str(forbidden)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_encoding_and_size_bounds_are_enforced(self):
        self.csv.write_bytes(b"\xff\xfe")
        with self.assertRaisesRegex(menus.MenuValidationError, "UTF-8"):
            self.result()
        self.csv.write_bytes(b"x" * (menus.MAX_BYTES + 1))
        with self.assertRaisesRegex(menus.MenuValidationError, "5 MB"):
            self.result()


if __name__ == "__main__":
    unittest.main()
