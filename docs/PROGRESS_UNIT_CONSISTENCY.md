# Progress weight-unit consistency

Claude's independent cards/widgets review found that the check-in form wrote
only progressWeightUnit, Progress read that key, and Today/Settings used the
separate FoundationSettings.massUnit. Any unrelated Settings save mirrored its
older unit back into progressWeightUnit. A person could save kg in Progress,
see lb on Today and lose the kg preference after changing the theme.

This branch reads FoundationSettings.massUnit across Progress form, chart,
timeline detail and Today. The form's selected unit remains a draft until a
successful check-in save. Cancel and failed saves do not change the preference.
Number-free note/photo saves do not change units. The original pounds-based
storage and conversion functions are untouched; there is no weight-data
migration or numerical rescaling.

On the first launch of this version, a valid legacy progressWeightUnit choice is
adopted once into FoundationSettings. Every older Settings save also mirrored
that legacy key, so a different valid legacy value indicates a later Progress
choice. Invalid strings do not override the canonical preference. The private
progress.weightUnit.unified.v1 marker prevents later stale legacy writes from
taking authority back. Other settings are preserved. Runtime still maintains
the old key as a compatibility mirror; no screen treats it as authoritative.

Worktree: /Users/jcrock/Documents/Codex/Caliber-progress-units
Branch: codex/progress-unit-consistency, from c8d24c0.
The owner local preview and installed personal build remain unchanged.

Verification commands:

```sh
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,id=2998CE67-7D71-460B-AD69-76DAA4D014F6' \
  -derivedDataPath /tmp/caliber-progress-units-derived -parallel-testing-enabled NO \
  '-only-testing:Caliber (DEV)Tests/ProgressUnitPreferenceMigrationTests' \
  '-only-testing:Caliber (DEV)UITests/ProgressUnitConsistencyUITests' CODE_SIGNING_ALLOWED=NO
```

The focused migration tests cover adoption/round-trip/one-time behavior and
invalid legacy values while preserving privacy/locale settings. UI checks cover
saving kg, matching the Today/Progress labels, an unrelated Settings theme save, retained unit on
relaunch, and a canceled unit draft. Native run status is recorded in AI_HANDOFF.

## Verification report

- PASS: 2 migration persistence tests (adoption/round-trip/one-time and invalid
  input), `/tmp/caliber-progress-units-final.xcresult`.
- PASS: canceled unit draft leaves the preference unchanged (same run).
- PASS: saved kg agrees on Progress/Today, survives the independent theme save
  and remains selected in a new form after app relaunch,
  `/tmp/caliber-progress-units-verified.xcresult` (**TEST SUCCEEDED**, exit 0).
- PASS: strict Foundation formatting, strict Dynamic Type lint (235 files),
  clean diff; app and embedded widget extension compile in native test builds.
- SOURCE: Settings and detail screens bind to that same authoritative value;
  no native VoiceOver Picker-value assertion is claimed.
- PRESERVED: stored pounds/conversion functions, owner local preview's three
  dirty files, personal simulator/store and real provider/Health/share settings.

The first UI probe queried an offscreen picker and then assumed its native
`value` was the selected unit; SwiftUI exposes an empty value for that button.
A later menu query matched both the menu option and the existing appearance
preview card. These harness failures are preserved in earlier xcresults; the
final test uses the stable appearanceTheme-dark ID and verifies the actual
cross-screen/relaunch behavior that regressed. Optional verbose simulator
sysdiagnose collection hung after earlier runs; final commands use documented
`-collect-test-diagnostics never` and retain ordinary test output/xcresults.

Native Mac app controls are independently unavailable: the service still reports
locked after the owner reported Unlocked. No security settings were weakened or
lock bypass attempted. Widget gallery/hardware work remains pending this access.
