# iPhone beta release preparation — November 2, 2026

Target: a reviewed, signed TestFlight beta before public App Store submission.
This checkpoint verifies packaging and compilation, not release approval.

## Source and scope

Branch `codex/release-readiness`, isolated checkout
`/Users/jcrock/Documents/Codex/Caliber-release-readiness`, starts at integrated
commit `70c4012`. It includes packaged-food name/barcode lookup, widget routing,
seasonal appearance, and saved energy-unit presentation. The original QA
checkout contains additional uncommitted fixes; those changes were inspected
but neither copied nor modified here. The owner's local preview and its three
existing edits are preserved.

Changes in this batch:

```text
Caliber (DEV)/PrivacyInfo.xcprivacy
scripts/check_release_archive.py
scripts/test_check_release_archive.py
docs/RELEASE_READINESS.md
docs/{AI_HANDOFF,DECISIONS,CHANGELOG}.md
```

The application manifest declares two directly used required-reason categories:

| API | Reason | Actual source use |
|---|---|---|
| UserDefaults | CA92.1 | App-local settings, consent state, food preferences, and local feature preferences; FoundationRuntime supplies the app's defaults store. |
| System boot time | 35F9.1 | OpenFoodFactsBarcodeService uses `systemUptime` to measure request intervals and local rate-limit cooldowns; the uptime value is not sent in its request. The optional provider remains off. |

Widgets exchange a bounded file snapshot through their App Group, not a shared
UserDefaults suite, so no App Group defaults reason was added. GRDB supplies its
own manifest. This app manifest declares required-reason API use only; it does
not assert that the separate App Store data-collection disclosures are complete.
The source/API audit is bounded, and Xcode's aggregated privacy report must
still be reviewed before distribution. No migration or health-math change.

Apple references checked November 2:
[required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api),
[API categories and reason definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype),
[distribution preparation](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution),
and [TestFlight distribution](https://help.apple.com/xcode/mac/current/en.lproj/dev2539d985f.html).

## Ordered work remaining before beta distribution

| Priority | Concrete action | Current evidence |
|---|---|---|
| 1 | Review and commit the existing QA corrections, resolve remaining failures, and rerun regression on that exact commit. | Latest recorded full UI run is 82/91; focused reruns do not establish a green full run. Read `parallel/integrated-iphone/VERIFICATION.md` in the original QA checkout. |
| 2 | Install the approved normal Home Screen icon and verify compiled phone/iPad icon metadata. | AppIcon.appiconset has no filenames, and the original hardware archive contains no CFBundleIcons. Christmas in-app artwork is not the approved normal icon. |
| 3 | Select the owner's enrolled Apple team and confirm production app/extension/App Group identifiers, then sign and validate the exact archive. | No DEVELOPMENT_TEAM in the project; this QA build explicitly disables signing. Current identifier is `CAL.Caliber--DEV-`, widget suffix `.widgets`; do not rename stores or App Groups silently. |
| 4 | Exercise the signed build on a physical iPhone. | Camera scanning, real Health permissions/source data, Home Screen widgets/redaction, cold launches, and protected storage/backup behavior need device evidence. |
| 5 | Finish actual beta scope and data review. | COMPLIANCE.md contains open release gates; Stack calculator remains gated. Restaurant candidate/reuse review remains separate in `codex/restaurant-data-intake`. Hosted recovery email setup is pending per owner choice. Do not claim these dependencies are complete. |
| 6 | Prepare App Store Connect beta information and disclosures for the exact build. | Privacy/support contact and URLs, privacy answers, screenshots, review notes, and owner submission approval remain open. No account, provider, or store configuration changed here. |

The complete master brief includes additional unfinished P0 work. This checkpoint
does not redefine that scope or call the app production-ready. Signing and
uploading a build do not establish feature completeness or review clearance.

## Verification on this branch

| Check | Result and evidence |
|---|---|
| Baseline hardware Release archive | PASS — `/tmp/caliber-release-readiness-20261102.xcarchive`; log `/tmp/caliber-release-readiness-archive.log` ends ARCHIVE SUCCEEDED. Baseline has no root app privacy manifest. |
| Final hardware Release archive with manifest | PASS — `/tmp/caliber-release-readiness-manifest-20261102.xcarchive`; log `/tmp/caliber-release-readiness-manifest.log` ends ARCHIVE SUCCEEDED. This is unsigned compile evidence, not an installable beta. |
| Root privacy resource packaged | PASS — both audited required-reason entries are present in the final app bundle, separate from GRDB's resource bundle manifest. |
| Widget packaging and version | PASS — embedded extension exists, child identifier and build/version numbers match. |
| Archive checker tests | PASS — 8/8 covering missing root manifest, missing icon/executable, simulator target, mismatched extension, missing signing material, and complete compile-only packaging. |
| Static checks | PASS — Foundation lint, plist syntax check and git diff whitespace check. |
| Final packaging inspection | FAIL — 9/10 compile-only checks pass; the empty Home Screen icon catalog fails. Exact output is `evidence/release-readiness/unsigned-archive-check.json`. Default signing checks also remain unsatisfied by this deliberately unsigned archive. |
| Full UI, device, App Store validation | OPEN — no UI or physical-device tests rerun in this packaging-only batch; existing failed regression evidence is retained. |

The archive logs contain inherited Swift concurrency isolation warnings. A
successful archive is not a warning-free or Swift 6 migration claim.

## Commands

```sh
xcodebuild archive -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/caliber-release-readiness-manifest-20261102.xcarchive \
  -derivedDataPath /tmp/caliber-release-readiness-derived CODE_SIGNING_ALLOWED=NO
python3 -m unittest discover -s scripts -p 'test_check_release_archive.py' -v
python3 scripts/check_release_archive.py \
  /tmp/caliber-release-readiness-manifest-20261102.xcarchive --allow-unsigned
python3 scripts/lint_foundation.py
git diff --check
```

The archive checker reads built bundle metadata, required-reason entries,
primary-icon metadata, executable presence, and app/widget identity/version consistency. Without
`--allow-unsigned`, it additionally requires signature and provisioning files.
It only checks their presence: Xcode validation must verify their validity.
It does not assess privacy accuracy, nutrition accuracy, safety, UI behavior,
App Store eligibility, or all SDK obligations. It never signs or uploads.
