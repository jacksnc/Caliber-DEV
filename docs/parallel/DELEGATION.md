# Codex ↔ Claude delegation protocol

This is the shared rulebook for a session that hands work to the other agent as
a subagent. It works in both directions:

- **Codex leads, Claude is the subagent**: Codex skill
  `.agents/skills/claude-subagent` (`delegate.py start --agent claude`).
- **Claude leads, Codex is the subagent**: Claude skill
  `.claude/skills/codex-subagent` (`delegate.py start --agent codex`).

Both directions use the same script, the same files and the same rules. The
script gives the subagent this file (Claude gets it appended to its system
prompt; Codex gets it inlined in the task). It extends the earlier parallel
batches in `docs/parallel/*/` (pass2, lookbook-v2, v2-native, cards-widgets).

Git is the only shared memory. Neither agent sees the other's chat. Anything
the other side must know goes in a file in this repository or a commit.

## Roles

- **The lead** is whichever agent dispatched the work. It owns the batch: it
  picks the seed commit, writes the task, decides file ownership, reviews the
  subagent's commits, integrates them into its own branch, runs native, Xcode
  and simulator checks one at a time, and updates the global docs
  (`docs/AI_HANDOFF.md`, `docs/DECISIONS.md`, `docs/BACKLOG.md`).
- **The subagent** works only in its own worktree and branch
  (`claude/<slug>` or `codex/<slug>`), only on the paths it was given, and reports
  back through its handoff file and its final structured result.
- **The owner (Jackson) decides scope.** Neither agent activates hosted services,
  paid providers, publishing, submission, or messages outside the repo unless the
  owner asked for it in the current task.
- A subagent never dispatches its own subagent. Only the lead delegates.

## Files for each batch

Every delegation belongs to a batch folder `docs/parallel/<batch>/`:

| File | Written by | Purpose |
| --- | --- | --- |
| `README.md` | Lead | Goal, seed commit, ownership table (owner, branch, exclusive paths), contracts between the pieces |
| `CLAUDE_TASK.md` / `CODEX_TASK.md` | Lead | The exact brief sent to the subagent (the script writes it) |
| `DISPATCH_LOG.md` | Lead | One line per dispatch/resume: time, slug, agent, branch, seed, session id (the script appends it) |
| `CLAUDE_HANDOFF.md` / `CODEX_HANDOFF.md` | Subagent | What the subagent did, on its own branch (format below) |
| `SESSION.md`, `VERIFICATION.md` | Lead | Checkpoint and evidence after integration |

The lead commits its files on its branch. The subagent commits only its handoff
file and its owned paths on its own branch.

## Isolation

- One agent per checkout. The subagent gets a dedicated Git worktree (default
  `../Caliber-<agent>-<slug>`) on branch `<agent>/<slug>`, created from the seed
  commit the lead names. The lead never edits that worktree; the subagent never
  edits the lead's checkout or the owner's local-preview checkout.
- Ownership is by path. A path belongs to exactly one agent in a batch. Shared
  files the lead keeps by default: `*.xcodeproj/project.pbxproj`, entitlements,
  `scripts/test_ios.py`, `scripts/lint_foundation.py` lists, `.github/`, the
  skills in `.agents/` and `.claude/`, and the global docs above. If the
  subagent needs a change in a path it does not own, it stops and asks in its
  result instead of editing.
- The subagent does not push, merge, rebase, reset, switch branches, or touch
  other worktrees. The lead integrates (cherry-pick or merge) after review and
  names the resulting commit in `SESSION.md`, e.g. "5af0a69 reviewed and
  integrated as 6066fa7".

## Subagent working rules

1. Read `CLAUDE.md` or `AGENTS.md`, `docs/AI_HANDOFF.md`, the batch `README.md`
   if it exists, and the docs your task touches. Run `git status` and
   `git log -3` first and confirm you are on your `<agent>/<slug>` branch at or
   after the seed.
2. Stay inside your owned paths plus your handoff file.
3. Follow `AGENTS.md`: health and nutrition math per `docs/HOW_WE_CALCULATE.md`,
   no estimated food mass or restaurant nutrition, FUEL-13 stays off, no secrets.
4. Run the checks you can (`python3 scripts/lint_foundation.py`, the Python unit
   tests, `swift test` for touched packages). Do not run simulator or
   `xcodebuild` jobs unless the task says so, because the lead runs those one at
   a time. Anything you could not run is **UNTESTED**. Say so, and never imply
   it passed.
5. Commit with conventional commits on your branch. Stage paths by name; never
   `git add -A`. Codex's sandbox keeps `.git` read-only, so a Codex subagent
   never commits: it leaves its changes and handoff in the worktree, and the lead
   commits them on `codex/<slug>` after review (`delegate.py commit <slug>`).
   Claude commits normally; if its commit is ever refused, it does the same.
6. Write your handoff, commit it, then return the structured result. If you are
   blocked or need a decision, still commit what is safe, record the question in
   the handoff, and return `status: "needs_input"` or `"blocked"`. You cannot
   ask anyone mid-run; nobody is there to answer a prompt.

## Handoff format

```markdown
# <Claude|Codex> handoff — <batch>/<slug> — <date>

- Seed: <sha>   Branch: <agent>/<slug>   Head: <sha>
- Status: done | partial | needs_input | blocked

## Changed
- <path>: <one line on what and why>

## Checks
- `<command>`: PASS/FAIL (<short evidence>)
- UNTESTED: <what was not run and why>

## Decisions and open questions
- <decision taken, or question for the lead/owner>

## Findings outside my paths
- <issue, evidence, suggested owner>  (do not fix these)
```

## Lead's review and integration

1. `delegate.py status <slug>` shows the run state, the structured result,
   commits since the seed, uncommitted files, and any path outside ownership.
2. `delegate.py check <slug>` must pass before integration. For a Codex
   subagent, review the uncommitted diff, then `delegate.py commit <slug>`. A violation is
   either reverted on integration or explicitly accepted in `SESSION.md`.
3. Read the diff, not only the summary. Re-run the checks in the lead's checkout.
4. To send corrections, `delegate.py resume <slug> --message ...` continues the
   same subagent session with its context, rather than starting over.
5. Record the integration commit and any corrections in `SESSION.md`, and update
   `docs/AI_HANDOFF.md` when the batch ends.
