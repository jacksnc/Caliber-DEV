#!/usr/bin/env python3
"""Check all local GTIN forms and a source-identified convenience sample.

This measures database lookup/normalization, not optical camera performance or
population coverage. It makes no provider requests and uses no personal scans.
"""
import json
from pathlib import Path
import sqlite3
from import_label_foods import gtin

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = [
    ('Oikos Pro vanilla 5.3 oz cup', '036632042552', 'https://www.target.com/p/-/A-81995727'),
    ('Core Power chocolate 26 g 14 fl oz', '811620021951', 'https://www.target.com/p/-/A-78824043'),
    ('Coca-Cola 2 L', '049000050103', 'https://www.target.com/p/-/A-12958783'),
    ('Barilla spaghetti 16 oz', '076808280081', 'https://www.target.com/p/-/A-13156213'),
    ('Jif creamy peanut butter 16 oz', '051500255162', 'https://www.azdhs.gov/documents/prevention/azwic/vendors/arizona-wic-foods-database.pdf?v=20221108'),
    ('Honey Nut Cheerios 17 oz', '00016000275713', 'https://www.cub.com/store/cub/products/34101-cheerios-cereal-honey-nut-17-oz'),
]


def main():
    connection = sqlite3.connect('file:' + str(ROOT / 'Caliber (DEV)/Resources/PackagedFoodDatabase.sqlite') + '?mode=ro', uri=True)
    codes = [row[0] for row in connection.execute('SELECT gtin14 FROM packaged_products')]
    checked = 0
    for code in codes:
        assert gtin(code) == code
        forms = {code}
        if code.startswith('0'): forms.add(code[1:])
        if code.startswith('00'): forms.add(code[2:])
        if code.startswith('000000'): forms.add(code[6:])
        for form in forms:
            assert gtin(form) == code
            assert connection.execute('SELECT gtin14 FROM packaged_products WHERE gtin14=?', (gtin(form),)).fetchone()[0] == code
            checked += 1
    labels = json.loads((ROOT / 'Caliber (DEV)/Resources/LabelFoods.json').read_text())
    corrections = {food['gtin14']: food for food in labels['foods'] if food['gtin14']}
    samples = []
    for name, code, source in SAMPLES:
        key = gtin(code)
        old = connection.execute('SELECT name FROM packaged_products WHERE gtin14=?', (key,)).fetchone()
        samples.append(dict(name=name, barcode=code, identitySource=source, bundledHit=old is not None,
                            reviewedOverride=key in corrections, resultingHit=old is not None or key in corrections))
    report = dict(reviewedOn='2026-11-01', catalogProducts=len(codes), equivalentFormsChecked=checked,
                  invalidLocalGTINs=0, sampleHits=sum(row['resultingHit'] for row in samples),
                  sampleSize=len(samples), samples=samples, marketCoverageEstablished=False,
                  opticalCameraTested=False, onlineFallbackConfigured=False,
                  interpretation='Six selected US SKUs are a convenience sample, not a statistical market estimate. Local-form checks do not test camera optics or label accuracy.')
    out = ROOT / 'docs/evidence/packaged-import/barcode-coverage.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + '\n')
    print(f'{len(codes)} local codes / {checked} equivalent forms; sample hits {report["sampleHits"]}/{len(samples)}; market coverage unproven')


if __name__ == '__main__': main()
