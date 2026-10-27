# Caliber AI handoff

This file is the shared checkpoint for work across Codex and Claude. The Git
checkout and its commits are the source of truth; neither assistant inherits the
other's chat automatically, and there is no automatic credit-exhaustion trigger.

## Project state

- Repository: `Caliber (DEV)` inside the `Caliber (DEV) - Project` folder.
- Active branch: `astra/foundation` in the main project checkout. The existing
  app history through `2db865d` was pushed and independently verified on GitHub
  on 2026-10-26. Xcode now has the owner's repository-scoped GitHub account.
- Current slice: native Graphite/Frost integration, imported selectively from
  Claude commit `d017a1aaecbad29372bb93ead3ac98cabec153fa`. See
  `docs/THEME_INTEGRATION_VERIFICATION.md` for evidence and remaining limits.
  Local validation includes 14 user-flow tests, four theme/text-growth tests,
  a two-test final scanner/Frost rerun, package/unit suites and 115 Python tests.
  The default-size automatic Dynamic Type audit remains an explicit open item;
  do not claim full accessibility/device certification.
- The first GitHub iOS job rejected project format 110 before compiling. This
  slice aligns serialization with Xcode 16 format 77 and the pinned CI toolchain.
  A second run reached compilation and found three ambiguous dynamic-title
  Section initializers; explicit Text headers address that older-compiler issue.
  The third run still failed in `RestaurantDetailView.swift` (ChartContentBuilder
  error at the inner ForEach). The real cause was the theme slice wrapping the
  whole list in one `Group` so one `.listRowBackground` covers it: Xcode 16.4
  could not type-check that single builder and fell back to a Charts overload.
  Claude split the list into five `@ViewBuilder` properties inside the same
  `Group`; behaviour is unchanged. Only a Linux syntax parse and swift-format
  lint were run on it; GitHub's macOS job is the first real compile.
  That guess was incomplete: runs 6 and 7 still failed at the same inner ForEach
  after the split and after the rows became their own views. The menu sections
  now use a named `RestaurantMenuGroup` instead of a tuple, a separate section
  view, and rows keyed by `persistentModelID` with an explicit closure type,
  because `MenuItem` declares its own `id` beside the one SwiftData supplies.
  Run 8 (`55ffdfd`) compiled the app on Xcode 16.4 for the first time. All unit
  tests passed; 9 of 13 UI tests failed on the iOS 18.5 simulator. Five could not
  find Settings (the last row of Profile's lazy list was never scrolled into
  view) and one typed into a field before its sheet finished presenting; the test
  helpers now scroll to Settings and retry until the field has keyboard focus.
  The rest are system accessibility audits that pass on iOS 27 but flag text on
  iOS 18.5: clipping at default size on Diary and Restaurants, and "Dynamic Type
  partially unsupported" on the scanner's no-camera text, Retry Camera and
  Cancel, and on the demo data table at AX5. The audit gives no element for the
  clipped text, and the result bundle cannot be downloaded from the cloud
  sandbox; open the `simulator-results` artifact in Xcode to see them.
  Check the latest GitHub Actions result before merging; local simulator passes
  do not prove CI has passed.
- Owner request 2026-10-26: make the app match the look book closely, including the
  concept's tabs and a Stack module (D110). Claude is doing this in stages on
  `astra/foundation`: navigation first (custom tab bar, Quick Log, profile avatar;
  Diary is now the Fuel tab), then Stack (first slice in D111: opt-in under
  Settings → Modules, separate store, lock, today's doses, supply, default-off
  estimate; `StackUITests` and `StackPlannerTests` cover it), then restyling each
  screen. CI now pushes
  each run's simulator screenshots to the `ci-screenshots` branch so the cloud agent
  can see them. Avoid editing Navigation, RootTabView, Profile, Today, Diary, Train,
  Progress, Restaurants and the UI-test navigation helper until this lands.
- CI is green at `1979c44` (run 20, 2026-10-27): lint, packages, engine packages,
  an Xcode 16.4 app build with all unit tests (iOS 18.5 SDK), the backend, and all
  15 UI tests with their accessibility audits on macOS 26 / Xcode 26.6 (iOS 26.5
  simulator; no Xcode 27 is installed on GitHub's image).
- CI (D112): the macOS 15 / Xcode 16.4 job builds the app and runs unit tests; a
  macOS 26 job runs the UI tests and accessibility audits on the newest installed
  Xcode and publishes screenshots to `ci-screenshots`.
- Still needed by hand: run on a physical iPhone (glass blur, Face ID lock for
  Stack, scanner camera); check an iOS 17 or 18 device, which UI tests no longer
  cover; review the restyled screens against `design/lookbook/`. Stack's release
  gates in COMPLIANCE.md are untouched and remain open. Before that move, runs 13-17 on
  iOS 18.5 still reported unlocated clipped text on every screen; a probe showed the
  tab labels were not the cause.
- Claude imported the seven engine packages from its branch at the owner's
  request (D109): `HeliosTime`, `TrainingCore`, `NutritionCore`, `StackCore`,
  `InsightsCore`, `FoodCore`, `RestaurantCore`. The app links `HeliosTime`,
  `StackCore` (Stack) and `NutritionCore` (only `WeightTrend`, the §9.3 EWMA that
  draws Progress's trend line and Today's trend weight; it matches the
  HOW_WE_CALCULATE row). The rest are not linked yet. 402 tests
  pass locally on Swift 6.1.3 (Linux), and a new Foundation CI step runs them.
  Before wiring one into a screen, reconcile it with `HOW_WE_CALCULATE.md`
  (for example `TrainingCore` e1RM vs the planned rules, `NutritionCore` vs
  Profile's Mifflin–St Jeor estimate), and keep `RestaurantCore.DishEstimator`
  unused: AGENTS.md forbids estimating restaurant nutrition.
- Steps 1 and 2 from the owner's requested sequence are complete. Evidence is in
  `docs/PACKAGED_FOOD_VERIFICATION.md` and
  `docs/RESTAURANT_IMPORT_VERIFICATION.md`.
- Step 3 is the reusable recipe/meal builder. It supports USDA and My Foods
  ingredients plus manual portions, batch servings, optional measured cooked and
  raw weights, per-serving or cooked-gram review, diary logging, and personal
  macro edits. Source catalogs stay read-only; saved recipes and diary entries
  use personal snapshots.
- Step 3 implementation and all executed checks are complete. Review
  `docs/RECIPE_VERIFICATION.md` for simulator, native math/persistence/archive,
  formatting, build, and limitation evidence.
- The next slice adds Train and Profile foundations. Train now has additive local
  SwiftData records, a small original starter library, custom exercises, empty
  workout start/resume, immediate set persistence, warm-up handling, finish and
  history. Profile now exposes existing account status, local goals, and a pure
  guarded Mifflin–St Jeor starting estimate. Review
  `docs/TRAIN_PROFILE_FOUNDATION_VERIFICATION.md`.
- App unit tests and the focused Profile/workout UI flows pass on the iPhone 17
  simulator. The exercise picker now exposes an explicit accessible name, fixing
  the workout runner's earlier lookup failure.
- The production restaurant import registry is intentionally empty because no
  licensed/current restaurant source was supplied. Keep FUEL-13 disabled.
- The selected Supabase DEV project is deployed for the previously authorized
  foundation work. Email delivery setup remains pending at the owner's request.
- The working tree may include an unrelated Xcode scheme preference change;
  inspect it and leave it out of phase commits.

## Safe handoff routine

1. Finish the current change and run its checks. Update this file with the commit,
   changed paths, test commands/results, remaining risks, and one next task.
2. Commit the handoff together with the completed work. If a user change is
   present, preserve it and do not include it in the commit.
3. Open this same repository folder in the other coding tool. Before editing,
   have it read `CLAUDE.md` (for Claude Code), `AGENTS.md`, this handoff, and the
   relevant verification docs; ask it to inspect the branch and `git status`.
4. Work sequentially in one checkout. If both assistants must work at once,
   create a separate Git worktree and branch for each, then integrate and test
   the changes in the main checkout.
5. When switching back, ask the other assistant to update this handoff and commit
   its work. Tell Codex: “Read `AGENTS.md` and `docs/AI_HANDOFF.md`, inspect the
   branch/status, and continue from **Next task**.”

## Ready-to-paste Claude Code prompt

```text
Open this Caliber repository. Read CLAUDE.md, AGENTS.md, docs/AI_HANDOFF.md,
docs/MASTER_BUILD_BRIEF.md, and the latest verification docs. Inspect the current
branch and git status before editing. Continue from the “Next task” in the
handoff. Preserve user changes, keep FUEL-13 off without documented data rights,
run the required checks, update docs/AI_HANDOFF.md with evidence and remaining
work, and commit only the completed task files using a conventional commit.
```

## Next task

Finish the native theme verification gates listed in
`docs/THEME_INTEGRATION_VERIFICATION.md`, including a physical iPhone check and
minimum-supported-iOS execution. Then continue Phase 2 from this Train foundation:
add metric-specific set editors and
the complete set-type model, then previous-performance copy and the rest timer.
Do not claim TRN-01 complete or import a 600+ exercise/media catalog until a
specific source's current reuse rights and attribution duties are documented and
reviewed. Keep FUEL-13 off for the same restaurant-data reason. Preserve the
owner's unrelated Xcode scheme preference in the original checkout.
