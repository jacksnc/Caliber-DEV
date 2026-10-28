# Workout engine verification — 2026-10-27

Scope: service/model foundation on `codex/workout-engine`, base `116d46a`.
See `WORKOUT_ENGINE_HANDOFF.md` for complete-file locations and integration APIs.

## Acceptance report

| Criterion | Result | Evidence |
| --- | --- | --- |
| Nine metric types validate required fields and canonical dimensions | Pass | WorkoutSetMetricsTests |
| Original entered mass/distance retained; source units are explicit | Pass | Unit factors and locale tests; disk-store test |
| BW/weighted/assisted volume uses captured reading; future readings excluded | Pass | All-metric and source-edit persistence tests |
| Invalid values fail before saved set/timer mutation | Pass | Validation, effort, overflow, native invalid-input tests |
| Warm-up defaults exclude volume/hard sets/PRs; independent overrides | Pass | Kind tests; legacy warm-up toggle regression |
| Copies/duplicates never complete new sets or carry effort/BW/rest observations | Pass | Native copy, repeat and source-edit tests |
| Previous lookup respects finished time, gym, exercise, metric | Pass | Native history test |
| Reorder/delete preserve saved order and recompute live volume | Pass | Native copy/edit test |
| Deadlines survive JSON round-trip and disk close/reopen | Pass | Pure timer and native disk tests |
| Explicit next-set start records actual rest; skip never fabricates it | Pass | Pure and native timer tests |
| Old workout model store opens with original values/relationships intact | Pass | WorkoutLegacyMigrationTests disposable disk fixture |
| App compiles and relevant native tests pass | Pass | 10 XCTest + 212 Swift Testing tests; existing workout save/history UI flow |
| Foundation package suite and strict formatting pass | Pass | 10 XCTest + 113 Swift Testing tests reported; two optional full-source dataset measurements skipped; lint log |
| Screen fields, notifications/Live Activity, physical-device and minimum-OS checks | Not delivered | Coordinated follow-up; full requirements remain partial |

## Commands

Run from this branch's checkout. Use a disposable simulator, replacing the UDID
below with one listed by `xcrun simctl list devices available`.

```sh
python3 scripts/lint_foundation.py
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-workout-swift
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,id=39AB59DC-9E44-4B9B-98AF-9EBC781B9541' \
  -derivedDataPath /tmp/caliber-workout-build \
  -resultBundlePath /tmp/caliber-workout-ready.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  '-only-testing:Caliber (DEV)Tests' \
  '-only-testing:Caliber (DEV)UITests/TrainProfileUITests/testWorkoutSetSavesAndFinishedWorkoutAppearsInHistory' \
  CODE_SIGNING_ALLOWED=NO
git diff --check
```

Use a fresh result-bundle path for a repeat run. Local toolchain: Xcode 27.1,
iPhone 17 simulator running iOS 27.0. This is not minimum-iOS execution or a
physical-device performance measurement. No new charts require image baselines
in this slice, and no full Phase 2 acceptance/coverage/budget claim is made.

## Evidence and review

`docs/evidence/workout-engine/results.json` and compact logs record the executed
checks. Full local Xcode result: `/tmp/caliber-workout-ready.xcresult`; full
package log: `/tmp/caliber-workout-package-complete.log`. The two dataset skips
require optional full-source files; they are not failures of the new metric or
timer tests. Contract/migration fixtures and `git diff --check` pass.

The native full suite can emit the existing `ProgressPersistence` fixture's
SQLite open-file cleanup warning. The new workout fixtures no longer unlink
open SwiftData stores; their synthetic temp files live until the test host/QA
simulator is removed. Xcode also reports SDK metadata warnings. No warning-free
runtime, 100% branch coverage, physical-device timing or whole-app accessibility
claim is made. The existing workout UI assertion now checks the saved-set button
because Claude's grid exposes weight and reps as separate cells.

Source review checked the complete model/service/pure-engine diff and §11
boundaries: no network/provider activation, health telemetry, Stack capture,
new data source, dietary/dose recommendation, or estimate was added. New errors
use a separate English `WorkoutEngine.xcstrings` table; translation review is
still future work. GitHub CI status is tracked separately from local evidence.

## Migrations and limits

All new SwiftData properties are optional with nil defaults. Legacy completed
rows retain the original weight × reps interpretation until explicitly edited;
no inferred BW/duration data is backfilled. The old-store fixture uses exact
pre-engine model shapes and a fresh disposable SQLite destination. No personal
store, source archive, GRDB locator, Supabase schema or hosted setting is changed
by the migration test. The original 15-model export rehearsal still excludes
training; full protected portability and canonical revision storage remain open.

Rest deadline range is >0 to 24 hours; adjustments may shorten a target to zero.
These are configurable timer bounds, not training recommendations. Absolute dates
survive process loss; a manual system-clock change can change wall-clock remaining
time. Locked-screen alert delivery and Live Activities require their own adapter
and device tests. Unmeasured actual rest stays nil.
