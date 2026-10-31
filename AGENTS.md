# Repository instructions for coding agents

Before changing code, read `docs/MASTER_BUILD_BRIEF.md`, `docs/AI_HANDOFF.md`,
`docs/DECISIONS.md`, `docs/BACKLOG.md`, `docs/MIGRATIONS.md`, and
`docs/HOW_WE_CALCULATE.md`. Then inspect `git status` and preserve every existing
user change. `docs/AI_HANDOFF.md` is the current task checkpoint; update it when
finishing or handing off work.

Keep the app native Swift/SwiftUI with SwiftData and the package boundaries in
`docs/PACKAGE_LAYOUT.md`. Use source protocols and local fixtures where the brief
requires them. Keep secrets out of source control. Never activate hosted services,
send messages, publish, submit, or enable a paid provider unless the owner asks.

Health and nutrition math must follow `docs/HOW_WE_CALCULATE.md`; write focused
tests for calculations and persistence. Do not estimate missing food mass,
restaurant nutrition, or cooking yield. Do not import a menu dataset unless its
reuse permission is documented and reviewed. Keep FUEL-13 off until then.

Before committing, run `python3 scripts/lint_foundation.py`, the relevant package
tests, and the relevant Xcode tests. Use a conventional commit per completed
phase. Never stage unrelated files or use `git add -A` without inspecting every
path first. If tasks are performed concurrently, use separate Git worktrees;
never edit the same checkout from two agents at once.

## Active parallel pass 2

While working on a branch assigned by `docs/parallel/pass2/README.md`, follow its
file ownership boundaries. Claude and Gemini update their role-specific handoff
in that directory instead of competing edits to shared planning documents; Codex
aggregates those into AI_HANDOFF/BACKLOG/DECISIONS/CHANGELOG/method/migration docs.
This changes coordination only; safety, math, licensing and verification rules
above still apply. Report cross-boundary changes to Codex for integration.

## Active Lookbook V2

For branches assigned by docs/parallel/lookbook-v2/README.md, use its V2 ownership
contract. This is a design-first checkpoint; keep native code, generated tokens
and the owner's installed build unchanged until the reviewed book/handoffs.

## V2 native iPhone batch

On branches assigned by docs/parallel/v2-native/README.md, follow that ownership
and simulator contract. The V2 design checkpoint is complete. Translate existing
native screens without copying mock values, changing storage/math/providers or
weakening privacy. Codex integrates; peers update only native role handoffs.


## V2 responsive batch

Branches assigned by docs/parallel/v2-responsive/README.md follow that ownership
and explicit-device contract. Native presentation seed is verified separately;
keep all data/math/providers/flags/privacy gates frozen. Codex owns shared view
widths and footer/navigation integration. Peers must not edit shared app sources
outside their assignment. Preserve original clones and in-progress changes.

## V2 window and Frost review batch

Branches assigned by docs/parallel/v2-window-beta/README.md follow its file
ownership and sequential native-QA contract. Claude owns only compact Diary
header presentation, Gemini owns review documents, and Codex owns window QA and
integration. Do not restart the completed native/food deliveries or edit the
owner's local-preview checkout. Models, formulas, data and privacy gates stay frozen.
