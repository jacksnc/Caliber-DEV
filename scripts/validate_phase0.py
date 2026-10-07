#!/usr/bin/env python3
"""Validate architecture contracts using Python's standard library.

This never opens an app database. SQL checks use disposable test databases.
Passing this script does not mean the proposed application is implemented.
"""
from collections import Counter
from decimal import Decimal
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(relative):
    return json.loads((ROOT / relative).read_text())


def unique(rows, label):
    ids = [row['id'] for row in rows]
    require(len(ids) == len(set(ids)), f'Duplicate {label} ID')
    return set(ids)


def check_contracts():
    for path in ROOT.rglob('*.json'):
        json.loads(path.read_text())
    for path in ROOT.rglob('*.py'):
        compile(path.read_text(), str(path), 'exec')
    brief = (ROOT / 'docs/MASTER_BUILD_BRIEF.md').read_text()
    # Numbered prose requirements and the compact visualization tables.
    declared = dict(re.findall(r'\*\*([A-Z]+-\d+)\s*·\s*(P[012])\*\*', brief))
    declared.update({'VZ-' + i: priority for i, priority in re.findall(r'^\|\s*([TWFBSX]\d+)\s*\|\s*(P[012])\s*\|', brief, re.M)})
    requirements = read_json('architecture/requirements.json')['requirements']
    requirement_ids = unique(requirements, 'requirement')
    explicit = {r['id']: r['priority'] for r in requirements if r['origin'].startswith('explicit')}
    require(len(declared) == 211, f'Expected 211 explicit brief IDs; parsed {len(declared)}')
    require(declared == explicit, f'Brief ID/priority mismatch: {set(declared.items()) ^ set(explicit.items())}')
    counts = Counter(r['priority'] for r in requirements)
    require(counts == {'P0': 81, 'P1': 116, 'P2': 26}, f'Unexpected traceability counts: {counts}')
    manifest = read_json('architecture/schema/TABLES.json')
    tables = {f'{store}.{t["name"]}' for store, rows in manifest.items() for t in rows}
    backlog = (ROOT / 'docs/BACKLOG.md').read_text()
    for row in requirements:
        require(row['id'] in backlog, f'{row["id"]} missing from backlog')
        if row['priority'] == 'P0':
            require(row['tables'] and row['screens'] and row['tests'], f'{row["id"]} lacks mapping')
            require(set(row['tables']) <= tables, f'{row["id"]} references absent P0 table')
        if row['priority'] != 'P2':
            require(row['tests'], f'{row["id"]} lacks planned acceptance test')
            for test in row['tests']:
                require(test['id'] and len(test['assertion']) >= 25, f'{row["id"]} lacks test assertion')
                require(test['status'] == 'planned', f'{row["id"]} must not claim future test passed')
    flags = read_json('architecture/feature-flags.json')['flags']
    flag_ids = unique(flags, 'flag')
    p1 = {r['id'] for r in requirements if r['priority'] == 'P1'}
    require({f['requirement'] for f in flags} == p1, 'P1 flag coverage incomplete')
    require(len(flags) == len(p1), 'More than one flag per P1 requirement')
    for flag in flags:
        require(flag['default'] is False, f'{flag["id"]} is enabled')
    for row in requirements:
        if row['priority'] == 'P1':
            require(row['featureFlag'] in flag_ids and row['defaultEnabled'] is False,
                    f'{row["id"]} flag binding mismatch')
    series = read_json('architecture/series-registry.json')['series']
    events = read_json('architecture/event-registry.json')['events']
    unique(series, 'series')
    unique(events, 'event')
    for row in series + events:
        require(set(row['requirements']) <= requirement_ids, f'{row["id"]} unknown requirement')
        require(row['sourceQuery'] and row['domain'] and row['privacy'], f'{row["id"]} incomplete query contract')
    for row in series:
        require(row['unit'] and row['kind'] and row['aggregation'], f'{row["id"]} incomplete measure')
        require(row['registeredNotImplemented'] is True, f'{row["id"]} must not claim implementation')
        require(row['rollupTable'] in tables, f'{row["id"]} rollup table missing')
        if row['schemaAvailability'] == 'v1':
            require(set(row['sourceTables']) <= tables, f'{row["id"]} source table missing')
        else:
            require(row['schemaAvailability'] == 'future-P1' and row['priority'] == 'P1',
                    f'{row["id"]} invalid deferred source')
        if row['priority'] == 'P1':
            require(row['featureFlag'] in flag_ids, f'{row["id"]} flag missing')
        if row['domain'] == 'stack':
            require(row['store'] == 'stack' and row['privacy'] == 'stack-private', f'{row["id"]} private store mismatch')
            require(all(t.startswith('stack.') for t in row['sourceTables']), f'{row["id"]} crosses privacy store')
        else:
            require(all(t.startswith('core.') for t in row['sourceTables']), f'{row["id"]} persists Stack in core')
    for row in events:
        if row['schemaAvailability'] == 'v1':
            require(f'{row["sourceStore"]}.{row["sourceEntity"]}' in tables, f'{row["id"]} event table missing')
        else:
            require(row['schemaAvailability'] == 'future-P1', f'{row["id"]} deferred source invalid')
        if row['domain'] == 'stack':
            require(row['sourceStore'] == 'stack' and row['persistInCore'] is False,
                    f'{row["id"]} persists private event in core')
    print(f'PASS: {len(declared)} explicit + 12 derived IDs; {counts["P0"]} P0 table/screen/test mappings; '
          f'{len(flags)} default-off P1 flags; {counts["P2"]} P2 backlog items.', flush=True)
    print(f'PASS: {len(tables)} table contracts; {len(series)} series and {len(events)} events with valid store bindings.', flush=True)


def check_links():
    count = 0
    for path in ROOT.rglob('*.md'):
        # Strip code blocks to avoid interpreting example Markdown as file links.
        body = re.sub(r'```.*?```', '', path.read_text(), flags=re.S)
        for match in re.finditer(r'\[[^\]]+\]\(([^)]+)\)', body):
            target = match.group(1).strip('<>')
            if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target) or target.startswith('#'):
                continue
            target = unquote(target.split('#')[0])
            require((path.parent / target).is_file(), f'Broken local link: {path.relative_to(ROOT)} -> {target}')
            count += 1
    print(f'PASS: {count} local Markdown file links resolve. External URL freshness is a separate review.', flush=True)


def check_generated_sql():
    source = ROOT / 'architecture/schema'
    with tempfile.TemporaryDirectory(prefix='caliber-schema-') as folder:
        scratch = Path(folder)
        shutil.copy2(source / 'generate_schema.py', scratch / 'generate_schema.py')
        subprocess.run([sys.executable, str(scratch / 'generate_schema.py')], check=True)
        for relative in ('TABLES.json', 'core/001_v1.up.sql', 'core/001_v1.down.sql',
                         'stack/001_v1.up.sql', 'stack/001_v1.down.sql'):
            require((source / relative).read_bytes() == (scratch / relative).read_bytes(),
                    f'Generated schema drift: {relative}')
    print('PASS: schema generator reproduces all four SQL files and table manifest byte-for-byte.', flush=True)


def check_fixture_arithmetic():
    """Independently check the brief's numbers; this is not an app math engine."""
    rows = read_json('architecture/golden-vectors.json')['fixtures']
    unique(rows, 'golden fixture')
    require(len(rows) == 8, 'Expected eight explicit arithmetic vectors')
    for row in rows:
        x, expected = row['input'], row['expected']
        if row['engine'] == 'e1rm':
            w, r = x['weightKg'], x['reps']
            values = {'Epley': w * (1 + r / 30), 'Brzycki': w * 36 / (37 - r),
                      'OConner': w * (1 + 0.025 * r), 'Lombardi': w * r ** 0.1}
            require(abs(values[x['formula']] - expected) <= row['tolerance'], row['id'])
        elif row['engine'] == 'draw':
            amount, volume, target = (Decimal(x[k]) for k in ('vialUg', 'finalSolutionVolumeUL', 'doseUg'))
            draw = target * volume / amount
            require(amount / volume == Decimal(expected['concentrationMgPerML']), row['id'])
            require(draw == expected['drawUL'], row['id'])
            require(draw / 1000 * x['syringeUnitsPerML'] == Decimal(expected['syringeUnits']), row['id'])
            require(int(amount // target) == expected['fullDoses'], row['id'])
        elif row['engine'] == 'blend':
            actual = [Decimal(v) * x['drawUL'] / x['finalSolutionVolumeUL'] for v in x['componentUg']]
            require(actual == expected['componentUg'], row['id'])
        else:
            raise ValueError(f'Unknown fixture engine: {row["engine"]}')
    print('PASS: eight supplied arithmetic fixture values independently reconciled; app engines remain unimplemented.', flush=True)


def main():
    check_contracts()
    check_links()
    check_generated_sql()
    check_fixture_arithmetic()
    subprocess.run([sys.executable, str(ROOT / 'scripts/check_tokens.py')], check=True)
    subprocess.run([sys.executable, str(ROOT / 'architecture/schema/tests/test_migrations.py')], check=True)
    print('PASS: Phase 0 static contracts, token checks and disposable SQL suite. Runtime features remain planned.', flush=True)


if __name__ == '__main__':
    main()
