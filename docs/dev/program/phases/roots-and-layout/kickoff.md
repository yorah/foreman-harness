# Phase B — roots and layout

## First — `foreman-phase` Step 0, then Step 1a, then Step 1b's `EnterWorktree`

Step 0's dependency check comes before anything else. Then record `<main-checkout>` (the
directory `/foreman:phase` was invoked from — `git rev-parse --show-toplevel`, not a worktree;
on this machine `/home/yorah/projects/foreman-harness`) and `<default>` (`main`) before
entering the worktree — they are needed at gate 6 and by task 11, and are hard to reconstruct
once inside a worktree. Then:

`EnterWorktree(name: "roots-and-layout")` — branches from `origin/main`.

**Your branch is `feat/roots-and-layout`.** The program manager chose it and has already written
it into `STATE.md`, which is how a running phase's ledger is found. If the worktree tool creates
a branch under a different name, rename it to this one (`git -C <worktree> branch -m
feat/roots-and-layout`) rather than reporting a different name back — the name is an input here,
not an output.

## Context

Phase A left a green suite on any machine and an installable plugin. This phase gives the
harness spec §4's durability split in single mode: durable files under `docs/dev/`, transient
state in a gitignored nested `.foreman/` repository, one function that resolves both roots, a
ledger read as a file, and every skill re-pointed. Its last task migrates **this repository**
onto that layout, so the harness stops targeting a layout its own repository does not use.

Twelve tasks, in `docs/dev/plans/2026-09-03-roots-and-layout/`. The order is load-bearing:
tasks 1–6 are additive and build the headroom task 7 spends when it retires the `git show`
read (43 assertions out, about 27 in); task 11 is last because it moves `POLICY.md` and
`tests/run.sh`'s baseline gate must follow in the same commit. Do not reorder.

**You run under the pre-B installed plugin.** Its skill writes your ledger to
`docs/dev/program/phases/roots-and-layout/state.md` and reads it there through `git show`; the
PM reads it the same way. Task 11 therefore leaves five things where they are — the plan's
"carve-out" section lists them — and the PM moves them after the merge. If you find yourself
about to `git rm` `STATE.md`, `DEFERRED.md`, this kickoff, this plan or your own report, stop:
that is the modify/delete conflict the carve-out exists to prevent.

Three things are unusual about this phase and are deliberate:

- **`<abs-policy>` changes mid-phase.** It is `<worktree>/docs/dev/program/POLICY.md` until
  task 11's commit, and `<worktree>/docs/dev/POLICY.md` from then on — for gate 1's baseline read
  at task 12 and for every `foreman-baseline` call in the gate chain. Nothing else about
  `POLICY.md` changes; you never edit it.
- **Review packages.** Until task 2 lands, read and write diffs with `/usr/bin/git`, not `git`: a
  command-rewriting hook on this machine abridges `git diff` output (`[JUDGE-1]`, phase A lost 250
  lines across ten packages that way). From task 2's commit onward, write every review package
  with the worktree's own tool — `PATH="<worktree>/bin:$PATH" foreman-diff --repo <worktree>
  --base <base> --head "$head" --out <abs-phase-dir>/task-N-review.diff` — and treat its exit 1
  as task 9 describes. That is this phase dogfooding its own fix.
- **Task 11 writes outside the worktree**, once, to create `<main-checkout>/.foreman/`. The
  authorization for exactly that and nothing else:

  `AUTH: user selected "Full migration inside B" (2026-09-03) — this authorizes task 11 to
  create and commit <main-checkout>/.foreman/ and nothing else outside the worktree.`

  Quote it in the task 11 report before the write. No other task writes outside the worktree.

Absorbed backlog items, closed by the tasks that do the work: `[DIST-2]` (4), `[JUDGE-1]` (2, 9),
`[JUDGE-2]` (12), `[T2-R1-M1]` `[T2-R1-M4]` (3), `[BR-6]` (6), `[BR-11]` (9), `[T-PLAN]` (11).
`[BR-3]` is **not** yours: it moved to phase C by ruling.

## Read first

- `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — constraints, the expected count
  trajectory, the carve-out, and the task table
- `docs/dev/program/POLICY.md` — gate commands, baseline, trust boundaries, invariants
- `docs/dev/specs/2026-09-02-program-layer-merge.md` §4.1–4.6, §10 row B, §11, §12.2–12.3 — the
  requirements this argues from

Read nothing else until a task requires it. **Do not read the plan's task bodies** — generate
briefs with `foreman-brief`.

## Rulings that must not be relitigated

- This repository migrates inside B (task 11), not in a later step. Operator's decision.
- One phase of twelve tasks, absorbed items kept. Operator's decision. If you stall, the resume
  path is phase A's: commit the ledger, stop cleanly, report.
- The carve-out: `STATE.md`, `DEFERRED.md`, this phase's own `phases/roots-and-layout/`, its
  plan directory and its report stay at the old paths; the PM moves them post-merge.
- `foreman-init` writes `mode: single` without asking until phase D adds multi mode.
- `[JUDGE-1]` is fixed by a script (`foreman-diff`, structural completeness check), not by
  prose, and names no vendor. `[BR-3]` goes to phase C's `foreman-kickoff-lint`.
- Spec §12.2 is run **for real** against a scratch repository in task 12, by following the
  worktree's `foreman-init` text literally; that run also settles `[JUDGE-2]`.
- Every task touching `scripts/`, `bin/`, `MANIFEST.tsv` or `tests/run.sh` runs at Opus with an
  Opus reviewer; every skill or template change takes an Opus reviewer. The plan's task table
  says which is which; record the models actually used.
- Gate 6 ends in a pull request, not a merge (spec D5, `POLICY.md`'s integration rule). Rebase
  onto `origin/main`, re-run gate 1 in full — with `<abs-policy>` at its new home — push, open the
  PR with the gate evidence in its body, and stop. Do not run gate 7: the PM probes the worktree
  first.
- The PM edits only `STATE.md`'s row for this phase, and `DEFERRED.md`, on `main` while you run;
  `POLICY.md`, `RULINGS.md` and `HISTORY.md` are frozen until merge, so your `git mv` of them
  rebases cleanly.

## Method

`foreman-phase`. Subagent-driven execution against the plan, then the gate chain in
`references/gate-chain.md`.

## Report back

Write `docs/dev/program/phases/roots-and-layout/state.md` as you go and commit it — the program
manager reads it off your branch.

End with a summary under 150 words: status, commit range, gate results, the PR link, the final
suite count against the plan's trajectory, open Minors, what remains uncovered. The human pastes
it to the program manager, so it must stand alone.

**Model** Opus. **Effort** high.
