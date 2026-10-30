# Gemini Argon on Mac — V2 responsive food flow

Start from published gemini/lookbook-v2-responsive seed in your existing clone.
Read shared README and docs/LOOKBOOK_V2.md. Own responsive.css, food-entry.html,
food-review.html, qa/ and GEMINI_HANDOFF.md only. Do not edit other role files.

Implement a clear food hub (search, barcode, photo mock, restaurant entry,
recents) and editable portion/macros review: meal/date context, original source,
serving amount, calories/protein/carbs/fat fields, explicit Add preview. No
network, real data writes, guessed nutrition or source changes. Mock food is
Demo chicken bowl. Shared fixture is canonical. No real branded menu imports.

Responsive CSS should adapt common board classes at 320/375/390/430/480px,
short landscape and scale=2/3. No truncation/shrinking text to fit; reflow rows,
macros and nav, allow scrolling. Plan iPad/resizing behavior in your handoff;
do not start Android or runtime changes. Add repeatable QA in qa/, using only
existing available tooling. Report tested vs untested honestly; avoid claiming
HTML text stress establishes native Dynamic Type/VoiceOver. Check both themes,
reduced glass, keyboard focus and touch targets. Do not alter system settings.

Do not use the personal iPhone simulator or Codex worktrees. No simulator is
needed in this design slice. Use existing Argon access, no purchases/overages.
Commit/push your branch. Handoff includes exact commit, commands, evidence,
own-file list, limitations, native food-flow mapping and prioritized beta ideas.
