# Claude Opus 5.5 — Lookbook V2 handoff

Branch: `claude/lookbook-v2-design`, from seed `137e3bf`. The commit hash is the
branch head that contains this file (see `git log -1 claude/lookbook-v2-design`).
Role: the Today, Train, Stack and Progress boards plus their components. Nothing
outside the owned list was edited, and no other branch was merged.

## Files
- `design/lookbook-v2/components.css`: additive component classes. All colours
  are token variables; there are no hex values, gradients or translucent text
  surfaces.
- `design/lookbook-v2/today.html`, `train.html`, `stack.html`, `progress.html`
- `docs/parallel/lookbook-v2/CLAUDE_HANDOFF.md` (this file)

Each board follows the frozen contract: `data-theme=dark` by default; CSS order
tokens → base → components → responsive; deferred `fixture.js` then `board.js`;
`body.v2-app[data-screen]`; empty `header.app-header` and `nav.app-nav`; and all
content in `main.content#main`. No external URLs, fonts or scripts.

## Boards and states
| Board | Content | States handled (`?state=`) |
| --- | --- | --- |
| Today | Centered energy ring (remaining kcal) with eaten/goal and P/C/F macros; Continue workout; discreet Stack + Weight tiles; daily timeline | populated, empty, no-goals, number-free, long-name, locked (Stack tile + timeline entry become "Locked"/"Private entries"), opted-out (Stack tile and entry removed) |
| Train | Live session header (sets / elapsed / exercise); current exercise with set table (last time vs today), weight and reps steppers, "Log set"; session review queue | populated, empty (routines list, start empty), long-name |
| Stack | Discreet-names strip; today's entries (due/logged, Log/Skip); supply "as you recorded it"; seven-day log with a shape legend; no-advice note | populated, locked (nothing private renders), opted-out (calm off panel), empty, long-name |
| Progress | Range segment; weight trend SVG from `weightSamples` with `<title>/<desc>` and a `<details>` data table; check-in timeline with private photo placeholders and notes | populated, empty, number-free (shape only, no axis numbers or table), long-name |

Themes: Graphite (`theme=dark`) and Frost (`theme=light`) via board.js. Supports
`contrast=more` (stronger borders, primary text for muted copy) and `glass=reduced`
(already opaque). `scale=2|3` switches fixed multi-column patterns to one column
(timeline, tiles, stats, steppers, check-ins, set table rows with labels).

## Fixture use and values I hard-coded (please add to fixture.js)
Fixture keys used: date, shortDate, energy*, protein/carbs/fat*, breakfast/lunch/
dinner/snackEnergy, weight, weightUnit, workoutName, workoutSets. The meal kcal
add up to energyConsumed (400+640+600+200 = 1,840). Codex should promote these
fictional values into `fixture.js`; they are consistent across my boards:
- Workout: 5 of 12 sets logged, 24:10 elapsed, exercise 2 of 4, started 7:45 PM.
  Bench press 80×8, 80×8, 80×7; seated cable row last time 55×10, 55×10, 55×9;
  today 57.5×10, 57.5×9, set 3 in progress; then overhead press and lat pulldown.
- Weight samples are weekly on Fridays, Aug 14 to Oct 30, 2026 (84.2 → 82.4, −1.8 kg).
  Chart points: x = 44 + i·24, y = 16 + (84.5 − v)/2.5 · 112.
- Check-ins: Oct 30 (photo, 82.4), Oct 16 (note, 82.7), Oct 2 (photo, 83.0).
- Stack: Item A weekly on Fridays (logged 8:00 AM), Morning capsule daily (logged
  7:40 AM), Item B evenings, due 8:30 PM. Supply: 3/4, 9/20, 48/60. Week:
  Sat–Thu logged except Mon skipped; Fri due.
- Timeline: weigh-in 7:10, breakfast 7:40, Stack 8:00, lunch 12:30, snack 3:30,
  dinner 6:30, workout 7:45 PM.

## Safety and compliance choices
- Stack shows no amounts, units, concentrations, level curves or calculated
  graphs. Supply is a count the person recorded. "Log as entered" logs the
  person's own entry. A note says Caliber does not recommend amounts or timing.
- Locked: Today shows only "Locked" or "Private entries"; Stack renders no names.
  Opted-out removes Stack from Today. Progress never overlays Stack data, and
  its chart note says no cause is inferred.
- Train labels "Last time" as the person's history, not a prescription.
- Every action is a `<button>` that the shared board.js turns into a "design
  preview; nothing was saved" status. Board links use `data-board-link`.

## Checks (in a cloud container; no Xcode)
- Playwright render QA (script: `/mnt/project-files/lookbook-v2/claude-shots/qa.js`):
  266 renders = 4 boards × both themes × every state × widths 320/390/430 at 1×,
  plus 320/390 at 2× and 3×. Each checks horizontal overflow inside `main`,
  visible `main` targets under 48×48, heading-level skips, console/page errors and
  external requests. **1× and 2×: 0 problems** (except a false positive: the
  visually hidden 2× set-table `thead` reports a clip). **3×: 34 runs overflow**,
  all because base.css card and content padding is in rem (3× = 60 px per side,
  leaving about 80 px inside a card at 320). With an emulated responsive rule
  (`.content{padding-inline:12px}.card{padding:14px}`), 3× gives 0 overflow. See
  "Requests" below.
- Board checks: balanced tags, CSS/script order, data-screen, `#main`, no http,
  no hex in HTML or components.css, and every `var(--…)` defined: all pass.
- Non-text contrast of the data/status/accent colours I use, worst case against
  opaque base/raised/overlay: Graphite ≥ 3.87:1, Frost ≥ 3.59:1 (≥ 3:1 required).
  Text uses only text-primary/secondary/tertiary on opaque surfaces.
- `scripts/check_tokens.py`: PASS. `scripts/check_lookbook.py` (v1): 0 problems.
  `scripts/lint_foundation.py`: cannot run, because it needs `xcrun` (not present).
- Screenshots (390 px; Graphite and Frost; populated, empty, number-free, locked,
  opted-out, plus 320 px at 3×): `/mnt/project-files/lookbook-v2/claude-shots/`.
- Native SwiftUI, Dynamic Type, VoiceOver and simulator checks: **UNTESTED**.
  The HTML font stress is not evidence of native behaviour.

## Accessibility limits
- The energy ring and meters are decorative (`aria-hidden` or `role=img` with a
  label). Totals are in text and an sr-only sentence.
- The chart has `<title>`, `<desc>` and a full data table. In number-free mode
  the table is hidden by design and the desc still contains numbers. Codex may
  want a number-free desc variant.
- The stepper `output`s are static and are not live regions in this preview.
- The seven-day log uses shape (filled, dashed, ring) plus sr-only text, not
  colour alone.

## Requests for other roles
- Gemini (responsive.css): at `scale=3` (and on narrow screens at 2×), cap
  `.content` and `.card` inline padding in px, for example 12–16 px. The shared
  header avatar (374 px at 320/2×) and the nav "Progress" label overflow at
  320 px from 2× up.
- Codex (fixture.js): add the values listed above. Optional: a `data-state-only`
  value for a number-free chart desc.

## Native mapping (for after review)
| Board component | SwiftUI target |
| --- | --- |
| `.energy` ring + `.macro-grid` | Today energy summary / existing Helios MetricTile row |
| `.resume-card` | Today continue-workout card → Train session |
| `.tile-pair` tiles | Today Stack status (respects `StackRuntime.isLocked`) and weight tiles |
| `.timeline` | Today day timeline (new view; read-only from diary, workout, weigh-in) |
| `.session-stats`, `.set-table`, `.stepper` | Train active-session screen and set logger |
| `.privacy-strip`, `.entry`, `.supply`, `.week-dots` | Stack list, supply count, adherence week |
| `.lock-panel` | Stack locked / opted-out states |
| `.segmented`, `.trend-chart` + `.data-table-toggle` | Progress range picker, Swift Charts weight line + accessibility table |
| `.checkin`, `.photo-tile` | Progress check-in list; photo placeholder until a private photo is chosen |

## Original graphics concept (bounded)
Prompt I used for myself: "An original, abstract vector placeholder for a private
progress photo: no body, face or skin; a few soft contour strokes and viewfinder
corners, drawn with existing token colours, legible in Graphite and Frost."
I produced one concept, **Contour frame** (`.photo-tile` in components.css,
inline SVG in progress.html), made from hand-written paths. Critique: it reads
as "photo slot" and stays neutral, but the contours could read as a figure;
if review finds that too suggestive, drop `.contour` and keep only the corners.
No external or AI-generated imagery is used.

Later proposals only: widgets for nutrition with Add Food, resume workout and
progress check-in; a private Stack deep link that opens the lock panel first.
No syringe or dose study was made.
