# Deferred checks

Checks that need elapsed time, a live event, or an integration before they can be answered.
**Read this when one comes due, not at every session start** — `STATE.md` names which are close.

A session must never hold itself open waiting for one; the program manager runs them.

Each entry: what is being checked, the exact command or query, and the **condition** under
which it becomes answerable — never a wall-clock time nobody has read.

- [ ] **Re-register the plugin from the GitHub source.** Condition: phase A
  (`feat/prerequisites`) has merged to `main`. Action, from this checkout:
  `claude plugin marketplace remove foreman` (drops the local directory registration written to
  `.claude/settings.local.json` on 2026-09-02), then start a session in this repository and
  accept the trust prompt for the `foreman` marketplace that the tracked `.claude/settings.json`
  now declares, or run `claude plugin install foreman@foreman`. Check:
  `claude plugin marketplace list` shows `foreman` with `Source: GitHub (yorah/foreman-harness)`
  and `claude plugin list` shows `foreman@foreman` enabled. Then restart the PM session so it
  runs the installed skill (spec §10).
- [ ] **Raise the baseline.** Condition: the same merge. Action: set `baseline-count:` in
  `docs/dev/program/POLICY.md` to the count the merged `main` prints for `bash tests/run.sh`
  (the plan expects 634; trust the run, not the plan), with the merge SHA and the date, in the
  same commit as the `STATE.md` row update.
- [ ] **Spec §12.11, carried from the 2026-08-28 spec §15.4: measure the reviewer return-size
  ratio** during phase A, the first phase of this program. Condition: phase A's ledger is
  complete. Action: for each task, compare the size of the reviewer's returned message (in the
  phase session's transcript, which the human has) against the size of
  `docs/dev/program/phases/prerequisites/task-N-review.md`; record the ratio in
  `docs/dev/CONTEXT.md` under a dated heading.
