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
- [ ] **Re-attribute the baseline to the merge commit.** Condition: the same merge. Note the
  raise itself is already done: phase A set `baseline-count:` in `docs/dev/program/POLICY.md` to
  `660` on its own branch, on the operator's instruction, so it lands with the merge rather than
  claiming a count `main` cannot meet. What is left is the attribution. Action: run
  `bash tests/run.sh` on the merged `main`, confirm it prints `660` (**not** the `634` this entry
  used to name — that figure predated the phase's actual assertion count, and phase A observed
  660 passed, 0 failed, exit 0), and re-attribute the baseline paragraph to the merge SHA and
  date, in the same commit as the `STATE.md` row update. If the merged count is not 660, trust
  the run and not this entry — but then find out why, because phase A's branch was green at 660
  with zero headroom.
- [x] **Spec §12.11, carried from the 2026-08-28 spec §15.4: measure the reviewer return-size
  ratio** during phase A, the first phase of this program. **Done** at phase A's gate 5, recorded
  in `docs/dev/CONTEXT.md` under "Phase A (`prerequisites`) — 2026-09-03". Result: 317,565 bytes
  of findings files against roughly 12 KB of return blocks, an aggregate ratio of about **1:26** —
  the controller absorbed under 4% of what the reviewers wrote. The file sizes are exact; the
  return sizes are counted from the session transcript and include harness framing, so treat the
  ratio as an order of magnitude. The verdicts-only contract holds by a wide margin.
