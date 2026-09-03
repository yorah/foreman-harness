# Task 8: The program side on roots — `program-status`, `foreman-program`, milestones

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Modify: `commands/program-status.md` — replaced wholesale (text below)
- Modify: `commands/program.md` — replaced wholesale (text below)
- Modify: `skills/foreman-program/SKILL.md` — the edits enumerated below, nothing else
- Modify: `skills/foreman-program/references/milestones.md` — four paths
- Modify: `tests/test_program_skill.sh`

**Interfaces:**
- Consumes: `foreman-roots <abs-start-dir>` from task 1; `foreman-state --phase <slug>
  --work-root <abs> --head` and its stderr reasons from task 7; the kickoff template's
  `WORK_ROOT` and `POLICY_PATH` variables from task 5.
- Produces: the dispatch contract task 9's `foreman-phase` reads: a kickoff at
  `<work-root>/phases/<slug>/kickoff.md` carrying a `**Work root**` line and a `**Policy**` line,
  both absolute; the `STATE.md` row written to `<work-root>/STATE.md`; nothing pushed.

**Why this exists.** Spec §4.4: only the PM resolves roots, through `foreman_roots`. Spec §4.5:
the ledger is a file, so the PM's triage of "no such file on branch" — two paragraphs in this
skill and one in `program-status` that told the PM to check whether a branch existed locally,
then remotely, then retry with `--branch origin/…` — is retired with the read path it explained.
And a consequence the spec states but does not spell out: a kickoff in a work root on the same
machine is read by absolute path, so in single mode **dispatch pushes nothing**. The routine
kickoff push, and the paragraph about `POLICY.md`'s standing grant for it, go.

---

- [ ] **Step 1: Write the failing tests**

In `tests/test_program_skill.sh`:

Change `assert_contains "$status" 'foreman-state --phase <slug> --head'` to
`assert_contains "$status" 'foreman-state --phase <slug> --work-root <work-root> --head'`.

Delete the assertion labelled `the skill's own not-started/unreadable guard checks the remote
branch, not just the local one` (the `rev-parse --verify --quiet origin/<branch>` needle) and
its comment block. Delete the `for f in "$skillf" "$statusf"` loop asserting `must have had a
branch` and its comment. Keep the two `planned, not yet launched` assertions and the `it means
the opposite` assertion as they are.

Append:

```bash

# --- phase B: roots come from foreman-roots; the ledger is a file; dispatch pushes nothing ------
assert_contains "$skill" 'foreman-roots' "the PM resolves roots through the wrapper"
assert_contains "$skillf" 'exit `2` — this repository is not initialised' \
  "an unresolvable root is reported as not initialised, not guessed around"
for f in "$s" "$m" "$c" "$st"; do
  assert_not_contains "$(cat "$f")" "docs/dev/program/" \
    "$(basename "$f") no longer hardcodes docs/dev/program/"
done
assert_contains "$skillf" '<work-root>/STATE.md' "STATE.md is read at the work root"
assert_contains "$skillf" '<program-root>/POLICY.md' "POLICY.md is read at the program root"
assert_contains "$skillf" 'git -C <work-root> add STATE.md phases/<slug>/kickoff.md' \
  "dispatch commits the kickoff and the row to the work root's own repository, own paths only"
assert_contains "$skillf" 'Nothing is pushed' "single-mode dispatch pushes nothing"
assert_not_contains "$skillf" 'rev-parse --verify --quiet origin/<branch>' \
  "the branch-existence dance is retired with the git show path"
assert_not_contains "$skillf" 'git show' "the skill no longer describes a git show read"
# The retired triage's replacement: the script's own reason strings decide, plus the row's status.
for f in "$skillf" "$statusf"; do
  assert_contains "$f" 'no ledger at' "the triage keys on the script's literal reason"
  assert_contains "$f" 'has not reached Step 3' \
    "a phase past planned with no ledger is not started, not an anomaly"
done
assert_contains "$skill" '/foreman:phase <work-root>/phases/<slug>/kickoff.md' \
  "the launch block pastes an absolute kickoff path"
```

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: the changed `program-status` needle and every appended positive assertion red; the
four `no longer hardcodes` assertions red; nothing outside this file.

- [ ] **Step 3: Implement**

**`commands/program.md`** — replace wholesale:

```
---
description: Act as the program manager for this repository
---

Become the program manager for this repository, using the `foreman-program` skill.

Run the refusal gate first. Then resolve the roots with `foreman-roots`, read
`<work-root>/STATE.md`, and act on the next action it names. $ARGUMENTS
```

**`commands/program-status.md`** — replace wholesale:

```
---
description: One line per phase, read from the work root
---

Print the current program status. Do not read source files.

1. Resolve the roots: `foreman-roots "$PWD"` prints `program_root`, `work_root` and the config
   path, tab-separated. Exit 2 means this repository is not initialised for the harness — print
   the script's stderr and stop.
2. Read the phase table in `<work-root>/STATE.md`. Then `git fetch` in the product repository,
   and if the local default branch is behind its remote, say so on its own line before the
   table — the durable files every row depends on may be stale.
3. For each row, run `foreman-state --phase <slug> --work-root <work-root> --head`.
   - Exit 0: read the frontmatter as normal.
   - Exit 2 whose stderr begins `no ledger at`: the phase has not opened its ledger. Consult the
     row's own `Status` column: `planned` means exactly that, so print `planned, not yet
     launched`; any other status means the phase session exists and has not reached Step 3, so
     print `not started`.
   - Exit 2 for any other reason (a malformed frontmatter block, a ledger that is not a readable
     file, an unreadable work root): print `unreadable — <the script's stderr>` on this row and
     continue to the next. Never fold this into `not started` — it means the opposite: state
     exists and could not be read, not that none exists yet.
4. Print one line per phase: slug, owner, branch, status, task progress from the frontmatter,
   and the next action.
5. Then print any deferred check in `<work-root>/DEFERRED.md` whose condition has come due.

Nothing else. No narration.
```

**`skills/foreman-program/SKILL.md`** — apply these edits and no others:

1. In Step 0's first paragraph, extend the wrapper list to `foreman-gate`, `foreman-brief`,
   `foreman-baseline`, `foreman-state`, `foreman-roots`, `foreman-diff`.

2. Insert a new section between `### Dependencies` and `## Then read exactly three things`:

   ```
   ## Then resolve the roots

   ```bash
   foreman-roots "$PWD"
   ```

   One line, tab-separated: `<program-root>`, `<work-root>`, and the config path. In single
   mode `<program-root>` is `<repo>/docs/dev` and `<work-root>` is `<repo>/.foreman`, a nested
   repository the product repository ignores; started from a linked worktree, the wrapper still
   finds the main checkout's work root. Use these two names for the rest of this skill.

   - exit `0` — continue.
   - exit `2` — this repository is not initialised for the harness (no `foreman.json`), or its
     config cannot be read; stderr names which. Say so, tell the user to run
     `/foreman:foreman-init`, and stop. Do not guess a layout.
   ```

3. In `## Then read exactly three things`, change the first sentence to read
   `` `<work-root>/STATE.md`, then `<program-root>/POLICY.md`, then `<work-root>/DEFERRED.md`. ``
   and change every later `docs/dev/program/DEFERRED.md` in that section to
   `<work-root>/DEFERRED.md`.

4. In "Your job" step 3, replace the sentences from `Write a self-contained kickoff to
   \`docs/dev/program/phases/<slug>/kickoff.md\`. Commit and push it …` through `… needs its own
   \`AUTH:\` line before it happens.` with:

   ```
   Write a self-contained kickoff to `<work-root>/phases/<slug>/kickoff.md`. It must carry two
   absolute paths the phase cannot derive — a `**Work root**` line naming `<work-root>` and a
   `**Policy**` line naming `<program-root>/POLICY.md` — because a phase never resolves roots
   (spec §4.4; invariant 4 one level up). Commit the kickoff and the row to the work root's own
   repository, own paths only: `git -C <work-root> add STATE.md phases/<slug>/kickoff.md`, then
   `git -C <work-root> commit`; if the commit fails on the index lock, retry once. **Nothing is
   pushed:** in single mode the work root is local to this machine and the phase reads the
   kickoff by absolute path.
   ```

5. In "## The launch block", replace `Write the kickoff file, commit it, and push it — under the
   same authorization rule … — then print exactly:` with `Write the kickoff file and commit it
   to the work root, then print exactly:`, and change the paste line to
   `` paste: `/foreman:phase <work-root>/phases/<slug>/kickoff.md` `` — absolute, the same path
   you wrote.

6. In "## Verifying a finished phase, cheaply", replace the fenced `foreman-state` command and
   the two exit bullets that follow it (from `Read a running phase's ledger without leaving
   your directory:` through the end of the exit `2` bullet) with:

   ```
   Read a running phase's ledger without leaving your directory — it is a file:

   ```bash
   foreman-state --phase <slug> --work-root <work-root> --head
   ```

   - exit `0`: the machine-readable head (or, without `--head`, the full prose) came back; read
     it.
   - exit `2` whose stderr begins `no ledger at`: the phase has not opened its ledger. The row's
     own `Status` column tells you which kind of not-yet this is: `planned` means exactly that,
     so say `planned, not yet launched`; any other status means the phase session exists and
     has not reached Step 3, so say `not started`.
   - exit `2` for any other reason — a malformed frontmatter block, a ledger that is not a
     readable file, an unreadable work root — say `unreadable — <the script's stderr>`. Never
     fold this into `not started`; it means the opposite: state exists and could not be read.
   ```

7. In the `unverified` bullet, replace `Commit and push that fix to the default branch under the
   same authorization as the kickoff push (step 3 above)` with `Commit that fix to the default
   branch under \`POLICY.md\`'s authorization rule — it lives in the product repository, so this
   is a push and needs its `AUTH:` line`.

8. In "## Rulings", `docs/dev/program/RULINGS.md` → `<program-root>/RULINGS.md`. In "## Deferred
   checks", `docs/dev/program/DEFERRED.md` → `<work-root>/DEFERRED.md`.

**`references/milestones.md`**: `docs/dev/program/STATE.md` → `<work-root>/STATE.md`,
`docs/dev/program/RULINGS.md` → `<program-root>/RULINGS.md`, `docs/dev/program/DEFERRED.md` →
`<work-root>/DEFERRED.md`, `docs/dev/program/HISTORY.md` → `<program-root>/HISTORY.md`.

Then `grep -n 'docs/dev/program' skills/foreman-program commands/program.md
commands/program-status.md` must print nothing.

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, about `+13` on the count before this task (two removed, fifteen
added). `awk 'length > 100' skills/foreman-program/SKILL.md commands/*.md` prints nothing.

- [ ] **Step 5: Mutation-check**

Temporarily delete the `Nothing is pushed` sentence: its assertion goes red. Restore.
Temporarily reintroduce `docs/dev/program/STATE.md` anywhere in `milestones.md`: its
`no longer hardcodes` assertion goes red. Restore. Green.

- [ ] **Step 6: Commit**

```bash
git add commands/program.md commands/program-status.md skills/foreman-program tests/test_program_skill.sh
git commit -m "program: roots via foreman-roots; ledger read as a file; single-mode dispatch pushes nothing; triage tables retired"
```
