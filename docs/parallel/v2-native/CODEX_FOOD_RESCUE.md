# Gemini native food handoff - coordinator rescue

Gemini 4 Argon High completed an uncommitted seven-file diff on the owner's Mac
in gemini/v2-native-food, based on a07ceb9. Its native chat then reported baseline
quota exhausted. No overages, purchase, model-provider or privacy setting was
changed. The original clone remains untouched.

Codex reviewed the full diff, obtained a separate read-only source review, and
ported it through /tmp/caliber-gemini-v2-native-rescue.patch into the native
integration branch. This is a source rescue, not a published Gemini commit.

## Preserved contribution

- Opaque Graphite/Frost hub, tiles, rows and nutrition review.
- Explicit meal-slot buttons; every existing route receives selected meal/date.
- Centered reported calories, editable portion and macro override/reset.
- Independent source/library snapshots and save/cancel guards retained.
- Larger input targets and AX review actions in a bottom inset.
- Existing scoped food tests plus meal switching and reported-energy checks.

No schema, services, food datasets, health engines, flags or providers changed.

## Coordinator corrections after review

- Removed a new per-100-g calorie figure beside typed list portions, because the
  phrase can mean a different mass. Exact nutrition remains in resolved review.
- At large sizes, stack row quick actions below the label so long names retain
  full reading width. Stack macro tiles explicitly at these sizes as well.
- Test scrolling treats zero-size evicted elements as absent.

## Evidence and remaining work

Gemini's latest result /tmp/caliber-gemini-v2-native/FoodPass2UI.xcresult:
4 passed, 1 failed (AX5 manual action could not be revealed after quick review),
plus four invalid-frame runtime warnings. This is not a green suite. Its earlier
228-unit-case report is peer evidence only. Codex combined native build/unit
result passes 243 cases in /tmp/caliber-v2-combined-unit.xcresult; updated layout
and UI checks continue in /tmp/caliber-v2-combined-food.xcresult.

Inspect actual native captures and failures, complete scoped regressions, then
commit reviewed code. Keep all UI work on Codex QA and leave the original Gemini
QA and owner devices alone. See SESSION.md for current outcome.

Original rescue patch SHA-256: `f75e44e0a3ffd803a11b45b86cf5eb5636363d14f9f63abfa491f33e91642763`.

Combined functional cases pass 4/4; final AX audit rerun is pending after fixing
its stale-frame scrolling direction. The invalid-frame warning reproduces on
unchanged a07ceb9 app sources; baseline-keyboard-summary.json records it.
