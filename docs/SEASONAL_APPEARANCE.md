# Automatic Christmas appearance

Christmas decoration follows the iPhone's Gregorian local date: December 1 at
00:00 through December 31 at 23:59:59. January 1 restores the normal appearance.
This repeats every year. There is no Christmas picker, early unlock or stored
activation flag. Normal System/Frost/Graphite/OLED choices stay saved beneath the
seasonal decoration. This is a local-clock feature, not a server/account gate.
If the person changes the device clock/timezone, the appearance follows that
clock as requested; it is not an anti-tampering mechanism.

## In the app

- Sparse six-arm flakes fall slowly behind the shared screen canvas, including
  pushed screens and sheets. They never take taps or enter the VoiceOver tree.
- The Today header has a Christmas badge only during December.
- Settings shows a locked availability message outside December. During
  December it shows the Christmas mark and a Snowfall Motion switch. Turning
  motion off retains a quiet static field; it does not manually switch seasons.
- The seasonal logo has dark/light color assets selected by the existing
  appearance. It is an in-app logo preview; the Home Screen app icon is not
  automatically replaced by this work.

## Clock and accessibility

SeasonalAppearancePolicy is Foundation-only and takes explicit date/timezone
inputs. It deliberately uses Gregorian months even if the interface uses another
locale/calendar. A single observed seasonal model feeds an environment value
through the app. It refreshes on foreground activation, local midnight, system
significant-time-change and timezone-change notifications. A cancellable calendar-
midnight sleep is active only in the foreground; no background polling or network.
The sleep is rescheduled after clock/timezone notifications and handles DST.

Snow is procedural SwiftUI Canvas art: at most 22 flakes, scheduled no faster
than 15fps. Hidden/inactive screens stop scheduling animation. Reduce Motion,
Reduce Transparency, Increase Contrast, Low Power Mode and the optional motion
switch all use a static eight-flake field. System Reduce Motion is read-only and
always honored; a test-only environment flag can further reduce motion, never
turn the OS preference off. The screen/text/series palette and all health math
remain unchanged. No dose graphics or recommendations are added.

Relevant Apple APIs: [Reduce Motion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion),
[significant time changes](https://developer.apple.com/documentation/uikit/uiapplication/significanttimechangenotification),
and [bounded timeline scheduling](https://developer.apple.com/documentation/swiftui/timelineschedule/animation%28minimuminterval%3Apaused%3A%29).

## Data and assets

No database or existing-settings migration. One optional app-private preference
`appearance.christmas.snowMotion.v1` defaults to true; its choice persists between
years. There is no seasonal history or personal data in the scheduler. Home Screen
widgets, Health reads/adjustments and existing logs are unaffected.

The owner-approved infinity/aura mark was refined with the built-in image tool:
the center ray becomes one snowflake, with the two outer rays retained. Originals
and earlier variants are preserved. Exact prompts/provenance and export images
are in design/branding/christmas. Runtime images are in
Assets.xcassets/HeliosChristmasMark.imageset. Falling flakes use native paths,
not animated raster frames or a network resource.

## QA

Use the isolated Caliber Compact QA simulator only. Production uses Date.now and
TimeZone.current; release builds have no test-clock override. Debug date fixtures
require an isolated UI-test launch, with --season-now ISO8601 and --season-zone
IANA timezone. --season-reduce-motion only reduces that effect for a test. These
are not UI settings and do not change the simulator/system date, diary dates or
Health calculations. QA images may therefore show the real November date in the
Today header while exercising a December-only appearance fixture.

Core vectors cover local December/January boundaries, annual repeat, opposite
UTC offsets, invalid date and DST midnight scheduling, plus foreground/visibility/
accessibility/power animation policy. Native model tests cover clock/timezone
refresh and reversal; UI cases cover locked November/January, active December,
Frost/Graphite captures, the motion switch and food/Progress routes. Verify
physical-device smoothness and battery separately; source bounds and simulator
captures are not a hardware performance certification.

```sh
swift test --package-path Packages/CaliberFoundation --filter seasonal
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict
xcodebuild test -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,id=2998CE67-7D71-460B-AD69-76DAA4D014F6' \
  -derivedDataPath /tmp/caliber-seasonal-derived -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  '-only-testing:Caliber (DEV)Tests/SeasonalAppearanceModelTests' \
  '-only-testing:Caliber (DEV)UITests/SeasonalAppearanceUITests' CODE_SIGNING_ALLOWED=NO
```
