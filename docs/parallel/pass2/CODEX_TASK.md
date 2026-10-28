# Codex assignment — goal setup and integration

Work on `codex/goal-setup-pass-2` from the seeded common base. Own the coordinator
role and files specified in [README](README.md).

Deliver a short native guided setup that reuses `EnergyTargetCalculator`: explicit
adult age and equation choice, measurements/units, activity, goal/rate, optional
target weight and an editable final calorie/macro review. Persist only on final
confirmation in protected local model storage; skip/cancel must not create goals,
weigh-ins or diary logs. Existing users must not have targets overwritten or be
forced through a new setup. Existing Profile remains reachable with editable goals.

Provide additive persistence tests, locale/unit/validation checks, cancel/save/
reopen UI flows and the existing golden calculation tests. Preserve calorie
floors, low-BMI and rate limits, hide-numbers mode and the existing adult/scope
gate. No new adaptive targets, projected finish date, diet presets, provider or
cloud feature in this slice. Document any new model's archive/restore limitations
and migration behavior honestly; do not change the live store locator.

Integrate external branches deliberately after their handoffs; retain each
owner's tested behavior. Run common native/theme checks and update shared docs,
then refresh the owner's local preview after a data/edit backup.
