# Christmas appearance verification — 2026-11-01

Branch: `codex/seasonal-christmas`, seed 66017a2. Native execution used only
Caliber Compact QA (SE3, iOS 27), ID
2998CE67-7D71-460B-AD69-76DAA4D014F6, with DerivedData in
`/tmp/caliber-seasonal-derived`. All data shown is the isolated fictional fixture.

| Acceptance criterion | Result | Evidence |
|---|---|---|
| Local December 1 activation, December 31 inclusion, January 1 restoration and annual repeat | PASS | Five Core tests, including parameterized month-boundary vectors; native clock-reversal model tests |
| Local timezone and calendar-midnight scheduling, including DST | PASS | Opposite-offset vectors, three midnight vectors and native timezone refresh test |
| No early season picker or persistent season unlock | PASS | November and January native UI case verifies locked status and absent Christmas/motion controls; source review |
| December mark, badge and motion preference | PASS | December Graphite and Frost UI cases; preference toggled from enabled to disabled |
| Gentle background snow moves, reduced motion stays still | PASS | Native screenshots sampled two seconds apart: exposed background bytes differ for live snow and match for reduced motion |
| Animation obeys visibility, foreground, accessibility and power gates | PASS | Core policy vectors and source review; static branch has no TimelineView |
| Normal logging/navigation remains usable | PASS | Graphite food-add/search route and Frost Progress navigation |
| Native build and focused model tests | PASS | Two model tests in native-running result; final UI builds succeed |
| Formatting, Dynamic Type and whitespace checks | PASS | Strict Foundation formatter; Dynamic Type: 240 files, zero errors/warnings; git diff --check |
| Source bounds and privacy | PASS | At most 22 live flakes, 15fps schedule, eight static flakes, no network, no health math or database changes; decoration ignores taps and accessibility |
| Physical device, battery and minimum-iOS appearance | NOT VERIFIED | Follow-up hardware/OS checks required; simulator evidence does not certify these |

## Runs and artifacts

- `/tmp/caliber-seasonal-core.log`: 5 Core tests passed, including parameterized vectors.
- `/tmp/caliber-seasonal-native-running.xcresult`: two native model tests passed;
  locked November/January and Frost UI cases passed. The original Graphite case
  failed when its test queried a lazy offscreen Add Food button without scrolling.
- `/tmp/caliber-seasonal-december-verified.xcresult`: Graphite UI case passed
  after bounded test scrolling; no production change was required for that failure.
- `/tmp/caliber-seasonal-motion-verified.xcresult`: final Graphite live-motion
  and Frost reduced-motion UI cases both passed, including pixel-sample checks.
- `/tmp/caliber-seasonal-motion-verified.log`: TEST SUCCEEDED.
- `/tmp/caliber-seasonal-commit-lint.log` and
  `/tmp/caliber-seasonal-dynamic.log`: strict formatter and Dynamic Type results.
- `output/screenshots/christmas/`: reviewed Graphite Today/Settings and Frost
  static Today/Settings PNGs, exported from the final native result.

Initial compile checks caught a read-only accessibility environment assignment
and a missing defining-module import. Both were fixed before the successful
builds. The custom Debug-only reduction flag now only adds a motion restriction;
it never disables an OS accessibility preference.

The December theme fixture does not change the simulator date or logging clock;
the Today date may therefore still show November 1 in these screenshots. Release
builds ignore the fixture arguments. See SEASONAL_APPEARANCE.md for exact commands.

No owner local-preview, personal simulator, provider configuration, health
formula, signing/team setting or existing user record was changed. This delivery
does not claim the unrelated widget or Health hardware checks are complete.
