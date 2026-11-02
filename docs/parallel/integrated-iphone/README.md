# Integrated iPhone verification batch — 2026-11-01

## Latest follow-up status

Claude Opus 5.5 Medium's energy-unit change is integrated locally on this
separate branch. Gemini Argon hit its quota; Gemini 3.8 Flash Medium completed
the assigned read-only review, and Claude independently checked its five
findings. The result is recorded in `MODEL_REVIEW.md` and `GEMINI_HANDOFF.md`.
Energy values still store and calculate as kcal; saved-unit conversion applies
to Diary, food search and copy previews only. The corrected energy run passed
six unit tests and the end-to-end kcal→kJ→kcal UI test; three QA captures were
visually inspected. Strict Foundation, Dynamic Type and token checks pass.
Follow-up QA passes all 244 app unit tests, the three affected FoodShortcuts UI
cases and the Dinner/oats review path. The next serial 91-case rerun completed
with 76 passes and 15 failures; see `VERIFICATION.md` for each case and its
observed stopping point. No owner-local build or personal simulator was
touched.

The earlier checkpoint notes below remain as the history of the original
navigation batch. This follow-up supersedes its “not sent” model-task status.

Owner requested continued progress with Claude receiving the largest suitable
assignment and Gemini a smaller task. Baseline: pushed `e5aaa04` on
`codex/seasonal-christmas`; peers must start from the subsequently published HEAD
of `codex/integrated-iphone-qa`, verified to contain e5aaa04. It contains the reviewed cards/widgets,
Health allowance and weight-unit work; do not merge those ancestor branches again.

| Role | Bounded assignment | State |
|---|---|---|
| Codex coordinator | Separate `codex/integrated-iphone-qa` checkout; test fixes, verification and handoff | Full serial batch complete; 76/91 UI cases pass, 15 failures triaged in `VERIFICATION.md` |
| Available Codex review agent | Read-only widget routing/privacy review, no simulator or file edits | Completed in earlier checkpoint |
| Existing Claude native chat, Opus 5.5 Medium | Energy-display consistency in Diary/search/copy, canonical kcal unchanged | Completed; reviewed and cherry-picked as `26cd3dc` |
| Existing Gemini native chat | Read-only Frost/large-text review | Gemini 4 Argon quota error; Gemini 3.8 Flash Medium completed review in separate checkout; commit `06d365f` handoff is integrated |

Read-only repository check: Claude's previous published cards/widgets branch is
still 5af0a69; Gemini's is b01514e and its dedicated local checkout is clean.
These Git observations do not establish actual native chat/model/usage state.

Both native chats and branches were inspected before dispatch; no duplicate
implementation was started. No usage balance is claimed. Gemini's quota error
did not trigger a purchase or plan change. Claude owned the energy-display
source; Gemini's fallback review owned its handoff; Codex owns tests, shared
planning and integration. Preserve owner local-preview, personal simulator and
all private stores; use only Compact QA 2998CE67-7D71-460B-AD69-76DAA4D014F6.

No provider activation, Health permission request, health formula/schema change,
Stack calculator activation, signing/team change or production release. Source
review and fixture runs do not prove physical widgets, camera or Health behavior.

Next: review and rerun corrected failures individually, beginning with the
AX5 workout/chart paths and missing offline catalog result. Physical-device
widgets, camera and Health behavior remain a later validation.
