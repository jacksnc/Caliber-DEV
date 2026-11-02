#!/usr/bin/env python3
"""Inspect built iPhone archive packaging. This is not App Store validation.

Read-only: never signs, uploads, registers identifiers, or changes an archive.
Signing checks establish material presence only; use Xcode's validation before
distribution to verify certificates, entitlements and provisioning.
"""
import argparse
import json
from pathlib import Path
import plistlib

REASONS = {
    "NSPrivacyAccessedAPICategoryUserDefaults": "CA92.1",
    "NSPrivacyAccessedAPICategorySystemBootTime": "35F9.1",
}


def plist(path):
    try:
        value = plistlib.loads(path.read_bytes())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError, plistlib.InvalidFileException):
        return {}


def inspect_archive(path, allow_unsigned=False):
    checks = []

    def check(name, passed, detail):
        checks.append({"check": name, "passed": bool(passed), "detail": detail})

    apps = list((path / "Products/Applications").glob("*.app"))
    check("application", len(apps) == 1, "Archive must contain exactly one application.")
    if len(apps) != 1:
        return checks
    app = apps[0]
    info = plist(app / "Info.plist")
    check("device_platform", info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"],
          "Expected a hardware iPhoneOS build, not a simulator build.")
    primary = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
    check("app_icon", bool(primary.get("CFBundleIconName")),
          "Compiled primary app icon metadata must be present.")
    manifest = plist(app / "PrivacyInfo.xcprivacy")
    declared = {entry.get("NSPrivacyAccessedAPIType"): entry.get("NSPrivacyAccessedAPITypeReasons", [])
                for entry in manifest.get("NSPrivacyAccessedAPITypes", []) if isinstance(entry, dict)}
    for category, reason in REASONS.items():
        check(category, reason in declared.get(category, []), "Expected reason: " + reason)
    widgets = list((app / "PlugIns").glob("*.appex"))
    check("widget_extension", len(widgets) == 1, "Expected the embedded Caliber widget extension.")
    for widget in widgets:
        extension = plist(widget / "Info.plist")
        bundle_id = info.get("CFBundleIdentifier", "")
        check("widget_identifier", bool(bundle_id) and
              extension.get("CFBundleIdentifier", "").startswith(bundle_id + "."),
              "Extension identifier must be a child of the app identifier.")
        check("widget_version", all(info.get(key) and info.get(key) == extension.get(key)
                                    for key in ("CFBundleVersion", "CFBundleShortVersionString")),
              "App and widget build/version numbers must match.")
    for bundle in [app, *widgets]:
        executable = plist(bundle / "Info.plist").get("CFBundleExecutable", "")
        check("executable:" + bundle.name,
              bool(executable) and Path(executable).name == executable and
              (bundle / executable).is_file(),
              "Bundle must contain its declared executable.")
    if not allow_unsigned:
        for bundle in [app, *widgets]:
            check("signing_material:" + bundle.name,
                  (bundle / "_CodeSignature/CodeResources").is_file() and
                  (bundle / "embedded.mobileprovision").is_file(),
                  "Requires signature and profile; presence does not validate either.")
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--allow-unsigned", action="store_true",
                        help="Skip signing-material presence checks for compile-only QA")
    args = parser.parse_args()
    checks = inspect_archive(args.archive, args.allow_unsigned)
    print(json.dumps({"scope": "archive packaging only", "checks": checks}, indent=2))
    return 0 if all(check["passed"] for check in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
