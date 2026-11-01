# Cards, iPhone widgets and Health adjustment verification

Coordinator worktree: `/Users/jcrock/Documents/Codex/Caliber-cards-widgets`.
Branch: `codex/cards-widgets`, seed `e6ba3ec` / role pack `300388e`.
Reviewed deliveries: Claude `5af0a69`, Gemini `b01514e`; independently reviewed
pure Health engine `31c1e63`. Latest integration is the commit updating this report.

## Acceptance evidence

| Check | Result | Evidence / limits |
| --- | --- | --- |
| Separate native Claude/Gemini assignments and actual acknowledgments | PASS | Existing Caliber chats, published peer branches, owned paths and role handoffs; Gemini stayed on Mac |
| Both independent app gap reviews | PASS | CLAUDE_HANDOFF.md and GEMINI_HANDOFF.md; proposals triaged in BACKLOG.md, not treated as ten confirmed bugs |
| Today pages Calories/Protein/Carbs/Fat by swipe and named controls | PASS | TodayInfoCardPagerUITests default-size case, corrected run in `/tmp/caliber-health-cards-second.xcresult` |
| Large text pager controls stack and retain target sizes | PASS | Same run, large accessibility case; speech/VoiceOver and AX5 hand audit still pending |
| Existing app unit/persistence regressions | PASS | First run `/tmp/caliber-cards-widgets-first.xcresult`: 236 Swift Testing cases plus existing XCTest cases passed |
| App + embedded small/medium WidgetKit extension compile | PASS | Native builds and subsequent targeted native test builds, isolated DerivedData; generated widget extension-point and Health purpose string inspected |
| Widget sharing starts off and persists only explicit choice | PASS | WidgetSettingsUITests in corrected second xcresult; captured Frost settings, QA temporary cache only |
| Protected, minimal snapshot; corrupt/invalid/stale/timezone/day rejection and revocation | PASS | Foundation package widget/store tests, including DST midnight, invalid numbers, backup exclusion and oversized/corrupt cache |
| Canonical-kcal allowance formula / precision / DST / 899–900s / local midnight / timezone / missing-data / overflow | PASS | Latest focused Foundation run: 16 tests total including widget and Health cases (`/tmp/caliber-core-verified.log`) |
| Health defaults, explicit allowance, no readable data, no persistence, disconnect race, replacement rather than accumulated credits | PASS | 4 native HealthEnergyModelTests in Health runs; fixture service only |
| Health connect → allowance confirmation → adjustment → displayed base/credit/total | PASS | HealthEnergyUITests corrected scrolling run `/tmp/caliber-health-ui-scroll.xcresult`, 1 UI case plus 4 controller cases; real Health permissions were never requested |
| Immediate ring/breakdown agreement after connecting Health; today/past-day Diary consistency | PASS | Ring assertion run `/tmp/caliber-health-ring-final.xcresult`; expanded today → yesterday → today Diary run `/tmp/caliber-health-diary-final.xcresult` |
| Strict formatting / Dynamic Type lint / clean diff | PASS | `scripts/lint_foundation.py`, strict app/package lint 234 files, strict CaliberWidgets lint 3 files, `git diff --check` |
| Physical WidgetKit Home Screen sizing/redaction/tap/refresh, Health permissions and wearable source reconciliation | PENDING | Not established by app settings screenshots, fixtures or compilation. No release-readiness claim |
| Owner local preview/private stores/personal simulator unchanged | PASS | Local-preview branch and three pre-existing dirty files rechecked; all native tests on Caliber Compact QA |

## Corrections and review

First build caught a nonexistent opaque.surface token in peer widget code. Codex
uses opaque.base, avoids Int(Double) traps, uses the actual snapshot timestamp,
checks privacy redaction for visual and accessibility content and offers a full-
app shortcut at extra-large/larger text sizes. Small widgets use a single root
URL by design. Apple's docs differ by version on small-family Link support;
Gemini's categorical "unsupported" claim is not relied on as a current API fact.
Medium widgets have discrete Fuel/Add links. Xcode small/medium previews use
explicitly fictional fixtures, scoped to DEBUG. No generated images or mock
nutrition are used in the extension's real provider.

Claude's review found no blocking pure-math flaw. Codex added a day-boundary test
where the observation is still fresh, fixed the test calendar's timezone,
documented kcal boundaries, covered DST/fractional/899s/kJ cases and replaced a
trivial repeated-pure-function assertion with changed-reading controller tests.

The first card UI run failed a one-second predicate timing check for no autoplay;
all preceding swipe/tap/value checks passed. An inverted page-change expectation
now waits three seconds and the corrected case passed. The first widget relaunch
test failed because its Progress fixture bypassed welcome only for that launch;
it now completes the normal welcome on relaunch, and preference persistence and
opt-out passed. Health setup initially overshot a short field with full-screen
swipes; smaller bounded drags fixed the test and the full setup flow passed.

Review of the Health screenshot then found a real rendering mismatch: a cached
UI timer date could precede a newly fetched reading and temporarily classify it
as future. Breakdown used current time, while the ring could show the base for
up to a minute. Today and Diary now evaluate with actual render time (the timer
only triggers expiry rerenders). The final UI regression asserts the ring goal
is 2,500 and left is 1,038 for the fictional 2,350 base / 450 active / 300 allowance /
1,462 eaten, alongside the base/credit/total breakdown.

The corrected Health run finished all tests but hung in Xcode's post-test
`simctl diagnose --timeout=600`. Codex terminated only that owned diagnostics
collector after test completion; xcodebuild then finalized its xcresult with
**TEST SUCCEEDED**, exit 0. This did not skip or terminate tests. SDK-version and
known non-fatal SwiftUI keyboard frame warnings remain recorded in logs.

## Reproduce

```sh
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict
python3 scripts/lint_dynamic_type.py --strict CaliberWidgets
swift test --package-path Packages/CaliberFoundation --filter 'activity|widget|Credit'
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,id=2998CE67-7D71-460B-AD69-76DAA4D014F6' \
  -derivedDataPath /tmp/caliber-cards-widgets-derived -parallel-testing-enabled NO \
  '-only-testing:Caliber (DEV)Tests/HealthEnergyModelTests' \
  '-only-testing:Caliber (DEV)UITests/TodayInfoCardPagerUITests' \
  '-only-testing:Caliber (DEV)UITests/WidgetSettingsUITests' \
  '-only-testing:Caliber (DEV)UITests/HealthEnergyUITests' CODE_SIGNING_ALLOWED=NO
```

Do not use the owner's personal simulator, enable real data sharing or request
Health permissions on their device as part of these checks. Hardware review
checklists and setup limits are in IPHONE_WIDGETS.md and HEALTH_ENERGY.md.
