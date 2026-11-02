import plistlib
from pathlib import Path
import tempfile
import unittest

from check_release_archive import REASONS, inspect_archive


class ArchiveChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / "Products/Applications/Example.app"
        self.widget = self.app / "PlugIns/Example.appex"
        self.widget.mkdir(parents=True)
        self.info = {"CFBundleIdentifier": "example.app", "CFBundleExecutable": "Example", "CFBundleVersion": "1",
                     "CFBundleShortVersionString": "1.0", "CFBundleSupportedPlatforms": ["iPhoneOS"],
                     "CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconName": "AppIcon"}}}
        self.write(self.app / "Info.plist", self.info)
        self.write(self.widget / "Info.plist", {**self.info, "CFBundleIdentifier": "example.app.widgets"})
        for bundle in [self.app, self.widget]:
            (bundle / "Example").write_bytes(b"fixture binary placeholder")
        self.write(self.app / "PrivacyInfo.xcprivacy", {"NSPrivacyAccessedAPITypes": [
            {"NSPrivacyAccessedAPIType": category, "NSPrivacyAccessedAPITypeReasons": [reason]}
            for category, reason in REASONS.items()]})

    def write(self, path, value):
        path.write_bytes(plistlib.dumps(value))

    def failed(self, unsigned=True):
        return {c["check"] for c in inspect_archive(self.root, unsigned) if not c["passed"]}

    def test_complete_compile_only_archive(self):
        self.assertEqual(self.failed(), set())

    def test_empty_archive_fails(self):
        self.assertFalse(inspect_archive(self.root / "absent")[0]["passed"])

    def test_missing_root_manifest_is_not_satisfied_by_dependency(self):
        (self.app / "PrivacyInfo.xcprivacy").rename(self.widget / "PrivacyInfo.xcprivacy")
        self.assertTrue(set(REASONS).issubset(self.failed()))

    def test_missing_icon_fails(self):
        self.info.pop("CFBundleIcons")
        self.write(self.app / "Info.plist", self.info)
        self.assertIn("app_icon", self.failed())

    def test_simulator_build_fails(self):
        self.info["CFBundleSupportedPlatforms"] = ["iPhoneSimulator"]
        self.write(self.app / "Info.plist", self.info)
        self.assertIn("device_platform", self.failed())

    def test_missing_executable_fails(self):
        (self.app / "Example").unlink()
        self.assertIn("executable:Example.app", self.failed())

    def test_extension_identity_and_version_must_match(self):
        self.write(self.widget / "Info.plist", {"CFBundleIdentifier": "other.widgets",
                                               "CFBundleVersion": "2"})
        self.assertTrue({"widget_identifier", "widget_version"}.issubset(self.failed()))

    def test_unsigned_archive_fails_by_default(self):
        self.assertEqual(self.failed(unsigned=False),
                         {"signing_material:Example.app", "signing_material:Example.appex"})


if __name__ == "__main__":
    unittest.main()
