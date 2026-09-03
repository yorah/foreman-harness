# foreman-harness — program state

The program manager's working memory, read at the start of every session. **Kept short
deliberately** — completed phases live in `HISTORY.md`, standing decisions in `RULINGS.md`,
time-gated checks in `DEFERRED.md`.

Last updated 2026-09-03.

## Program

Program layer merge: `docs/dev/specs/2026-09-02-program-layer-merge.md`, approved 2026-09-02.
Six phases (A–F) in §10; F is deferred. Each phase runs under the *installed* plugin, so after
a phase merges the plugin is updated before the next launches (§10). Done for A on 2026-09-03:
the plugin is installed from the GitHub source, version 0.1.0 at `f811034`.

## Phases

| Phase | Owner | Branch | Status | Next action |
|---|---|---|---|---|
| prerequisites | yorah | feat/prerequisites | merged | none — `HISTORY.md`; worktree removal pending (locked by the phase session) |

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

**Specify and dispatch phase B, roots and layout** (spec §10 row B, §4 for the design). Under
the current harness the program manager writes the plan: `superpowers:writing-plans`, into
`docs/dev/plans/2026-09-03-roots-and-layout/`, then the kickoff at
`docs/dev/program/phases/roots-and-layout/kickoff.md`, branch `feat/roots-and-layout`, Opus
controller (it touches `scripts/lib.sh` and `MANIFEST.tsv`). Before writing, read §4.1–4.6 of
the spec and the open rulings below; they fix B's scope. Housekeeping first: once the phase A
terminal is closed, `git worktree remove .claude/worktrees/prerequisites`, `git branch -d
feat/prerequisites`, `git push origin --delete feat/prerequisites`.

## Open rulings

Rulings about the present. When one stops being about the present, move it to `RULINGS.md`.

- Ruling: phase B absorbs `[DIST-2]` (every shipped slash command written namespaced,
  `/foreman:phase` and so on, with an assertion that no bare form survives) — because B rewrites
  the same skills, templates and `CLAUDE.md` for the layout change, and a second pass over them
  would cost a reviewer round for nothing — costs, if wrong, a wider B diff.
- Ruling: phase B absorbs `[JUDGE-1]` (the review package `foreman-phase` Step 4 item 4 writes
  with `git diff > file` was silently abridged by a command-rewriting proxy hook on this machine,
  250 lines withheld across phase A's ten packages). The fix is mechanised, not prose: a
  `foreman-diff` wrapper script (`bin/` plus `scripts/`) that writes `<base>..<head>` to the
  package path and exits 1 when the file carries a truncation marker or is shorter than
  `git diff --stat` implies; the skill calls it by bare name like every other script, which no
  hook on `git` rewrites — because a wrapper is the same immunity `bin/` already gives the other
  scripts, and a prose instruction to "avoid the hook" cannot name the hook without naming a
  vendor (spec §2) — costs, if wrong, one more script to maintain. The same proxy abridges the
  program manager's own `git diff` reads; until B lands, read diffs with `/usr/bin/git`.
- Ruling: phase B's verification includes spec §12.2 run for real (a single-mode `/foreman-init`
  into a scratch repository that already has a `.claude/settings.json`), which also settles
  `[JUDGE-2]` (the `evolve` guarantee is prose-only and untested) — because §12.2 is B's own
  verification item and the scratch repository is the same one — costs nothing extra.
- Ruling: `[BR-3]` (no assertion checks a *rendered* kickoff, only the template) goes into B if
  B changes `kickoff.md.tmpl`, otherwise into C, which replaces the kickoff wholesale (§5.1) —
  because the assertion should be written against the shape that survives.
- Ruling: the remaining 20 backlog items from phase A (`[T1-M4]`…`[BR-13]`, `[JUDGE-3]`) stay
  in the backlog; phase B's plan absorbs only those that touch a file B already changes —
  because a Minor is not a phase.
