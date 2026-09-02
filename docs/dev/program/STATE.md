# foreman-harness — program state

The program manager's working memory, read at the start of every session. **Kept short
deliberately** — completed phases live in `HISTORY.md`, standing decisions in `RULINGS.md`,
time-gated checks in `DEFERRED.md`.

Last updated 2026-09-02.

## Program

Program layer merge: `docs/dev/specs/2026-09-02-program-layer-merge.md`, approved 2026-09-02.
Six phases (A–F) in §10; F is deferred. Each phase runs under the *installed* plugin, so after
a phase merges the plugin is updated before the next launches (§10, and `DEFERRED.md`).

## Phases

| Phase | Owner | Branch | Status | Next action |
|---|---|---|---|---|
| prerequisites | yorah | feat/prerequisites | planned | launch `/foreman:phase docs/dev/program/phases/prerequisites/kickoff.md` at Opus, high |

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

Launch phase A (row above). When its summary comes back with a PR URL: probe the worktree at
`<abs repo root>/.claude/worktrees/prerequisites` (plain `bash tests/run.sh` green, expected
634; `git ls-files skills/foreman-init/templates/settings.local.json.tmpl` empty), merge the PR,
then run the two `DEFERRED.md` entries conditioned on that merge. Then write the phase B
kickoff (§10: roots and layout, Opus).

## Open rulings

Rulings about the present. When one stops being about the present, move it to `RULINGS.md`.

- Ruling: plugin installed 2026-09-02 from the local directory source (`claude plugin
  marketplace add <checkout> --scope local`, then `claude plugin install foreman@foreman`), the
  shape this repository's `CLAUDE.md` documents today — because that is the documented
  mechanism until phase A's `[DIST-1]` replaces it — costs, if wrong, one re-registration after
  the merge, which `DEFERRED.md` already schedules.
- Ruling: phase A's Step 1c baseline is taken with an environment prefix (kickoff, first
  ruling) — because the tree is not what is red, the machine is, and phase A exists to make
  that distinction unnecessary — costs, if wrong, a baseline count the ledger attributes to the
  wrong cause; the plain run at task 2 corrects it either way.
