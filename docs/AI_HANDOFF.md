# Caliber AI handoff

This file is the shared checkpoint for work across Codex and Claude. The Git
checkout and its commits are the source of truth; neither assistant inherits the
other's chat automatically, and there is no automatic credit-exhaustion trigger.

## Project state

- Repository: `Caliber (DEV)` inside the `Caliber (DEV) - Project` folder.
- Branch: `codex/phase1-foundation`.
- Latest completed commits: `78691ed` (offline USDA packaged barcode collection)
  and `64f4826` (permission-gated restaurant menu imports).
- Steps 1 and 2 from the owner's requested sequence are complete. Evidence is in
  `docs/PACKAGED_FOOD_VERIFICATION.md` and
  `docs/RESTAURANT_IMPORT_VERIFICATION.md`.
- Step 3 is the reusable recipe/meal builder. It supports USDA and My Foods
  ingredients plus manual portions, batch servings, optional measured cooked and
  raw weights, per-serving or cooked-gram review, diary logging, and personal
  macro edits. Source catalogs stay read-only; saved recipes and diary entries
  use personal snapshots.
- Step 3 implementation and all executed checks are complete. Review
  `docs/RECIPE_VERIFICATION.md` for simulator, native math/persistence/archive,
  formatting, build, and limitation evidence.
- The production restaurant import registry is intentionally empty because no
  licensed/current restaurant source was supplied. Keep FUEL-13 disabled.
- The selected Supabase DEV project is deployed for the previously authorized
  foundation work. Email delivery setup remains pending at the owner's request.
- The working tree may include an unrelated Xcode scheme preference change;
  inspect it and leave it out of phase commits.

## Safe handoff routine

1. Finish the current change and run its checks. Update this file with the commit,
   changed paths, test commands/results, remaining risks, and one next task.
2. Commit the handoff together with the completed work. If a user change is
   present, preserve it and do not include it in the commit.
3. Open this same repository folder in the other coding tool. Before editing,
   have it read `CLAUDE.md` (for Claude Code), `AGENTS.md`, this handoff, and the
   relevant verification docs; ask it to inspect the branch and `git status`.
4. Work sequentially in one checkout. If both assistants must work at once,
   create a separate Git worktree and branch for each, then integrate and test
   the changes in the main checkout.
5. When switching back, ask the other assistant to update this handoff and commit
   its work. Tell Codex: “Read `AGENTS.md` and `docs/AI_HANDOFF.md`, inspect the
   branch/status, and continue from **Next task**.”

## Ready-to-paste Claude Code prompt

```text
Open this Caliber repository. Read CLAUDE.md, AGENTS.md, docs/AI_HANDOFF.md,
docs/MASTER_BUILD_BRIEF.md, and the latest verification docs. Inspect the current
branch and git status before editing. Continue from the “Next task” in the
handoff. Preserve user changes, keep FUEL-13 off without documented data rights,
run the required checks, update docs/AI_HANDOFF.md with evidence and remaining
work, and commit only the completed task files using a conventional commit.
```

## Next task

Step 3 is ready to commit with the paths in `docs/RECIPE_FILES.txt`; preserve the
unrelated Xcode scheme preference change. For restaurant coverage, continue only
after the owner provides or approves a source whose current reuse rights can be
verified; keep FUEL-13 off in the meantime.
