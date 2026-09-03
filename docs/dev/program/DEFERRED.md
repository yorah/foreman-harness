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
- [ ] **Update the plugin after phase B merges, then restart the PM session.** Condition: the
  phase B pull request has merged. Action: `claude plugin update foreman@foreman` (or remove and
  reinstall), confirm `claude plugin list` shows the new version, then start a fresh
  `/foreman:program` session, because B moves this repository's own state files and a PM still
  running the pre-B skill would look for `STATE.md` where it no longer is (spec §10).
