#!/usr/bin/env python3
"""Run only suites that use fixtures; never open a personal persistent app store."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
UI_SUITES = [
    '-only-testing:Caliber (DEV)UITests/FoodEntryPass2UITests',
    '-only-testing:Caliber (DEV)UITests/VisualPass2UITests',
    '-only-testing:Caliber (DEV)UITests/GoalSetupUITests',
    '-only-testing:Caliber (DEV)UITests/FoundationUITests',
    '-only-testing:Caliber (DEV)UITests/ProgressUITests',
    '-only-testing:Caliber (DEV)UITests/ThemeIntegrationUITests',
    '-only-testing:Caliber (DEV)UITests/StackUITests',
    '-only-testing:Caliber (DEV)UITests/LookbookPolishUITests',
    '-only-testing:Caliber (DEV)UITests/CustomExerciseUITests',
]
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--unit-only', action='store_true',
                        help='build the app and run only the unit tests (no UI or audits)')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
    # Prefer the newest installed iOS runtime.
    runtimes = sorted((r for r in devices if '.iOS-' in r),
                      key=lambda r: [int(p) for p in r.rsplit('.iOS-', 1)[1].split('-') if p.isdigit()],
                      reverse=True)
    choices = [d for runtime in runtimes for d in devices[runtime] if d['name'].startswith('iPhone')]
    if not choices:
        raise SystemExit('Install an iOS simulator runtime in Xcode → Settings → Components.')
    device = next((d for d in choices if d['state'] == 'Booted'), choices[0])
    subprocess.run([
        'xcodebuild', 'test', '-project', 'Caliber (DEV).xcodeproj', '-scheme', 'Caliber (DEV)',
        '-destination', f"platform=iOS Simulator,id={device['udid']}",
        '-derivedDataPath', str(output / 'DerivedData'), '-resultBundlePath', str(output / 'Checks.xcresult'),
        '-parallel-testing-enabled', 'NO', '-collect-test-diagnostics', 'never',
        '-only-testing:Caliber (DEV)Tests', *([] if args.unit_only else UI_SUITES),
        'CODE_SIGNING_ALLOWED=NO'
    ], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
