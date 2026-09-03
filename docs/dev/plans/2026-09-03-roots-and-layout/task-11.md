# Task 11: This repository migrates onto the layout it installs; version `0.2.0`

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table. Read its "What stays where it is — the carve-out" section before starting: it lists the
five things this task must **not** move.

**Files:**
- Move (`git mv`): `docs/dev/program/{POLICY,RULINGS,HISTORY}.md` → `docs/dev/`
- Remove (`git rm`): `docs/dev/program/phases/prerequisites/`,
  `docs/dev/plans/2026-08-28-harness-v1/`, `docs/dev/plans/2026-09-02-prerequisites/`, every
  file under `docs/dev/reports/`
- Create, **outside the worktree, under the kickoff's `AUTH:` line**: `<main-checkout>/.foreman/`
  as a nested repository holding those removed files, `foreman.json` and `.gitignore`
- Modify: `.gitignore`, `tests/run.sh`, `.github/workflows/tests.yml`, `CLAUDE.md`,
  `docs/dev/README.md`, `.claude-plugin/plugin.json`, `tests/test_dogfood.sh`
- Delete: `tests/test_plans.sh`
- Modify: `docs/dev/backlog.md` — close `[T-PLAN]` as moot

**Interfaces:**
- Consumes: `foreman.json.tmpl` and `work-root.gitignore` from task 5 (rendered by hand here);
  `scripts/roots.sh` from task 1 for the verification.
- Produces: the layout the post-B program manager reads. The PM's post-merge step moves the
  five carve-out items and removes the then-empty `docs/dev/program/`.

**Why this exists.** Spec §4.1: `docs/dev/program/` ceases to exist. The operator ruled that
this repository migrates inside B rather than later, so that the harness does not spend a phase
targeting a layout its own repository does not use. Two constraints shape the task. First,
`tests/run.sh`'s baseline gate reads `docs/dev/program/POLICY.md` and **silently skips the gate
when the file is absent** — so the `git mv` and the `run.sh` path change land in one commit, or
the suite goes green with its baseline check disabled. Second, the phase runs under the pre-B
plugin, which writes this phase's own ledger to the old path and reads it there, and the PM
edits `STATE.md`/`DEFERRED.md` on `main` while this runs; those stay, per the carve-out.

**Authorization.** Writing `<main-checkout>/.foreman/` is a write outside the worktree, which
`POLICY.md` forbids a phase without an `AUTH:` line. The kickoff carries one, quoting the
operator's decision. It covers that directory and nothing else outside the worktree. If the
kickoff you were given has no `AUTH:` line, stop before Step 3's second half and report.

---

- [ ] **Step 1: Write the failing tests**

In `tests/test_dogfood.sh`:

- Both `for f in …` lists near the top: replace the five `docs/dev/program/…` entries with
  `docs/dev/POLICY.md docs/dev/RULINGS.md docs/dev/HISTORY.md` (three entries; `STATE.md` and
  `DEFERRED.md` are transient and are not in the product repository).
- `leftover_path="$(find "$R/docs/dev/program" "$R/.claude" …` → `find "$R/docs/dev" "$R/.claude"`.
- `policy="$R/docs/dev/program/POLICY.md"` → `policy="$R/docs/dev/POLICY.md"`.
- Delete the `STATE.md parses as the phase index` block's `assert_contains … STATE.md …` (the
  template test pins the header; the file is no longer in the repository). Keep the
  `an unknown phase is a clean exit-2` assertion (task 7 already put it on `--work-root`).
- Append:

```bash

# --- phase B: this repository is on the layout it installs ---------------------------------------
if [ -e "$R/docs/dev/program/POLICY.md" ]; then fail "POLICY.md still lives under docs/dev/program/"; else _ok; fi
assert_eq "" "$(git -C "$R" ls-files docs/dev/plans/2026-08-28-harness-v1 docs/dev/plans/2026-09-02-prerequisites docs/dev/program/phases/prerequisites)" \
  "completed transient artefacts have left the product repository"
assert_exit 0 ".foreman is ignored by this repository" -- git -C "$R" check-ignore -q .foreman
assert_contains "$(grep -E '^policy=' "$R/tests/run.sh")" 'docs/dev/POLICY.md' \
  "the runner's baseline gate reads POLICY.md at its new home"
assert_eq "0.2.0" "$(jq -r '.version' "$R/.claude-plugin/plugin.json")" \
  "the plugin version is bumped so that a plugin update has something to update to"
```

Delete `tests/test_plans.sh` (`git rm`): every one of its five assertions reads a plan this task
moves out of the repository, and the `[T-PLAN]` refresh it guards becomes moot when plans are
transient.

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: `dogfood did not produce docs/dev/POLICY.md` (and RULINGS, HISTORY), `POLICY.md has no
baseline-count` (the new path does not exist yet), the five appended assertions red. The suite's
**baseline gate is now silently skipped** because `run.sh` still names the old path and the
dogfood `policy` variable names the new one — read the tail: there must be no `WARNING: baseline
could not be read` line yet, and there must be one after Step 3's `run.sh` edit if the `git mv`
were ever done without it. That asymmetry is the reason both land in one commit.

- [ ] **Step 3: Implement — in the worktree**

```bash
cd <worktree>
git mv docs/dev/program/POLICY.md  docs/dev/POLICY.md
git mv docs/dev/program/RULINGS.md docs/dev/RULINGS.md
git mv docs/dev/program/HISTORY.md docs/dev/HISTORY.md

# Stage a copy of every transient artefact that leaves, for the work root below.
stage=<scratch>/foreman-migration
mkdir -p "$stage/phases" "$stage/plans" "$stage/reports"
cp -r docs/dev/program/phases/prerequisites          "$stage/phases/"
cp -r docs/dev/plans/2026-08-28-harness-v1           "$stage/plans/"
cp -r docs/dev/plans/2026-09-02-prerequisites        "$stage/plans/"
find docs/dev/reports -maxdepth 1 -type f -exec cp {} "$stage/reports/" \;

git rm -r -q docs/dev/program/phases/prerequisites
git rm -r -q docs/dev/plans/2026-08-28-harness-v1 docs/dev/plans/2026-09-02-prerequisites
git rm -q docs/dev/reports/*.md
git rm -q tests/test_plans.sh
```

Do **not** touch `docs/dev/program/STATE.md`, `docs/dev/program/DEFERRED.md`,
`docs/dev/program/phases/roots-and-layout/`, or `docs/dev/plans/2026-09-03-roots-and-layout/`.
`git status --short` must show them unchanged. `docs/dev/reports/` may now be empty until Step 6
of `foreman-phase` writes this phase's report into it; that is expected.

`.gitignore` — replace wholesale (it is `gitignore-additions.txt` plus this repository's one
extra line):

```
# Harness: regenerable review diff packages.
*.diff

# Harness work root: transient program state -- STATE.md, ledgers, briefs, reviews, plans,
# reports -- in a nested repository of its own, versioned there and never here. `git clean -fdx`
# deletes it, history included: -x removes ignored files.
/.foreman/

# SDD scratch: briefs, reports, reviews and the ledger for a running plan.
/.superpowers/

# Per-contributor: Claude Code writes local permission grants here. Never shared, never tracked.
.claude/settings.local.json
```

`tests/run.sh`: `policy="${FOREMAN_POLICY:-$FOREMAN_ROOT/docs/dev/program/POLICY.md}"` →
`policy="${FOREMAN_POLICY:-$FOREMAN_ROOT/docs/dev/POLICY.md}"`.

`.github/workflows/tests.yml`: in the comment, `docs/dev/program/POLICY.md` → `docs/dev/POLICY.md`.

`.claude-plugin/plugin.json`: `"version": "0.1.0"` → `"version": "0.2.0"`.

`CLAUDE.md`:
- `## Architecture`, the `bin/` bullet: after `by bare name` add ` — \`foreman-gate\`,
  \`foreman-brief\`, \`foreman-baseline\`, \`foreman-state\`, \`foreman-root\`, \`foreman-roots\`,
  \`foreman-diff\``.
- `## Invariants` lead-in: `docs/dev/program/POLICY.md` → `docs/dev/POLICY.md`. Invariant 6's
  list: add `foreman-roots`, `foreman-diff`.
- `## How work is organised`: replace `- Current state: \`docs/dev/program/STATE.md\`.` with

  ```
  - Durable record — policy, rulings, history, specs — in `docs/dev/`, tracked. Transient state —
    `STATE.md`, ledgers, plans, reports — in `.foreman/`, a nested repository this one ignores.
    `git clean -fdx` deletes it, history included.
  - Current state: `.foreman/STATE.md`.
  ```

`docs/dev/README.md`: replace wholesale with the rendered form of task 5's
`docs/README.md.tmpl` — `{{PROJECT_NAME}}` → `foreman-harness` — so this repository's own copy
and the one it installs say the same thing.

Run `bash tests/run.sh 2>&1 | tail -3` now: `0 failed`, no `WARNING`, and the count about `−5`
from before this task (the deleted `test_plans.sh`; the appended dogfood assertions are still
red because `.foreman/` does not exist yet — `check-ignore` is green already, so expect exactly
the `.foreman`-independent ones green).

- [ ] **Step 4: Implement — the work root, outside the worktree, under `AUTH:`**

Quote the kickoff's `AUTH:` line in your report before running this. `<main-checkout>` is the
path Step 1a recorded.

```bash
main=<main-checkout>
[ ! -e "$main/.foreman" ] || { echo "REFUSING: $main/.foreman already exists"; exit 1; }
mkdir -p "$main/.foreman"
cp -r "$stage/phases" "$stage/plans" "$stage/reports" "$main/.foreman/"
sed -e 's#{{PROGRAM_NAME}}#program-layer-merge#' -e 's#{{TODAY}}#2026-09-03#' \
    -e "s#{{WORK_ROOT}}#$main/.foreman#" -e 's#{{REPO_NAME}}#foreman-harness#' \
    -e "s#{{REPO_PATH}}#$main#g" -e 's#{{DEFAULT_BRANCH}}#main#' \
    <worktree>/skills/foreman-init/templates/program/foreman.json.tmpl > "$main/.foreman/foreman.json"
cp <worktree>/skills/foreman-init/templates/program/work-root.gitignore "$main/.foreman/.gitignore"
jq -e 'type == "object" and .mode == "single"' "$main/.foreman/foreman.json" >/dev/null
git -C "$main/.foreman" init -q
git -C "$main/.foreman" add -A
git -C "$main/.foreman" commit -qm "Work root bootstrapped by phase B: phase A artefacts, plans and reports moved from docs/dev"
```

Then the §12.2 observations, against reality:

```bash
git -C <worktree> check-ignore -q .foreman && echo "ignored: yes"
git -C "$main/.foreman" rev-parse --is-inside-work-tree
( cd "$main/.foreman" && git rev-parse --show-toplevel )        # must print $main/.foreman
git -C "$main/.foreman" ls-files | wc -l                         # > 30: phase A alone is 22 files
PATH="<worktree>/bin:$PATH" foreman-roots "$main"                # program root, work root, config
PATH="<worktree>/bin:$PATH" foreman-state --phase prerequisites --work-root "$main/.foreman" --head
```

The last two prove the post-B PM will be able to read what was moved. Record every output in
your report. Note that `check-ignore` in the *main checkout* will fail until this branch merges
(its `.gitignore` is the old one); that is expected and is why the check runs in the worktree.

- [ ] **Step 5: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, **no `WARNING` line** — the baseline gate ran against
`docs/dev/POLICY.md` — and a count about `−5 + 5 = 0` net from before this task. Also:

```bash
awk 'length > 100' CLAUDE.md docs/dev/README.md .gitignore
grep -rn 'docs/dev/program' CLAUDE.md docs/dev/README.md tests/run.sh .github README.md
```

Both print nothing.

- [ ] **Step 6: Mutation-check and commit**

Temporarily revert the `run.sh` path: the suite prints `WARNING: baseline could not be read from
…/docs/dev/program/POLICY.md` and the dogfood `policy=` needle goes red. Restore. Green.

In `docs/dev/backlog.md`, `- [ ] **[T-PLAN]` → `- [x] **[T-PLAN]` with `**Closed 2026-09-03,
phase B task 11, as moot:** plans are transient under spec §4.1 and the harness-v1 plan now lives
in the work root, outside this repository; there is nothing left in the tree to refresh.`

```bash
git add -A docs/dev .gitignore tests/run.sh tests/test_dogfood.sh .github/workflows/tests.yml \
        CLAUDE.md .claude-plugin/plugin.json
git status --short   # confirm: nothing under .foreman/, nothing staged from the carve-out
git commit -m "Migrate this repository onto the spec 4.1 layout: POLICY/RULINGS/HISTORY to docs/dev, transient artefacts to the .foreman work root; runner reads the moved POLICY; plugin 0.2.0"
```

`git add -A docs/dev` picks up the `git mv` and `git rm` results and the backlog edit;
`STATE.md` and `DEFERRED.md` are untouched so they do not appear. If `git status` shows either
of them, you edited a file the carve-out reserves — undo that before committing.
