# Responsive V2 verification

## Scope and files

Codex worktree Caliber-v2-responsive, branch codex/v2-responsive, native base
ab5320b. Complete sources are checked into the repository:

```text
Caliber (DEV)/Views/Components/CaliberAppearance.swift
Caliber (DEV)/Views/Navigation/CaliberTabBar.swift
Caliber (DEV)/Views/Diary/FoodEntryPass2Components.swift
Caliber (DEV)/Views/Train/ActiveWorkoutView.swift
Caliber (DEV)UITests/ResponsiveLayoutUITests.swift
scripts/lint_foundation.py
docs/evidence/v2-responsive/
docs/parallel/v2-responsive/
```

The presentation uses a centered content column up to720pt and navigation up
to680pt. Narrow windows use available width; fonts keep their full Dynamic Type
range. The food-review backdrop spans the window, with controls aligned to the
reading column. No model, migration, formula, catalog, provider or privacy change.

## Results

| Acceptance | Status | Evidence |
| --- | --- | --- |
| Build + iPad Frost main routes and inherited clipping audits | PASS1/1 | tablet-frost-default-summary.json; eight exported captures visually reviewed as contact sheet |
| Theme package tests | PASS48/48 | helios-tests.log |
| iPad Graphite routes and inherited clipping audits | PASS | tablet-confirmed-summary.json,5/5combined responsive/Graphite cases |
| Correct full-screen landscape captures | PASS2/2 on each device | tablet-fullscreen-summary.json and compact-fullscreen-summary.json; old cropped app captures excluded |
| Foundation formatting and full strict scaling lint | PASS | lint_foundation.py;224files0errors/warnings |
| Portrait/landscape centered bounds and navigation targets | PASS | All five main routes on375pt phone and820/1180pt tablet; centered720pt/680pt bounds and48pt targets |
| Keyboard rotation preserves meal/query/portion and saves once | PASS | Both devices;0.75portion,150.375calorie review,250.625exact diary total, modal gone and navigation usable |
| Large-text fractional workout drafts survive rotation/collapse | PASS | Both devices atXXXL andAX5; same set retains42.75weight and11reps; compactXXXL changes layout width |
| Compact phone rotation | PASS4distinct cases | compact-fullscreen-summary.json passes main/food; compact-xxxl-confirmed-summary.json and compact-ax-confirmed-summary.json pass draft cases |
| Real iPad split windows, minimum-iOS/physical device/foldable | PENDING | not inferred from orientation or HTML studies |
| Independent full-app Frost beta and graphics/widgets | PENDING | next separate batch |

Devices: Caliber Compact QA2998CE67-7D71-460B-AD69-76DAA4D014F6,
iPhoneSE3/iOS27.0,375pt portrait and667pt landscape; Caliber Tablet QA B02CFF79-2810-4011-B8CF-72F205F5ACC5,
iPad Air11 M4, iOS27.0 simulator,820/1180pt. Compiler Xcode27.1, app deployment target17.
No owner preview installation or personal simulator/data use.

## Retained failures and limits

The first new rotation run failed3/3 because of test assumptions: a hidden
navigation bar was read without checking existence; Today/Stack ScrollViews
were assumed to be Lists; a shared text replacement helper left a trailing
character because it tapped the middle of the wide field. The new helper now
selects a visible scroll container, drags inside its bounds, guards hidden bars,
places the caret at the end and verifies the typed input before rotating.
Original failure summary is retained as tablet-rotation-initial-summary.json.
The compact AX5 helper later needed gutter-based drags and a known heading
before finding an evicted set; both original failing results remain recorded.

Second-run food rotation/save passed. The other two checks needed header-owned
container measurement (a List itself need not be hittable) and an explicit return
to the top after a lazy header was evicted. The next enumerated-container attempt
was interrupted after an index vanished during navigation; live queries replace
enumerated handles. Stable UUID/field identifiers now track the same workout set.
Subsequent concurrent cold starts stalled in simulator dyld before app code;
their interrupted runs are not passes. SESSION records the sequential retry.

The existing Invalid frame dimension warning is retained. The native checkpoint
reproduced it on unchanged a07ceb9; this phase does not claim a warning-free app.
The native deep-scrolled Form system-audit identity limitation remains
INCONCLUSIVE, distinct from passing measured growth/bounds/capture checks.
Read ../v2-native/VERIFICATION.md; no inherited audit is filtered or suppressed.

## Reproduce

```sh
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict
swift test --package-path Packages/HeliosDesign
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' -destination 'platform=iOS Simulator,id=B02CFF79-2810-4011-B8CF-72F205F5ACC5' -derivedDataPath /tmp/caliber-v2-responsive-derived -parallel-testing-enabled NO -collect-test-diagnostics never '-only-testing:Caliber (DEV)UITests/ResponsiveLayoutUITests'
```

Use only the explicitly owned QA destination, never an arbitrary booted device.
Do not run concurrently against a device another role is using.

## Visual evidence

Application-only rotated screenshots exported cropped black areas; they were
not approved as visual evidence. The capture helper now uses the full owned
simulator screen. Capture reruns pass2/2 per device; full Diary/review landscape
images were inspected with all edges visible. Correct orientation metadata is
normalized by a lossless90-degree transpose only, without cropping, repair or
content changes. Selected images live in output/screenshots/v2-responsive; full
raw bundles and unapproved exports remain in /tmp at the paths in SESSION.

This verifies the stated native layouts and behaviors, not every device, window
size, accessibility certification, release readiness or the full P0 feature set.
Next: actual iPad window resizing, then independent Frost beta.
