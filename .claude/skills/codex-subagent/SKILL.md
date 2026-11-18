---
name: codex-subagent
description: Delegate a bounded Caliber task to OpenAI Codex as a subagent (headless `codex exec`) in its own worktree and codex/<slug> branch, then review and integrate its work. Use when Jackson asks to have Codex do, review, or parallelize part of the work while Claude leads.
---

# Codex as a Claude subagent (Caliber)

You (Claude) are the lead. Codex works in its own Git worktree on
`codex/<slug>`, only on the paths you give it, and reports back through a
committed `CODEX_HANDOFF.md` plus a JSON result. This is the mirror of the Codex
skill `.agents/skills/claude-subagent`, with the same script, files and rules,
so read `docs/parallel/DELEGATION.md` once per session.

Script (shared by both directions):

```bash
D=.agents/skills/claude-subagent/scripts/delegate.py
[ -f "$D" ] || D=~/.agents/skills/claude-subagent/scripts/delegate.py   # older branches
```

Always pass `--agent codex` to `start` (or export `DELEGATE_AGENT=codex`).
`status`, `wait`, `check`, `resume`, `stop` and `list` read the agent from
the delegation's saved state.

## When to delegate

- Good: a self-contained slice with exclusive paths, an independent review of
  your diff, a second opinion on a failing test, or parallel work while you
  keep going on other paths.
- Not good: shared files you own as lead (`project.pbxproj`, entitlements,
  `scripts/test_ios.py`, `.github/`, `.agents/`, `.claude/`, global docs),
  anything needing the owner's device, accounts or paid providers, or paths you
  are editing right now.
- Jackson's request to involve Codex is the authorization. Don't delegate on
  your own initiative; suggest it instead. If you are yourself running as a
  delegated subagent, never delegate.

## Workflow

1. **Check:** `python3 "$D" doctor --agent codex`. If `codex` is missing or not
   logged in, stop and tell Jackson the step it prints.
2. **Prepare the batch.** Commit your work so the seed is clean. Create or
   update `docs/parallel/<batch>/README.md` with goal, seed and an ownership
   table that includes Codex's row. Commit it.
3. **Write the task** to a file: goal, files to read, the contract with your
   side, acceptance criteria, checks to run, out of scope. Codex can't ask you
   anything mid-run.
4. **Dispatch:**
   ```bash
   python3 "$D" start progress-units --agent codex --batch units-v2 \
     --task-file /tmp/progress-units-task.md \
     --own 'Packages/CaliberCore/Sources/CaliberCore/Units/*' \
     --own 'Packages/CaliberCore/Tests/CaliberCoreTests/UnitsTests.swift'
   ```
   This creates `../Caliber-codex-progress-units` on `codex/progress-units`,
   writes `CODEX_TASK.md` and `DISPATCH_LOG.md` in your checkout, and starts
   Codex detached in `workspace-write`. Its sandbox keeps `.git` read-only, so
   Codex is told not to commit; you commit for it in step 6. Network is off inside its sandbox; add `--network` only when
   the task needs it (e.g. SwiftPM resolving packages). Other flags: `--seed`,
   `--read-only`, `--model <codex model>`, `--effort low|medium|high|max`,
   `--wait` for short tasks. Codex has no cost cap flag: usage counts against
   Jackson's ChatGPT plan.
5. **Keep working** on your own paths. Poll with `python3 "$D" wait <slug>`
   (≤9 min per call; exit 2 means still running). In Claude Code you can run it
   in the background and carry on.
6. **Review:** `python3 "$D" status <slug>` (structured result, commits,
   uncommitted files, ownership violations), then `python3 "$D" check <slug>`
   must exit 0, then read the diff:
   `git -C ../Caliber-codex-<slug> diff` plus `git -C ../Caliber-codex-<slug> status`
   for new files. Codex's work is uncommitted. Once it looks right, run
   `python3 "$D" commit <slug> --message "feat(<scope>): ..."`, which commits only
   owned paths and the handoff on `codex/<slug>` and refuses if anything is outside
   ownership.
7. **Correct:** `python3 "$D" resume <slug> --message-file fix.md` continues the
   same Codex thread.
8. **Integrate** into your branch (`git cherry-pick <seed>..codex/<slug>`), re-run
   the checks yourself, record "<codex sha> reviewed and integrated as <your
   sha>" in `docs/parallel/<batch>/SESSION.md`, update `docs/AI_HANDOFF.md`
   when the batch ends, and commit `CODEX_TASK.md` and `DISPATCH_LOG.md`.
9. **Clean up** only when Jackson is fine with it:
   `git worktree remove ../Caliber-codex-<slug>`; keep the branch.

`codex/<slug>` shares the prefix Codex uses for its own lead branches, so pick a
slug that isn't already a branch (`start` refuses an existing one unless you
pass `--reuse-branch`).

## Reporting

Describe Codex's work in your own words with commit SHAs, check results and its
UNTESTED list. A source review is not runtime evidence.

## Troubleshooting

- `state: error` with an auth message: Jackson runs `codex login`.
- `status: needs_input`: answer with `resume`.
- A command failed for lack of network: `resume <slug> --network --message ...`.
- `stop <slug>` interrupts a run. State lives in
  `$(git rev-parse --git-common-dir)/claude-delegate/<slug>/`.
