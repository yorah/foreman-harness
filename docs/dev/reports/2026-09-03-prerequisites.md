# Phase `prerequisites` — session report

**Date** 2026-09-02 to 2026-09-03. **Branch** `feat/prerequisites`, based at `origin/main`
`cc489e9`, 28 commits. **Worktree** `.claude/worktrees/prerequisites`. **Controller** Opus, high
effort.

**Outcome: complete, merged.** All four tasks passed and all seven gates are done. The phase
ended at **https://github.com/yorah/foreman-harness/pull/1**, which the program manager merged
after its probe as `f811034`, per spec D5 and `POLICY.md`'s integration rule; the phase was closed
at `06170ef`. The authoritative record is
`docs/dev/program/phases/prerequisites/state.md`; this file is the session-level record.

The body below is the phase session's own account, written at PR-open time and preserved in its
voice. Its "For the program manager" hand-off is answered in **Program manager's close** at the
end of this file.

## What landed

| Task | Commits | Verdict | Fix rounds |
|---|---|---|---|
| 1 — user settings tier via `CLAUDE_CONFIG_DIR` | `13dce8e..0c6f90d` | Spec ✅ / Approved | 1 |
| 2 — runner pins git configuration | `8273545..57f5323` | Spec ✅ / Approved | 1 |
| 3 — `[DEP-1]` dependency check at skill entry | `a03a298..e50992b` | Spec ✅ / Approved | 3 |
| 4 — `[DIST-1]` GitHub marketplace source | `c033155..fd90e51` | Spec ✅ / Approved | 1 |

Suite **610 → 660**, fifty net assertions, never below baseline at any point.

## Gate results

| Gate | Result |
|---|---|
| 1 — gate commands | green: exit 0, `14 files, 660 passed, 0 failed`; baseline pass, delta 0 |
| 2 — whole-branch review | **`GO`**, on the seventh dispatch after six API 529s |
| 3 — adversarial verification | **`VERIFIED WITH CAVEATS`**, all seven recorded |
| 4 — backlog flush (blocking) | passed: 24 items tagged, verified 0 missing |
| 5 — context distillation (blocking) | passed, including the §12.11 ratio measurement |
| 6 — integration | rebase (no-op, `main` had not moved), full gate-1 re-run, PR #1 |
| 7 — close | deliberately not run, so the PM can probe the worktree |

## The result that matters

Spec §12.1 item 1 is satisfied on this machine, verified rather than asserted. At Step 1c the
plain suite was **522 passed / 88 failed** and needed
`env PATH="/usr/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null` to reach 610/0. Gate 1 now runs **plain**
at 660/0. The signing half was demonstrated against a deliberately constructed hostile global
config (`commit.gpgsign=true`, `gpg.format=ssh`, absent key) whose hostility was itself probed — a
bare `git commit` fails under it — because those 12 failures never occur ambiently here, so a fix
merely asserted would be indistinguishable from no fix. Task 2's isolation was also confirmed
against env-injected config (`GIT_CONFIG_COUNT`), which had defeated it at 612/13 before its fix
round.

## Two findings worth more than their severity labels

**The review packages were abridged, and nothing said so.** `foreman-phase` Step 4 item 4
specifies `git diff <base> <head> > task-N-review.diff`. A `git`-rewriting proxy hook turned that
into a *summary* — stat lines and a `... (N lines truncated)` footer. **250 lines were withheld
across ten packages**, worst at 73 and 60 on task 4, the `MANIFEST.tsv` trust boundary. All ten
were regenerated raw and gate 2 read the whole branch raw as the first complete read. The verdicts
stand — every reviewer mutation-checked against the live tree, and they found real defects
including one Important and the phase's only Not-approved — but the judge is right that this is
unprovable by re-execution, and the worst-affected reviewer compensated for the **9** lines its
marker disclosed rather than the **73** actually missing. Filed as `[JUDGE-1]`: a defect in the
harness's own instruction, producing a review package that looks complete and is not, affecting
every future phase until `foreman-phase` Step 4 changes. The judge hit the same hook itself.

**`GIT_DIR` residual, `[T2-R1-M4]`.** Pre-existing and outside task 2's brief, so correctly not
fixed — but the reviewer reproduced **the suite committing five branches into a victim repository
while reporting 624 passed / 4 failed**. The suite can write into a repository outside itself when
`GIT_DIR` is set, and report a nearly-clean run while doing it. Roughly one line to fix. It should
not sit in the backlog at the weight of a comment nit.

## Where the process caught things the controller did not

Worth recording, because it is evidence about the harness rather than about this phase:

- **Gate 2 caught two Importants that were the controller's own work.** `[BR-1]`: this phase's own
  kickoff still told a resuming session that Step 1a comes first, routing it past the `[DEP-1]`
  Step 0 check task 3 had just added. The controller had *seen* that at task 3 and dismissed it as
  a harmless historical artefact — then its own `STATE.md` edit pointed the next session at that
  file, making it live. `[BR-2]`: asked to fix a stale `634`, the controller fixed `STATE.md`'s
  copy and missed `DEFERRED.md`'s — patching one instance minutes after writing the
  sweep-the-class lesson into the ledger.
- **The judge corrected a factual claim the controller had repeated three times** — that
  `bin/foreman-root` uses `MANIFEST.tsv` as a sentinel. It does not; it resolves via
  `BASH_SOURCE`/`readlink`, and the manifest appears only in one of its comments. The conclusion
  survived and strengthened (nothing consumes the manifest at all), but the stated reasoning was
  inferred from a grep hit on a comment without reading a six-line script.
- **Both reviewers independently confirmed the backlog was empty** before gate 4 — the one thing
  the controller could not check about itself, having been the one deferring the items.

## Rulings taken (full text in the ledger)

- Gate 1 ran with the kickoff's environment prefix until task 2 landed, plain thereafter; the
  ruling's premise was verified before adoption rather than taken on trust.
- Mechanical detection of an added `[DEP-1]` fallback is **declared impossible** — substring
  matching is polarity-blind, proved from both ends. The guard rests as a tripwire against known
  phrasings with its limit disclosed in test comments, assertion labels and `backlog.md`; the rule
  is enforced by review, not mechanically.
- The fix loop exits on the reviewer's verdict pair, not on the absence of Minors.
- Task 4's fix round was **adopted and committed by the controller** (`fd90e51`) under the
  dead-subagent protocol after two 529s; the controller ran the gate and the mutation checks the
  dead agent never reached, and its reviewer was told to re-derive every controller claim rather
  than accept it. It confirmed all of them.
- `evolve`'s guarantee for `.claude/settings.json` is sound but **rests on prose, not code**, and
  is unverified — that needs a live `/foreman-init`, which this phase may not run.
- At gate 2's five-529 blockage the phase **stopped cleanly rather than downgrade the reviewer,
  grade its own branch, or skip the gate** — the same principle as its own `[DEP-1]` ruling,
  applied to the controller. It resumed and completed on the operator's instruction.
- `POLICY.md` and `STATE.md` were edited by the phase session, which `POLICY.md` forbids, on the
  operator's explicit instruction; recorded on the branch so the raise lands with the merge.

## Deferred — 24 items, all in `docs/dev/backlog.md`, tagged

Twelve task Minors, nine branch-review findings, three judge caveats. Verified mechanically: 24
present, 0 missing. A recurring theme across `[T3-M4]`, `[T3-M10]` and `[T4R1-M1]`: **a guard
claiming more than it checks** — and in `[BR-7]`, its mirror image, a disclosure that makes
deletion look free. Worth a program-level look rather than four separate backlog lines.

## Not verified by this phase

A live session actually stopping on a missing plugin — the behaviour `[DEP-1]` exists to produce.
Claude Code resolving the `github` marketplace source and its trust prompt. `/foreman-init` end to
end, including the executed `evolve` merge. `jq` served by an `asdf` rather than `mise` shim. A
real WSL foreign-uid dubious-ownership path, as opposed to the `GIT_TEST_ASSUME_DIFFERENT_OWNER=1`
simulation used to verify it.

## For the program manager

- **Merge PR #1 after probing.** `STATE.md`'s next action carries the probe: plain
  `bash tests/run.sh` green at **660**, and
  `git ls-files skills/foreman-init/templates/settings.local.json.tmpl` empty. Both were run here
  and pass; the worktree is deliberately left in place for you.
- `POLICY.md`'s `baseline-count` is already `660` on the branch. **Zero headroom** (660/660/0).
  `DEFERRED.md` schedules re-attribution to the merge SHA.
- `DEFERRED.md`'s other merge-conditioned entry: re-register the plugin from the GitHub source.
  This phase installed, removed and re-registered nothing — a reviewer confirmed the marketplace
  registration and the main checkout's `.claude/settings.local.json` are both untouched.
- `STATE.md`'s row needs a final pass to `merged`, and gate 7
  (`superpowers:finishing-a-development-branch`) is left for you after the merge.
- `[BR-8]` needs your ruling, not a phase's: whether the no-vendor-names rule should carry an
  `extraKnownMarketplaces` exception, since a marketplace source must name a real repository and
  `Sahir619/fable-method` currently sits inside `skills/`.

## Program manager's close

Written by the program manager on 2026-09-03, after the merge. It answers the hand-off above,
which was accurate when the phase wrote it and is superseded here.

- **PR #1 merged** as `f811034` after the probe: plain `bash tests/run.sh` green at
  `14 files, 660 passed, 0 failed`, exit 0, and
  `git ls-files skills/foreman-init/templates/settings.local.json.tmpl` empty. Phase closed at
  `06170ef`.
- **Baseline re-attributed.** `POLICY.md`'s `baseline-count: 660` now names `f811034` as the
  commit it was observed green at, replacing the branch-side attribution. Zero headroom stands.
- **Plugin re-registered from the GitHub source.** `claude plugin marketplace list` shows
  `foreman` with `Source: GitHub (yorah/foreman-harness)`; `claude plugin list` shows
  `foreman@foreman`. The `DEFERRED.md` entry is closed.
- **`STATE.md`'s row reads `merged`.** Gate 7's teardown is partly done: the remote branch
  `feat/prerequisites` is deleted, and the local worktree `.claude/worktrees/prerequisites` is
  still present and locked, held by the phase session. `STATE.md` carries the remaining commands.
- **`[BR-8]` is still open and unruled**, in `docs/dev/backlog.md`. The phase was right to send
  it up; the ruling has not been made yet.

This file's stale copy — the "Outcome: incomplete, gate 2 never reached" version — was on `main`
until this commit. The phase's own rewrite was pushed to `feat/prerequisites` after PR #1 had
already been squashed, so it missed the merge. The ledger was complete and correct throughout;
only this session-level record lagged.
