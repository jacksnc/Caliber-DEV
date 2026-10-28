# Codex handoff

Status: goal setup and Claude visual changes integrated; native verification complete.
Branch: `codex/goal-setup-pass-2`, based on `96e8068`.

Four-step optional local setup reuses EnergyTargetCalculator. Explicit age,
measurements/units, equation/activity, goal/rate and optional target lead to an
editable final review. Only final Save changes profile targets; cancel does not
create health rows. Existing users enter through Profile. A new welcome can offer
setup once, after both confirmations. Hide-numbers mode is preserved.

Complete files, method, additive-schema behavior, exact commands and evidence:
[GOAL_SETUP_VERIFICATION](../../GOAL_SETUP_VERIFICATION.md). New
NutritionGoalSetup metadata is not yet included in legacy archive/canonical
adapters; full export/live cutover remain gated. Existing UserProfile fields and
calculator formulas are unchanged.

Verified locally: Foundation package (10 XCTest + 120 Swift Testing declarations,
two optional dataset skips), all native units (10 XCTest + 222 Swift Testing
declarations), static contracts, 130 Python tests, locale/unit/failure tests and
native save/reopen/cancel/validation/Profile compatibility. Graphite, Frost and
AX5 setup checks pass. First-welcome, theme/scanner/Progress and appearance-preview checks pass.
See [integration verification](INTEGRATION_VERIFICATION.md) for final runs and
remaining release gates.

Claude delivered `d956269`; its native code was explicitly UNTESTED in its Linux
environment. Codex reviewed, built and verified it on macOS, including integration fixes. Gemini's remote branch was
still at the seed base on the last fetch. No hosted/provider/food-license gate
was activated. Owner's local checkout edits remain untouched until backed up.
