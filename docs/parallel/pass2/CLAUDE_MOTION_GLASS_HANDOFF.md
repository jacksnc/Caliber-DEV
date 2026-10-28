# Claude handoff: depth and motion (Helios)

Status: **delivered for review, native build UNTESTED.** Branch
`claude/motion-glass`, stacked on `claude/visual-pass-2` (`d956269`) so it
inherits that branch's Helios changes without touching them. No PR opened and
nothing merged; Codex integrates after visual pass 2.

## Environment limits (read first)

Written in a Linux cloud container with no Xcode, `xcrun`, `swift` or
simulator. **Nothing here has been compiled or run.** The SwiftUI was checked by
hand against the iOS 17 / macOS 14 API surface the package targets. No captures
are claimed. Static checks that do run here passed:

```
python3 scripts/lint_dynamic_type.py --strict Packages/HeliosDesign   # 20 files, 0 errors, 0 warnings
python3 scripts/check_tokens.py                                       # PASS (tokens unchanged)
```

`scripts/lint_foundation.py` stops at `xcrun swift-format` here; it does not
list HeliosDesign files anyway.

## Commands for Codex / a Mac

```sh
git fetch origin && git switch --track origin/claude/motion-glass
swift test --package-path Packages/HeliosDesign          # adds MotionPolicyTests
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict Packages/HeliosDesign
# Visual check: show HeliosMotionGallery() (e.g. a #Preview or the dev toggle that shows HeliosGallery)
# under Graphite, Frost, Reduce Motion, Reduce Transparency, Increase Contrast and AX5 text.
```

## Files (all new, all inside `Packages/HeliosDesign/`)

| File | What it adds |
| --- | --- |
| `Sources/HeliosDesign/MotionPolicy.swift` | `HeliosMotionSpeed`, `HeliosMotionPolicy`: the Reduce Motion rules as plain values (testable without SwiftUI) |
| `Sources/HeliosDesign/SwiftUI/Motion.swift` | Curves, transitions, entrance cascade, numeric roll, chart draw-in, scroll depth, pressable style, haptics |
| `Sources/HeliosDesign/SwiftUI/DeepGlass.swift` | `HeliosGlassDepth`, `HeliosGlassSheen`, `HeliosDeepGlass`, `.deepGlassCard(...)` |
| `Sources/HeliosDesign/SwiftUI/Feedback.swift` | `HeliosToast` + `.heliosToast(_:)`, `HeliosCelebration` |
| `Sources/HeliosDesign/SwiftUI/MotionGallery.swift` | `HeliosMotionGallery` review screen with sample data |
| `Tests/HeliosDesignTests/MotionPolicyTests.swift` | Policy tests (Reduce Motion, stagger cap, 400 ms draw-in, toast timing) |

No existing file changed. Tokens, `tokens.json`, generated outputs, Today,
Progress, tab bar, header, models, services, routes and identifiers are
untouched. No migration.

## Design

The canvas stays static (as `Background.swift` intends). Motion only answers
something the person did, and nothing loops.

**Depth.** `deepGlassCard` is `glassCard` plus two static layers drawn between
the glass tint and the content: a highlight caught along the top edge, and a
faint accent refraction in the corner nearest the palette's ambient glow
(top-left in Graphite, top-right in Frost). Both use palette tokens. They draw
nothing under Reduce Transparency (opaque fallback unchanged) or Increase
Contrast (the strong edge stays the cue). Meant for one hero card per screen,
not every card.

**Sheen.** `deepGlassCard(sheenTrigger:)` sweeps one diagonal band of light
across the pane each time the trigger changes (meal logged, dose taken). It is
behind the text, so contrast is never reduced, and it is removed under Reduce
Motion, Reduce Transparency and Increase Contrast.

**Motion.** All durations and springs come from the `motion` tokens.

- `.heliosEntrance(order:)`: cards fade in, rise 14 pt and settle with the house
  spring, cascading 37.5 ms apart (capped at 4 steps, 150 ms). Reduce Motion:
  fade only, no stagger.
- `.heliosNumericTransition(value:)`: digits roll (`numericText`). Reduce Motion:
  crossfade.
- `.heliosDrawIn()`: a chart is revealed left to right in 400 ms (the brief's
  limit). Reduce Motion: fade in.
- `.heliosScrollDepth()`: cards ease back to 95% and dim to 70% as they pass
  under the screen edges. Reduce Motion: dim only. Increase Contrast: no dim.
- `.buttonStyle(.heliosPressable)`: tappable tiles shrink to 97% and spring back.
  Reduce Motion: dim instead.
- `heliosRise` / `heliosDrop` transitions and `withHeliosAnimation` become plain
  fades under Reduce Motion. `.heliosAnimation(_:value:)` animates nothing then.

**Haptics.** `.heliosHaptic(_:trigger:)` and a `condition:` variant cover the
brief's moments: dose logged and meal logged (success), set complete (medium
impact), personal record (heavy impact), rest ended (rigid impact), selection,
limit reached (warning). They play under Reduce Motion; the system haptics
switch still silences them.

**Toast.** `.heliosToast($toast)` floats a confirmation on deep overlay glass at
the top, drops in (fades under Reduce Motion), plays its haptic, posts a
VoiceOver announcement, and clears after 2.6 s, or 6 s with VoiceOver on. Tap
dismisses it. Identifier: `heliosToast`. The caller passes localized text.

**Celebration.** `HeliosCelebration(trigger:)` layered around a badge or ring
fires twelve sparks in the data colours once per change. Reduce Motion: an accent
ring glows and fades in place. It is decorative and hidden from VoiceOver, so the
caller announces the achievement in text (the toast does this).

## Suggested adoption (not applied; needs the owners' go-ahead)

These touch files owned elsewhere, so they are only recommendations for Codex
to apply after visual pass 2 lands:

1. Today hero card (`TodayFoundationView.swift`): `.glassCard()` to
   `.deepGlassCard(sheenTrigger: <eaten kcal>)`, and add
   `.heliosNumericTransition(value:)` to the kcal-left number.
2. Today dose tile: wrap in `Button` with `.heliosPressable`. After a dose is
   logged, set a `HeliosToast(symbol: "syringe", message: "Dose logged", haptic: .doseLogged)`
   on a `.heliosToast` at the root.
3. Today and Progress cards: `.heliosEntrance(order:)` by position (eager
   stacks only).
4. Progress charts (`WeightTrendChart`, Calories card): `.heliosDrawIn()`.
5. Train (frozen in batch 1): `HeliosCelebration` + `.personalRecord` haptic
   for TRN-50 PRs, `.setComplete` and `.restEnded` haptics.
6. Add `HeliosMotionGallery()` next to `HeliosGallery()` behind the developer
   toggle.

UI tests: the entrance starts each card at opacity 0 for up to about 0.45 s.
Existing `waitForExistence` calls should cover that; if any test taps
immediately, launch with Reduce Motion on or skip `heliosEntrance` under the
UI-testing launch flags.

## Not done

- iOS 26 system Liquid Glass (`glassEffect`). CI's iOS job builds with Xcode 16.4,
  which lacks that API, and `Glass.swift` deliberately avoids system materials
  because they gray Graphite. Worth revisiting as an opt-in for floating
  controls (tab bar, toasts) once CI moves to Xcode 26.
- Device-motion parallax on glass: left out on purpose (the tokens forbid
  parallax under Reduce Motion, and it costs battery).
- PaletteAudit does not model the depth layers. They only brighten the top of
  a pane by at most about 11% white in Graphite, so text contrast should stay
  well above the audited 5.94:1 minimum, but this has not been measured.
