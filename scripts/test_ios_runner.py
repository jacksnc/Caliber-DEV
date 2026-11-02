"""Regression guards for fixture coverage and simulator ownership, without Xcode."""
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import test_ios as runner


class IOSRunnerTests(unittest.TestCase):
    def test_shards_cover_every_reviewed_suite_once(self):
        shards = [runner.selected_tests(shard=f'{i}/4') for i in range(1, 5)]
        flattened = [value for shard in shards for value in shard]
        expected = {f'-only-testing:Caliber (DEV)UITests/{s}' for s in runner.UI_SUITES}
        self.assertEqual(set(flattened), expected)
        self.assertEqual(len(flattened), len(expected))
        self.assertEqual(runner.selected_tests(shard='1/4'), shards[0])

    def test_invalid_shards_fail_before_any_device_action(self):
        for value in ['0/4', '5/4', '1/0', '1/99', 'invalid', '1/2/3']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                runner.selected_tests(shard=value)

    def test_unit_only_and_default_selection(self):
        self.assertEqual(runner.selected_tests(unit_only=True), ['-only-testing:Caliber (DEV)Tests'])
        self.assertEqual(len(runner.selected_tests()), len(runner.UI_SUITES) + 1)
        with self.assertRaises(ValueError):
            runner.selected_tests(unit_only=True, shard='1/4')

    def test_all_source_suites_are_reviewed_or_explicitly_excluded(self):
        classes = set()
        for path in (runner.ROOT / 'Caliber (DEV)UITests').glob('*.swift'):
            source = path.read_text()
            found = set(re.findall(r'class\s+(\w+)\s*:\s*XCTestCase\b', source))
            classes.update(found)
            if found.intersection(runner.UI_SUITES):
                self.assertTrue('--progress-ui-testing' in source or '--foundation-ui-testing' in source,
                                f'{path.name} has no reviewed isolated launch argument')
        # Xcode's old template launches a persistent store without fixture assertions.
        self.assertEqual(classes - set(runner.UI_SUITES), {'Caliber__DEV_UITests'})
        self.assertTrue(set(runner.UI_SUITES).issubset(classes))

    def exercise_device_ownership(self, failure=False):
        personal = '11111111-1111-1111-1111-111111111111'
        created = '22222222-2222-2222-2222-222222222222'
        devices = {'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-27-0': [
            {'udid': personal, 'name': 'iPhone 17', 'state': 'Booted',
             'deviceTypeIdentifier': 'com.apple.CoreSimulator.SimDeviceType.iPhone-17'}]}}
        with tempfile.TemporaryDirectory() as output, \
                patch.object(runner.subprocess, 'check_output', side_effect=[json.dumps(devices).encode(), created]), \
                patch.object(runner.subprocess, 'run') as run:
            if failure:
                run.side_effect = [subprocess.CalledProcessError(65, 'xcodebuild'), None, None]
                with self.assertRaises(subprocess.CalledProcessError):
                    runner.run_tests(Path(output), unit_only=True)
            else:
                runner.run_tests(Path(output), unit_only=True)
            calls = [c.args[0] for c in run.call_args_list]
            self.assertIn(f'platform=iOS Simulator,id={created}', calls[0])
            self.assertEqual(calls[1:], [['xcrun', 'simctl', 'shutdown', created],
                                         ['xcrun', 'simctl', 'delete', created]])
            self.assertNotIn(personal, ' '.join(' '.join(c) for c in calls))

    def test_success_uses_and_removes_only_new_simulator(self):
        self.exercise_device_ownership()

    def test_failed_native_run_still_removes_only_new_simulator(self):
        self.exercise_device_ownership(failure=True)


if __name__ == '__main__':
    unittest.main()
