import csv
import io
from pathlib import Path
import unittest
import subprocess
import sys
import tempfile

from import_label_foods import convert, FIELDS


class LabelImportTests(unittest.TestCase):
    def setUp(self):
        raw = (Path(__file__).resolve().parents[1] / 'docs/templates/packaged-food/reviewed-label-foods.csv').read_text()
        self.row = next(csv.DictReader(io.StringIO(raw)))

    def payload(self, rows):
        result = io.StringIO()
        writer = csv.DictWriter(result, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
        return result.getvalue().encode()

    def test_preserves_exact_per_serving_values_and_leading_zeroes(self):
        result = convert(self.payload([self.row]))
        food = result['foods'][0]
        self.assertFalse(result['reviewed'])
        self.assertEqual(food['gtin14'], '00036632042552')
        self.assertEqual((food['calories'], food['servingGrams'], food['proteinGrams']), (130, 150, 20))
        self.assertIsNone(food['servingMilliliters'])

    def test_optional_mass_and_barcode_are_not_invented(self):
        row = {**self.row, 'barcode': '', 'barcode_source_url': '', 'serving_grams': '', 'serving_ml': '240'}
        food = convert(self.payload([row]), reviewed=True)['foods'][0]
        self.assertIsNone(food['gtin14'])
        self.assertIsNone(food['servingGrams'])
        self.assertEqual(food['servingMilliliters'], 240)

    def test_rejects_bad_nutrition_identity_dates_and_unit_inference(self):
        for change in [dict(protein_g=''), dict(calories='NaN'), dict(fat_g='-1'),
                       dict(barcode='036632042553'), dict(barcode='00000000000000'),
                       dict(barcode_source_url=''), dict(serving_ml='150'),
                       dict(source_url='http://example.com'), dict(retrieved_on='2026-02-30'),
                       dict(country='CA')]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                convert(self.payload([{**self.row, **change}]))

    def test_rejects_duplicate_record_or_gtin(self):
        with self.assertRaises(ValueError): convert(self.payload([self.row, self.row]))
        with self.assertRaises(ValueError): convert(self.payload([self.row, {**self.row, 'id': 'another-id'}]))

    def test_failed_cli_import_preserves_previous_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'input.csv'
            output = Path(directory) / 'existing.json'
            source.write_bytes(self.payload([{**self.row, 'protein_g': ''}]))
            output.write_text('previous catalog')
            process = subprocess.run([sys.executable, str(Path(__file__).with_name('import_label_foods.py')),
                                      '--csv', str(source), '--output', str(output)], capture_output=True)
            self.assertEqual(process.returncode, 2)
            self.assertEqual(output.read_text(), 'previous catalog')


if __name__ == '__main__':
    unittest.main()
