#!/usr/bin/env python3
"""Validate boundaries and exact bundled contracts without touching an app store."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'Packages/CaliberFoundation'
for original, bundled in [
    ('architecture/feature-flags.json', 'Sources/CaliberCore/Resources/feature-flags.json'),
    ('architecture/design-tokens.json', 'Sources/CaliberDesignSystem/Resources/design-tokens.json'),
]:
    assert json.loads((ROOT / original).read_text()) == json.loads((PACKAGE / bundled).read_text()), original
for file in (PACKAGE / 'Sources/CaliberCore').glob('*.swift'):
    source = file.read_text()
    assert not any(f'import {x}' in source for x in ['SwiftUI', 'SwiftData', 'GRDB', 'UIKit', 'HealthKit']), file
for file in (PACKAGE / 'Sources').rglob('*.swift'):
    source = file.read_text()
    assert 'print(' not in source and 'debugPrint(' not in source, f'Unstructured diagnostic: {file}'
for file in (PACKAGE / 'Sources').rglob('*.xcstrings'):
    assert json.loads(file.read_text())['sourceLanguage'] == 'en', file
assert 'https://github.com/groue/GRDB.swift.git' in (PACKAGE / 'Package.swift').read_text()
subprocess.run([sys.executable, str(ROOT / 'scripts/validate_phase0.py')], check=True)
print('PASS: Foundation bundle consistency, pure-core boundary and closed diagnostics.')
