# Claude handoff: depth and motion (Helios)

Status: **delivered for review, native build UNTESTED.** Branch
`claude/motion-glass`, stacked on `claude/visual-pass-2` (`d956269`). Nothing
from another stream was merged in. No PR opened and nothing merged. Codex owns
native integration.

Commits:

- `63ed08b` feat(helios): add depth, sheen, motion, toast and celebration primitives
- this follow-up: measured deep-glass contrast, reworked depth/sheen/toast, accessibility and caller contracts

## Environment limits (read first)

This was written in a Linux cloud container with no Xcode, `xcrun`, `swift` or
simulator. **No Swift in this branch has been compiled or run, including the new
tests.** The contrast numbers below come from a line-by-line Python mirror of
`DeepGlassAudit.swift`. It reads the shipped values from `GeneratedTokens.swift`
and uses the same WCAG and compositing formulas as `ColorMath`/`RGBA`. That
mirror is evidence for the design, but it doesn't replace `swift test`.

## Commands for Codex / a Mac

```sh
git fetch origin && git switch --track origin/claude/motion-glass
swift test --package-path Packages/HeliosDesign     # DeepGlassAuditTests, MotionPolicyTests + existing
python3 scripts/lint_foundation.py
python3 scripts/lint_dynamic_type.py --strict Packages/HeliosDesign
python3 scripts/check_tokens.py
# Visual: show HeliosMotionGallery() under Graphite, Frost, Reduce Motion,
# Reduce Transparency, Increase Contrast, VoiceOver and AX5 text.
```

## Checks run here (2026-10-29)

| Check | Result |
| --- | --- |
| `python3 scripts/lint_dynamic_type.py --strict Packages/HeliosDesign` | 22 files, 0 errors, 0 warnings |
| `python3 scripts/check_tokens.py` | PASS, 54 pairs, minimum 5.94:1 (tokens unchanged) |
| `python3 scripts/gen_tokens.py --check` | design tokens are up to date |
| `python3 scripts/test_gen_tokens.py`, `test_lint_dynamic_type.py` | OK, OK |
| `scripts/lint_foundation.py` | not runnable here (stops at `xcrun swift-format`). It doesn't list HeliosDesign files. |
| `swift test` HeliosDesign, Xcode build, UI tests | **UNTESTED** |

## 1. Contrast: the unmeasured gap, closed

**The first draft failed.** Measured with the audit rules, Graphite's draft
depth fails badly. That draft was white top light, a 10% accent wash and a white
sheen across the face. The worst case is an overlay on a deep card over the
stacked glows: primary text 3.33:1, tertiary 1.65:1, carbs 1.06:1. The
"should stay above" claim was wrong. In Frost, the draft's accent wash passed
the minimums but cost up to 0.55:1 of contrast.

**What changed.**

- `DeepGlassComposition` (new, Foundation-only) states each decorative layer as
  data with its peak alpha. `HeliosGlassDepth` draws only these layers, so the
  audit measures what is drawn. The rule is that a layer may only move the
  surface away from the text on it:
  - Graphite gets a bottom shade: the darkest canvas tone, peak 30% at the
    bottom edge, clear above half the height.
  - Frost gets a top light: the highlight at 55% of its alpha, faded out by
    38% of the height.
  - The accent wash was removed in both themes, because an accent wash already
    means "selected" in Helios.
  - Under Reduce Transparency or Increase Contrast there are no layers.
- The sheen no longer crosses the face of the pane. It is a 1.5 pt accent glint
  that runs once along the pane's edge, inside the card padding.
  `deepGlassCard` now pads content by at least that width, so text never sits
  under the glint.
- A toast now sits on the opaque overlay tone with the overlay tint on top,
  instead of see-through glass. Content scrolling underneath can't be
  predicted, so it can't be audited.
- `heliosScrollDepth` no longer dims. Text and chart data near the screen edge
  keep full contrast. It only scales to 95%, and does nothing under Reduce
  Motion.

**`DeepGlassAudit`** (new) uses PaletteAudit's colours and minimums: text and
status 4.5:1, primary advisory 7:1, focus ring and data graphics 3:1, and the
Increase Contrast edge 3:1. It runs them over 55 surfaces per palette with
every layer at its peak:

- each glass level as a deep pane over all 10 `PaletteAudit` backdrops;
- raised and overlay plain glass on a deep card, over each backdrop (a tile or
  pressed control on a card, the maximum overlay state the primitives create);
- the toast, normal and under Reduce Transparency;
- the three opaque fallbacks.

It also reports an error when any layer lowers any colour's contrast on any
surface compared with the same surface without layers.

Results from the Python mirror: no findings in any of the four palettes.

| Palette | Worst primary | Worst tertiary | Worst status | Worst data graphic | HC edge |
| --- | --- | --- | --- | --- | --- |
| Graphite | 9.69 | 4.80 | danger 5.35 | carbs 3.09 | n/a |
| Frost | 16.96 | 5.38 | success 5.03 | training 3.58 | n/a |
| Graphite IC | 9.77 | 5.97 | danger 5.39 | carbs 3.11 | 6.10 |
| Frost IC | 16.84 | 7.60 | success 4.99 | training 3.55 | 6.53 |

Graphite's worst case is an overlay on a deep card over the stacked glows.
Frost's worst case is a deep base pane over the bottom of the first glow.

`DeepGlassAuditTests` pins:

- all four palettes pass;
- primary stays at AAA;
- the no-contrast-loss rule holds on every surface and colour;
- surface coverage, including the brightest Graphite stack and the toast;
- Reduce Transparency and Increase Contrast draw no layers and no sheen;
- layers carry no accent tint;
- the toast is opaque;
- the sheen is an accent glint no wider than the edge.

It also has two regressions proving the audit catches problems: the first
draft's Graphite depth, and a Frost accent wash.

**Pre-existing finding (outside these files; for Codex and the palette
owner).** `PaletteAudit` doesn't model glass nested on glass. In Graphite, a
plain raised tile on a plain card, such as `MetricTile` inside `glassCard`,
already measures below the rules at the stacked-glow backdrop: tertiary 4.44,
carbs 2.85, fat 2.87, training 2.89, peptide 2.94. A pressed overlay on that
tile is lower still: tertiary 3.22, carbs 2.07.

A deep card fixes the two-level case. On a deep card even the heavier one-level
stack (an overlay) measures tertiary 4.80 and carbs 3.09, both passing. The three-level case still fails on a deep card in
Graphite (carbs 2.43) and in Graphite IC (carbs 2.70).

Fixing that needs token or `PaletteAudit` changes, which are out of scope here.
Tokens and generated outputs are unchanged.

## 2. Accessibility behaviour, checked per primitive

| Primitive | Reduce Motion | Reduce Transparency | Increase Contrast | Notes |
| --- | --- | --- | --- | --- |
| `deepGlassCard` / `HeliosGlassDepth` | static anyway | no layers (audited opaque) | no layers, strong edge | layers never lower contrast |
| Edge glint (`sheenTrigger`) | removed | removed | removed | edge only; one sweep per trigger, never loops |
| `heliosEntrance` | fade only, no stagger | n/a | n/a | starts at opacity 0 for about half a second at most |
| `heliosNumericTransition` | crossfade | n/a | n/a | shows the caller's formatted value unchanged |
| `heliosDrawIn` | fade in (0.15 s) | n/a | n/a | at most 400 ms; masks drawing only, data and accessibility summary unchanged |
| `heliosScrollDepth` | nothing | n/a | n/a | scale only, never dims |
| `.heliosPressable` | dims to 75% while pressed | n/a | n/a | shrinks to 97% otherwise; only while the finger is down |
| `heliosRise`/`heliosDrop`, `withHeliosAnimation` | plain fade | n/a | n/a | `heliosAnimation` animates nothing under RM |
| Toast | fades instead of dropping | opaque overlay tone | strong edge from `GlassBackground` | Button with label, hint and `heliosToast` id; VoiceOver announcement; dismiss on tap or escape gesture; 2.6 s, or 6 s with VoiceOver |
| `HeliosCelebration` | ring glow fades in place | n/a | n/a | hidden from VoiceOver; caller announces in text |
| Haptics | play (not motion) | n/a | n/a | system haptics switch still applies |

## 3. Caller contract (documented in source)

- **Toast, haptics, edge glint:** fire only after the save they confirm has
  succeeded, meaning the write returned without error. Never fire them on tap,
  optimistically, or after a failure. A failed save gets an inline error.
  `.selection` is the one haptic that confirms a control choice, not a save.
  Toast text states what was saved and never praises or judges a number.
- **Celebration:** `HeliosCelebration(.personalRecord, trigger:)`. The only
  `HeliosAchievement` is a saved PR from the PR engine (TRN-50, warm-ups never
  count). The type has no case for calorie deficits, weight changes or targets,
  or doses, and a test pins that. Change the trigger once per saved record,
  not when the screen reappears or the record is recomputed on edit. The
  default spark colours are training and accent.

## Files (all inside `Packages/HeliosDesign/` plus this note)

| File | Change |
| --- | --- |
| `Sources/HeliosDesign/DeepGlassComposition.swift` | new: layers as data, toast base, sheen rules |
| `Sources/HeliosDesign/DeepGlassAudit.swift` | new: deep-glass contrast audit |
| `Sources/HeliosDesign/MotionPolicy.swift` | `scrollScaleDepth`, `HeliosAchievement` |
| `Sources/HeliosDesign/SwiftUI/DeepGlass.swift` | depth drawn from the composition; edge glint; minimum padding |
| `Sources/HeliosDesign/SwiftUI/Feedback.swift` | opaque toast base, escape dismissal, contracts, achievement-gated celebration |
| `Sources/HeliosDesign/SwiftUI/Motion.swift` | scroll depth scale-only; haptic contract |
| `Sources/HeliosDesign/SwiftUI/MotionGallery.swift` | uses `.personalRecord`, notes sample-only saves |
| `Tests/HeliosDesignTests/DeepGlassAuditTests.swift` | new |
| `Tests/HeliosDesignTests/MotionPolicyTests.swift` | scroll scale, achievement scope |

Nothing outside Helios was touched: tokens, generated outputs, `PaletteAudit`,
app screens, schemas, shared scripts and planning docs. No migration.

## Adoption checklist (for Codex, after review)

- [ ] `swift test --package-path Packages/HeliosDesign` is green. If
      `DeepGlassAuditTests` disagrees with the numbers above, trust the Swift run
      and send it back.
- [ ] `HeliosMotionGallery()` checked on device in Graphite and Frost, each with
      Reduce Motion, Reduce Transparency, Increase Contrast, VoiceOver and AX5.
- [ ] Use `deepGlassCard` for one hero card per screen, such as the Today fuel
      card, where it also lifts nested tiles in Graphite.
- [ ] Wire toasts, haptics and the edge glint only in the save-success branch of
      the existing logging calls.
- [ ] Use `HeliosCelebration` only once the PR engine saves a record (Train, a
      later batch).
- [ ] UI tests: allow for `heliosEntrance`'s fade-in of about half a second, or
      launch with Reduce Motion on.
- [ ] Decide separately how to handle the pre-existing Graphite nested-glass
      finding.

## Not done

- iOS 26 system Liquid Glass (`glassEffect`): CI's iOS job uses Xcode 16.4, and
  `Glass.swift` avoids system materials on purpose.
- Device-motion parallax: left out (the tokens forbid it under Reduce Motion).
- No effect is wired into app screens. Codex owns that.
