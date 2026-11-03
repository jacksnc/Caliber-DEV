# Caliber AI handoff

## Active beta checklist integration — 2026-11-02

Owner authorized the beta checklist and Claude/Gemini delegation. Current work:
`codex/release-readiness` in `/Users/jcrock/Documents/Codex/Caliber-release-readiness`.
Read `docs/parallel/release-beta/{SESSION,PEER_REVIEW}.md`. The five pending
production view corrections and eight test changes were reviewed and copied
from the original QA working tree; that original and the owner's preview are
preserved. Do not duplicate those patches. No formula or storage migration.

Both native model reviews completed: Claude Opus 5.5 reviewed UI helpers;
Gemini 3.8 Flash High verified approved logo pixels/provenance and release notes.
The Mac later locked; a further warning audit was not sent. Gold-on-black v7
is now installed as the normal/dark Home Screen icon, proportionally downsampled
to 1024² without redesign. Compiled simulator metadata includes phone/iPad icons.

Three FoodEntry UI tests pass. The adjacent regression run passes 277/277:
260 app tests plus 17 UI tests. Together, 20 distinct focused UI tests pass.
The new disposable-simulator runner separately passes all 260 app tests and
removes its own created simulator. Six runner guards and eight archive-checker
tests pass; Foundation/Dynamic Type lint and YAML parsing pass. Layout warnings
remain (3 and 8 in the focused UI logs); no source attribution or fix claimed.
Exact summaries are in `docs/evidence/release-beta/test-results.json`.

CI coverage expands from nine to 24 reviewed fixture suites in four balanced
read-only shards, excluding only Xcode's two unasserting persistent-store
template cases. It creates its own simulator, preserves separate artifacts,
and compiles/checks a hardware Release archive. Screenshot publication retains
its trusted branch-only writer job. Cloud CI and the complete fixture regression
remain pending; the earlier full 82/91 run is not a green result. The first CI
attempt exposed a shared Xcode 26.6 type-check timeout at the spark modifiers
in `HeliosDesign/SwiftUI/Feedback.swift`; no UI tests started, and the iOS unit
job stayed queued. Drawing modifiers are now isolated in a private subview with
unchanged animation math. The HeliosDesign package tests pass 48/48 locally on
Xcode 27.1. The post-fix hardware Release archive succeeds at
`/tmp/caliber-beta-after-fix-20261102.xcarchive`, log
`/tmp/caliber-beta-after-fix-20261102.log`. All 10 compile-only checks pass;
default distribution checks fail only absent app/widget signing material.
Hardware phone/iPad icon metadata and the compiled small icon are verified.
All 149 Python script tests pass; lint/diff checks pass.

Physical signing remains blocked: zero valid local signing identities and no
physical iPhone available to Apple's device service; owner confirms an active
paid personal membership. The linked Xcode account currently shows only
“Personal Team”, zero provisioned devices and no signing certificates; refreshing
manual profiles did not surface the enrolled team. Do not change bundle or App
Group identifiers or weaken the existing capabilities/privacy boundary. No team,
identifier, account, provider, personal store, upload or public release changed.

## Hardware archive and beta packaging — 2026-11-02

Owner requested progress toward going live. Branch `codex/release-readiness`
in `/Users/jcrock/Documents/Codex/Caliber-release-readiness` starts at committed
integrated code `70c4012`; the dirty QA checkout and owner's preview are intact.
Read `docs/RELEASE_READINESS.md`. The hardware Release archive succeeds before
and after adding the application PrivacyInfo.xcprivacy. The app's audited direct
UserDefaults and systemUptime uses declare CA92.1 and 35F9.1; the actual built
app contains both declarations. No data-collection disclosure completeness is
claimed. No provider, entitlement, team, identifier, formula, or schema changed.

A read-only archive checker and 8 passing fixture tests are added. Actual final
archive inspection passes 9/10 compile-only checks and fails the missing primary
app icon: the asset catalog is empty. The archive is deliberately unsigned.
Widget embedding, version and identifier checks pass. Foundation lint, plist
syntax and diff checks pass; inherited concurrency warnings remain in the log.
No UI/device tests were rerun. The existing broad UI record remains 82/91;
uncommitted QA fixes must be reviewed and integrated before final regression.
Next: resolve that regression batch and approved icon assets, then confirm the
owner's Apple team/identifiers for a signed physical-device beta. Source/reuse,
privacy/disclosure and existing COMPLIANCE release gates still require evidence.
No App Store/TestFlight upload occurred. Exact commands, artifacts and ordered
remaining actions are in RELEASE_READINESS.md.

## Diary energy units and model review — 2026-11-01

Current coordinator checkout:
`/Users/jcrock/Documents/Codex/Caliber-integrated-iphone-qa`, branch
`codex/integrated-iphone-qa`. Claude Opus 5.5 Medium delivered the saved-unit
Diary/search/copy change in `29ad331`, cherry-picked locally as `26cd3dc`.
Gemini 4 Argon returned an account quota error, so the owner-approved review was
completed by Gemini 3.8 Flash Medium on the owner's Mac in a separate checkout;
its report is `parallel/integrated-iphone/GEMINI_HANDOFF.md` at `06d365f`.
Claude Opus 5.5 Medium independently reviewed that report read-only. The
consolidated findings and decisions are in `MODEL_REVIEW.md`.

Codex added the Settings picker identifier/accurate unit scope, strict lint
coverage for the new files, missing explicit CaliberCore imports caught by the
first native compile, a guard against positive over-goal kJ rounding to zero,
and the active Helios accent for Food Search favorite swipe actions. A broad
regression run caught a threshold-format bug; the corrected threshold now shows
`<0.1 kJ`, not a value converted from kcal. No storage, nutrition/Health
formula, source label, clinical, provider or sync behavior was changed. There is
no data migration. Latest focused native result is
`/tmp/caliber-energyunit-final3.xcresult`: six unit tests plus the full updated
UI flow pass on Compact QA. The earlier `/tmp/caliber-energy-regression.xcresult`
is a historical partial failure: it predates the kJ threshold correction, used
an obsolete Oikos search assertion, and exposed lazy-list assumptions in food
UI tests. Focused reruns now pass all three affected FoodShortcuts cases in
`/tmp/caliber-foodshortcuts-final.xcresult` and the Dinner/oats review path in
`/tmp/caliber-food-entry-oats-lazyfavorite.xcresult`. All 244 app unit tests
pass in `/tmp/caliber-unit-final.xcresult`. The full 22-case UI batch was not
rerun after these focused fixes, so the archived broad result is not described
as green.

Gemini's source review classified the Christmas logo background as supported;
the disabled Save and translucent navigation findings as partly supported;
the reported Diary clipping as stale/not supported; and the `.blue` swipe tint
as source-supported. Codex changed only the tint in this batch. Physical-device
widget sizing/redaction, live camera and Health behavior remain unverified.
Gemini Argon's quota error did not trigger an upgrade or overage. The owner
local-preview checkout and personal simulator remain untouched.

An available Codex agent performed read-only widget route/privacy reviews. Codex
reproduced the real Fuel link defect through XCUISystem URL opening: it stayed on
Food Library. A consumable in-memory request now returns safely to today's Diary
and optionally opens editable search. Existing sheets/searches, pushed Library
branches, Profile, Quick Log and shared check-in forms defer navigation. Repeated
Add preserves current input; privacy/Demo clears pending requests. No URL inserts
a record. A single type-erased Fuel path replaces conflicting nested navigation;
the first attempt's crash and subsequent harness fixes are documented honestly
in SESSION.md and VERIFICATION.md. The fictional stale widget preview now uses
the existing daily constructor, including historical midnight expiry.

All 11 targeted UI cases pass across the main final run and the last focused
test-only Close/Back correction. App logic: 238 Swift Testing plus 16 XCTest
cases pass; focused package suite: 21 pass. Strict formatter and Dynamic Type
lint (241 files, zero findings) pass. Four native fixture PNGs exported; Diary
and unsaved-note captures reviewed. No database/math/provider/signing changes;
owner local preview stays 84edf55 with its three original dirty paths and the
personal simulator/store remain untouched. All native runs use Compact QA
2998CE67-7D71-460B-AD69-76DAA4D014F6. No test batch remains running.

Next external assignments must start from the published HEAD of this integration
branch, not the older Christmas branch, and preserve its Diary route handling.
Claude owns energy display only; Codex owns Settings wording/shared integration.
Physical widget sizing/redaction/refresh, camera optics, real Health/source
reconciliation, minimum-iOS/hardware performance and wider editor/media-picker
route combinations remain separately unverified. The owner's installed build
has not been updated by this batch.

## Automatic Christmas appearance — 2026-11-01

Continuation branch `codex/seasonal-christmas`, separate checkout
`/Users/jcrock/Documents/Codex/Caliber-seasonal-christmas`, from progress-unit
commit 66017a2. The owner requested a Christmas logo/theme with minimal falling
snow, automatically unlocked by the local iPhone date on December 1. Implemented
the documented default season December 1–31, repeating annually and restoring the
saved base appearance January 1. There is no early Christmas selector or stored
season-unlock flag. Normal appearance choices remain available and saved.

Read SEASONAL_APPEARANCE.md and SEASONAL_APPEARANCE_VERIFICATION.md. A pure Core
policy and an observed app model handle Gregorian local date, foreground refresh,
calendar midnight and clock/timezone notifications. A shared background renders
at most 22 six-arm flakes with a 15fps scheduling limit. Reduce Motion, Reduce
Transparency, Increase Contrast, Low Power Mode or the motion switch use eight
static flakes. Decoration never takes taps or exposes accessibility elements.
The owner-approved infinity mark has dark/light Christmas variants with a center
snowflake; Settings displays the season-specific mark only during December.
This does not replace the Home Screen icon. Exact built-in image-tool prompts
and provenance are in design/branding/christmas/README.md.

Focused Core tests pass 5/5, native model tests 2/2, native UI cases 3/3. Final
native screenshot sampling verifies background movement when enabled and a
stationary background under reduced motion. Strict Foundation formatting and
Dynamic Type lint pass. Four native QA previews are in output/screenshots/christmas.
Test date overrides affect the theme only in isolated Debug UI tests; device,
diary and Health clocks are unchanged. No database migration, provider activation,
health formula change or owner-data access. The original local-preview checkout
remains at 84edf55 with its existing three dirty files; the personal simulator
is untouched. No native test batch is running at this checkpoint.

Remaining: physical-device animation/battery and minimum-supported-iOS visual
checks, then the previously pending widget gallery/privacy/deep-link review.
Keep these separate from the owner's local preview until an explicit build update.

## Progress unit consistency — 2026-11-01

Current continuation branch `codex/progress-unit-consistency`, worktree
`/Users/jcrock/Documents/Codex/Caliber-progress-units`, from pushed cards/widgets/
Health integration c8d24c0. Owner asked to continue. Native widget gallery review
could not start: the computer-control service repeatedly reported the Mac locked,
even after the owner's Unlocked reply and a fresh control session. No lock or
security setting was changed. Source/build/test work continued independently.

Resolved Claude's first independent review finding: Progress form/chart/detail
now use runtime.settings.massUnit, like Today and Settings. A form unit remains
local until its successful save. Cancel/failed save/number-free note/photo saves
do not change it. A one-time reversible preference merge adopts a valid last
legacy progressWeightUnit choice into FoundationSettings without rewriting any
weigh-in or changing conversion formulas. Invalid legacy strings preserve the
canonical setting; progress.weightUnit.unified.v1 prevents later stale legacy
writes from regaining authority. Preview runtime uses isolated fake preferences/
services and in-memory progress storage; no owner preferences are initialized or
migrated by that preview.

Read PROGRESS_UNIT_CONSISTENCY.md. Native migration tests pass 2/2; cancel UI
passes; the final saved-kg UI case passes across Progress, Today, a separate theme
save and relaunch. Result paths are in that document. Early UI harness failures
were offscreen/empty Picker.value assumptions and a duplicate theme label; final
checks use observable kg labels/selected unit and the stable appearance card ID.
Strict Foundation formatting and Dynamic Type lint pass; owner local preview,
personal simulator and data remain unchanged. No native test batch is left
running after this checkpoint.

The parent branch still contains the reviewed native cards, small/medium widgets
and confirmed-allowance Health adjustment, with detailed evidence in
parallel/cards-widgets/VERIFICATION.md. Physical WidgetKit layout/redaction,
real Health permissions/source reconciliation and signing remain open. Do not
claim those are verified from compilation, mocks or settings screenshots.
Claude and Gemini finished both assigned deliveries and review-only follow-ups;
no new native prompt was sent after desktop controls became unavailable. Next:
resume isolated widget gallery/deep-link/visual review once native control works;
then remaining ranked findings with refreshed branch ownership.

## Cards, iPhone widgets and Apple Health allowance — 2026-11-01

Current coordinator branch `codex/cards-widgets`, clean separate checkout
`/Users/jcrock/Documents/Codex/Caliber-cards-widgets`, from packaged-food e6ba3ec.
The owner asked to prompt/delegate to existing native Claude/Gemini chats,
implement swipeable info cards and iPhone widgets, and collect independent gap
reviews. Both received bounded tasks, acknowledged actual clean worktrees,
shipped on separate branches, and completed later review-only tasks. Gemini
stayed on Mac. See parallel/cards-widgets/SESSION.md and VERIFICATION.md.

Claude 5af0a69 adds Today nutrition paging Calories/Protein/Carbs/Fat with named
48pt tabs, previous/next, a value-panel-only gesture and VoiceOver alternatives;
Codex integrated it as 6066fa7. Diary headings and row actions are preserved.
Gemini b01514e supplies widget presentation/fixtures, integrated as 6b86db0;
Codex reviewed and corrected numeric casts, a nonexistent palette token, privacy
redaction/accessibility, timestamps, large-text fallback and family actions.
Small/medium WidgetKit target is embedded; neutral by default, with a protected
backup-excluded, two-hour/local-midnight-expiring cache of four opted-in daily
nutrition totals only. Health/Stack/user records/tokens are excluded. No private
SwiftData store is shared. IPHONE_WIDGETS.md documents the reviewed boundary.

The owner subsequently approved optional Apple Health adjustments above an
explicitly confirmed daily activity allowance. Read and adjustment are separate
opt-ins; only canonical-kcal Active Energy is queried, never extra resting or
workout totals. `base + max(0, active - allowance)` changes only today's displayed
calorie goal. Saved base, macro goals and past days remain intact. Missing,
invalid, old, future or mismatched-day/timezone data keep the base. Values stay
in memory and out of widgets/backend/logs. Disconnect, number-free, Demo and
background suppress observations. HEALTH_ENERGY.md and HOW_WE_CALCULATE.md explain
refresh and limitations; no real Health request or owner sharing was enabled.

Native checks use only isolated Caliber Compact QA and
`/tmp/caliber-cards-widgets-derived`. Existing app/persistence suite passed;
card paging/large-text and widget opt-in/persistence UI checks passed. Focused
Foundation engine/widget/store cases and Health controller defaults/no-data/
race/replacement cases pass. Native full Health setup verifies the fictional
2350 base + (450 active - 300 allowance) = 2500 goal. Capture review caught and
fixed a real cached-render-time ring lag; final assertions check both 2500 goal
and 1038 left immediately; the expanded case verifies today/yesterday/today Diary goals too. Detailed run paths, early test-harness failures and
Xcode diagnostic-collection handling are in VERIFICATION.md. Physical WidgetKit
render/redaction/provisioning and real Health/source-overlap checks remain open.
Source gap proposals are triaged in BACKLOG.md, led by Progress weight-unit
consistency and energy-label consistency. No provider or clinical calculator was
enabled. Owner local preview remains at 84edf55 with its three original dirty
files; personal simulator/store and installed build are unchanged.

## Packaged name search, label imports and barcode checks — 2026-11-01

Branch `codex/packaged-food-import`, worktree
`/Users/jcrock/Documents/Codex/Caliber-packaged-food-import`, from `8fce224`.
Owner requested branded-food imports, a Gemini research format and barcode
coverage verification. The existing 50,000-product barcode collection was absent
from name search. FoodSearchView now queries it in a bounded local task and opens
the existing editable review. A reviewed per-serving LabelFoods.json supplement
is shared by name search and barcode lookup; exact GTIN corrections suppress the
stale corresponding base result. No private logs are rewritten.

Read PACKAGED_FOOD_IMPORT.md and PACKAGED_IMPORT_VERIFICATION.md. The CSV template
and Gemini prompt are in docs/templates/packaged-food. The importer rejects
missing nutrition, invalid/duplicate GTINs, guessed mass/volume combinations and
unreviewed writes to app resources. A maintainer supplies a consolidated reviewed
collection; the supplement is bounded at 1,000 rows. One source-checked Oikos Pro
vanilla cup correction uses 130 kcal/20 P/6 C/3 F per 150 g from the manufacturer.
Retailer and old USDA discrepancies are documented, not averaged.

Camera delivery expands UPC-E using FoodCore's explicit symbology; full manual
GTIN validation rejects all-zero codes. No provider was activated. The catalog
audit passed 50,000 GTINs / 149,996 equivalent lookups. Only 2/6 selected mainstream
SKUs matched offline: this is not market-coverage or physical-camera proof.
Gemini's prompt prioritizes the four documented misses.

Python import checks pass 5/5; existing packaged builder checks 24/24; focused
database package suite passes (one optional external-resource case skipped);
FoodCore barcode suite passes 28/28; strict Dynamic Type lint is 226 files with
zero findings. App/unit checks and the new Oikos name/barcode UI checks passed
in the corrected run. Two older mass/liquid UI tests needed navigation helpers
updated for the V2 review footer and retained Fuel navigation stack; their final
scoped rerun passed 2/2 with exact saved-diary totals. Initial failures remain
documented in PACKAGED_IMPORT_VERIFICATION.md. The owner's local preview,
personal simulator, private data and provider settings are untouched. Native
build/test evidence is from isolated Caliber Compact QA. Next: collect/review
Gemini's exact product batches; fill the four misses and perform physical-camera
QA before claiming broad coverage. No further native job is running.

## Gemini restaurant archive intake — 2026-11-01

Branch `codex/restaurant-data-intake`, worktree
`/Users/jcrock/Documents/Codex/Caliber-restaurant-intake`, from `c56bea2`.
Owner supplied `/Users/jcrock/Desktop/restaurant-nutrition-data.zip`.
Read `docs/data-intake/restaurants-2026-11-01/README.md`: 200 restaurants,
1,839 items, 144 chains below 10 items, one cross-chain duplicate item ID.
Aggregate and per-chain items match and numeric fields are structurally valid;
official-source spot checks nevertheless found macro/serving-inclusion issues.
All sources declare `official-public`, without the completed rights review
required by the existing importer/ADR-015. Raw production import fails the
100-source bound, and a one-chain probe correctly rejects its license status.
Do not relabel sources approved, infer grams, or call this full-menu coverage.

Committed artifacts are an inventory, reproducible audit and correction/recheck
brief, not raw production menus. The ZIP stays outside Git; its SHA-256 is in the
report. Archive programs were inspected as text only and never executed. App
resources, FUEL-13, user data and schemas remain unchanged. Existing importer
tests pass 23/23; CSV preparation tests pass 12/12; the report reproduces byte for
byte. The foundation linter passed. No Xcode checks are
relevant to this intake-only change. Owner was asked whether Gemini has explicit
permission references and questioned the requirement for factual nutrition.
Clarified using U.S. Copyright Office guidance: facts are not copyrighted, and
a permission letter is not automatically required per chain. A source review
can document a facts-only basis; this intake does not approve all source access
conditions, copied expression or dataset rights. The existing importer gate is
unchanged. Source accuracy and serving-scope corrections independently remain.
Next: independently reconcile source rows/serving scope and collect rights
evidence for Chipotle/LongHorn, then prepare a reviewed subset through the
existing CSV workflow. The prepared Gemini prompt has not been dispatched.

## Diary headers, swipe metrics, and widget lookbook — 2026-11-01

Current branch: `codex/v2-meal-headers` in
`/Users/jcrock/Documents/Codex/Caliber-v2-meal-headers` (seed `ccd74c1`). The
implementation commit is `734da57` (`feat(diary): center meal headers and
swipe nutrition metrics`).
owner requested centered Breakfast/Lunch/Dinner/Snack headers, data cards that
can swipe between information, and a phone widget lookbook. `DiaryView.swift`
centers each meal title, shows its saved entry count and recorded calories, and
uses visible labeled Copy/Add controls with adaptive stacking. The daily
nutrition summary value area pages through saved Calories, Protein, Carbs and
Fat totals. Named metric buttons, previous/next controls, VoiceOver adjustable
and custom actions, and the touch swipe are alternatives. Only the summary value
panel captures horizontal gestures; the diary rows keep their edit/delete
behavior. Content changes without a sliding animation. No health math or
storage changed.

The Graphite/Frost concept is in
`design/lookbook-v2/cards-and-widgets.html` with its CSS/JS, and the five-page
PDF handoff is `output/pdf/Caliber-Cards-and-Widgets-Lookbook.pdf`. It uses
fictional values and shows small/medium/large nutrition widgets plus a locked
privacy preview. WidgetKit remains unimplemented; there is no App Group, shared
snapshot, entitlement or save action. Claude recommended a shared metric
selector so meals remain comparable. Gemini proposed a per-meal Overview / Macro
/ Foods pager and contributed widget size, privacy, refresh and accessibility
ideas. We chose Claude's single shared card pattern to keep gestures out of
List rows; the widget concepts combine both reviews.

Validation: HTML parsed with unique IDs; JavaScript syntax passed; SwiftFormat
and the foundation linter passed; strict Dynamic Type lint reported 224 files,
zero errors/warnings. The latest isolated incremental iOS Simulator build exited
0 after the last source edit (with Xcode's existing non-fatal
`Supported platforms ... is empty` destination warning). The focused UI suite
passed 3/3 on the isolated `Caliber Compact QA` iPhone SE simulator, covering
all meal headers, 48pt actions, Frost accessibility-size layout, and metric
button/arrow navigation. A separate one-case rerun passed with a direct
finger-swipe assertion, and the Breakfast header screenshot was exported and
visually inspected. The earlier result bundle has 0 passed / 1 failed runner
record (`Testing was canceled`) and is superseded by the passing runs, not
hidden. The final five-page PDF was rendered and visually reviewed; a
locked-preview text/button overlap found on page 4 was corrected and re-rendered.
Do not use or modify the owner's iPhone 17 simulator. No owner build was
installed. Final git checks and commit remain.

See `docs/parallel/diary-widgets/SESSION.md` for exact evidence, peer review and
the remaining checklist.

## Owner local preview updated — 2026-10-31

Explicit owner request to see a local build is fulfilled with verified84edf55 in
the personal source checkout and ordinary iPhone17 simulator. Existing data and
all three local edits are preserved; the Graphite Diary is open in Device Hub.
Read parallel/v2-window-beta/LOCAL_PREVIEW_2026-10-31.md. No test fixtures or new
peer patch was installed. Claude7e8813a/Gemini955e1f3 are delivered but still
await integration/review; iPad window QA and the approved later sequence remain.

## Window layouts and Frost review batch — 2026-10-31

Owner explicitly requested Codex to select next work and involve the LLMs.
Use parallel/v2-window-beta/README.md, CODEX_TASK.md and SESSION.md for ownership
and actual dispatch state. Codex owns real iPad window QA/integration; Claude
compact-height Diary header; Gemini document-only independent Frost food review.
No app source or personal build is changed by preparing the coordination pack.
All prior width verification and safety/data/provider limits remain in force.

## Verified responsive V2 checkpoint — 2026-10-31

The owner resumed work after the overnight window. Its expired automation was
deleted. Current work is in /Users/jcrock/Documents/Codex/Caliber-v2-responsive,
branch codex/v2-responsive, based on published native ab5320b. Read
parallel/v2-responsive/SESSION.md and VERIFICATION.md for actual test/device
state. Native compact-phone/tablet rotation and draft checks pass; corrected
full-screen image reruns pass2/2 on each device. Width changes are presentation
only; no owner preview installation. All QA jobs are finished.
Claude e9d41cb and Gemini cf70732 deliveries are already integrated/reviewed;
neither has a newly dispatched responsive task. Preserve Gemini's dirty clone.
Independent Frost beta, real split windows and graphics/widgets are not complete.

## Native V2 iPhone checkpoint - 2026-10-31 03:16 UTC

Read docs/parallel/v2-native/SESSION.md and VERIFICATION.md. Diary/food and reviewed
peer surfaces are integrated in /Users/jcrock/Documents/Codex/Caliber-v2-native,
branch codex/v2-native-integration. Full7food UI cases,243unit and48theme tests pass;
default/AX captures are reviewed. The deep-scroll system audit is inconclusive,
separately documented from passing native growth/bounds checks. Known inherited
unit-preference/width risks remain in BACKLOG. No physical-owner build changed.
Responsive pack is PREPARED, not dispatched; use the latest SESSION for actual
published seed/role/device state before starting another task.


This file is the shared checkpoint for work across Codex and Claude. The Git
checkout and its commits are the source of truth; neither assistant inherits the
other's chat automatically, and there is no automatic credit-exhaustion trigger.

## Lookbook V2 design checkpoint delivered - 2026-10-30

Full seven-screen Graphite/Frost V2 and required state appendices are reviewed in
[VERIFICATION](parallel/lookbook-v2/VERIFICATION.md). The 15-page PDF is in
output/pdf/Caliber-Lookbook-V2.pdf, canonical source design/lookbook-v2/index.html.
Claude 30ff32b and Gemini aecebd9 are integrated. Codex's 322 browser layout/target
checks pass, plus focused food/meal/privacy preview checks. Native tests are not
claimed. No installed app, personal simulator, models, providers or flags changed.

Next is the [native iPhone pack](parallel/v2-native/README.md). Same eight-hour
session/deadline and simulator boundaries apply. Native peer assignments must be
sent/verified, not assumed dispatched from file creation. Read SESSION for latest
actual dispatch status. After native iPhone checks: iPad/resizing, then Frost beta.

## Active Lookbook V2 session — 2026-10-30

Owner approved eight hours of coordinated work and phone follow-ups. Use
[the V2 coordination pack](parallel/lookbook-v2/README.md) and its
[session checkpoint](parallel/lookbook-v2/SESSION.md), not the old pass2 task
assignments. Common published seed is 137e3bf; Codex branch codex/lookbook-v2 in
/Users/jcrock/Documents/Codex/Caliber-lookbook-v2. Claude and Gemini native-app
assignments were actually sent and both visibly started; see
[dispatch evidence](parallel/lookbook-v2/DISPATCH_LOG.md). Do not duplicate them.
First checkpoint: complete reviewed full-app HTML/PDF V2 and role handoffs,
before installed-app changes. Then native iPhone, iPad/resizing and Frost beta.
All privacy/provider/data-license/live-calculator gates remain unchanged.

## Local build update — 2026-10-29

The local Xcode checkout is updated and the exact verified app is installed and
open in the ordinary iPhone 17 simulator, without test/fixture arguments. All
three original local edits and original model/photo/settings files were preserved.
The new food hub is visible with existing recents; no new food/goal was saved.
The owner requested updating the local build. Codex fetched and merged Gemini
`41b3985` (food-entry hub, quick review, explicit macro fields, future-date fix)
and Claude `4de64f3` (new Helios motion/glass library and contrast tests) into
`codex/pass2-integration`. See [LOCAL_BUILD_UPDATE](parallel/pass2/LOCAL_BUILD_UPDATE_2026-10-29.md)
for verification, delivered scope, backups and remaining motion adoption work.
Gemini's follow-up is integrated; do not restart that assignment. New motion
primitives compile but remain unadopted in real app screens pending render and
full-gradient contrast validation. Codex retains final app/native integration.

## Manual peer dispatch — 2026-10-28

The owner explicitly asked Codex to prompt the already selected Claude/Gemini
chats through their laptop. Both messages were sent through the native apps;
Claude acknowledged and began commands, and Gemini began inspecting date handling
and the dedicated simulator. See [DISPATCH_LOG](parallel/pass2/DISPATCH_LOG.md).

Gemini delivery `577cc28` (implementation `4457beb`) has been fetched; it is not
merged. Its follow-up owns future-date labeling plus final isolated food UI checks
on Food Entry QA. Claude motion/glass `63ed08b` is fetched, unmerged and natively
untested; its follow-up owns measured contrast/accessibility checks within that
new package code. Codex retains app integration/builds; preserve branch/file and
simulator ownership. Do not restart either assignment from scratch.

## Pass 2 delivery checkpoint — 2026-10-28

Integrated code is `3a5e7bd` on published `codex/pass2-integration`; the owner's
local-preview source is updated with all three original edits preserved. Final
native evidence and remaining gates are in
[INTEGRATION_VERIFICATION](parallel/pass2/INTEGRATION_VERIFICATION.md). The exact
verified app is open on **Caliber Lookbook QA** with fictional in-memory data.

At this earlier delivery checkpoint Gemini's branch was still at seed; the
new manual-dispatch checkpoint above supersedes that status. A simulator
installation overlapped that peer's ordinary-iPhone run. Codex stopped using the
ordinary simulator; Gemini must rerun final UI checks on its new dedicated
**Caliber Food Entry QA** (`4387978B-A0DF-4A04-9525-19805A4340E0`) before handoff.
See the role brief and shared Mac simulator ownership section. Integrate its
reviewed branch next; leave providers/Health/menu-license gates unchanged.

## Goal setup implementation — Codex, 2026-10-28

The guided starting-goal slice is implemented on `codex/goal-setup-pass-2`.
See [GOAL_SETUP_VERIFICATION](GOAL_SETUP_VERIFICATION.md) and
[Codex handoff](parallel/pass2/CODEX_HANDOFF.md) for complete files, tests and
additive storage limitations. Existing users retain targets until an explicit
save. New metadata requires future archive/canonical adapters before export or
live cutover. Claude has delivered visual branch `d956269`; Codex integrated and verified its native changes on macOS. See
[pass 2 verification](parallel/pass2/INTEGRATION_VERIFICATION.md). Gemini's delivery/follow-up status is now recorded in the manual-dispatch
checkpoint above.

## Parallel pass 2 — owner authorized, 2026-10-28

The owner authorized implementation and task distribution across Codex, Claude
Opus 5.5 and Gemini 4 Argon, using separate GitHub branches/clones.
[The coordination pack](parallel/pass2/README.md) is the current ownership and
dispatch contract. Codex owns goal setup and integration, Claude the next native
visual pass, Gemini food-entry convenience. Shared base also incorporates
Claude's scanner/accessibility and grammar fixes through `c9413af`. The owner started the external chats; Codex subsequently sent authorized
follow-ups through the native apps and verified both running. See DISPATCH_LOG.
The first batch excludes water/Health, adaptive coaching, micronutrients, meal
planning, new providers and broad menu data imports. Existing P1/P2 gates remain.

## Recording review — Codex, 2026-10-28

The owner supplied three screen recordings and asked for missing functional and
visual features to gather, not implementation. The comparison against the current
native build (`955a91b`) is in [RECORDING_FEATURE_REVIEW](RECORDING_FEATURE_REVIEW.md),
on isolated branch `codex/recording-feature-review`. It includes 28 functional
opportunities, 12 visual patterns, timestamps, missing/partial/core-only status,
existing brief IDs and a proposed sequence. Visible-only menu/promotional items
are distinguished from demonstrated screens. No app code, math, schema, feature
flag, user setting or provider changed. Do not treat the proposed sequence as
approval to enable P1/P2 work. Original videos/frames and personal health/account
or purchase details are not in Git. The main checkout's existing scheme and
localization edits remain untouched.

Recommended next slice: short guided goal setup over the current calculator,
then a shared food-entry workspace; retain existing editable macros, food reuse,
recipes, charts, photo/notes check-ins and all privacy/safety gates.

## Look-book alignment — Codex, 2026-10-28

The owner's latest request explicitly authorizes improving the native visuals to
match their attached **Helios Look Book.pdf**. This supersedes the older request
to leave UI files to Claude. Work is isolated on `codex/lookbook-polish` in
`/Users/jcrock/Documents/Codex/Caliber-lookbook-polish`, based on workout-engine
commit `38624a6` and merged with Claude's `astra/foundation` through `1e9f4a9`.
Do not overwrite Claude's branch. See [LOOKBOOK_ALIGNMENT](LOOKBOOK_ALIGNMENT.md)
for source files, verification, screenshots, remaining differences and commands.
The local preview checkout retains the owner's unrelated localization edits.
Local verification: 225 native unit cases, 16 distinct UI scenarios passing
across the broad run and corrected focused reruns, both theme walkthroughs,
AX5/growth audits, Helios/Foundation packages, 130 Python tests and static checks.
There are no model migrations, provider changes, new health formulas or licensed
menu imports. FUEL-13 and production menu gates remain unchanged.

## Parallel workout engine branch — Codex, 2026-10-27

The owner authorized separate work while Claude handles visuals. Codex is working
in `/Users/jcrock/Documents/Codex/Caliber-workout-engine` on
`codex/workout-engine`, based on `116d46a`. Its models/services and pure tests
and local verification are described in [WORKOUT_ENGINE_HANDOFF](WORKOUT_ENGINE_HANDOFF.md) and
[WORKOUT_ENGINE_VERIFICATION](WORKOUT_ENGINE_VERIFICATION.md). The first engine commit changed no screens or colors. The owner's subsequent
manual-exercise request adds only the picker shortcut and shared creation form;
see [CUSTOM_EXERCISE_MENU_VERIFICATION](CUSTOM_EXERCISE_MENU_VERIFICATION.md). Keep Claude's navigation/visual work on `astra/foundation`;
integrate the branch deliberately after reviewing its checks and adapter
contract. The engine commit `23db8f2` passed all three GitHub jobs (run
40614365696). The new CSV guide is [RESTAURANT_MENU_TEMPLATE](RESTAURANT_MENU_TEMPLATE.md).
The owner also requested updating the local Xcode build; preserve the unrelated
scheme preference and both generated localization catalogs when refreshing that
checkout, and keep Claude's remote visual branch separate. This branch's CI publishes no shared screenshot branch, so Claude's
visual evidence is not overwritten.

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
- Look-book polish on 2026-10-27 (Claude, runs 23-29): showcase screenshots
  (`--showcase-fixture`, plus `--showcase-workout` for `graphite-Workout-default`);
  Progress draws the §9.3 trend line; Fits your <meal> uses 45-100% of calories
  left; list screens put `CaliberHeader` in the first section header; the
  scanner is a full-screen cover with a close button; the workout grid is
  Set · Previous · weight · Reps with RPE beside warm-up, and finished sets keep
  a filled tick that reopens them; each exercise card shows its best logged set;
  Train's card lists the last workout and "Repeat" copies it as open, pre-filled
  sets (`TrainingWorkoutLogger.repeating`, unit-tested).
- Known intermittent audit failures, all at AX5 and present before this work:
  "Dynamic Type partially unsupported" on the scanner's Enter Barcode heading,
  no-camera text and Retry Camera (also with the full-screen cover) and on Exit
  Demo; plus an occasional failed tap on `accountEmail`. They pass on some runs
  with no code change; run 30 flagged Stack the same way. D113 now fails only
  issues that repeat on a second audit pass, printing both passes. Run 32: the
  scanner's three flags then repeated on pass 2 (Exit Demo and Stack did not), so
  in that state they are consistent. Next step needs a Mac: open the scanner at
  AX5 in the simulator with Accessibility Inspector's audit and compare a run
  where it passes. The scanner code has no timers or repeated state updates.
- Owner decision pending: the look book's "best e1RM" needs a formula choice
  (HOW_WE_CALCULATE, training estimates); the app shows the best logged set.
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
