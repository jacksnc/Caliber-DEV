#!/usr/bin/env python3
"""Run only suites that use fixtures; never open a personal persistent app store."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
    choices = [d for runtime, rows in devices.items() if '.iOS-' in runtime for d in rows if d['name'].startswith('iPhone')]
    if not choices:
        raise SystemExit('Install an iOS simulator runtime in Xcode → Settings → Components.')
    device = next((d for d in choices if d['state'] == 'Booted'), choices[0])
    subprocess.run([
        'xcodebuild', 'test', '-project', 'Caliber (DEV).xcodeproj', '-scheme', 'Caliber (DEV)',
        '-destination', f"platform=iOS Simulator,id={device['udid']}",
        '-derivedDataPath', str(output / 'DerivedData'), '-resultBundlePath', str(output / 'Checks.xcresult'),
        '-parallel-testing-enabled', 'NO', '-collect-test-diagnostics', 'never',
        '-only-testing:Caliber (DEV)Tests', '-only-testing:Caliber (DEV)UITests/FoundationUITests',
        '-only-testing:Caliber (DEV)UITests/ProgressUITests',
        '-only-testing:Caliber (DEV)UITests/ThemeIntegrationUITests',
        '-only-testing:Caliber (DEV)UITests/StackUITests', 'CODE_SIGNING_ALLOWED=NO'
    ], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
