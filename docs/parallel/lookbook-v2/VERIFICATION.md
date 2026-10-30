# V2 verification - initial checkpoint, IN PROGRESS

| Criterion | Status | Evidence |
| --- | --- | --- |
| Isolated worktree/branches and file ownership | PASS | Common seed 137e3bf on Codex/Claude/Gemini branches; README contract |
| Manual dispatch to actual peer apps | PASS | DISPATCH_LOG; both visibly started; phone alert confirmed |
| Centered Diary in Graphite/Frost | PASS for initial design | evidence/diary-graphite-390.jpg and diary-frost-390.jpg; no native UI claim |
| Default-text Diary at five requested widths | PASS | evidence/diary-width-smoke.json, including corrected 480px dark rerun |
| 200%/300% and short-height/landscape | FAIL / pending | 320px/300% overflow: 521px document; assigned to Gemini |
| All main boards, food hub and review | PENDING | Peer commits not yet delivered |
| States, contrast and accessible controls | PENDING | State designs present; complete render/interaction audit not yet run |
| Existing static checks | PASS | lint_foundation.py; check_lookbook.py (v1 only); gen_tokens.py --check; verify_phase1.py (43 scratch SQL tests) |
| Source syntax | PASS | node --check board.js and book.js; Python AST parse exporter |
| Complete inspected PDF | PENDING | Export source prepared; intentionally no final PDF yet |
| Migrations / installed app | NONE | Design/docs only; owner checkout and personal simulator untouched |

Do not equate existing v1/static-contract passes with V2 responsive/native
certification. New runtime math, providers, schema and feature flags: none.

## Run / inspect

From the V2 checkout, run:

```sh
python3 -m http.server 8768 --bind 127.0.0.1 --directory design
python3 scripts/lint_foundation.py
python3 scripts/gen_tokens.py --check
python3 scripts/check_lookbook.py
python3 scripts/verify_phase1.py
```

Open http://127.0.0.1:8768/lookbook-v2/ for the local book, currently Diary-first.
Other boards require the pending peer integration. Direct diary.html supports
query controls in README. Export command after every capture is reviewed:
`python3 design/lookbook-v2/tools/export_pdf.py` using the bundled Python runtime
with reportlab. Render the resulting PDF with pdftoppm and inspect every page.
The PDF operation marker already ran for this operation; do not duplicate it.
