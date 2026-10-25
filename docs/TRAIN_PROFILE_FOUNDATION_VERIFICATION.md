# Train and Profile foundation verification — 2026-10-24

## Delivered slice

- Five primary tabs: Today, Diary, Train, Progress, Profile.
- Food Library route from Diary; Settings and Account & Sync routes from Profile.
- Additive local exercise, workout, workout-exercise, and workout-set SwiftData models.
- Original starter exercise list plus offline custom exercise creation/deletion.
- Empty-workout start, one active workout resume, exercise/set entry, RPE, warm-up flag, immediate confirmed-set save, undo, finish, summary, and history.
- Local profile fields and editable daily calorie/protein/carbohydrate/fat goals.
- Pure Mifflin–St Jeor starting estimate with explicit coefficient selection, activity factors, cut/maintain/lean-bulk/bulk/recomposition choices, and macro starting point.

## Acceptance evidence

| Check | Status | Evidence |
| --- | --- | --- |
| App compiles for an iOS Simulator | Pass | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` exited 0. |
| Mifflin golden vectors and activity factors | Pass | `EnergyTargetCalculatorTests` verifies both coefficients and a 1.55 activity factor. |
| Reject target below product floor | Pass | Focused test submits 900 kcal and expects the 1,200 kcal floor error. |
| Block deficit below BMI 18.5 | Pass | Focused test receives `deficitBlockedForLowBMI`. |
| Reject loss above 1% body weight/week | Pass | Focused test receives `lossRateAboveLimit` at 1.01%. |
| Confirmed set survives a fresh SwiftData context | Pass | `completedSetIsImmediatelyDurableAndWorkoutResumes` reloads the exact 225 lb × 5 @ 8.5 set. |
| Invalid set leaves saved values unchanged | Pass | `invalidSetDoesNotOverwriteSavedValues`. |
| Warm-up excluded from volume | Pass | Two 100 kg × 10 sets produce 1,000 kg-reps when one is a warm-up. |
| Profile calculation and local save UI flow | Pass | Focused iPhone 17 UI test entered age, height, and weight, saved the estimate, confirmed the alert, and found the saved-goal result. |
| Workout logging UI flow | Inconclusive | The dedicated Xcode 27 simulator clone stalled before finalizing a result bundle. The app built, while the logger's persistence, validation, and warm-up unit tests passed on the same simulator. |
| Existing account remains optional and local health data is not uploaded | Pass | Profile routes to the existing consent-gated account screen; gateway behavior is unchanged. |

## Limits

This is a foundation slice, so the affected backlog rows remain `partial-prototype`. The exercise catalog has 12 original weight × reps starter names rather than the required licensed 600+. All nine metric identifiers are modeled, but the library exposes only weight × reps until the other dedicated editors exist. Rename/merge, muscle/equipment filters, prior-performance copy, all set types, timers, routines, PRs, full history editing/export, charts, bodyweight attachment, clinician override, Katch–McArdle, adaptive targets, and clinical eligibility review remain open.

No hosted service, account policy, private upload, Supabase schema, restaurant source, or live GRDB cutover changed.
