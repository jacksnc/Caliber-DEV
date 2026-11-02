#!/usr/bin/env python3
"""Run reviewed fixture suites on a newly created, disposable simulator."""
import argparse
import json
from pathlib import Path
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
# Balanced using the November 2 broad run, capping each historical stalled case
# at the 420-second focused budget. Each group had about 25–26 minutes of work;
# the expensive food-entry audit is kept alone. This is scheduling, not skipping.
UI_SUITE_SHARDS = [
    ['FoodEntryPass2UITests'],
    ['FoodShortcutsUITests', 'DiaryMealHeaderUITests', 'RecipeBuilderUITests',
     'StackUITests', 'CustomExerciseUITests', 'TodayInfoCardPagerUITests'],
    ['FoundationUITests', 'ResponsiveLayoutUITests', 'GoalSetupUITests',
     'WidgetRoutingUITests', 'DiaryV2UITests', 'HealthEnergyUITests',
     'WidgetSettingsUITests', 'LookbookPolishUITests'],
    ['FoodExperienceUITests', 'ThemeIntegrationUITests', 'DiaryEnergyUnitDisplayUITests',
     'SeasonalAppearanceUITests', 'TrainProfileUITests', 'ProgressUITests',
     'ProgressUnitConsistencyUITests', 'RestaurantCustomizationUITests', 'VisualPass2UITests'],
]
UI_SUITES = [suite for shard in UI_SUITE_SHARDS for suite in shard]


def selected_tests(unit_only=False, shard=None):
    if unit_only and shard:
        raise ValueError('unit-only and ui-shard are mutually exclusive')
    if unit_only:
        return ['-only-testing:Caliber (DEV)Tests']
    suites = UI_SUITES
    if shard:
        try:
            index, count = map(int, shard.split('/'))
        except (ValueError, AttributeError):
            raise ValueError('ui-shard must be INDEX/COUNT, for example 1/4') from None
        if not 1 <= index <= count <= len(suites):
            raise ValueError('ui-shard must satisfy 1 <= INDEX <= COUNT <= suite count')
        suites = UI_SUITE_SHARDS[index - 1] if count == len(UI_SUITE_SHARDS) else suites[index - 1::count]
    return ([] if shard else ['-only-testing:Caliber (DEV)Tests']) + [
        '-only-testing:Caliber (DEV)UITests/' + suite for suite in suites]


def run_tests(output, unit_only=False, shard=None):
    selectors = selected_tests(unit_only, shard)
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
    # Prefer the newest installed iOS runtime.
    runtimes = sorted((r for r in devices if '.iOS-' in r),
                      key=lambda r: [int(p) for p in r.rsplit('.iOS-', 1)[1].split('-') if p.isdigit()],
                      reverse=True)
    choices = [d for runtime in runtimes for d in devices[runtime] if d['name'].startswith('iPhone')]
    if not choices:
        raise SystemExit('Install an iOS simulator runtime in Xcode → Settings → Components.')
    # Read an available device's type/runtime, never its store or current boot state.
    # Only the simulator created by this invocation may be shut down or deleted.
    prototype = choices[0]
    runtime = next(r for r in runtimes if prototype in devices[r])
    created = subprocess.check_output([
        'xcrun', 'simctl', 'create', 'Caliber automated QA ' + str(uuid.uuid4()),
        prototype['deviceTypeIdentifier'], runtime], text=True).strip()
    uuid.UUID(created)  # Refuse malformed output rather than target an arbitrary device.
    try:
        subprocess.run([
            'xcodebuild', 'test', '-project', 'Caliber (DEV).xcodeproj', '-scheme', 'Caliber (DEV)',
            '-destination', f'platform=iOS Simulator,id={created}',
            '-derivedDataPath', str(output / 'DerivedData'), '-resultBundlePath', str(output / 'Checks.xcresult'),
            '-parallel-testing-enabled', 'NO', '-collect-test-diagnostics', 'never',
            *selectors, 'CODE_SIGNING_ALLOWED=NO'
        ], cwd=ROOT, check=True)
    finally:
        # Xcode may already have shut it down; silence that harmless state error.
        subprocess.run(['xcrun', 'simctl', 'shutdown', created], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(['xcrun', 'simctl', 'delete', created], check=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, type=Path)
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument('--unit-only', action='store_true',
                       help='build the app and run only the unit tests (no UI or audits)')
    scope.add_argument('--ui-shard', help='run one deterministic UI-only shard, e.g. 1/4')
    args = parser.parse_args()
    try:
        run_tests(args.output, args.unit_only, args.ui_shard)
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
