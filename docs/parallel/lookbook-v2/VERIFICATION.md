# Lookbook V2 - reviewed design checkpoint, 2026-10-30

Design phase complete. Native app implementation/testing is the next batch;
none of these passes certifies native Dynamic Type, VoiceOver or release safety.

## Plan delivered
1. Shared synthetic fixture, existing semantic tokens and isolated role branches.
2. Seven complete source boards in Graphite and Frost.
3. Centered Diary energy, balanced macros and clear meal cards.
4. Selected-food/meal-aware hub and editable review preview.
5. Responsive phone and required private/empty/number-free states.
6. Reviewed 15-page PDF, native mapping and bounded later studies.

## Files

```text
design/lookbook-v2/
  index.html, book.css, book.js
  base.css, components.css, responsive.css, fixture.js, board.js
  diary.html, today.html, train.html, stack.html, progress.html
  food-entry.html, food-review.html
  evidence/ (reviewed captures and integration audit)
  qa/ (peer QA source, tests and original reports)
  tools/export_pdf.py
output/pdf/Caliber-Lookbook-V2.pdf
docs/parallel/lookbook-v2/ (tasks, handoffs, session, mapping, studies)
docs/parallel/v2-native/ (next batch contract)
```

## Acceptance evidence

| Criterion | Result | Evidence |
| --- | --- | --- |
| Isolated checkout and actual peer dispatch | PASS | Common seed 137e3bf; DISPATCH_LOG; phone receipt confirmed |
| Reviewed peer deliveries | PASS | Claude 30ff32b (boards b4070ab); Gemini aecebd9 (source 97c233f), merged with authorship retained |
| Five main tabs plus hub/review, both themes | PASS | All 14 main captures in evidence/; native installed app unchanged |
| Centered Diary, balanced macros, four meal cards | PASS | diary-{graphite,frost}-390.jpg; reported kcal preserved |
| 320/375/390/430/480, 100/200/300% text | PASS for browser geometry | 210 cases in integration-layout-audit.json, no page overflow or visible target below 48 CSS px |
| Short landscape and large-text states | PASS for browser geometry | 28 landscape + 84 state cases; total 322 passing cases |
| Empty/no-goals/long names/number-free/locked/off designs | PASS for specified preview states | state-privacy-audit.json, number-free-svg-audit.json and 14 appendix captures; number-free chart description contains no weight values; off removes Stack tab |
| Food identity, nutrients and meal routing | PASS for preview | Breakfast -> hub -> yogurt review retained 200/20/22/4 and 1 cup; change to Dinner updated CTA/return link; manual protein 35 stayed editable |
| Preview never claims a real save | PASS | Clicking Add reports design preview/nothing saved; no storage/network code added |
| Shared preview controls/navigation | PASS | Parent Fuel tab for child boards; theme/state/text/surface context retained on links |
| Static checks and QA helper tests | PASS | lint_foundation.py, gen_tokens.py --check, check_lookbook.py (v1), V2 --static-only, six QA helper unit tests, node --check |
| Complete exported PDF visually inspected | PASS | 15 pages, 2.3 MB, Poppler-rendered pages 1-15 inspected; readable full-height comparison spreads |
| Data/model migrations | NONE | Native Swift, stores, schema, providers, feature flags and personal simulator unchanged |
| Native iPhone/iPad/VoiceOver/Dynamic Type | UNTESTED in this phase | Explicitly assigned next; no HTML claim substitutes for native tests |

## Integration corrections

Codex resolved cross-file requests and issues after reviewing the completed peer
branches: preserved meal and selected food into review, changed meal selection
and CTA together, centralized food identity/values, highlighted parent Fuel,
removed opted-out Stack navigation and locked private timeline timestamps,
restored Today nutrition when Stack is locked/off, removed number-free chart
numeric descriptions and fixed SVG hidden attributes and viewport-based font caps. Large text uses the fully
scaled metric role and reflow; no minimumScaleFactor or hidden page overflow.
Simplified technical product copy. All corrections are on the integration branch,
not on peer-owned design branches.

One browser API session needed a CUA reset. Viewport overview captures sometimes
returned a narrower raster despite correct layout metrics; final overview crops
are taken from the verified 390px full captures. PDF uses full captures. This is
a capture limitation, not a claimed native-device result. PDF is image-based and
untagged; the HTML source provides the navigable/semantic design reference.

The live browser audit checks overflow, selected widths and target geometry.
It is not a comprehensive accessibility certification, typography/contrast proof
for every possible rendered state or native performance benchmark. Stock token
checks and opaque text surfaces reduce known contrast risks; real app audits
remain required. Peer reports describe their own commits, not final integration.

## Run / verify

```sh
python3 -m http.server 8768 --bind 127.0.0.1 --directory design
python3 scripts/lint_foundation.py
python3 scripts/gen_tokens.py --check
python3 scripts/check_lookbook.py
python3 -m unittest discover -s design/lookbook-v2/qa -v
python3 design/lookbook-v2/qa/check_v2_responsive.py --static-only
python3 scripts/verify_phase1.py
```

Open http://127.0.0.1:8768/lookbook-v2/ or the local index.html. Controls select
screen, exact preview width, state, text stress and accessibility surface modes.
Use the bundled Python with reportlab to regenerate the PDF after reviewed source
captures: `python3 design/lookbook-v2/tools/export_pdf.py`. The required PDF create
marker already ran for this operation. Render with pdftoppm and inspect each page.

Next: [native iPhone batch](../v2-native/README.md), then iPad/resizing and Frost
beta. The owner local-preview checkout is preserved with its original three
scheme/localization edits. No app installation was changed for this checkpoint.
