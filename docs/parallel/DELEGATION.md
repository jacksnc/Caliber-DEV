# Codex ↔ Claude delegation protocol

This is the shared rulebook for a Codex session that hands work to Claude Code
as a subagent (`.agents/skills/claude-subagent`). Both agents read it: Codex
through the skill, Claude because the dispatch script appends this file to its
system prompt. It extends the earlier parallel batches in `docs/parallel/*/`
(pass2, lookbook-v2, v2-native, cards-widgets) rather than replacing them.

Git is the only shared memory. Neither agent sees the other's chat. Anything
the other side must know goes in a file in this repository or a commit.

## Roles

- **Codex is the lead.** It owns the batch: it picks the seed commit, writes the
  task, decides file ownership, reviews Claude's commits, integrates them into its
  own branch, runs native/Xcode/simulator checks one at a time, and updates the
  global docs (`docs/AI_HANDOFF.md`, `docs/DECISIONS.md`, `docs/BACKLOG.md`).
- **Claude is the subagent.** It works only in its own worktree and branch, only
  on the paths it was given, and reports back through its handoff file and its
  final structured result.
- **The owner (Jackson) decides scope.** Neither agent activates hosted services,
  paid providers, publishing, submission, or messages outside the repo unless the
  owner asked for it in the current task.

## Files for each batch

Every delegation belongs to a batch folder `docs/parallel/<batch>/`:

| File | Written by | Purpose |
| --- | --- | --- |
| `README.md` | Codex | Goal, seed commit, ownership table (owner, branch, exclusive paths), contracts between the pieces |
| `CLAUDE_TASK.md` | Codex | The exact brief sent to Claude (the dispatch script writes it) |
| `DISPATCH_LOG.md` | Codex | One line per dispatch/resume: time, slug, branch, seed, session id, budget (the script appends it) |
| `CLAUDE_HANDOFF.md` | Claude | What Claude did, on its own branch (format below) |
| `SESSION.md`, `VERIFICATION.md` | Codex | Checkpoint and evidence after integration |

Codex commits its files on its branch. Claude commits only `CLAUDE_HANDOFF.md`
and its owned paths on `claude/<slug>`.

## Isolation

- One agent per checkout. Claude gets a dedicated Git worktree
  (default `../Caliber-claude-<slug>`) on branch `claude/<slug>`, created from the
  seed commit Codex names. Codex never edits that worktree; Claude never edits
  Codex's checkout or the owner's local-preview checkout.
- Ownership is by path. A path belongs to exactly one agent in a batch. Shared
  files Codex keeps by default: `*.xcodeproj/project.pbxproj`, entitlements,
  `scripts/test_ios.py`, `scripts/lint_foundation.py` lists, `.github/`, and the
  global docs above. If Claude needs a change in a path it does not own, it stops
  and asks in its result instead of editing.
- Claude does not push, merge, rebase, reset, switch branches, or touch other
  worktrees. Codex integrates (cherry-pick or merge) after review and names the
  resulting commit in `SESSION.md`, e.g. "5af0a69 reviewed and integrated as
  6066fa7".

## Claude's working rules when delegated

1. Read `CLAUDE.md`, `AGENTS.md`, `docs/AI_HANDOFF.md`, the batch `README.md` if
   it exists, and the docs your task touches. Run `git status` and `git log -3`
   first and confirm you are on `claude/<slug>` at or after the seed.
2. Stay inside your owned paths plus `docs/parallel/<batch>/CLAUDE_HANDOFF.md`.
3. Follow `AGENTS.md`: health and nutrition math per `docs/HOW_WE_CALCULATE.md`,
   no estimated food mass or restaurant nutrition, FUEL-13 stays off, no secrets.
4. Run the checks you can (`python3 scripts/lint_foundation.py`, the Python unit
   tests, `swift test` for touched packages). Do not run simulator or
   `xcodebuild` jobs unless the task says so: Codex runs those one at a time.
   Anything you could not run is **UNTESTED**; say so, never imply it passed.
5. Commit with conventional commits on your branch. Stage paths by name; never
   `git add -A`.
6. Write `CLAUDE_HANDOFF.md`, commit it, then return the structured result.
   If you are blocked or need a decision, still commit what is safe, record the
   question in the handoff, and return `status: "needs_input"` or `"blocked"`.
   You cannot ask anyone mid-run; nobody is there to answer a prompt.

## CLAUDE_HANDOFF.md format

```markdown
# Claude handoff — <batch>/<slug> — <date>

- Seed: <sha>   Branch: claude/<slug>   Head: <sha>
- Status: done | partial | needs_input | blocked

## Changed
- <path>: <one line on what and why>

## Checks
- `<command>`: PASS/FAIL (<short evidence>)
- UNTESTED: <what was not run and why>

## Decisions and open questions
- <decision taken, or question for Codex/owner>

## Findings outside my paths
- <issue, evidence, suggested owner>  (do not fix these)
```

## Codex's review and integration

1. `claude_delegate.py status <slug>` shows the run state, the structured
   result, commits since the seed, and any path outside ownership.
2. `claude_delegate.py check <slug>` must pass before integration. A violation is
   either reverted on integration or explicitly accepted in `SESSION.md`.
3. Read the diff, not only the summary. Re-run the checks in Codex's checkout.
4. To send corrections, `claude_delegate.py resume <slug> --message ...` continues
   the same Claude session with its context, rather than starting over.
5. Record the integration commit and any corrections in `SESSION.md`, and update
   `docs/AI_HANDOFF.md` when the batch ends.
