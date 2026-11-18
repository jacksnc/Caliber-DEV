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

## Codex and Claude working together

Codex can hand a bounded task to Claude Code with the repo skill
`.agents/skills/claude-subagent` (headless `claude -p`, one worktree and
`claude/<slug>` branch per task). Both agents follow
`docs/parallel/DELEGATION.md`: Codex leads, owns shared files and integration,
and runs simulator jobs; Claude edits only its assigned paths, never pushes or
merges, and records its work in `docs/parallel/<batch>/CLAUDE_HANDOFF.md`.
