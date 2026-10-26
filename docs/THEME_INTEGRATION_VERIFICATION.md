# Native Graphite / Frost integration

## Scope and plan

1. Publish the existing app foundation for the owner's Claude workflow.
2. Import Helios tokens/components from Claude's design commit, retaining native services.
3. Apply the themes to real navigation, forms, diary, training, progress and scanner routes.
4. Make typography and layouts adapt to accessibility sizes.
5. Build, exercise isolated data flows, capture native screens, and record limitations.
6. Commit and publish only the reviewed theme slice.

## Files

```text
Packages/HeliosDesign/                  imported tokens, components, palette tests
Packages/CaliberFoundation/             palette adapter and chart colors
Caliber (DEV)/App/FoundationRuntime.swift root theme and isolated test options
Caliber (DEV)/Views/Components/CaliberAppearance.swift
Caliber (DEV)/Views/                    themed native screens and adaptive layouts
Caliber (DEV)UITests/ThemeIntegrationUITests.swift
Caliber (DEV).xcodeproj/project.pbxproj local package wiring
design/                                token source and HTML look book
docs/DESIGN.md                          Claude's design specification
docs/design/                           design references and native captures
scripts/                               token, look-book, typography and fixture checks
.github/workflows/foundation.yml        design gates alongside existing app tests
```

Complete source files are in this checkout. Design source:
`d017a1aaecbad29372bb93ead3ac98cabec153fa` on
`claude/macro-peptide-tracker-prompt-yjhvcw`; unrelated Claude math/service code
was not merged. All five native tabs remain. Food-library, scanner and restaurant
screens inherit the same palette; saved theme preference raw values remain valid.
OLED retains a black canvas. Native list rows are opaque to avoid repeated blur.
Glass cards honor Reduce Transparency; palettes honor Increase Contrast.

## Migration and safety

No model, personal-data migration, calorie/macro calculation, source catalog,
backend, or hosted setting changes. No new licensed menu import. FUEL-13 remains
off. UI launches use isolated preferences and in-memory health stores. Real
camera capture, private photos and live accounts are not used by these tests.
The code does not connect separate health records merely because they share a
color or chart; no new causal or clinical claims were added.

## Verification

Environment: Xcode 27.1, iPhone 17 simulator / iOS 27.0, minimum deployment 17.0.
Build/test logs and xcresult bundles are under `/tmp/caliber-helios-*`.

| Criterion | Status | Evidence |
| --- | --- | --- |
| Existing foundation reachable on GitHub | PASS | `git ls-remote` matches `2db865d048704963034ccd18a84e94a61785ff2a`; repository-scoped token configured in Xcode |
| Simulator app builds | PASS | `/tmp/caliber-helios-build.log`; generic iOS simulator build |
| Design tokens, look book, strict typography lint | PASS | Generated output current; look book 0 problems; 130 app/package files, 0 typography errors/warnings |
| Helios package | PASS | 30 tests, `/tmp/caliber-helios-package.log` |
| Foundation package | PASS with exclusions | Test runs of 3, 32, 56, 12 and 9 tests; two optional full-source measurement tests skipped; `/tmp/caliber-foundation-theme-tests.log` |
| Native math/persistence unit suites | PASS | 10 XCTest and 181 Swift Testing tests in `/tmp/caliber-helios-tests.log`; UI failures from that initial combined run are recorded separately below |
| Architecture contracts and disposable migrations | PASS | `scripts/verify_phase1.py`; 43 disposable SQL tests, token/contracts/link checks |
| Python tooling tests | PASS | 115 tests in `/tmp/caliber-theme-python-final.log`; CLI runner is import-safe for discovery |
| Native theme screenshots and focused audits | PASS within stated scope | Four tests, 0 failures; `/tmp/caliber-helios-ui4.xcresult`; final Frost/functional barcode rerun 2 tests, 0 failures in `/tmp/caliber-helios-final.xcresult` |
| Affected user-flow regressions | PASS | 14 tests, 0 failures; food/barcode/restaurant/customization/recipes/progress/Train/Profile/demo; `/tmp/caliber-helios-regressions.xcresult` |
| Default-size automatic Dynamic Type audit | OPEN | Xcode reports unsupported fonts for several lazy-list nodes, including nodes that cease to resolve during resizing. Full original failures remain in `/tmp/caliber-helios-ui3.xcresult` |
| Physical iPhone, iOS 17 execution, VoiceOver and chart/device budgets | NOT VERIFIED | No minimum-OS runtime or physical-device run in this slice |

Native examples: [Graphite Today](design/native/graphite-Today-default.png),
[Frost Diary](design/native/frost-Diary-default.png),
[Graphite Restaurants](design/native/graphite-Restaurants.png),
[Frost Scanner](design/native/frost-Scanner.png),
[seeded demo chart](design/native/demo-chart.png).

Text-height evidence (points, normal → AX5): Progress 64.3 → 497.3;
Profile 47.7 → 274.7; restaurant disclaimer 47.7 → 274.7.

### Accessibility method and limits

Fixed-size fields and inline-symbol labels were replaced with wrapping/scaling
layouts. Scanner cancellation is a full-width bottom action, and its numeric
field has a short placeholder with full instructions outside the field. Native
restaurant search uses an in-list text field. Workout rows stack vertically at
accessibility sizes. No Dynamic Type size cap was introduced.

The normal-size screenshot runs check text clipping. The AX5 run checks clipping
and the system Dynamic Type audit. A separate fresh-launch test compares actual
rendered paragraph heights at normal size and AX5 for the Progress, Profile and
restaurant text reported by the default-size audit. This is additional evidence,
not a claim that the original default-size audit is green. No audit issue handler
returns true to suppress a reported issue. Investigate the open system-audit
behavior on a second iOS runtime before calling full accessibility acceptance done.
Xcode 27 also logs an unlocated "Invalid frame dimension" warning while entering
the barcode lookup route; no visible clipping or failed navigation resulted in the
focused theme run. Diagnose this on the minimum-supported runtime/device too.

### CI compatibility correction

The first published foundation run failed before compilation because its project
used serialization format 110 while CI is pinned to Xcode 16.4:
[failed job](https://github.com/jacksnc/Caliber-DEV/actions/runs/40376208614/job/121759828469).
The project now uses format 77, matching its existing preferred version and its
object types. This is the Xcode 16 format in the
[Xcodeproj compatibility map](https://github.com/CocoaPods/Xcodeproj/blob/master/lib/xcodeproj/constants.rb).
Local format-77 build passes (`/tmp/caliber-helios-compatible-build.log`). A fresh CI run verifies the pinned older compiler separately from app logic.

## Reproduce

From the repository root:

```sh
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict 'Caliber (DEV)' Packages
python3 scripts/gen_tokens.py --check
python3 scripts/check_lookbook.py
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 scripts/verify_phase1.py
swift test --package-path Packages/HeliosDesign
swift test --package-path Packages/CaliberFoundation
python3 scripts/test_ios.py --output /tmp/caliber-ios-verification
```

The last command runs isolated app/Foundation/Progress/theme suites and writes
an xcresult. To run manually in Xcode: open `Caliber (DEV).xcodeproj`, select the
`Caliber (DEV)` scheme and an iPhone simulator in the top toolbar, then click
Run (triangle). In Profile → Settings choose Graphite (Dark), Frost (Light),
System or OLED. Change simulator text size in Settings → Accessibility →
Display & Text Size → Larger Text. Camera permission/capture requires device QA.

The Frost scanner screenshot reflects the final explicit field-surface/placeholder
contrast fix. Earlier Graphite scanner captures precede that palette-only adjustment.

## Next step

Review the native screenshots with the owner, resolve the remaining audit/device
gates, then resume metric-specific Train editors, previous-performance copy and
the rest timer. The full master brief, all look-book interactions, and all chart
performance gates are not complete.
