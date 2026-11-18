---
name: claude-subagent
description: Delegate a bounded Caliber task to Claude Code as a subagent (headless `claude -p`) in its own worktree and branch, then review and integrate its work. Use when the owner asks to have Claude do, review, or parallelize part of the work, or for a Codex+Claude batch.
---

# Claude Code as a Codex subagent (Caliber)

You (Codex) stay the lead. Claude works in its own Git worktree on
`claude/<slug>`, only on the paths you give it, and reports back through a
committed handoff file plus a JSON result. The shared rulebook is
`docs/parallel/DELEGATION.md`: read it once per session, because Claude is
given the same file and you both have to follow it.

Script: `.agents/skills/claude-subagent/scripts/claude_delegate.py`. Run it
from your own checkout; below, `$D` stands for that path:
`D=.agents/skills/claude-subagent/scripts/claude_delegate.py`. It needs network
access and writes outside the workspace (the sibling worktree and `~/.claude`),
so request sandbox escalation when you run it.

## When to delegate

- Good: a self-contained slice with clear exclusive paths (a view and its UI
  test, a component, a package module, a doc or review), an independent review
  of your diff, or a second pair of eyes on a failing test.
- Not good: edits to shared files you own (`project.pbxproj`, entitlements,
  `scripts/test_ios.py`, `.github/`, global docs), anything needing the owner's
  device, accounts, hosted services or paid providers, or work that overlaps a
  path you are editing right now.
- The owner's request to involve Claude is the authorization. Don't start a
  delegation on your own initiative without it; suggest it instead.

## Workflow

1. **Check once per machine:** `python3 "$D" doctor`. If `claude` is missing
   or not logged in, stop and tell the owner the setup step it prints.
2. **Prepare the batch.** Commit your current work so the seed is clean. Create
   or update `docs/parallel/<batch>/README.md` with goal, seed, and an ownership
   table that includes Claude's row (copy the shape of
   `docs/parallel/cards-widgets/README.md` on `codex/cards-widgets`). Commit it.
3. **Write the task** to a file: goal, context files to read, the contract with
   your side (names, types, signatures you will rely on), acceptance criteria,
   which checks to run, and what is out of scope. Be specific; Claude can't
   ask you mid-run.
4. **Dispatch:**
   ```bash
   python3 "$D" start today-cards --batch cards-v3 \
     --task-file /tmp/today-cards-task.md \
     --own 'Caliber (DEV)/Views/Today/*' \
     --own 'Caliber (DEV)UITests/TodayCardsUITests.swift'
   ```
   This creates `../Caliber-claude-today-cards` on `claude/today-cards` from
   `HEAD`, appends the brief to `docs/parallel/<batch>/CLAUDE_TASK.md` and a line
   to `DISPATCH_LOG.md` in your checkout, and starts Claude detached.
   Useful flags: `--seed <sha>`, `--read-only` (review only), `--model sonnet`,
   `--effort medium`, `--max-budget-usd 15` (default), `--allow-simulator` (only
   when you aren't running simulator jobs yourself), `--wait` (block; only for
   short tasks).
5. **Keep working on your own paths** while Claude runs. Poll with
   `python3 "$D" wait <slug>` (returns after ≤9 min; exit 2 means still
   running, call it again) or `python3 "$D" status <slug>`.
6. **Review.** `status` shows the structured result (status, commits, checks,
   UNTESTED items, questions), commits since seed, uncommitted files, and paths
   outside ownership. `python3 "$D" check <slug>` must exit 0. Then read the
   real diff: `git -C ../Caliber-claude-<slug> diff <seed>..HEAD`.
7. **Correct, if needed:** `python3 "$D" resume <slug> --message-file fix.md`
   continues the same Claude session with its context.
8. **Integrate** into your branch with `git cherry-pick <seed>..claude/<slug>`
   (or a merge), re-run the checks in your checkout, including Xcode/simulator
   checks, sequentially. Record "<claude sha> reviewed and integrated as
   <your sha>" plus any corrections in `docs/parallel/<batch>/SESSION.md`, and
   update `docs/AI_HANDOFF.md` when the batch ends. Commit `CLAUDE_TASK.md` and
   `DISPATCH_LOG.md` with it.
9. **Clean up** after integration, only when the owner is fine with it:
   `git worktree remove ../Caliber-claude-<slug>`. Keep the branch.

## Running more than one

Use one slug per Claude task, each with disjoint `--own` paths. `python3 "$D" list`
shows them all. Never point two delegations at the same worktree.

## Reporting to the owner

Say what Claude did in your own words, with commit SHAs, check results, and
whatever Claude marked UNTESTED. A source review is not runtime evidence. Report
the spend shown in `status` (an estimate) when it is notable.

## Troubleshooting

- `state: error` with "not logged in": the owner runs `claude auth login`.
- Run ends with `status: needs_input`: answer the questions with `resume`.
- Budget or turn cap reached: `resume` with a higher `--max-budget-usd` or
  `--max-turns`, or split the task.
- Claude was denied a tool it needed: it is listed in the result. Grant it
  narrowly next time with `--allow-tool 'Bash(<prefix> *)'`.
- `stop <slug>` interrupts a run cleanly.
- State lives in `$(git rev-parse --git-common-dir)/claude-delegate/<slug>/`
  (`meta.json`, `run-N.json`, `run-N.stderr`, `run-N.prompt.md`).
