# Deferred checks

Checks that need elapsed time, a live event, or an integration before they can be answered.
**Read this when one comes due, not at every session start** — `STATE.md` names which are close.

A session must never hold itself open waiting for one; the program manager runs them.

Each entry: what is being checked, the exact command or query, and the **condition** under
which it becomes answerable — never a wall-clock time nobody has read.

- [x] **Re-register the plugin from the GitHub source.** Condition: phase A merged. **Done
  2026-09-03** after the merge of PR #1: `claude plugin marketplace remove foreman`, then
  `claude plugin marketplace add yorah/foreman-harness` and `claude plugin install
  foreman@foreman`. Observed: `claude plugin marketplace list` shows `foreman` with
  `Source: GitHub (yorah/foreman-harness)`, `claude plugin list` shows `foreman@foreman` 0.1.0
  enabled at user scope; this repository's `.claude/settings.local.json` now holds an empty
  `extraKnownMarketplaces`. The PM session restart the spec asks for is the milestone handover
  recorded in `STATE.md`.
- [x] **Re-attribute the baseline to the merge commit.** Condition: phase A merged. **Done
  2026-09-03**: plain `bash tests/run.sh` on merged `main` at `f811034` printed
  `14 files, 660 passed, 0 failed`, exit 0; `POLICY.md`'s baseline paragraph now names that
  commit.
- [x] **Spec §12.11, carried from the 2026-08-28 spec §15.4: measure the reviewer return-size
  ratio** during phase A. **Done** at phase A's gate 5, recorded in `docs/dev/CONTEXT.md` under
  "Phase A (`prerequisites`) — 2026-09-03": 317,565 bytes of findings files against roughly
  12 KB of return blocks, about 1:26. Return sizes were counted from the transcript and include
  harness framing, so the ratio is an order of magnitude, not a measurement to three figures.
- [ ] **After phase B's pull request merges — five steps, in this order.** Condition: the phase
  B PR has merged and the PM has probed the worktree (`STATE.md` names the probe).
  1. **Move the carve-out into the work root.** From the main checkout on `main`, up to date:
     `cp` `docs/dev/program/STATE.md`, `docs/dev/program/DEFERRED.md`,
     `docs/dev/program/phases/roots-and-layout/`, `docs/dev/plans/2026-09-03-roots-and-layout/`
     and `docs/dev/reports/2026-09-03-roots-and-layout.md` into `.foreman/` (as `STATE.md`,
     `DEFERRED.md`, `phases/roots-and-layout/`, `plans/2026-09-03-roots-and-layout/`,
     `reports/…`); `git -C .foreman add -A && git -C .foreman commit`; then `git rm -r` the
     originals, `rmdir docs/dev/program docs/dev/plans docs/dev/reports` (all now empty),
     commit. This is a push to `main` that is not a kickoff dispatch: it needs the operator's
     `AUTH:` line.
  2. **Correct `docs/dev/POLICY.md`** (PM-owned, frozen during B): invariant 6's wrapper list
     gains `foreman-roots` and `foreman-diff`; the Authorization section's sentence about the
     routine kickoff push is replaced — in single mode dispatch writes to the work root and
     pushes nothing; the baseline paragraph re-attributes `baseline-count` to the merge SHA and
     the merged count (the plan's row 12 predicts about 696). Same commit as step 1.
  3. **Update the plugin:** `claude plugin update foreman@foreman` (or remove and reinstall);
     `claude plugin list` must show `0.2.0`. Task 11 bumps the version so this has something to
     update to.
  4. **Verify the post-B read path from this checkout** before trusting it: `foreman-roots
     "$PWD"` (from the main checkout *and* from a worktree — both must resolve to
     `/home/yorah/projects/foreman-harness/.foreman`), then `foreman-state --phase
     roots-and-layout --work-root <that> --head` returns B's ledger head.
  5. **Start a fresh `/foreman:program` session.** A PM still running the pre-B skill looks for
     `STATE.md` where it no longer is (spec §10). The new session's first read is
     `.foreman/STATE.md`; its next action is phase C.
