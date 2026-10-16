#!/usr/bin/env python3
"""Small offline CSV fixtures for packaged barcode import policy and resources."""
import copy
import hashlib
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest import mock
import zipfile

import build_packaged_database as importer


def food(identifier=1, publication="2026-04-01", name="Fictional cereal, dry"):
    return {"fdc_id": str(identifier), "data_type": "branded_food", "description": name,
            "publication_date": publication, "market_country": "United States"}


def branded(identifier=1, code="036000291452", modified="2026-03-01"):
    return {"fdc_id": str(identifier), "gtin_upc": code, "brand_name": "Fictional Brand",
            "brand_owner": "Fictional Owner", "modified_date": modified,
            "market_country": "United States", "discontinued_date": "", "serving_size": "30",
            "serving_size_unit": "g", "household_serving_fulltext": "1 cup (30 g)",
            "preparation_state_code": "UNPREPARED"}


def nutrients(identifier=1):
    return [{"fdc_id": str(identifier), "nutrient_id": str(nutrient), "amount": str(value)}
            for nutrient, value in ((1008, 400), (1003, 10), (1005, 70), (1004, 0))]


def metadata(foods=None, brands=None):
    with sqlite3.connect(":memory:") as db:
        audit = {}
        importer.stage_foods(db, foods or [food()], audit)
        importer.stage_brands(db, brands or [branded()], audit)
        candidates = importer.latest_candidates(db, audit)
    return candidates, audit


def product(identifier=1, code="036000291452", unit="g"):
    brand = branded(identifier, code)
    brand["serving_size_unit"] = unit
    candidates, audit = metadata([food(identifier)], [brand])
    nutrition = importer.gather_nutrition(nutrients(identifier), candidates)
    return importer.complete_products(candidates, nutrition, audit)[0]


class BarcodeTests(unittest.TestCase):
    def test_checksum_and_equivalent_leading_zero_forms(self):
        for code in ("036000291452", "0036000291452", "00036000291452"):
            self.assertEqual(importer.canonical_gtin(code), "00036000291452")
        self.assertIsNotNone(importer.canonical_gtin("96385074"))

    def test_bad_lengths_characters_and_unassigned_all_zero_are_rejected(self):
        for code in ("036000291453", "03600029145", "１２３４５６７８", "abc", "00000000", "", None, 36000291452):
            with self.subTest(code=code):
                self.assertIsNone(importer.canonical_gtin(code))


class VersionPolicyTests(unittest.TestCase):
    def test_latest_publication_precedes_manufacturer_modified_date(self):
        candidates, _ = metadata([food(1, "2026-03-01"), food(2, "2026-04-01")],
                                 [branded(1, modified="2026-04-01"), branded(2, modified="2026-02-01")])
        self.assertEqual(list(candidates), [2])

    def test_modified_date_resolves_equal_publication(self):
        candidates, _ = metadata([food(1), food(2)],
                                 [branded(1, modified="2026-02-01"), branded(2, modified="2026-03-01")])
        self.assertEqual(list(candidates), [2])

    def test_tied_latest_records_are_ambiguous_not_arbitrarily_chosen(self):
        candidates, audit = metadata([food(1), food(2, name="Fictional cereal, prepared")], [branded(1), branded(2)])
        self.assertFalse(candidates)
        self.assertEqual(audit["latestRecordRejections"]["ambiguous_latest_date_tie"], 1)

    def test_latest_missing_macros_never_falls_back_to_older_complete_record(self):
        candidates, audit = metadata([food(1, "2026-03-01"), food(2)], [branded(1), branded(2)])
        values = importer.gather_nutrition(nutrients(1), candidates)
        self.assertFalse(importer.complete_products(candidates, values, audit))
        self.assertEqual(audit["completenessRejections"], {"missing_or_invalid_macros": 1})

    def test_latest_invalid_name_discontinued_and_non_us_never_restore_old_version(self):
        for reason in ("name", "discontinued", "market", "basis"):
            new_food, new_brand = food(2), branded(2)
            if reason == "name":
                new_food["description"] = ""
            elif reason == "discontinued":
                new_brand["discontinued_date"] = "2026-03-15"
            elif reason == "market":
                new_brand["market_country"] = "New Zealand"
            else:
                new_brand["serving_size_unit"] = "IU"
            candidates, _ = metadata([food(1, "2026-03-01"), new_food], [branded(1), new_brand])
            self.assertFalse(candidates, reason)

    def test_unknown_dates_cannot_hide_newer_incomplete_versions(self):
        bad = branded(2)
        bad["modified_date"] = "not-a-date"
        candidates, audit = metadata([food(1), food(2)], [branded(1), bad])
        self.assertFalse(candidates)
        self.assertEqual(audit["latestRecordRejections"]["unorderable_version_date"], 1)
        bad["modified_date"] = ""
        self.assertFalse(metadata([food(1), food(2)], [branded(1), bad])[0])

    def test_single_version_can_truthfully_keep_unsupplied_modified_and_brand(self):
        source = branded()
        source.update(modified_date="", brand_name="", brand_owner="")
        candidates, _ = metadata(brands=[source])
        self.assertEqual(candidates[1]["modified_date"], "")
        self.assertEqual(candidates[1]["brand"], "")

    def test_duplicate_source_fdc_and_orphan_references_fail(self):
        with self.assertRaises(sqlite3.IntegrityError):
            metadata([food(1), food(1)], [branded(1)])
        with self.assertRaisesRegex(ValueError, "no source"):
            metadata([food(1)], [branded(2)])


class NutritionAndPortionTests(unittest.TestCase):
    def test_explicit_zero_and_source_macros_remain_per100g(self):
        result = product()
        self.assertEqual((result["calories"], result["protein_g"], result["carbohydrate_g"], result["fat_g"]), (400, 10, 70, 0))
        self.assertEqual((result["basis_unit"], result["serving_quantity"], result["serving_unit"]), ("g", 30, "g"))
        self.assertEqual(result["serving_label"], "1 cup (30 g)")
        self.assertEqual(result["name"], "Fictional cereal, dry")

    def test_volume_basis_does_not_turn_milliliters_into_grams(self):
        source = branded()
        source.update(serving_size_unit="mL", serving_size="240", household_serving_fulltext="1 cup (240 mL)")
        candidates, audit = metadata(brands=[source])
        result = importer.complete_products(candidates, importer.gather_nutrition(nutrients(), candidates), audit)[0]
        self.assertEqual(result["basis_unit"], "mL")
        self.assertEqual((result["serving_quantity"], result["serving_unit"]), (240, "mL"))
        self.assertNotIn("serving_grams", result)
        self.assertEqual(result["calories"], 400)

    def test_no_guess_for_unknown_units_nonpositive_and_nonfinite_servings(self):
        for key, value in (("serving_size_unit", "oz"), ("serving_size_unit", "IU"), ("serving_size_unit", "GRM"),
                           ("serving_size", "0"), ("serving_size", "NaN"), ("serving_size", "Infinity"), ("serving_size", "10001")):
            source = branded()
            source[key] = value
            self.assertFalse(metadata(brands=[source])[0], (key, value))

    def test_only_allowed_source_preparation_states_are_kept(self):
        for state in importer.ALLOWED_PREPARATIONS:
            source = branded()
            source["preparation_state_code"] = state
            self.assertTrue(metadata(brands=[source])[0])
        for state in ("PREPARED", "BAKE", "RECONSTITUTE", "UNKNOWN"):
            source = branded()
            source["preparation_state_code"] = state
            self.assertFalse(metadata(brands=[source])[0])

    def test_missing_invalid_and_duplicated_nutrients_are_not_zero_filled(self):
        candidates, _ = metadata()
        for value in ("", "-1", "NaN", "Infinity", "101", "true", "not supplied"):
            rows = nutrients()
            rows[1]["amount"] = value
            self.assertFalse(importer.complete_products(candidates, importer.gather_nutrition(rows, candidates), {}), value)
        rows = nutrients()[1:]
        self.assertFalse(importer.complete_products(candidates, importer.gather_nutrition(rows, candidates), {}))
        rows = nutrients() + [copy.deepcopy(nutrients()[1])]
        self.assertFalse(importer.complete_products(candidates, importer.gather_nutrition(rows, candidates), {}))

    def test_specific_then_general_then_historical_kcal_priority(self):
        candidates, _ = metadata()
        rows = nutrients() + [{"fdc_id": "1", "nutrient_id": "2047", "amount": "401"},
                              {"fdc_id": "1", "nutrient_id": "2048", "amount": "402"}]
        for expected in (402, 401, 400):
            result = importer.complete_products(candidates, importer.gather_nutrition(rows, candidates), {})[0]
            self.assertEqual(result["calories"], expected)
            rows.pop()

    def test_nutrient_units_must_be_explicit_correct_and_unique(self):
        source = [{"id": str(identifier), "unit_name": "KCAL" if position < 3 else "G"}
                  for position, identifier in enumerate(importer.NUTRIENT_IDS)]
        self.assertEqual(importer.nutrient_units(source)[1003], "g")
        for altered in (source[:-1], source + [source[0]], [{**row, "unit_name": "kJ"} for row in source]):
            with self.assertRaises(ValueError):
                importer.nutrient_units(altered)

    def test_mass_and_volume_nutrient_bounds_follow_their_own_basis(self):
        for unit, amount, expected in (("g", "150", False), ("mL", "150", True), ("mL", "201", False)):
            source = branded()
            source["serving_size_unit"] = unit
            candidates, _ = metadata(brands=[source])
            values = nutrients()
            values[1]["amount"] = amount
            self.assertEqual(bool(importer.complete_products(candidates, importer.gather_nutrition(values, candidates), {})), expected)


class DeterminismAndArchiveTests(unittest.TestCase):
    def test_selection_priority_then_freshness_is_explicit_deterministic_subset(self):
        foods = [food(1, "2026-03-01"), food(2), food(3)]
        a, b, c = branded(1), branded(2, "012345678905"), branded(3, "042100005264")
        a["brand_owner"] = "General Mills Sales Inc."
        selected = []
        for source_foods, source_brands in ((foods, [a, b, c]), (list(reversed(foods)), [c, b, a])):
            candidates, audit = metadata(source_foods, source_brands)
            values = importer.gather_nutrition(nutrients(1) + nutrients(2) + nutrients(3), candidates)
            result = importer.complete_products(candidates, values, audit, limit=2)
            self.assertEqual(result[0]["fdc_id"], 1)
            self.assertEqual(audit["omittedBySubsetLimit"], 1)
            selected.append(result)
        self.assertEqual(selected[0], selected[1])

    def test_database_relationships_schema_and_bytes_are_reproducible(self):
        products = [product(), product(2, "012345678905", "mL")]
        with tempfile.TemporaryDirectory() as directory:
            a, b = Path(directory) / "a.sqlite", Path(directory) / "b.sqlite"
            importer.build_database(a, products)
            importer.build_database(b, list(reversed(products)))
            self.assertEqual(a.read_bytes(), b.read_bytes())
            with sqlite3.connect(a) as db:
                self.assertEqual(db.execute("PRAGMA application_id").fetchone()[0], importer.APPLICATION_ID)
                self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 1)
                self.assertEqual(db.execute("PRAGMA integrity_check").fetchall(), [("ok",)])
                self.assertEqual(db.execute("PRAGMA foreign_key_check").fetchall(), [])
                columns = [row[1] for row in db.execute("PRAGMA table_info(packaged_products)")]
                self.assertEqual(len(columns), 15)
                self.assertNotIn("serving_grams", columns)
                db.execute("PRAGMA foreign_keys=ON")
                with self.assertRaises(sqlite3.IntegrityError):
                    db.execute("UPDATE packaged_products SET source_id='missing'")

    def test_pin_mismatch_and_size_bounds_are_rejected_before_parsing(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.zip"
            path.write_bytes(b"not a USDA ZIP")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                importer.verify_archive(path)
            with self.assertRaisesRegex(ValueError, "compressed"):
                importer.verify_archive(path, maximum=1)

    def test_csv_header_and_stream_hash_are_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.zip"
            raw = b'"id","unit_name"\n"1003","G"\n'
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(importer.ARCHIVE_PREFIX + "nutrient.csv", raw)
            audits = {}
            with zipfile.ZipFile(path) as archive:
                self.assertEqual(list(importer.rows(archive, "nutrient.csv", ("id", "unit_name"), audits)), [{"id": "1003", "unit_name": "G"}])
            self.assertEqual(audits["nutrient.csv"]["sha256"], hashlib.sha256(raw).hexdigest())
            with zipfile.ZipFile(path) as archive:
                with self.assertRaisesRegex(ValueError, "header"):
                    list(importer.rows(archive, "nutrient.csv", ("missing",), {}))

    def test_handled_second_output_failure_restores_previous_pair(self):
        with tempfile.TemporaryDirectory() as directory:
            a, b = Path(directory) / "a.sqlite", Path(directory) / "b.json"
            a.write_bytes(b"old db")
            b.write_bytes(b"old manifest")
            real_replace, count = importer.os.replace, 0

            def fail_second(source, destination):
                nonlocal count
                count += 1
                if count == 2:
                    raise OSError("simulated output failure")
                return real_replace(source, destination)

            with mock.patch.object(importer.os, "replace", side_effect=fail_second):
                with self.assertRaisesRegex(OSError, "simulated"):
                    importer.replace_outputs([(a, b"new db"), (b, b"new manifest")])
            self.assertEqual(a.read_bytes(), b"old db")
            self.assertEqual(b.read_bytes(), b"old manifest")
            importer.replace_outputs([(a, b"new db"), (b, b"new manifest")])
            self.assertEqual(a.stat().st_mode & 0o777, 0o644)
            self.assertEqual(b.stat().st_mode & 0o777, 0o644)

    def test_shipped_resource_has_matching_hash_counts_and_real_mass_and_volume(self):
        manifest = json.loads(importer.DEFAULT_MANIFEST.read_bytes())
        data = importer.DEFAULT_OUTPUT.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), manifest["databaseSHA256"])
        self.assertEqual(len(data), manifest["databaseBytes"])
        self.assertLessEqual(len(data), importer.MAX_DATABASE_BYTES)
        self.assertEqual(manifest["source"]["archiveSHA256"], importer.ARCHIVE_SHA256)
        with sqlite3.connect(importer.DEFAULT_OUTPUT) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM packaged_products").fetchone()[0], manifest["productCount"])
            self.assertEqual({row[0] for row in db.execute("SELECT DISTINCT basis_unit FROM packaged_products")}, {"g", "mL"})
            self.assertEqual(db.execute("PRAGMA foreign_key_check").fetchall(), [])
            for (gtin,) in db.execute("SELECT gtin14 FROM packaged_products"):
                self.assertEqual(importer.canonical_gtin(gtin), gtin)
        self.assertGreater(manifest["productCount"], 10_000)
        self.assertLessEqual(manifest["productCount"], 50_000)


if __name__ == "__main__":
    unittest.main()
