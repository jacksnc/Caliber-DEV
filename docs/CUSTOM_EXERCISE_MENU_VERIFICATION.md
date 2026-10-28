# Custom exercise shortcut and restaurant menu format — 2026-10-27

Branch: `codex/workout-engine`, following the green `23db8f2` engine commit.
Claude keeps ownership of colors and general screen design on `astra/foundation`.
Only the exercise picker/creation route is changed for the owner's explicit
manual-exercise request. No workout grid, theme, navigation shell, official menu
resource, feature flag or hosted service is changed.

## Plan

1. Reuse one custom-exercise form from the library and workout picker.
2. Offer creation directly when a search has no match and prefill the name.
3. Save before selection; preserve Cancel and reject accidental duplicate names.
4. Add a ten-column restaurant CSV and one source-metadata document.
5. Reuse existing strict restaurant source/nutrition validation and atomic output.
6. Test create/log/reuse, Cancel, invalid rows and importer compatibility.

## Files and migrations

```text
Caliber (DEV)/
  Services/CustomExerciseEditor.swift
  Views/Train/CustomExerciseView.swift
  Views/Train/ExerciseLibraryView.swift
  Views/Train/ActiveWorkoutView.swift
  Resources/CustomExercises.xcstrings
Caliber (DEV)Tests/CustomExerciseEditorTests.swift
Caliber (DEV)UITests/CustomExerciseUITests.swift
scripts/prepare_restaurant_menu_csv.py
scripts/test_prepare_restaurant_menu_csv.py
docs/RESTAURANT_MENU_TEMPLATE.md
docs/templates/restaurant-menu/
  menu-template.csv
  menu-example.csv
  metadata-example.json
```

Complete files are saved in the repository. No private model/schema migration,
new nutrition estimate, live data import, hosted configuration or API key is
needed. The custom form uses the current weight × reps editor. The other eight
metric input controls remain a separate integration task; the new form does not
offer a logging style that the current screen cannot edit.

## Verification report

| Acceptance | Result | Evidence |
| --- | --- | --- |
| Create missing exercise from search and immediately log a set | Pass | CustomExerciseUITests: both flows pass |
| Exercise also appears in the library for later workouts | Pass | Native UI route and saved-row test |
| Cancel writes nothing; blank Save is disabled | Pass | UI Cancel test and service validation |
| Duplicate name cannot overwrite seeded/custom exercise | Pass | Case/spacing/accent/width service tests |
| Menu CSV supports all five app categories with exact source values | Pass | 12 Python tests and existing-importer round-trip |
| Missing nutrition rejected; explicit zero and unknown mass differ | Pass | CSV numeric tests |
| Malformed/duplicate/foreign rows and headers fail without output loss | Pass | CSV and CLI tests |
| Fictional data stays gated; production source rules are reused | Pass | Fixture/source validation tests |
| Build, relevant package/native tests, formatting and typography | Pass | 225 native unit tests, two UI flows, 130 Python tests, 11 reader tests, strict lint and typography |
| Full metric controls, physical device/minimum OS, menu production rights | Open | Separate work; no completion claim |

## Run commands

```sh
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict 'Caliber (DEV)' Packages
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-workout-swift --filter restaurantMenu
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,id=AC180DB6-5769-4269-9D6C-1C2B5393DEBB' \
  -derivedDataPath /tmp/caliber-workout-build \
  -resultBundlePath /tmp/caliber-custom-exercise3.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  '-only-testing:Caliber (DEV)Tests' \
  '-only-testing:Caliber (DEV)UITests/CustomExerciseUITests' CODE_SIGNING_ALLOWED=NO
```

Use an available disposable simulator and a fresh result path. Exact evidence is
recorded under `docs/evidence/custom-exercise-menu/`. Local toolchain is Xcode
27.1, iPhone 17 simulator, iOS 27.0. No new chart is introduced. This is not full
Phase 2, accessibility, release, coverage or device-performance certification.

## Owner route

Train → Start/Resume Workout → Add Exercise → search → Create Custom Exercise →
Save. The search name is prefilled, and the saved exercise is added to the
workout. It also remains available under Train → Exercises. The library's existing
Add Exercise action uses the same form. Unused custom exercises retain their
existing swipe-to-delete action; seeded exercise rows remain protected.

Restaurant maintainers use `RESTAURANT_MENU_TEMPLATE.md`; the complete runnable
example has software-test foods only. A permitted current menu source remains
required before production coverage can be enabled.

The native unit run is in `/tmp/caliber-custom-exercise2.xcresult` (10 XCTest +
215 Swift Testing functions). Both custom UI flows passed after making library
search persistently visible and searching to reveal the lazily rendered new row.
The earlier UI assertion failures and missing test import were corrected before
publication. No app data or feature flags were reset.
