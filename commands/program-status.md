---
description: One line per phase, read from each phase's own branch
---

Print the current program status. Do not read source files.

1. Read the phase table in `docs/dev/program/STATE.md`. Other people may be running phases:
   `git fetch` first, and if the local default branch is behind its remote, say so on its own
   line before the table — every row below it may be stale.
2. For each row, run `foreman-state --phase <slug> --head`.
   - Exit 0: read the frontmatter as normal.
   - Exit 2 whose stderr says `no docs/dev/program/phases/<slug>/state.md on branch '<branch>'`:
     `phase-state.sh` reads the ledger with a single `git show <branch>:<path>`, which fails
     identically whether the ledger has simply not been opened yet or `<branch>` does not exist at
     all — the script cannot tell those apart, so do not either. Confirm the branch is real first:
     `git rev-parse --verify --quiet <branch>` (local). If it exists, the ref this call actually
     queried was real, so print `not started` on this row. If it does not exist locally, fetch and
     check `git rev-parse --verify --quiet origin/<branch>`. If that does not exist either, the
     branch has not been created yet — and since the program manager writes a phase's `STATE.md` row
     at dispatch, before the phase session creates its branch, that is the expected state of a phase
     that was dispatched moments ago. Disambiguate with this row's own `Status` column: `planned`
     means exactly that, so print `planned, not yet launched`. Any other status with no branch
     anywhere is a real anomaly — a phase that reached `executing` or beyond must have had a branch
     — so print `unreadable — branch <branch> not found locally or at origin/<branch>` on that row
     instead. Either way continue to the next row, and never print `not started`: a branch that does
     not exist is not the same claim, in either direction. If `origin/<branch>` does exist, this
     call queried a ref that was never real, which says nothing about the ledger — retry with
     `--branch origin/<branch>` before printing anything: exit 0 there is a real ledger, read it
     normally; the identical exit-2 message there means the now-confirmed-real branch genuinely has
     no ledger yet, and only then do you print `not started`.
   - Exit 2 naming a `STATE.md`-level problem instead (no `STATE.md` at all, no header row, or
     a missing/duplicate `Phase`/`Branch` column): stop entirely and report that defect in
     place of the table — it is wrong for every row, not just this one, so print none of it.
   - Exit 2 for any other reason (this phase's own duplicate row, an empty resolved branch, a
     malformed frontmatter block): print `unreadable — <the script's stderr>` on this row and
     continue to the next row. Never fold this into `not started` — it means the opposite:
     state exists and could not be read, not that none exists yet.
3. Print one line per phase: slug, owner, branch, status, task progress from the frontmatter,
   and the next action.
4. Then print any deferred check in `docs/dev/program/DEFERRED.md` whose condition has come due.

Nothing else. No narration.
