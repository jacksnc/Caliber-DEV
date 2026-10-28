# Guided goal setup — pass 2

## Plan

1. Reuse the tested starting-energy engine and existing guards.
2. Collect explicit age, measurements, equation, activity and goal.
3. Review editable targets before one local save.
4. Preserve profiles, cancellation, units and hide-numbers behavior.
5. Test math, locale, persistence and accessible native flows.
6. Integrate separate visual/food branches after their handoffs.

## Complete source files

```text
Packages/CaliberFoundation/
  Sources/CaliberCore/{GoalSetupPlan,NumericInputText,EnergyTargetCalculator}.swift
  Tests/CaliberCoreTests/GoalSetupPlanTests.swift
Caliber (DEV)/
  Models/NutritionGoalSetup.swift
  Services/GoalSetupEditor.swift
  ViewModels/GoalSetupDraft.swift
  Views/Profile/GoalSetup/{GoalSetupView,GoalSetupHostView,GoalSetupSummary}.swift
  Views/Profile/ProfileView.swift
  App/FoundationRuntime.swift
Caliber (DEV)Tests/GoalSetupPersistenceTests.swift
Caliber (DEV)UITests/{GoalSetupUITests,TrainProfileUITests}.swift
scripts/{lint_foundation.py,test_ios.py}
```

Complete implementations are in Git; no provider or placeholder save is used.

## Behavior and migrations

Four steps collect measurements, equation/activity, goal/rate/optional target,
then review. Only **Save goals** writes. **Set up later** discards the draft;
entering a weight does not create a Progress weigh-in. Existing users open
Profile → Set up nutrition goals. A fresh adult/scope welcome may offer setup
once. The prompt preference uses the runtime's own preference store; tests use a
separate suite and in-memory health store.

`NutritionGoalSetup` is an additive SwiftData entity keyed to the unchanged
`UserProfile` ID. Versioned JSON retains explicit inputs, target/reference weight,
reviewed targets and edited status. One save updates it and the seven existing
profile fields. Failure restores only affected records, preserving unrelated
in-flight edits. Unsupported/corrupt setup cannot silently overwrite goals.

No store locator, hosted schema or existing profile property changes. A disposable
on-disk old-profile → additive-schema test preserves ID and exact targets. This
is not proof of every historical iOS store migration. The older 15-model archive
and normalized rehearsal **do not include NutritionGoalSetup**: daily profile
targets remain represented, but guided input/target metadata do not. Extend and
verify portability before full export or live canonical-store cutover. Neither
is activated here. See [MIGRATIONS](MIGRATIONS.md).

## Method

See [HOW_WE_CALCULATE](HOW_WE_CALCULATE.md). Reuses Mifflin–St Jeor and one
explicit activity factor. Existing age/rate/BMI/calorie-floor rules apply;
clinical suitability and screening remain release gates. Finite nonnegative
manual macros remain independent of macro-energy equality.

An optional new loss target must be below its reference weight and not below
BMI 18.5; gain must be above it. A reached target retains its original reference
when daily goals change. Changing goal clears the old target. No finish date,
adaptive prescription, Health access or cloud health upload is introduced.
Canonical kg/cm caches prevent repeated conversion drift. Editable numbers use
locale decimals without grouping or scientific notation and retain Double
precision; display rounding remains separate.

## Verification evidence

Local checks use fictional inputs on the iOS 27.1 simulator. Foundation package:
10 XCTest cases and 120 Swift Testing declarations pass, with two optional full
dataset skips. Existing golden energy vectors remain green. Full native unit
suite: 10 XCTest cases and 222 Swift Testing declarations pass. New persistence
checks cover additive disk schema, exact reopen, save/create failure isolation,
three numeric locales, unit changes and maintenance-to-cut rate defaults.

UI checks pass for first-run/skip, explicit age/equation validation, save/reopen/
cancel, existing Profile calculation, Graphite/Frost and largest text. See
[pass 2 integration evidence](parallel/pass2/INTEGRATION_VERIFICATION.md) and
[native goal captures](design/goal-setup/). Early checks
exposed placeholder clipping, a test tap under a footer, propagated identifiers
and first-run preference isolation; these were corrected without audit suppression.

## Run commands

```sh
python3 scripts/lint_foundation.py
python3 scripts/verify_phase1.py
python3 -m unittest discover -s scripts -p 'test_*.py'
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-goalsetup-foundation
python3 scripts/test_ios.py --output /tmp/caliber-goal-setup-checks --unit-only
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,name=Caliber Lookbook QA' \
  -parallel-testing-enabled NO \
  '-only-testing:Caliber (DEV)UITests/GoalSetupUITests' \
  '-only-testing:Caliber (DEV)UITests/TrainProfileUITests/testProfileCalculatesAndSavesLocalGoals' \
  CODE_SIGNING_ALLOWED=NO
```

Full FUEL-20/BODY-07, clinical screening, protected export and physical-device/
minimum-iOS execution are not certified by this slice. Next: integrate the peer
visual/food changes and verify combined flows.
