# Pass 2 integration verification — 2026-10-28

This is the first bounded implementation batch, not completion of the master
brief. Codex goal setup and Claude visual delivery are integrated. Gemini's
food-entry branch remains pending its pushed handoff.

## Plan

1. Seed separate branch assignments from common base 96e8068.
2. Integrate Claude d956269 with its original authorship intact.
3. Integrate Codex guided goals d8ab44b and its additive storage.
4. Wire theme previews and preserve existing setting/test contracts.
5. Fix native audit/visual issues; run common checks and inspect captures.
6. Refresh the local preview after preserving edits and simulator data.

## Source tree and migrations

Complete goal files: [GOAL_SETUP_VERIFICATION](../../GOAL_SETUP_VERIFICATION.md).
Complete Claude files: [CLAUDE_HANDOFF](CLAUDE_HANDOFF.md). Integration files:

```text
Caliber (DEV)/Views/Foundation/FoundationSettingsView.swift
Caliber (DEV)/Views/Profile/ProfileView.swift
Caliber (DEV)/Views/Progress/{ProgressCards,WeightTrendChart}.swift
Caliber (DEV)UITests/VisualPass2UITests.swift
Packages/HeliosDesign/Sources/HeliosDesign/SwiftUI/{Gallery,States}.swift
scripts/{lint_foundation.py,test_ios.py}
docs/design/{goal-setup,pass2-native}/
docs/{AI_HANDOFF,BACKLOG,CHANGELOG,DECISIONS,DESIGN,HOW_WE_CALCULATE,MIGRATIONS}.md
```

Claude's native Swift was explicitly untested in its cloud environment. Codex
compiled it on macOS, connected its standalone preview, applied formatting and
added default/AX5 selection checks. Zero-calorie entries now prevent the false
"no food logged" message. Progress weight summaries expand vertically and stack
at accessibility sizes. Profile applies theme preference to its own presentation
so an open Settings sheet updates native navigation text when theme changes.
Existing setting IDs/picker, logging routes, chart data and edit/delete remain.

The only schema addition is NutritionGoalSetup, documented in MIGRATIONS. No
existing profile field, live store locator, food source, provider, hosted service,
feature gate, token value or health formula changes. Legacy archive/canonical
adapters still need the new guided metadata before full export/live cutover.

## Acceptance report

| Criterion | Result | Evidence |
| --- | --- | --- |
| Separate published assignments and owned files | PASS | Common 96e8068 base; role branches and briefs; Claude commits preserved |
| Explicit inputs and editable final review | PASS | GoalSetupUITests; locale/unit/persistence tests |
| Skip/cancel preserves targets, no inferred weigh-in | PASS | First-run and save/reopen/cancel UI; editor writes only profile/setup |
| Existing users keep their route/targets until save | PASS | Normal launch opens Profile directly; fresh-welcome flag and explicit Save |
| One local save and failure isolation | PASS | Failed update/create tests preserve prior rows and unrelated edits |
| Additive schema preserves old profile | PASS | Disposable on-disk reopen retains ID and exact targets |
| Starting-energy correctness and guards | PASS | Existing golden vectors, planner invalid input/target/floor tests |
| Theme preview edits existing setting | PASS | Default + AX5 selection UI and inspected captures |
| Progress scopes/empty actions preserve behavior | PASS | VisualPass2 empty timeline action opens/cancels real check-in form |
| Graphite/Frost and AX5 native routes | PASS | Final three theme walkthroughs; repeated clipping/Dynamic Type audits |
| Scanner and actual text growth | PASS | AX5 scanner audit; Progress/Profile/Restaurants grow >1.4× |
| Sensitive inputs stay local; release gates preserved | PASS for this diff | Diff/§11 reread; no uploads/keys/data imports or new provider paths |

## Executed checks

- Native unit target: **10 XCTest + 222 Swift Testing declarations pass**.
- **13 distinct UI scenarios pass** across the combined run and focused reruns:
  five guided setup; Profile calculation; two visual-pass; three theme
  walkthroughs; scanner AX5; text growth. Each walkthrough covers Today, Train,
  Fuel, Stack, Progress, Profile, Restaurants and scanner using fictional fixtures.
- First combined run exposed two normal-size Progress clipping cases. They were
  fixed in layout, then all three theme walkthroughs passed. No audit suppression.
- Appearance selection rerun passes default/AX5 after the navigation color fix;
  both captures were inspected. The earlier black-on-dark native title is fixed.
- Foundation package: **10 XCTest + 120 Swift Testing declarations pass**, with
  two optional full dataset skips. HeliosDesign: **30 XCTest cases pass**.
- Strict Swift formatting, Phase 1/static SQL contracts and look-book/token
  consistency pass. Dynamic Type lint: **215 files, 0 errors, 0 warnings**.
- Python suite: **130 tests pass**. Its intentional failing-lint fixtures print
  expected diagnostics; the real-source final lint has zero errors/warnings.
- Diff reread, whitespace check, no-key/no-placeholder scan and §11 review done.

Local result bundles (not committed): `/tmp/caliber-pass2-combined.xcresult`,
`/tmp/caliber-pass2-theme-fixed.xcresult`,
`/tmp/caliber-pass2-appearance-fixed.xcresult`. Package/static logs share the
`/tmp/caliber-pass2-` prefix; Foundation package log is
`/tmp/caliber-goal-setup-package-final.log`. Selected inspected captures are in
[pass2-native](../../design/pass2-native/) and [goal-setup](../../design/goal-setup/).

## Repeat commands

```sh
python3 scripts/lint_foundation.py
python3 scripts/verify_phase1.py
python3 scripts/lint_dynamic_type.py --strict 'Caliber (DEV)' Packages
python3 scripts/check_lookbook.py
python3 -m unittest discover -s scripts -p 'test_*.py'
swift test --package-path Packages/HeliosDesign
swift test --package-path Packages/CaliberFoundation
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,name=Caliber Lookbook QA' \
  -parallel-testing-enabled NO '-only-testing:Caliber (DEV)Tests' \
  '-only-testing:Caliber (DEV)UITests/GoalSetupUITests' \
  '-only-testing:Caliber (DEV)UITests/VisualPass2UITests' \
  '-only-testing:Caliber (DEV)UITests/TrainProfileUITests/testProfileCalculatesAndSavesLocalGoals' \
  '-only-testing:Caliber (DEV)UITests/ThemeIntegrationUITests/testGraphiteScreens' \
  '-only-testing:Caliber (DEV)UITests/ThemeIntegrationUITests/testFrostScreens' \
  '-only-testing:Caliber (DEV)UITests/ThemeIntegrationUITests/testLargestTextScreens' \
  '-only-testing:Caliber (DEV)UITests/ThemeIntegrationUITests/testScannerLargestTextLayout' \
  '-only-testing:Caliber (DEV)UITests/ThemeIntegrationUITests/testTextGrowthAcrossSizes' \
  CODE_SIGNING_ALLOWED=NO
```

Physical iPhone, minimum-iOS runtime, clinical/screening review, production
camera checks, performance budgets and full P0 acceptance remain open. This pass
adds no new chart engine and does not certify device frame/search budgets. Email
sender setup remains deferred. FUEL-13 and all prior provider/privacy gates stay
as before. Recommended next step: review/integrate Gemini's food-entry handoff,
then choose the next bounded date-strip/manual-hydration batch.
