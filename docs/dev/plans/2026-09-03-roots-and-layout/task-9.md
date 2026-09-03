# Task 9: The phase side on roots — `foreman-phase`, the gate chain, `foreman-diff`; `[BR-11]`

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Modify: `skills/foreman-phase/SKILL.md` — the edits enumerated below
- Modify: `skills/foreman-phase/references/gate-chain.md` — §2, §6, §7 and one path
- Modify: `commands/phase.md` — replaced wholesale
- Modify: `tests/test_phase_skill.sh`
- Modify: `docs/dev/backlog.md` — close `[JUDGE-1]` and `[BR-11]`

**Interfaces:**
- Consumes: the kickoff's `**Work root**` and `**Policy**` lines (task 8); `foreman-diff`
  (task 2); `foreman-state --phase --work-root --head` (task 7).
- Produces: the phase's artefact contract the PM relies on — ledger, briefs, reviews and report
  under `<work-root>/phases/<slug>/` and `<work-root>/reports/`, committed to the work root's
  repository with own-paths staging; `backlog.md` and `CONTEXT.md` still committed in the
  worktree.

**Why this exists.** Spec §4.2 and §4.6: phase sessions reach the work root by the absolute
path the kickoff gives them, commit to the nested repository, stage only their own paths, and
retry once on an index-lock collision. Everything the phase used to commit under
`<worktree>/docs/dev/program/phases/<slug>/` moves; the commits of `backlog.md` and
`CONTEXT.md`, which are durable per repository, do not. `[JUDGE-1]` wires in task 2's
`foreman-diff` at the two places the controller writes a diff. `[BR-11]`: the skill's
`Announce:` line sits above `Step 0 — … before anything else`, so the text contradicts its own
ordering claim; the announcement moves to the end of Step 0.

---

- [ ] **Step 1: Write the failing tests**

In `tests/test_phase_skill.sh`:

Change the two `assert_near` markers `"--phase <slug> --branch <branch>"` to
`"--phase <slug> --work-root <work-root>"`. Change the needle
`` "\`<abs-policy>\` = \`<worktree>/docs/dev/program/POLICY.md\`" `` to
`` "\`<abs-policy>\` = \`<worktree>/docs/dev/POLICY.md\`" `` and its label to `abs-policy is
defined concretely, at POLICY.md's new home under the worktree`. Change the needle
`` "\`<abs-plan-dir>\` means \`<worktree>/docs/dev/plans/<slug>/\`" `` to
`` "\`<abs-plan-dir>\` means \`<work-root>/plans/<slug>/\`" `` and its label to `abs-plan-dir is
defined concretely, under the work root`.

Append:

```bash

# --- phase B: the phase's artefacts live in the work root and are committed to its repository ---
assert_contains "$skill" '`<abs-phase-dir>` means `<work-root>/phases/<slug>/`' \
  "abs-phase-dir is defined concretely, under the work root"
assert_contains "$skill" '**Work root**' "Step 1a takes the work root from the kickoff's own line"
assert_contains "$skill" 'git -C <work-root> add phases/<slug>' \
  "phase artefacts are staged by own path in the work root's repository"
assert_contains "$(flow "$s")" 'retry once' "an index-lock collision in the shared work root is retried once"
assert_contains "$skill" '<work-root>/reports/' "the session report is written under the work root"
for f in "$s" "$g" "$c"; do
  assert_not_contains "$(cat "$f")" "docs/dev/program/" \
    "$(basename "$f") no longer hardcodes docs/dev/program/"
done
assert_contains "$gate" 'docs/dev/RULINGS.md' "the gate chain promotes rulings to RULINGS.md's new home"

# [JUDGE-1] Both places the controller writes a review diff go through foreman-diff, and the raw
# redirect is gone from both.
assert_contains "$skill" 'foreman-diff --repo <worktree> --base <base> --head "$head" --out <abs-phase-dir>/task-N-review.diff' \
  "the per-task review package is written by foreman-diff"
assert_contains "$gate" 'foreman-diff --repo <worktree>' "the branch review package is written by foreman-diff"
assert_not_contains "$skill" 'diff <base> "$head" >' "the raw per-task diff redirect is gone"
assert_not_contains "$gate" 'git diff origin/<default>...HEAD >' "the raw branch diff redirect is gone"
assert_near "$skill" 'foreman-diff --repo <worktree> --base <base>' 8 'Exit 1' \
  "foreman-diff: exit 1 has a stated action"

# [BR-11] Step 0 is "before anything else", so the announcement comes after it, not above it.
step0_at="$(grep -n '^## Step 0 ' "$s" | head -1 | cut -d: -f1)"
announce_at="$(grep -n 'Announce' "$s" | head -1 | cut -d: -f1)"
if [ -n "$step0_at" ] && [ -n "$announce_at" ] && [ "$step0_at" -lt "$announce_at" ]; then _ok
else fail "the Announce line ($announce_at) must come after the Step 0 heading ($step0_at) [BR-11]"; fi
```

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: the three changed needles and the two `assert_near` rows red; every appended positive
assertion red; the `[BR-11]` ordering check red. Nothing outside this file.

- [ ] **Step 3: Implement**

**`commands/phase.md`** — replace wholesale:

```
---
description: Execute one harness phase from its kickoff file
---

Run the phase whose kickoff file is: $ARGUMENTS

Use the `foreman-phase` skill. If no kickoff path was given, resolve the work root with
`foreman-roots "$PWD"`, read `<work-root>/STATE.md`, list the phases whose status is `planned`,
and ask which one.
```

**`skills/foreman-phase/SKILL.md`** — apply these edits and no others:

1. `[BR-11]` Delete the line `Announce: "Running phase \`<slug>\` from \`<kickoff path>\`."` and
   its blank line from above Step 0. At the end of Step 0, after the paragraph beginning `If
   either is missing, stop:`, add: `Both present? Announce: "Running phase \`<slug>\` from
   \`<kickoff path>\`." — and only now.`

2. Step 1a: after the `<default>` bullet, add:

   ```
   - `<work-root>`: the kickoff's **Work root** line, verbatim. It is absolute and sits at the
     main checkout — never inside the worktree — and it is a git repository of its own. Every
     artefact this phase produces except code goes under it, and every commit of one goes to
     *its* repository. If the kickoff has no such line, stop and ask; do not derive one.
   ```

3. Step 1c: `` `<abs-policy>` = `<worktree>/docs/dev/program/POLICY.md` `` →
   `` `<abs-policy>` = `<worktree>/docs/dev/POLICY.md` `` — the worktree's copy of the file the
   kickoff's **Policy** line names.

4. Step 2: `` `<abs-plan-dir>` means `<worktree>/docs/dev/plans/<slug>/` `` →
   `` `<abs-plan-dir>` means `<work-root>/plans/<slug>/` ``.

5. Step 3: `` `<abs-phase-dir>` means `<worktree>/docs/dev/program/phases/<slug>/` `` →
   `` `<abs-phase-dir>` means `<work-root>/phases/<slug>/` ``. Where Step 3 says to commit the
   ledger, replace with: `Commit it to the work root's repository: \`git -C <work-root> add
   phases/<slug>\` then \`git -C <work-root> commit -qm "<slug>: ledger opened"\`. Stage only your
   own paths — never \`add -A\` there; the PM writes to the same repository. If the commit fails
   on the index lock, retry once (spec §4.6); if it fails again, ledger it and stop.`

6. Step 4 item 4: replace the fenced block

   ```bash
   head="$(git -C <worktree> rev-parse HEAD)"
   git -C <worktree> diff <base> "$head" > <abs-phase-dir>/task-N-review.diff
   ```

   with

   ```bash
   head="$(git -C <worktree> rev-parse HEAD)"
   foreman-diff --repo <worktree> --base <base> --head "$head" --out <abs-phase-dir>/task-N-review.diff
   ```

   and add directly after it:

   ```
   - **Exit 0:** the package is complete — it holds every file and every line git's own
     accounting says the range has, and nothing else. Continue.
   - **Exit 1:** incomplete; stderr says which count disagreed. Regenerate once. If it exits 1
     again, set this task `blocked` with that stderr as the reason, commit the ledger, and stop:
     a review of a package that is not the diff reviews nothing.
   - **Exit 2:** an argument error — fix the invocation. It is not a question for anyone else.
   ```

   Item 5's regenerate bullet: replace `regenerate the diff from the **same original \`<base>\`**
   to a new file` with `run \`foreman-diff\` again from the **same original \`<base>\`** to a new
   file, with the same three exits as item 4`.

7. Step 4 item 6's last paragraph: replace `Then commit the whole of \`<abs-phase-dir>\` — the
   ledger, the brief, the report, and every round's findings file. \`.diff\` files are
   gitignored; everything else under \`docs/dev/\` is tracked on purpose, and gate 7's claim that
   these travel with the merge is only true if this commit happens now, every task, not once at
   the very end.` with:

   ```
   Then commit the whole of `<abs-phase-dir>` — the ledger, the brief, the report, and every
   round's findings file — to the work root's repository: `git -C <work-root> add
   phases/<slug>`, then commit; retry once on the index lock. `.diff` files are ignored by the
   work root's own `.gitignore`. This commit happens now, every task, not once at the very end:
   the PM reads the ledger as a file, and a file that is not committed is a file one `git
   checkout` in the work root can lose.
   ```

8. Step 6: replace the fenced `foreman-state` block with

   ```bash
   foreman-state --phase <slug> --work-root <work-root> --head
   ```

   and in the sentence after it, `an uncommitted \`state.md\`, a malformed frontmatter block, or
   a branch name that does not match what \`docs/dev/program/STATE.md\` expects` →
   `an unwritten \`state.md\`, a malformed frontmatter block, or a wrong \`<work-root>\``. Replace
   `Write \`docs/dev/reports/YYYY-MM-DD-<slug>.md\` (\`mkdir -p\` its parent first — nothing else
   in this program creates that directory)` with `Write
   \`<work-root>/reports/YYYY-MM-DD-<slug>.md\` (\`mkdir -p\` its parent first) and commit it to
   the work root's repository`.

**`references/gate-chain.md`**:

- §2: replace the fenced `git diff origin/<default>...HEAD > <abs-phase-dir>/branch-review.diff`
  with

  ```bash
  base="$(git -C <worktree> merge-base origin/<default> HEAD)"
  foreman-diff --repo <worktree> --base "$base" --head HEAD --out <abs-phase-dir>/branch-review.diff
  ```

  and add: `Exit 1 means the package is incomplete: regenerate once; a second exit 1 is a stop,
  ledgered, before any reviewer sees it.` The `NO-GO` bullet's `against a regenerated diff` →
  `against a package regenerated the same way`.
- The `RULINGS.md` sentence: `docs/dev/program/RULINGS.md` → `docs/dev/RULINGS.md`.
- §6 first paragraph: `If any was skipped, commit \`<abs-phase-dir>\`, \`docs/dev/backlog.md\`
  and \`docs/dev/CONTEXT.md\` now` → `If any was skipped, commit \`<abs-phase-dir>\` to the work
  root's repository, and \`docs/dev/backlog.md\` and \`docs/dev/CONTEXT.md\` in the worktree, now`.
- §7: replace the paragraph with:

  ```
  `superpowers:finishing-a-development-branch`. The ledger, the briefs, the reports and every
  review file live in the work root, committed to its repository as each task closed — they were
  never in the worktree, so nothing needs rescuing before it goes, and nothing about them
  travels with the merge. What outlives the phase is in `docs/dev/`: `backlog.md`, `CONTEXT.md`,
  and the code.
  ```

Then `grep -n 'docs/dev/program' skills/foreman-phase commands/phase.md` must print nothing.

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, about `+15` on the count before this task. `awk 'length > 100'`
over the three files prints nothing.

- [ ] **Step 5: Mutation-check**

Temporarily move the `Announce` sentence back above Step 0: the `[BR-11]` check goes red.
Restore. Temporarily change `foreman-diff --repo <worktree> --base <base>` back to a `git diff …
>` redirect: two assertions go red. Restore. Green.

- [ ] **Step 6: Close the backlog items and commit**

In `docs/dev/backlog.md`, `- [ ] [JUDGE-1]` → `- [x] [JUDGE-1]` with `**Closed 2026-09-03,
phase B tasks 2 and 9:** \`foreman-diff\` writes both review packages and exits 1 unless the file
agrees with git's numstat and contains only unified-diff line shapes; both skills call it by bare
wrapper name.` And `- [ ] [BR-11]` → `- [x] [BR-11]` with `**Closed 2026-09-03, phase B task 9:**
the announcement follows Step 0.`

```bash
git add skills/foreman-phase commands/phase.md tests/test_phase_skill.sh docs/dev/backlog.md
git commit -m "phase: artefacts under the work root, committed to its repository; review packages via foreman-diff [JUDGE-1]; announce after Step 0 [BR-11]"
```
