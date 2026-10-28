# Workout engine handoff — 2026-10-27

## Ownership and branch

Codex owns `codex/workout-engine`, based on `116d46a` from `astra/foundation`.
The checkout is `/Users/jcrock/Documents/Codex/Caliber-workout-engine`.
Claude continues visual work on `astra/foundation`. The initial engine commit changes no screen, theme, navigation, token, catalog,
hosted service or account setting. The owner subsequently requested a manual
exercise shortcut; that follow-up touches the picker and shared creation form
only and is documented in CUSTOM_EXERCISE_MENU_VERIFICATION.md.
Integrate this branch after its checks; do not replace Claude's screen files.

## Plan

1. Preserve the existing workout editor API and historical values.
2. Validate all nine metric types in pure, tested values.
3. Save metric, effort, body-weight and set-kind snapshots.
4. Provide previous-performance and copy/edit/order commands.
5. Persist rest deadlines independently from UI redraws.
6. Verify disk reopen and the former SwiftData model shapes.
7. Leave screen controls and OS timer presentation for coordinated integration.

## Files

```text
Packages/CaliberFoundation/
  Sources/CaliberCore/Training/
    WorkoutSetMetrics.swift
    WorkoutRestTimer.swift
  Tests/CaliberCoreTests/Training/
    WorkoutSetMetricsTests.swift
    WorkoutRestTimerTests.swift
Caliber (DEV)/
  Models/TrainingExercise.swift
  Models/TrainingWorkout.swift
  Services/TrainingWorkoutLogger.swift
  Services/TrainingWorkoutHistory.swift
  Services/TrainingWorkoutRestTimer.swift
  Resources/WorkoutEngine.xcstrings
Caliber (DEV)Tests/
  WorkoutEnginePersistenceTests.swift
  WorkoutLegacyMigrationTests.swift
Caliber (DEV)UITests/TrainProfileUITests.swift
scripts/lint_foundation.py
```

Complete implementations are in those files. The existing `TrainingWorkoutLogger`
weight/reps completion signature stays available. Optional model columns are the
only live-schema change; see `MIGRATIONS.md`. No canonical GRDB or hosted migration
is executed. Training remains outside the old 15-model archive/export rehearsal.

## Screen integration contract

Import `CaliberCore`. Read `row.metric.usesWeight`, `.usesRepetitions`,
`.usesBodyweight`, `.usesDuration`, and `.usesDistance` to choose fields.
Construct `WorkoutSetDraft` and call:

```swift
try TrainingWorkoutLogger.complete(
  set, draft: draft, locale: locale, in: modelContext,
  restSeconds: chosenRestSeconds)
```

The draft uses seconds, positive distances, the person's chosen mass/distance
unit, exactly one effort scale, set kind and optional counting overrides.
Non-applicable fields are ignored and cleared on save. `.side` labels a side;
it does not silently double load or tonnage. Custom kinds require a name.
Validation errors use the separate English `WorkoutEngine` localization table.
Rest is optional until configured; there is no inferred compound/isolation
classification or new notification permission prompt.

Bodyweight metrics capture the latest positive finite weigh-in at/before the
set time (deterministic ID tie-break). No reading means a visible validation
error, never assumed zero. Edits retain the captured reading unless an explicit
replacement is supplied. Assistance above body weight fails. Editing the source
weigh-in or exercise definition cannot rewrite an existing captured set.

`TrainingWorkoutHistory.previousSets(for:in:)` selects the latest finished
workout before this one, with matching exercise, gym and metric. Nil gym is its
own scope. `copyPrevious(to:in:)` uses the target's current ordered index; no
formatted label is parsed. Show source units or convert from canonical values
when displaying a previous result. The service does not invent gym profiles.

`copyLastSet`, `copy`, `fillRemaining`, `duplicate`, `reorder`, and `delete` are
saved commands. Copies carry entered targets, type, side, counting choices and
planned rest; they clear effort, captured body weight and actual rest. Duplicates
have fresh IDs and are open. They never add a completed set. Reordering requires
a permutation of every set ID; deleting renumbers remaining sets. Use these
commands in the screen instead of direct deletion so timer cleanup occurs.

`TrainingWorkoutRestTimer.state(for:)` restores a `WorkoutRestTimer`. Render
`remaining(at: Date())`; stop using a decrementing counter. `adjust(by:)` accepts
±15 seconds, and `skip` stops the target. The screen/OS adapter must cancel or
reschedule its notification after each command. **This branch does not schedule
notifications, Live Activities, sound, voice or haptics.**

Actual rest requires calling `beginNextSet` when the next set starts. Expiring a
target or completing the next set does not establish actual rest. Skipping does
not invent a measured interval. Undo/delete of the owning set and finish clear
the active timer. Editing a completed set does not restart it.

Commands expect a context without unrelated pending edits: their save failure
rolls the context back. Validation/encoding runs before mutating saved values.
No background callback or view writes to the context through these engines.

## Imported TrainingCore review

The imported package remains unlinked. Its `VolumeEngine` has useful muscle
attribution policies, but expects resolved load and lacks these input/persistence
boundaries. This slice reuses existing `MassUnit` and `QuantityParsing` in
CaliberCore and supplies those missing boundaries without adding muscle stats.

`OneRepMax` returns the entered load for one rep, whereas decision M01 says use
the written formulas even at one rep. It clamps out-of-range RPE instead of
rejecting it and permits nonfinite weight inputs. Its three additional formulas
still need the pinned source review required by M01. `PRPolicy.countedKinds`
can also re-enable warm-ups, conflicting with M02's unconditional PR exclusion.
Do not wire e1RM/PR results into the UI until these are reconciled and tested.
This branch chooses no new e1RM formula and does not change those imported APIs.

## Verification

Results and exact commands are in `WORKOUT_ENGINE_VERIFICATION.md`.
The nine-metric input/model/service foundation is the deliverable. Full TRN-03,
11, 12, 13, 19 and 30 remain partial until controls, visual/a11y checks, OS timer
integration and physical-device verification land. No new chart is implemented.

Next: Claude can connect the metric-specific fields, previous-set copy action,
set-type picker, duplicate/delete actions and timer controls to these APIs, then
run the combined native UI and accessibility suites. Keep this engine branch
separate until that integration is ready.
