#!/usr/bin/env python3
"""Lint new Foundation files without reformatting unrelated existing screens."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
paths = sorted((ROOT / 'Packages/CaliberFoundation/Sources').rglob('*.swift'))
paths += sorted((ROOT / 'Packages/CaliberFoundation/Tests').rglob('*.swift'))
paths += [ROOT / 'Packages/CaliberFoundation/Package.swift']
paths += [ROOT / p for p in [
    'Caliber (DEV)/App/FoundationRuntime.swift',
    'Caliber (DEV)/Views/RootTabView.swift',
    'Caliber (DEV)/App/HostedAccountModel.swift',
    'Caliber (DEV)/Views/Foundation/HostedAccountView.swift',
    'Caliber (DEV)/Services/LegacySnapshotAdapter.swift',
    'Caliber (DEV)/Views/Foundation/FoundationSettingsView.swift',
    'Caliber (DEV)/Views/Foundation/TodayFoundationView.swift',
    'Caliber (DEV)Tests/LegacySnapshotTests.swift',
    'Caliber (DEV)Tests/HostedAccountTests.swift',
    'Caliber (DEV)UITests/FoundationUITests.swift',
]]
subprocess.run(['xcrun', 'swift-format', 'lint', '--strict', *map(str, paths)], cwd=ROOT, check=True)
