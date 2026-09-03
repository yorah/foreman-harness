# Phase `prerequisites` — session report

**Date** 2026-09-02 to 2026-09-03. **Branch** `feat/prerequisites`, based at `origin/main`
`cc489e9`. **Worktree** `.claude/worktrees/prerequisites`. **Controller** Opus, high effort.

**Outcome: incomplete.** All four tasks passed and gate 1 is green, but **gate 2 was never
reached** — five consecutive server-side 529s on Opus. Nothing was pushed, no pull request was
opened, `main` is untouched. Full detail in
`docs/dev/program/phases/prerequisites/state.md`, which is the authoritative ledger; this file is
the session-level record.

## What landed

| Task | Commits | Verdict | Rounds |
|---|---|---|---|
| 1 — user settings tier via `CLAUDE_CONFIG_DIR` | `13dce8e..0c6f90d` | Spec ✅ / Approved | 1 |
| 2 — runner pins git configuration | `8273545..57f5323` | Spec ✅ / Approved | 1 |
| 3 — `[DEP-1]` dependency check at skill entry | `a03a298..e50992b` | Spec ✅ / Approved | 3 |
| 4 — `[DIST-1]` GitHub marketplace source | `c033155..fd90e51` | Spec ✅ / Approved | 1 |

Suite: **610 → 660**, fifty net assertions. Never below baseline at any point.

## The result that matters

Spec §12.1 item 1 is satisfied on this machine, and it was verified rather than asserted. At Step
1c the plain suite was **522 passed / 88 failed** and needed
`env PATH="/usr/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null` to reach 610/0. Gate 1 now runs **plain**
at 660/0. The signing half was checked against a deliberately constructed hostile global config
(`commit.gpgsign=true`, `gpg.format=ssh`, absent key) whose hostility was itself probed — a bare
`git commit` fails under it — because those 12 failures never occur ambiently here. Task 2's
isolation was also confirmed against env-injected config (`GIT_CONFIG_COUNT`), which had defeated
it at 612/13 before its fix round.

## Two findings worth more than their severity labels

**The review packages were abridged, and nothing said so.** `foreman-phase` Step 4 item 4
specifies `git diff <base> <head> > task-N-review.diff`. A hook rewrites `git` to a token-reducing
proxy, so that redirection captured a *summary* — stat lines and a `... (N lines truncated)`
footer. **250 lines were withheld across ten packages**, worst at 73 and 60 on task 4, the
`MANIFEST.tsv` trust boundary. All ten were regenerated raw via `rtk proxy git diff`. The verdicts
stand — every reviewer mutation-checked against the live tree, and they found real defects
including one Important and the phase's only Not-approved — but the worst-affected reviewer
compensated for the **9** lines its marker disclosed, not the **73** actually missing. This is a
defect in the harness's own instruction, producing a silently incomplete review package that looks
complete. It is the program manager's to fix (skill Step 4 text: capture through an invocation the
proxy does not rewrite, and assert the artefact carries no truncation marker before dispatching),
not a phase task. **Gate 2 was to be the first complete read of this branch, and it did not run.**

**`GIT_DIR` residual, `[T2-R1-M4]`.** Pre-existing and outside task 2's brief, so correctly not
fixed — but the reviewer reproduced **the suite committing five branches into a victim repository
while reporting 624 passed / 4 failed**. The suite can write into a repository outside itself when
`GIT_DIR` is set, and report a nearly-clean run while doing it. This should not sit in the backlog
at the same weight as a comment nit.

## Rulings taken (full text in the ledger)

- Gate 1 ran with the kickoff's environment prefix until task 2 landed, plain thereafter; the
  ruling's premise was verified before adoption rather than taken on trust.
- Mechanical detection of an added `[DEP-1]` fallback is **declared impossible** — substring
  matching is polarity-blind, proved from both ends. The guard rests as a tripwire against known
  phrasings, with its limit disclosed in test comments, assertion labels and `backlog.md`. The
  rule is enforced by review, not mechanically.
- The fix loop exits on the reviewer's verdict pair, not on the absence of Minors.
- Task 4's fix round was **adopted and committed by the controller** (`fd90e51`) under the
  dead-subagent protocol after two 529s left work staged; the controller ran the gate and the
  mutation checks the dead agent never reached. Its round-1 reviewer was told to re-derive every
  controller claim rather than accept it, and confirmed all of them.
- `evolve` mode's guarantee for `.claude/settings.json` is sound but **rests on prose, not code**:
  nothing mechanically consumes `MANIFEST.tsv`, so no code path can clobber a contributor's
  settings, and the guarantee is `foreman-init`'s Step 5 text. Not behaviourally verified — that
  needs a live `/foreman-init`, which this phase may not run.
- The phase stops at gate 2 rather than downgrading the reviewer's model, reviewing the branch
  itself, or skipping ahead — the same principle as its own `[DEP-1]` ruling, applied to the
  controller.

## Open Minors — not yet flushed to `backlog.md` (gate 4 unreached)

`[T1-M4]`, `[T1-M5]`, `[T2-R1-M1]`, `[T2-R1-M2]`, `[T2-R1-M3]`, `[T2-R1-M4]`, `[T3-M14]`,
`[T3-M15]`, `[T4R1-M1]`, `[T4R1-M2]`, `[T4R1-M3]`. Eleven items, each described in the ledger's
per-task sections with its reason for deferral. Gate 4 is blocking and must flush all of them.

A recurring theme across three of them: **a guard claiming more than it checks** (`[T3-M4]`,
`[T3-M10]`, `[T4R1-M1]`). Worth a program-level look rather than three separate backlog lines.

## Also uncovered

Live-session stop behaviour on a missing plugin — the behaviour `[DEP-1]` exists to produce.
Claude Code resolving the `github` marketplace source and its trust prompt. `/foreman-init` end to
end, including the executed `evolve` merge. `jq` served by an `asdf` rather than `mise` shim. A
real WSL foreign-uid dubious-ownership path, as opposed to the
`GIT_TEST_ASSUME_DIFFERENT_OWNER=1` simulation used to verify it.

## For the program manager

- `docs/dev/program/STATE.md` was deliberately left untouched (a phase does not edit PM files). It
  still expects a count of **634** and still describes the retired local-directory marketplace
  source. Both need updating.
- `POLICY.md`'s `baseline-count: 610` likewise untouched, and should be raised to 660 on merge.
- Gate 6 was to end in a pull request, not a merge (spec D5). Unreached.
- **Resume by re-running `/phase docs/dev/program/phases/prerequisites/kickoff.md`.** A resuming
  session should skip Step 4 — all four tasks are `passed` with commit ranges in the ledger head —
  and re-enter at gate 1, then gate 2 against the existing raw `branch-review.diff`.
