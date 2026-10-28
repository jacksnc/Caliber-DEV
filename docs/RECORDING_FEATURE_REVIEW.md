# Recording feature review — 2026-10-28

Reviewed against Caliber commit `955a91b` (`codex/lookbook-polish`, also the local
preview). This is a proposal and gap analysis, not a request to implement every
observed feature. App code, data, feature flags and existing brief priorities are
unchanged. The older backlog tables contain historical statuses; the live views,
models and service call sites were checked directly for this comparison.

## Recording index and evidence limits

| Key | Owner-supplied file | Duration | Interface reviewed |
| --- | --- | --- | --- |
| A | `ScreenRecording_10-28-2026 14-26-29_1.MOV` | 00:32 | Cal AI: dashboard, progress, groups and profile |
| B | `ScreenRecording_10-28-2026 14-27-28_1.MOV` | 00:42 | MyFitnessPal: Today, plan, progress, nutrition and food entry |
| C | `ScreenRecording_10-28-2026 14-29-23_1.MOV` | 03:45 | MacroFactor: onboarding, goals, program setup, dashboard, strategy and food-entry workspace |

115 timestamped frames were reviewed across the recordings, with full-resolution
inspection of key screens. A/B sampling interval: two seconds; C: three seconds,
plus the end of each clip. These are observations of the supplied recordings,
not exhaustive live tests of those apps. **A visible menu/button is not proof
that its full workflow works:** those cases are identified below. Promotional
screens in C are also distinguished from the dashboard actually opened later.

Only generic descriptions and timestamps are stored in this report. The videos
and extracted frames stay outside the repository; account, payment and personal
health details from the recordings are not reproduced here.

Current official listings were cross-checked for product identity and broad
capabilities: [Cal AI](https://apps.apple.com/us/app/cal-ai-calorie-tracker/id6480417616),
[MyFitnessPal](https://apps.apple.com/us/app/myfitnesspal-calorie-counter/id341232718),
and [MacroFactor](https://apps.apple.com/us/app/macrofactor-macro-tracker/id1553503471).
The UI details below are supported by recording timestamps. No competitor
accuracy, database-size, price or outcome claims are adopted.

## Functional opportunities

**Missing** means no matching user-facing path was found in the inspected app.
**Partial** means a related flow already works but the specific behavior is absent.
**Core only** means supporting code exists outside the connected screen path.
**Next / Later / Release** are suggested sequencing, not replacements for P0/P1/P2.
P1 features keep their flag and release gates; P2 features stay later.

| ID | Feature to consider | Recording evidence | Caliber today | Suggested slice / sequencing |
| --- | --- | --- | --- | --- |
| RV01 | Guided setup for profile, goal and nutrition plan | C 00:12–01:30: individual questions, units, goal rate, plan summary | Partial: Profile calculates and saves daily goals; there is no comparable guided nutrition setup | **Next:** a short wizard over the existing calculator, with review/edit at the end. Preserve adult/safety gates. PLAT-01, FUEL-20. |
| RV02 | Saved target weight, estimated finish window and goal history | A 00:08–00:10; C 00:48–00:54 and 03:18 | Partial: trend and goal-rate input exist; `UserProfile` does not persist a target weight, goal history or projected date | **Next after setup:** goal summary with start/current/target and progress. Projections need our own documented method, uncertainty and insufficient-data state. BODY-01. |
| RV03 | Diet/protein preferences and editable program rationale | C 00:57–01:21 and 01:27–01:30 | Partial: editable macro targets and a starting estimate exist; named diet/protein presets and saved preference rationale do not | **Later:** optional preferences, explain each target, retain direct editing. Do not copy competitor formulas or diet recommendations. FUEL-20. |
| RV04 | Different targets across the week / training and rest days | C 01:12–01:15 and 01:27: distribution choice and seven-day macro columns | Missing connected weekly target schedule | **Later:** weekday/day-type targets with a transparent weekly total and explicit overrides. FUEL-21 P0; VZ-F14/15 P1. |
| RV05 | Weekly nutrition check-in and adaptive expenditure | C 00:54 plan explanation; 03:09 expenditure tile; 03:27–03:30 check-in entry point. Completed adaptation was not demonstrated | Core only: `ExpenditureEstimator` and `TargetAdjuster` exist in NutritionCore; the live Profile uses the starting-target calculator instead | **Later, flagged:** data-completeness review, estimate explanation, proposed adjustment and user confirmation. Resolve correctness/coverage before connecting. FUEL-22 and VZ-F6 are P1. |
| RV06 | Week strip with selected day and logging markers | A 00:00–00:06; B 00:00; C 03:15 | Partial: Diary has a date picker; Today is fixed to today. No shared swipeable week strip | **Next:** seven days, clear selection and logged-data indicators; synchronize the chosen diary date. Logged data does not imply a complete day. VZ-T5. |
| RV07 | Dashboard card selection and ordering | C 03:03 customization announcement and 03:06 settings icon; the editor itself was not opened | Missing: Today card layout is fixed | **Later, flagged:** show/hide/reorder a small set of useful cards. Begin with a few defaults rather than many tiles. VZ-T10 P1. |
| RV08 | Water quick log, daily total and history | A 00:04–00:06; B 00:06 and 00:30 | Missing: a volume-unit preference exists, but no hydration logger/card | **Next:** manual water amount, quick increments, editable entries and a daily card; no medical hydration advice. FUEL-06, VZ-T7. |
| RV09 | Apple Health steps, weigh-ins and active-energy cards | A 00:04–00:06 connection prompt; B 00:06/00:20 activity categories. Actual synchronization was not shown | Missing connected HealthKit path | **Next after permissions/storage design:** read-only consent, per-metric source/date and refresh state, manual logging still available. FUEL-INT-01 P0; richer BODY-04/VZ-B6 P1. |
| RV10 | One food-entry workspace for search, history, meals, recipes, scans and manual entry | B 00:30–00:40; C 03:33–03:44 | Partial: most methods exist, but are spread across links, list sections and separate screens | **Next:** compact method shortcuts plus clear library scopes, with selected meal/date retained. Reuse existing services and review screens. FUEL-01/04/05. |
| RV11 | Quick action beside a recent food, with last-used portion | B 00:30–00:36 shows a + on each row; the result of tapping it is not shown | Partial: recent/frequent/favorites and last-quantity review already exist; no inline quick action | **Next:** + opens a compact prefilled review, then Add; keep macro editing and an undo route. Avoid creating a second history system. FUEL-01/03. |
| RV12 | Multi-food draft / plate, combined totals and one final log action | C 03:42–03:44: quick entry and empty plate with plate/day nutrition view; a populated batch was not demonstrated | Partial: saved meals/recipes can log multiple ingredients; typed lists review one match at a time. No shared unsaved plate across input modes | **Next after RV10:** accumulate reviewed items in one draft, edit/remove, preview totals, save once; cancel writes nothing. FUEL-01/05. |
| RV13 | Short calorie/macro quick entry without building a saved food | B 00:30 shortcut; C 03:42 quick-entry fields | Partial: Add Food is a longer form requiring a name and defaults to saving to My Foods | **Next:** compact explicit macro entry, optional personal-library save. Calorie-only records need honest unknown-macro handling, not invented zeros. FUEL-01. |
| RV14 | Voice logging | B 00:30–00:36 voice button only; no recognition or saved result shown | Missing dedicated speech-input flow; typed multi-food parsing already exists | **Later, flagged:** speech → editable parsed items → source matches → confirmation. AI-01/FUEL-12 P1. |
| RV15 | Broader photo/description input and correction | C 03:39 photo-intro overlay and Snap/Describe controls; no successful recognition/correction shown | Partial: photo proposal/review and typed lists exist. Photo backend is gated; no multi-photo or fix-with-words flow | **Later, flagged:** finish current evaluation/provider gates, then editable corrections. Do not list basic photo UI as wholly absent. FUEL-10/AI-07 P1. |
| RV16 | Photo thumbnails on recent meal cards | A 00:02: recent uploads include an image thumbnail | Missing meal-photo attachment/history UI; Progress photos are a separate working feature | **Later:** optional local meal photo on the diary snapshot, with attachment storage/export/privacy handled. FUEL-07. |
| RV17 | Deeper progress dashboard: per-period changes, averages and chart detail | A 00:10–00:18; B 00:12–00:20 | Partial: weight trend, seven-day calorie bars, macro split and a check-in timeline exist. No multi-period change table or equivalent drill-down pages | **Next:** weight changes over useful windows, period calorie averages and chart-detail navigation. State the period for each chart; current range selection filters weight while food cards remain seven-day views. BODY-01, VZ-B1, VZ-F1/2/3. |
| RV18 | Nutrient totals/goal/remaining and per-nutrient trends | B 00:18 table; C 03:44 all-nutrients control (not expanded) | Core only/partial: FoodCore can represent more nutrients, but live `FoodItem` and diary snapshots store calories and three macros | **Later:** data/schema/source coverage first, then fiber/sodium/etc. Unknown stays unknown; never fill from food names or photographs. FUEL-02; VZ-F8/FUEL-24 P1. |
| RV19 | Meal calorie distribution and food contributors | B 00:16: meal distribution chart and top-food section; contributor details were not opened | Partial: meal groups and daily totals exist; no equivalent analytical chart/top-contributor page | **Later:** breakdown by meal and source-backed ranked contributors. Keep the current editable diary. VZ-F1; VZ-F11 P1. |
| RV20 | Intake versus expenditure summary | A 00:16–00:18 weekly energy card | Missing connected activity/energy-balance view | **Later, flagged:** reliable source definitions and coverage first. Keep active energy distinct from total expenditure; avoid duplicate activity imports or automatic extra calorie allowances. VZ-F4 P1. |
| RV21 | Logging/weight consistency calendars and optional achievements | A 00:08–00:10 streak/badge cards; C 03:09 habit grids | Missing user-facing habit calendars/streaks/achievement system | **Later:** logging consistency, with incomplete days distinguished. Streaks opt in and respect risk/hide-numbers settings. VZ-F7 P0; VZ-T6 P1; badges are an optional new proposal. |
| RV22 | Shareable weekly summary / PDF report | A 00:26 PDF-export row; B 00:14 report card. Neither export was demonstrated | Missing user-facing report export. Internal archive/restore rehearsal is not a PDF or complete user export | **Later:** choose dates/domains, preview/redact, export locally. Stack is excluded by default. PLAT-04 and existing VZ-X report scope. |
| RV23 | Meal planning, recipe discovery and recipe import | B 00:08–00:10 discovery/planner; 00:38 create/discover/import entry points only | Partial: recipe editor and saved meals already work; discovery, URL import and a weekly planner are absent | **Later:** planning remains FUEL-27 P2. Use original or permissioned recipes; do not scrape competitor content. Discovery/import are proposed extensions, not completed observed flows. |
| RV24 | Apple/Google sign-in, signup and subscription management | C 01:39–02:33 purchase/auth flows, 01:48 restore entry | Partial: optional existing-account email/password, recovery/delete client flows exist. No native social sign-in/signup or purchase/restore UI; provider/release gates remain | **Release work:** account continuity, duplicate-account recovery and restore purchases. Do not block offline logging. PLAT-03; subscriptions PLAT-07 P1. |
| RV25 | Support/FAQ/feedback/feature request hub | A 00:26–00:28; B 00:24; C 03:21–03:24 visible destinations | Partial: Settings has notices and scope text; no complete in-app support hub | **Release work:** our own help/calculation pages and an opt-in feedback flow. External services/policies require real destinations. PLAT-09 P1. |
| RV26 | Time-based food log and configurable meal slots | C 03:15 hourly timeline | Partial: diary entries have dates, but the native interface uses four fixed meal types | **Later:** optional time view/custom slots while retaining breakfast/lunch/dinner/snacks. A separate body check-in timeline already exists. FUEL-01/05 and meal-timing backlog. |
| RV27 | Fasting, sleep, GLP-1 support and Siri shortcuts | B 00:22 More entries; C 03:21 Siri entry only; underlying workflows not opened | Missing dedicated experiences: Stack logs compounds but is not a complete GLP-1 nutrition mode; no Health sleep screen, fasting timer or App Intents | **Later, flagged:** FUEL-25/26, BODY-04, PLAT-05. Keep separate consent, adult/privacy and sensitive-flow gates. Do not infer full capabilities from their menu names. |
| RV28 | Groups, friends/messages, family plans and referrals | A 00:22 groups and 00:24 referral/family entries; B 00:24 community/friends/messages entries | Missing; outside the current core logging flows | **Low priority proposal:** revisit after the private single-person experience. No public sharing of doses/protocols and no health-based advertising. |

## Visual patterns worth adapting to Helios

These are interaction/layout ideas, not instructions to copy assets, words,
branding or exact screen compositions. Keep Graphite/Frost tokens and Caliber's
existing macro colors.

| ID | Pattern and reference | Application in Caliber |
| --- | --- | --- |
| VX01 | Weekday strip with circular activity markers — A 00:00, B 00:00, C 03:15 | A visible selected day and simple logged/empty markers above Today/Fuel; text labels and VoiceOver state accompany color. |
| VX02 | Compact calorie hero with small macro cards — A 00:00–00:02, B 00:00–00:02 | An optional dense dashboard layout. Our concentric macro rings already serve this purpose; preserve them as the default rather than rebuilding totals. |
| VX03 | Swipeable dashboard groups with page dots — A 00:02–00:06, C 03:06–03:12 | Optional nutrition/activity/water groups once those sources work. Keep frequent logging actions visible and provide an accessible alternate to swiping. |
| VX04 | Short method toolbar and library tabs — B 00:30–00:40, C 03:33–03:44 | Search, barcode, label, photo and manual shortcuts above a history/library pane; a shared meal/date context prevents repeated setup. |
| VX05 | Dense recent-food rows with portion, calories and a right-side action — B 00:30–00:36 | Faster scanning and prefilled review. Use truthful source badges (USDA, personal, sample/approved menu); a checkmark must not imply unearned verification. |
| VX06 | One-question setup screens with progress, selectable cards and a bottom Next button — C 00:15–01:21 | Clear short questions, Back, validation, editable review and resume. Keep direct numeric entry alongside any ruler/wheel; do not reproduce the long promotional/paywall detour. |
| VX07 | Large metric, small change label and sparkline — A 00:10–00:18, C 03:09 | Add context and drill-down to existing Helios cards, with consistent periods, method access and honest missing-data states. Our current charts already use much of this structure. |
| VX08 | Stacked macro-colored calorie bars and seven-day program columns — A 00:14, C 01:27/03:06 | A daily macro-energy chart and a separately labeled target schedule; logged intake and planned targets must remain distinguishable. |
| VX09 | Draft sheet with persistent meal/time controls and a final total/action — C 03:33–03:44 | Preserve reviewed food drafts while switching input mode; show draft/day totals, a clear final Log action and safe dismissal. |
| VX10 | Persistent search/scan shortcut above the bottom navigation — C 03:06–03:12 | Consider a compact shortcut or direct actions in Quick Log; avoid obscuring content or stacking multiple floating controls. |
| VX11 | Small illustration, explanation and one useful action in empty states — A 00:12–00:14, B 00:10/00:38–00:40, C 03:44 | Improve current empty states using our own SF Symbols/assets and specific actions such as create recipe or log a weigh-in. |
| VX12 | Theme preview swatches — C 03:21–03:24 | Replace the appearance text-only picker with accessible previews while keeping existing System/Frost/Graphite/OLED choices. |

## Already available — evolve these

- **Food logging:** four meal groups, manual foods, portion review and editable
  macros, recents/frequent/favorites, day/meal copy, saved foods, meals and recipes.
- **Capture:** barcode/local lookup and nutrition-label scan. Photo-estimate UI
  exists behind its current gates; provider activation/evaluation is unfinished.
  Typed multi-food queries exist; voice transcription does not.
- **Restaurants:** categorized samples, builders and personal custom items. The
  approved production registry is empty; broad/current chain menus are a data
  rights and validation task, not something the recordings provide permission to
  import. Search history in B does not establish an official restaurant menu.
- **Progress:** weigh-ins, smoothed trend, chart ranges, calorie bars, macro split,
  photos, notes and an editable check-in timeline.
- **Presentation/privacy:** Graphite/Frost, system/OLED options, floating tabs,
  Quick Log, profile avatar, formatting/unit settings and hide-numbers mode.
- **Accounts:** optional permission plus an existing-account sign-in client and
  lifecycle work. This does not mean public signup, social login, hosted email
  delivery or personal health-data sync are release ready.

## Implementation evidence checked

| Code | What it establishes |
| --- | --- |
| `Views/Diary/FoodSearchView.swift` | Existing scopes, history, manual/barcode/label/photo links, saved meals and restaurant search; list items still open individual review. |
| `Views/Diary/AddFoodView.swift`, `Models/FoodItem.swift` | Current name-required manual form; calories/protein/carbs/fat storage; no general micronutrient or meal-photo fields. |
| `Views/Diary/DiaryView.swift`, `Views/RootTabView.swift`, `Views/Navigation/QuickLogSheet.swift` | Date picker, fixed meal groups, copy flows, four Quick Log destinations; no water action or shared plate. |
| `Views/MyMeals/RecipeEditorView.swift`, `Views/MyMeals/SavedMealDetailView.swift` | Working personal recipe/saved-meal foundation; not a discovery feed or weekly planner. |
| `Views/Profile/ProfileView.swift`, `Models/UserProfile.swift` | Starting estimate and editable daily goals; no persisted target-weight/program-history model. |
| `Views/Foundation/TodayFoundationView.swift` | Fixed dashboard cards and today-only selection; no hydration, steps or card editor. |
| `Views/Progress/ProgressDashboardView.swift`, `ProgressCards.swift`, `WeightTrendChart.swift` | Existing live charts and photo/notes timeline; weight range selection and fixed seven-day nutrition cards. |
| `Views/Foundation/FoundationSettingsView.swift`, `HostedAccountView.swift` | Theme/unit/privacy controls; optional existing-account email login; cloud health backup explicitly inactive. |
| `Packages/NutritionCore/Sources/NutritionCore/Expenditure.swift` | Adaptive estimate/target functions exist; no live app call site was found for them. Weight trend integration is separate and already present. |
| `Packages/FoodCore/Sources/FoodCore/Nutrients.swift` | Rich nutrient types exist separately from the live macro-only FoodItem snapshots. |
| `Packages/CaliberFoundation` archive/restore code and migration docs | Internal portability rehearsals are not a finished user export/report screen. |

App-relative code paths above start in `Caliber (DEV)/` unless prefixed with
`Packages/`. No source changes or new calculation estimates were made for this
review.

## Recommended build order

1. **First-run setup:** reuse the existing goal calculator, persist a real goal,
   show an editable summary, and complete the age/privacy/safety flow. Keep this
   short enough to log a first food quickly.
2. **Food-entry convenience:** shared method shortcuts and library scopes,
   compact recent-food review, then a multi-food draft with combined totals.
3. **Daily dashboard:** shared week strip and manual water; add Health metrics
   after consent, deduplication and source handling are ready.
4. **Progress depth:** period comparisons, goal progress and nutrition detail.
   Add micronutrients only after source and persistence coverage is complete.
5. **Optional advanced planning/coaching:** day-type targets and flagged adaptive
   check-ins, then personalization and richer reports. Keep meal planning P2.
6. **Release services:** complete account setup, support/export, then purchases
   and social sign-in if needed. Groups/referrals are lower priority.

## Verification and changes

- All three supplied clips are covered by the timestamped review.
- Missing/partial/core-only findings were compared to live app paths and models,
  not inferred solely from old backlog rows or available package names.
- Entries visible only as buttons, menus or promotional text are marked.
- No app code, schemas, datasets, hosted services or personal settings changed;
  no migration or runtime test is required for this documentation-only review.
- Documentation link/contract checks and a diff review are recorded with the
  commit. No native or competitor live test is claimed for this review.
