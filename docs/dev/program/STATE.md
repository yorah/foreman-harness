# foreman-harness — program state

The program manager's working memory, read at the start of every session. **Kept short
deliberately** — completed phases live in `HISTORY.md`, standing decisions in `RULINGS.md`,
time-gated checks in `DEFERRED.md`.

Last updated 2026-09-03.

## Program

Program layer merge: `docs/dev/specs/2026-09-02-program-layer-merge.md`, approved 2026-09-02.
Six phases (A–F) in §10; F is deferred. Each phase runs under the *installed* plugin, so after
a phase merges the plugin is updated before the next launches (§10, and `DEFERRED.md`).

## Phases

| Phase | Owner | Branch | Status | Next action |
|---|---|---|---|---|
| prerequisites | yorah | feat/prerequisites | gates | tasks passed, gate 1 green at 660/0; gate 2 unreached (529s) — resume per **Next action** |

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

Phase A is mid-gate-chain, not awaiting launch. Its four tasks are `passed` and gate 1 is green;
gate 2 (whole-branch review, Opus, always) never ran — five consecutive server-side 529s. Nothing
was pushed, no PR was opened, `main` is untouched.

Resume it: re-run `/foreman:phase docs/dev/program/phases/prerequisites/kickoff.md` at Opus, high.
A resuming session skips Step 4 — all four tasks carry commit ranges and verdicts in the ledger
head — and re-enters at gate 1, then gate 2 against the existing raw `branch-review.diff`.

When its summary comes back with a PR URL: probe the worktree at
`<abs repo root>/.claude/worktrees/prerequisites` — plain `bash tests/run.sh` green, expected
**660** (not 634; that figure predated the phase's actual assertion count, and `POLICY.md`'s
`baseline-count` has been raised to 660 on the phase branch), and
`git ls-files skills/foreman-init/templates/settings.local.json.tmpl` empty. Then merge the PR and
run the two `DEFERRED.md` entries conditioned on that merge. Then write the phase B kickoff
(§10: roots and layout, Opus).

Carry into phase B, from phase A's report: `foreman-phase` Step 4 item 4 produces a **silently
abridged** review package under a `git`-rewriting proxy hook — 250 lines were withheld across ten
packages on phase A, worst on a trust boundary. The fix is a skill change (capture the diff
through an invocation the proxy does not rewrite, and assert the artefact carries no truncation
marker before dispatching), so it is `/foreman-init` or a program decision, not a phase task.
Also `[T2-R1-M4]`: the suite can commit into a repository outside itself when `GIT_DIR` is set,
reporting a nearly-clean run while doing it.

## Open rulings

Rulings about the present. When one stops being about the present, move it to `RULINGS.md`.

- Ruling: plugin installed 2026-09-02 from the local directory source (`claude plugin
  marketplace add <checkout> --scope local`, then `claude plugin install foreman@foreman`) —
  because that was the documented mechanism until phase A's `[DIST-1]` replaced it — costs, if
  wrong, one re-registration after the merge, which `DEFERRED.md` already schedules.
  **Superseded on the branch, not yet on `main`:** `[DIST-1]` has landed in
  `feat/prerequisites`, so this repository's `CLAUDE.md`, its `.claude/settings.json` and
  `settings.json.tmpl` now declare a `github` source on `yorah/foreman-harness`, and
  `settings.local.json.tmpl` is retired. The installed plugin this session ran is still the
  directory-sourced one; the re-registration `DEFERRED.md` schedules is what closes the gap, and
  it is due after the merge, not before. Phase A did not install, remove or re-register anything
  — that fence was held, and a reviewer confirmed the marketplace registration and the main
  checkout's `.claude/settings.local.json` are both untouched.
- Ruling: phase A's Step 1c baseline is taken with an environment prefix (kickoff, first
  ruling) — because the tree is not what is red, the machine is, and phase A exists to make
  that distinction unnecessary — costs, if wrong, a baseline count the ledger attributes to the
  wrong cause; the plain run at task 2 corrects it either way.
