#!/usr/bin/env python3
"""Validate per-serving food-label CSV and atomically stage a bundled supplement.

Default output is unreviewed and rejected by the app. --reviewed records a
completed source/serving/GTIN review; it cannot establish truth by itself.
"""
import argparse
import csv
from datetime import date
import io
import json
import math
from pathlib import Path
import re
import os
import tempfile
from urllib.parse import urlsplit

FIELDS = ('id', 'brand', 'name', 'aliases', 'country', 'barcode', 'serving_description',
          'serving_grams', 'serving_ml', 'calories', 'protein_g', 'carbs_g', 'fat_g',
          'source_url', 'source_locator', 'retrieved_on', 'barcode_source_url')


def url(value):
    parsed = urlsplit(value)
    if parsed.scheme != 'https' or not parsed.hostname or '.' not in parsed.hostname or parsed.username or parsed.password or any(c.isspace() for c in value):
        raise ValueError('Expected a public HTTPS source URL without credentials')
    return value


def number(value, optional=False, positive=False):
    if not value and optional:
        return None
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+)?', value):
        raise ValueError('Expected explicit decimal nutrition; blank is not zero')
    result = float(value)
    if not math.isfinite(result) or not 0 <= result <= 10_000 or (positive and result == 0):
        raise ValueError('Amount outside supported label limits')
    return result


def gtin(value):
    if not value:
        return None
    if not re.fullmatch(r'(?:[0-9]{8}|[0-9]{12}|[0-9]{13}|[0-9]{14})', value) or set(value) == {'0'}:
        raise ValueError('Expected complete GTIN digits, including leading zeroes (not UPC-E)')
    digits = value.zfill(14)
    if sum(int(c) * (3 if i % 2 == 0 else 1) for i, c in enumerate(digits)) % 10:
        raise ValueError('Invalid barcode check digit; never invent or repair a UPC')
    return digits


def convert(raw, reviewed=False):
    if len(raw) > 4_000_000:
        raise ValueError('CSV exceeds size limit')
    reader = csv.DictReader(io.StringIO(raw.decode('utf-8-sig')))
    if reader.fieldnames != list(FIELDS):
        raise ValueError('Columns must match the template exactly, in order')
    foods, ids, codes = [], set(), set()
    for line, source in enumerate(reader, 2):
        try:
            if None in source or any(v is None for v in source.values()):
                raise ValueError('Wrong number of columns')
            row = {k: v.strip() for k, v in source.items()}
            if any(len(v) > 500 or any(ord(c) < 32 for c in v) for v in row.values()):
                raise ValueError('Oversized text or control characters')
            if not re.fullmatch(r'[a-z0-9][a-z0-9.-]{0,95}', row['id']) or row['id'] in ids:
                raise ValueError('Invalid or duplicate stable ID')
            if not all(row[k] for k in ('brand', 'name', 'serving_description', 'source_locator')) or row['country'] != 'US':
                raise ValueError('Brand, variant, serving and source are required; country must be US')
            if date.fromisoformat(row['retrieved_on']).isoformat() != row['retrieved_on']:
                raise ValueError('Expected canonical source retrieval date')
            code = gtin(row['barcode'])
            if code and (code in codes or not row['barcode_source_url']):
                raise ValueError('Duplicate barcode or missing barcode evidence URL')
            grams = number(row['serving_grams'], optional=True, positive=True)
            ml = number(row['serving_ml'], optional=True, positive=True)
            if grams is not None and ml is not None:
                raise ValueError('Choose source grams OR mL; never infer density')
            foods.append(dict(
                id=row['id'], brand=row['brand'], name=row['name'], aliases=row['aliases'], country='US', gtin14=code,
                servingDescription=row['serving_description'], servingGrams=grams, servingMilliliters=ml,
                calories=number(row['calories']), proteinGrams=number(row['protein_g']),
                carbGrams=number(row['carbs_g']), fatGrams=number(row['fat_g']),
                sourceURL=url(row['source_url']), sourceLocator=row['source_locator'], retrievedOn=row['retrieved_on'],
                barcodeSourceURL=url(row['barcode_source_url']) if row['barcode_source_url'] else None))
            ids.add(row['id'])
            if code: codes.add(code)
            if len(foods) > 1000: raise ValueError('Batch exceeds 1000 items')
        except ValueError as error:
            raise ValueError(f'Row {line}: {error}') from error
    if not foods: raise ValueError('CSV contains no foods')
    return {'schemaVersion': 1, 'reviewed': reviewed, 'foods': sorted(foods, key=lambda f: f['id'])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--csv', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--reviewed', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        if args.csv.resolve() == args.output.resolve(): raise ValueError('Cannot overwrite input CSV')
        resource = Path(__file__).resolve().parents[1] / 'Caliber (DEV)' / 'Resources'
        if args.output.resolve().is_relative_to(resource) and not args.reviewed:
            raise ValueError('Unreviewed data may only be staged outside app resources')
        result = convert(args.csv.read_bytes(), args.reviewed)
        content = json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + '\n'
        if args.check:
            if args.output.read_text() != content: raise ValueError('Output differs from CSV')
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            temporary = None
            try:
                with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=args.output.parent, delete=False) as handle:
                    temporary = handle.name
                    handle.write(content)
                os.replace(temporary, args.output)
            finally:
                if temporary and os.path.exists(temporary): os.unlink(temporary)
        print(f"Validated {len(result['foods'])} label foods; reviewed={args.reviewed}")
    except (ValueError, OSError, UnicodeError) as error:
        parser.exit(2, f'{error}\n')


if __name__ == '__main__':
    main()
