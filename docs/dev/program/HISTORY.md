# Completed phases

Background, not working memory. Rarely read — move material here so `STATE.md` can stay short.

One section per completed phase: what it delivered, its commit range, the gate results, and
anything it deferred.

## A. prerequisites — merged 2026-09-03

Spec: `docs/dev/specs/2026-09-02-program-layer-merge.md` §10 row A, §12.1. Plan:
`docs/dev/plans/2026-09-02-prerequisites/`. Branch `feat/prerequisites`, 28 commits, based at
`cc489e9`, merged as `f811034` through pull request #1. Controller Opus/high, 2026-09-02 to
2026-09-03. Authoritative record: `docs/dev/program/phases/prerequisites/state.md`; session
report `docs/dev/reports/2026-09-03-prerequisites.md`.

**Delivered.**

| Task | Change | Model | Fix rounds |
|---|---|---|---|
| 1 | user settings tier read through `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`; no test redirects `HOME` | Opus | 1 |
| 2 | `tests/run.sh` pins `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_NOSYSTEM`; scratch commits ignore the operator's signing config | Sonnet | 1 |
| 3 | `[DEP-1]` both session skills check their plugin dependencies at Step 0 and stop cleanly | Sonnet | 3 |
| 4 | `[DIST-1]` the `foreman` marketplace is a GitHub source in the tracked `settings.json`; `settings.local.json.tmpl` and its manifest row retired; also closes `[T8-I15]` | Opus | 1 |

Suite 610 → 660, plain run green with `jq` served by a mise shim and with no signing agent
reachable, which is §12.1 satisfied. Verified by the program manager's probe of the worktree
after the summary and again on merged `main`.

**Gates.** 1: 660/0, baseline pass. 2: `GO`, two Important findings fixed in-branch
(`e99c22a`). 3: `VERIFIED WITH CAVEATS`, seven caveats, all recorded, four carried to the
backlog. 4: 24 items flushed to `docs/dev/backlog.md`. 5: eight entries in `docs/dev/CONTEXT.md`,
including the reviewer return-size ratio spec §12.11 asked for (findings files 317,565 bytes
against about 12 KB returned, roughly 1:26). 6: rebase was a no-op, PR #1 opened with the
evidence. 7: report written, worktree and branch removed by the program manager after merge.

**Deviations worth remembering.** The phase edited `POLICY.md` (baseline 610 → 660) and
`STATE.md` on the operator's explicit instruction, against the rule that a phase never edits
them; disclosed in the ledger and the PR. After two 529s killed task 4's fixer mid-work, the
controller committed the fix round itself (`fd90e51`), then had it reviewed. All ten per-task
review packages were silently abridged by a command-rewriting proxy hook on `git`; regenerated
raw before gate 2, filed as `[JUDGE-1]`, fixed structurally in phase B.

**Deferred.** 24 backlog items tagged `[T1-M4]`, `[T1-M5]`, `[T2-R1-M1..4]`, `[T3-M13..15]`,
`[T4R1-M1..3]`, `[BR-3..8]`, `[BR-11..13]`, `[JUDGE-1..3]`. Two are absorbed by phase B by
ruling (`STATE.md`, 2026-09-03).
