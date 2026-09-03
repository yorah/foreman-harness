# foreman-harness — program state

The program manager's working memory, read at the start of every session. **Kept short
deliberately** — completed phases live in `HISTORY.md`, standing decisions in `RULINGS.md`,
time-gated checks in `DEFERRED.md`.

Last updated 2026-09-03 (phase B dispatched).

## Program

Program layer merge: `docs/dev/specs/2026-09-02-program-layer-merge.md`, approved 2026-09-02.
Six phases (A–F) in §10; F is deferred. Each phase runs under the *installed* plugin, so after
a phase merges the plugin is updated before the next launches (§10). Done for A on 2026-09-03:
the plugin is installed from the GitHub source, version 0.1.0 at `f811034`.

## Phases

| Phase | Owner | Branch | Status | Next action |
|---|---|---|---|---|
| prerequisites | yorah | feat/prerequisites | merged | none — `HISTORY.md`; worktree removal pending (locked by the phase session) |
| roots-and-layout | yorah | feat/roots-and-layout | planned | launch: `/foreman:phase docs/dev/program/phases/roots-and-layout/kickoff.md`, Opus, high |

One row per phase, edited in place as its status changes across the phase's lifetime — never
appended to as a second row for the same phase. This table is parsed by
`foreman-state` — keep the `Phase` and `Branch` column headers spelled exactly as they
are. The script resolves them by name; other columns and their order
are yours. Two rows naming the same phase make the branch unknowable, and the script refuses
rather than guess which one is current.

Statuses: `planned`, `executing`, `gates`, `awaiting rebase`, `merged`, and the three a phase can
halt on — `blocked`, `deferred`, `unverified`. The last three are what a phase's own summary
reports; record the one you were told rather than leaving a halted phase reading `executing`,
which is the same untruth as a ledger that says `in-progress` at a stop.

## Next action

**Launch phase B, roots and layout.** Plan at `docs/dev/plans/2026-09-03-roots-and-layout/`
(twelve tasks, README carries the expected count trajectory and the carve-out), kickoff at
`docs/dev/program/phases/roots-and-layout/kickoff.md`, branch `feat/roots-and-layout`, Opus at
high. When its summary comes back: probe the worktree (plain `bash tests/run.sh` green with no
`WARNING` line and a count at or above the plan's row 12; `git -C <wt> check-ignore -q .foreman`;
`PATH=<wt>/bin:$PATH foreman-state --phase prerequisites --work-root
/home/yorah/projects/foreman-harness/.foreman --head` returns phase A's ledger head), then merge
the PR and run `DEFERRED.md`'s post-B entry **in its stated order** before starting a new PM
session. While B runs, this session edits only this file's B row and `DEFERRED.md` on `main`;
`POLICY.md`, `RULINGS.md`, `HISTORY.md` are frozen (B moves them). Housekeeping still pending:
once the phase A terminal is closed, `git worktree remove .claude/worktrees/prerequisites` and
`git branch -d feat/prerequisites` (the remote branch is already gone). `[BR-8]` still needs the
operator's ruling; it does not block B.

## Open rulings

Rulings about the present. When one stops being about the present, move it to `RULINGS.md`.

- Ruling: this repository migrates onto the §4.1 layout **inside phase B** (task 11), not in a
  later step — operator's decision 2026-09-03 ("Full migration inside B"), so the harness does not
  spend a phase targeting a layout its own repository does not use — costs, if wrong, a revert
  that is a history edit plus a nested-repository salvage.
- Ruling: B runs as **one phase of twelve tasks** with every absorbed item kept — operator's
  decision 2026-09-03 over a B1/B2 split — costs, if wrong, a resume cycle if the phase stalls
  mid-plan; phase A's stop-and-resume path is the mitigation.
- Ruling: **the carve-out.** B runs under the pre-B plugin, which writes B's ledger to
  `docs/dev/program/phases/roots-and-layout/` and reads it there with `git show`
  (`scripts/phase-state.sh:30,116` hardcode the path), and the PM edits `STATE.md` and
  `DEFERRED.md` on `main` while B runs. So task 11 leaves those two files, B's own
  `phases/roots-and-layout/`, its plan directory and its report where they are; the PM moves them
  after the merge (`DEFERRED.md`). A phase-side removal would guarantee a modify/delete conflict
  at gate 6 — costs one directory outliving its retirement by a step.
- Ruling: `[BR-3]` goes to **phase C**, amending the ruling below — because under B's layout
  rendered kickoffs leave the product repository, so a suite assertion over them is vacuous in
  CI; C's `foreman-kickoff-lint` (spec §12.6) checks a kickoff at write time, which is the shape
  that survives — costs nothing; C already owns the lint.
- Ruling: `foreman-init` writes `mode: single` **without asking** until phase D adds multi mode —
  because a question with one valid answer is not a question — costs one prose edit in D.
- Ruling: `<abs-policy>` changes mid-phase at task 11's commit, from
  `<worktree>/docs/dev/program/POLICY.md` to `<worktree>/docs/dev/POLICY.md`; the plan and the
  kickoff both say so — because `tests/run.sh:120` skips the baseline gate silently when the file
  is absent, so the move and the runner's path must land in one commit — costs a wrong-path gate
  read if a later task forgets; the kickoff names it as the one deliberate mid-phase change.
- Ruling: during B the PM edits **only** B's `STATE.md` row and `DEFERRED.md` on `main`;
  `POLICY.md`, `RULINGS.md`, `HISTORY.md` are frozen until merge — because task 11 `git mv`s them
  — costs deferring any policy correction (invariant 6's wrapper list, the kickoff-push
  authorization paragraph) to the post-merge step, where `DEFERRED.md` schedules it.
- Ruling (task 4 of B): phase B absorbs `[DIST-2]` (every shipped slash command written namespaced,
  `/foreman:phase` and so on, with an assertion that no bare form survives) — because B rewrites
  the same skills, templates and `CLAUDE.md` for the layout change, and a second pass over them
  would cost a reviewer round for nothing — costs, if wrong, a wider B diff.
- Ruling (tasks 2 and 9 of B): phase B absorbs `[JUDGE-1]` (the review package `foreman-phase`
  Step 4 item 4 writes
  with `git diff > file` was silently abridged by a command-rewriting proxy hook on this machine,
  250 lines withheld across phase A's ten packages). The fix is mechanised, not prose: a
  `foreman-diff` wrapper script (`bin/` plus `scripts/`) that writes `<base>..<head>` to the
  package path and exits 1 when the file carries a truncation marker or is shorter than
  `git diff --stat` implies; the skill calls it by bare name like every other script, which no
  hook on `git` rewrites — because a wrapper is the same immunity `bin/` already gives the other
  scripts, and a prose instruction to "avoid the hook" cannot name the hook without naming a
  vendor (spec §2) — costs, if wrong, one more script to maintain. The same proxy abridges the
  program manager's own `git diff` reads; until B lands, read diffs with `/usr/bin/git`.
- Ruling (tasks 10 and 12 of B): phase B's verification includes spec §12.2 run for real (a
  single-mode `/foreman-init`
  into a scratch repository that already has a `.claude/settings.json`), which also settles
  `[JUDGE-2]` (the `evolve` guarantee is prose-only and untested) — because §12.2 is B's own
  verification item and the scratch repository is the same one — costs nothing extra.
- Ruling (superseded above, kept for its reasoning): `[BR-3]` (no assertion checks a *rendered*
  kickoff, only the template) was to go into B if B changes `kickoff.md.tmpl`, otherwise into C,
  which replaces the kickoff wholesale (§5.1) —
  because the assertion should be written against the shape that survives.
- Ruling (applied: B absorbs `[T2-R1-M1]`, `[T2-R1-M4]`, `[BR-6]`, `[BR-11]`, `[T-PLAN]`): the
  remaining backlog items from phase A (`[T1-M4]`…`[BR-13]`, `[JUDGE-3]`) stay
  in the backlog; phase B's plan absorbs only those that touch a file B already changes —
  because a Minor is not a phase.
