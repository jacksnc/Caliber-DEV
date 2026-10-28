# Pass 2: coordinated implementation

The owner authorized a second visual pass and feature implementation on
2026-10-28, with Codex distributing work between Codex, Claude and Gemini.
The owner selected **separate GitHub branches/clones**. This is the first bounded
batch; the full recording review is not a request to build all 28 items at once.

## Starting point

Repository: `jacksnc/Caliber-DEV`. Start from remote branch
`codex/pass2-integration`, at the commit that introduces this coordination pack
(or the seeded agent branch). This combines native polish `955a91b`, recording
review `4f3400c`, and Claude's scanner/grammar fixes through `c9413af`.
`docs/AI_HANDOFF.md` identifies the historical base; its older phase statuses are
not current acceptance evidence.

```sh
git fetch origin
# In a separate clone, use YOUR assigned branch from the table below.
git switch --track origin/claude/visual-pass-2
```

Do not start from GitHub's default branch or edit the owner's local preview.
Each contributor pushes only its assigned branch. Codex alone updates the
integration branch; leave `astra/foundation` and peer branches untouched. Do not merge another stream into your branch mid-task. Codex integrates
reviewed commits; it owns final conflict resolution, common tests and local builds.

## Ownership and delivery

| Owner | Branch | First deliverable | Current dispatch status |
| --- | --- | --- | --- |
| Codex | `codex/goal-setup-pass-2` | Guided goal setup, safe persistence, Profile entry/summary, first-run routing and integration | Goal setup delivered; native integration verified |
| Claude Opus 5.5 | `claude/visual-pass-2` | Second visual pass for shared Helios components, Today and Progress; accessible theme previews/empty states | Delivered d956269; integrated and natively verified by Codex |
| Gemini 4 Argon | `gemini/food-entry-pass-2` | Faster food-entry hub and recent-food review using existing logging services | Remote branch still at seed on last fetch; awaiting food-entry handoff |

Codex cannot launch external Claude/Gemini chats from this environment. These
statuses describe assignments, not a claim that those external agents are running.
Read the role brief, then update only your role's handoff file when finished.

- [Codex brief](CODEX_TASK.md) · [Codex handoff](CODEX_HANDOFF.md)
- [Claude brief](CLAUDE_TASK.md) · [Claude handoff](CLAUDE_HANDOFF.md)
- [Gemini brief](GEMINI_TASK.md) · [Gemini handoff](GEMINI_HANDOFF.md)
- [Recording review](../../RECORDING_FEATURE_REVIEW.md)
- [Native reference and evidence](../../LOOKBOOK_ALIGNMENT.md)
- Committed visual reference: `design/lookbook/index.html`, `docs/DESIGN.md`,
  `docs/design/native-lookbook/`. Personal Downloads are not available in clones.

## File boundaries

| Area | Owner / rules |
| --- | --- |
| `Packages/HeliosDesign/`, `design/tokens.json`, generated design outputs | Claude. Preserve semantic color meanings and audited accessibility fallbacks. |
| `Views/Foundation/TodayFoundationView.swift`, `Views/Progress/`, `Views/Components/CaliberAppearance.swift`, `Views/Navigation/CaliberHeader.swift`, `CaliberTabBar.swift` | Claude; presentation only. Keep source calculations, callbacks and identifiers. Do not add water/Health/goal logic here yet. |
| `Views/Diary/FoodSearchView.swift`, `AddFoodView.swift`, `FoodNutritionReviewView.swift`, `Views/MyFoods/`, `Views/MyMeals/`, new food-entry components/view models | Gemini. Reuse existing behavior; preserve service/model contracts and stable identifiers. New batch logging is deferred from this first PR. |
| `Views/Diary/BarcodeScannerView.swift`, `BarcodeFoodLookupView.swift`, `LabelScannerView.swift`, `PhotoEstimateView.swift` | Freeze in batch 1. Gemini may link to these; report a blocking defect to Codex instead of restyling their internals concurrently. |
| `Views/Profile/`, new goal-setup views/services/models/tests, `App/FoundationRuntime.swift`, `Views/RootTabView.swift` | Codex. Other agents expose views through existing callbacks; do not change root routes or goal storage. |
| `Views/Foundation/FoundationSettingsView.swift`, `Views/Navigation/QuickLogSheet.swift` | Codex integration. Claude may deliver a new standalone theme-preview component and document its intended insertion. Gemini documents any future root/Quick Log hook. |
| Restaurant views/data/models, Stack, Train, hosted code, existing math engines | Freeze in batch 1; no new coverage, providers, estimates or flags. |
| `*.pbxproj`, shared schemas/archives, CI, `scripts/test_ios.py`, shared UI helpers | Codex integration only. Keep project format 77. |
| Shared planning docs (`AI_HANDOFF`, `BACKLOG`, `DECISIONS`, `CHANGELOG`, `MIGRATIONS`, `HOW_WE_CALCULATE`) | Codex aggregates from role handoffs to avoid three competing checkpoints. |
| New test files | Use role-specific names: `GoalSetup*`, `VisualPass2*`, `FoodEntryPass2*`; do not edit another stream's tests. |

Paths starting with `Views/`, `App/`, `Models/` or `Services/` are relative to
`Caliber (DEV)/`. If a necessary change crosses a boundary, record the exact
requested patch in your handoff; do not expand ownership silently. All work stays
native Swift/SwiftUI, iOS 17+, with existing package/service boundaries.

## Frozen behavior

- Existing `UserProfile` calorie/protein/carbs/fat properties remain the shared
  target read model. Codex owns any additive persistence; other streams read the
  same values. No reference food or menu edits from a personal food log.
- `FoodSearchView(mealType:date:)` remains the logging entry point; selected meal
  and date must reach every capture/review route. Ordinary results still open an
  editable portion/macronutrient review. Names, labels, dates and user values are
  never guessed. Keep typed-list, recent/frequent/favorite and restaurant paths.
- Preserve `openProfile`, `screenTitle-*`, `tab-*`, `quickLog-*`, `openFoodLibrary`,
  `openBarcode`, `openLabelScan`, `openPhotoEstimate`, `foodSearchManual`,
  `foodSearchScope`, `recent-*`, `frequent-*`, `favorite-*` and existing review IDs.
- Placeholder/unknown data must not look measured. Keep seven-day food charts
  labeled seven-day; do not connect them to an unrelated weight-only range.
- P1 stays behind existing flags; P2 remains deferred. No paid providers, accounts,
  hosted changes, store submission or menu imports in these streams. Keep FUEL-13
  off. Photo-estimate provider/evaluation gates remain unchanged.
- Keep calorie floors, rate/low-BMI guards, adult gate, hide-numbers mode,
  Stack opt-in/lock, privacy and provenance. Do not copy competitor assets or text.

## Definition of done and integration

Each stream returns a commit/PR, owned-file list, behavior changes, screenshots
(Graphite/Frost and largest text when native tooling is available), tests with
exact commands/results, migrations and limitations in its handoff. No TODO/stub
on the delivered path. If native execution is unavailable, label it **UNTESTED**
and provide exact commands; a Linux syntax check is not an iOS build.

Codex reviews and integrates in this order: shared visual components → goal setup
→ food-entry stream → route/test integration. It runs package/static checks,
native logging/goal flows, theme/accessibility checks and a diff/privacy review.
Only Codex refreshes the owner's local preview, preserving their edits/data.

Next batch after this integration: shared date strip, manual hydration, progress
detail, then consented Health integration. Adaptive coaching, micronutrients,
meal planning and social features remain separate, gated work.
