# Task 5: The manifest and templates on the §4.1 layout

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Modify: `skills/foreman-init/templates/MANIFEST.tsv` — destinations; two new rows; variables
- Create: `skills/foreman-init/templates/program/foreman.json.tmpl`
- Create: `skills/foreman-init/templates/program/work-root.gitignore`
- Modify: `skills/foreman-init/templates/gitignore-additions.txt`
- Modify: `skills/foreman-init/templates/CLAUDE.md.tmpl`
- Modify: `skills/foreman-init/templates/docs/README.md.tmpl` — the table and "Who writes what"
- Modify: `skills/foreman-init/templates/program/kickoff.md.tmpl`
- Modify: `skills/foreman-init/templates/program/STATE.md.tmpl` — one paragraph, not the header
- Modify: `skills/foreman-init/templates/plans/plan-README.md.tmpl`, `plans/task-N.md.tmpl` — the
  plan-directory line in each
- Modify: `tests/test_templates.sh`

**Interfaces:**
- Consumes: nothing from other tasks. (Task 4's namespaced commands are already in these files.)
- Produces: the manifest below, which tasks 6, 10 and 11 read; `foreman.json.tmpl`'s variable
  names `PROGRAM_NAME`, `TODAY`, `WORK_ROOT`, `REPO_NAME`, `REPO_PATH`, `DEFAULT_BRANCH`, which
  tasks 6, 10 and 11 substitute; the kickoff template's two new variables `WORK_ROOT` and
  `POLICY_PATH`, which task 8's dispatch fills.

**Why this exists.** Spec §4.1: the classification is the contract and the location follows
from it. Durable-per-repository files land in `docs/dev/`; durable-per-program files land at the
program root, which in single mode is also `docs/dev/`; transient files land in the work root,
`.foreman/`, a nested repository the product repository ignores. `docs/dev/program/` ceases to
exist. The manifest is the specification of what `foreman-init` writes, so this is where the
layout is decided; the prose that describes it (task 6) and the test that renders it (task 10)
follow from these rows.

---

- [ ] **Step 1: Write the failing tests**

In `tests/test_templates.sh`, replace the `TABLE` heredoc's body (between `done <<'TABLE'` and
`TABLE`) with:

```
CLAUDE.md evolve
AGENTS.md create
.claude/settings.json evolve
.gitignore evolve
docs/dev/README.md create
docs/dev/CONTEXT.md create
docs/dev/backlog.md create
docs/dev/POLICY.md create
docs/dev/RULINGS.md create
docs/dev/HISTORY.md create
.foreman/foreman.json create
.foreman/.gitignore create
.foreman/STATE.md create
.foreman/DEFERRED.md create
.foreman/phases/{{PHASE_SLUG}}/kickoff.md create
.foreman/plans/{{PLAN_SLUG}}/README.md create
.foreman/plans/{{PLAN_SLUG}}/task-{{TASK_NUMBER}}.md create
docs/dev/specs/{{TODAY}}-{{TOPIC}}.md create
```

and update the comment above it: "eighteen destinations", not sixteen. Then append to the file:

```bash

# --- phase B: the §4.1 layout ---------------------------------------------------------------------
# Durable files under docs/dev/, transient files under .foreman/. The rows above fix the
# destinations; these pin the pieces that make .foreman/ a work root rather than a directory.
gi_add="$(cat "$t/gitignore-additions.txt" 2>/dev/null || true)"
assert_contains "$gi_add" "/.foreman/" \
  "the product repository is told to ignore the work root"
assert_contains "$gi_add" "git clean -fdx" \
  "the ignore file warns that git clean -fdx deletes the work root and its history"
wr_gi="$(cat "$t/program/work-root.gitignore" 2>/dev/null || true)"
assert_contains "$wr_gi" "*.diff" \
  "the work root's own .gitignore keeps review packages out of the nested repository"

# foreman.json.tmpl must render to one JSON object with mode single once its variables are
# substituted -- a template that only looks like JSON is found by the first jq that reads it.
fj_rendered="$(sed -e 's#{{PROGRAM_NAME}}#demo#' -e 's#{{TODAY}}#2026-09-03#' \
  -e 's#{{WORK_ROOT}}#/abs/demo/.foreman#' -e 's#{{REPO_NAME}}#demo#' -e 's#{{REPO_PATH}}#/abs/demo#g' \
  -e 's#{{DEFAULT_BRANCH}}#main#' "$t/program/foreman.json.tmpl" 2>/dev/null || true)"
fj_rc=0
printf '%s\n' "$fj_rendered" | jq -s -e 'length == 1 and (.[0] | type == "object")' >/dev/null 2>&1 || fj_rc=$?
assert_eq "0" "$fj_rc" "foreman.json.tmpl renders to exactly one JSON object"
assert_eq "single" "$(printf '%s\n' "$fj_rendered" | jq -r '.mode' 2>/dev/null)" \
  "foreman.json.tmpl renders mode single"
assert_eq "/abs/demo/docs/dev/POLICY.md" "$(printf '%s\n' "$fj_rendered" | jq -r '.repos[0].policy' 2>/dev/null)" \
  "foreman.json.tmpl points the repository's policy at docs/dev/POLICY.md"
assert_eq "" "$(printf '%s\n' "$fj_rendered" | grep -o '{{[A-Z_]*}}' || true)" \
  "foreman.json.tmpl has no variable the six named ones leave unsubstituted"

# The kickoff hands the phase its roots as absolute paths (spec §4.4, invariant 4 one level up).
ko="$(cat "$t/program/kickoff.md.tmpl" 2>/dev/null || true)"
assert_contains "$ko" "{{WORK_ROOT}}"   "the kickoff template carries the work root"
assert_contains "$ko" "{{POLICY_PATH}}" "the kickoff template carries the policy path"
assert_not_contains "$ko" "docs/dev/program/" "the kickoff template no longer hardcodes the old program directory"

# Both directions on the CLAUDE.md template: the new path is present, the old one is gone.
cm="$(cat "$t/CLAUDE.md.tmpl" 2>/dev/null || true)"
assert_contains "$cm" "docs/dev/POLICY.md" "CLAUDE.md.tmpl points at POLICY.md's new home"
assert_not_contains "$cm" "docs/dev/program/" "CLAUDE.md.tmpl no longer names docs/dev/program/"
assert_contains "$cm" ".foreman/" "CLAUDE.md.tmpl names the work root"

dr="$(cat "$t/docs/README.md.tmpl" 2>/dev/null || true)"
assert_contains "$dr" ".foreman/" "docs/README.md.tmpl describes the work root"
assert_not_contains "$dr" "program/STATE.md" "docs/README.md.tmpl no longer places STATE.md under program/"

# The plan templates name the plan's home through the work root, not a literal docs/dev/plans.
for pt in plans/plan-README.md.tmpl plans/task-N.md.tmpl; do
  assert_contains "$(cat "$t/$pt" 2>/dev/null || true)" "{{WORK_ROOT}}/plans/" \
    "$pt locates the plan directory through the work root"
done
```

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: `every manifest destination is covered with the right mode` red (the old rows are
missing and the new ones absent), and every appended assertion red except the ones whose
`assert_not_contains` happens to hold already. Nothing else red.

- [ ] **Step 3: Implement**

**`MANIFEST.tsv`** — replace the whole file. Fields are separated by one tab; `variables`
values are one line each. Write it with a heredoc and then check `awk -F'\t' '{print NF}'`
prints `4` on every line.

```
template	destination	variables	mode
CLAUDE.md.tmpl	CLAUDE.md	PROJECT_NAME,ONE_LINER,COMMANDS,ARCHITECTURE,INVARIANTS,DEFAULT_BRANCH	evolve
AGENTS.md.tmpl	AGENTS.md	PROJECT_NAME	create
settings.json.tmpl	.claude/settings.json	GATE_PERMISSIONS	evolve
gitignore-additions.txt	.gitignore	-	evolve
docs/README.md.tmpl	docs/dev/README.md	PROJECT_NAME	create
docs/CONTEXT.md.tmpl	docs/dev/CONTEXT.md	PROJECT_NAME	create
docs/backlog.md.tmpl	docs/dev/backlog.md	-	create
program/POLICY.md.tmpl	docs/dev/POLICY.md	GATE_TABLE,BASELINE_COUNT,BASELINE_SHA,TODAY,TRUST_BOUNDARIES,INVARIANTS,DEFAULT_BRANCH,PR_RULE,MODEL_OVERRIDES,OWNERSHIP,STANDING_AUTHORIZATION,PHASE_SCOPE,SPEC_LIFECYCLE	create
program/RULINGS.md.tmpl	docs/dev/RULINGS.md	-	create
program/HISTORY.md.tmpl	docs/dev/HISTORY.md	-	create
program/foreman.json.tmpl	.foreman/foreman.json	PROGRAM_NAME,TODAY,WORK_ROOT,REPO_NAME,REPO_PATH,DEFAULT_BRANCH	create
program/work-root.gitignore	.foreman/.gitignore	-	create
program/STATE.md.tmpl	.foreman/STATE.md	PROJECT_NAME,TODAY	create
program/DEFERRED.md.tmpl	.foreman/DEFERRED.md	-	create
program/kickoff.md.tmpl	.foreman/phases/{{PHASE_SLUG}}/kickoff.md	PHASE_SLUG,PHASE_NAME,CONTEXT,PLAN_PATH,SPEC_REF,RULINGS,MODEL,EFFORT,WORK_ROOT,POLICY_PATH	create
plans/plan-README.md.tmpl	.foreman/plans/{{PLAN_SLUG}}/README.md	PLAN_SLUG,PLAN_NAME,GOAL,ARCHITECTURE,STACK,SPEC_PATH,GLOBAL_CONSTRAINTS,BASELINE_COUNT,BASELINE_SHA,TASK_TABLE,WORK_ROOT	create
plans/task-N.md.tmpl	.foreman/plans/{{PLAN_SLUG}}/task-{{TASK_NUMBER}}.md	PLAN_SLUG,TASK_NUMBER,TASK_NAME,FILES,INTERFACES,WORK_ROOT	create
specs/spec.md.tmpl	docs/dev/specs/{{TODAY}}-{{TOPIC}}.md	TOPIC,TODAY,PURPOSE	create
```

**`program/foreman.json.tmpl`** (new):

```json
{
  "program": "{{PROGRAM_NAME}}",
  "mode": "single",
  "created": "{{TODAY}}",
  "work_root": "{{WORK_ROOT}}",
  "repos": [
    {
      "name": "{{REPO_NAME}}",
      "path": "{{REPO_PATH}}",
      "default_branch": "{{DEFAULT_BRANCH}}",
      "policy": "{{REPO_PATH}}/docs/dev/POLICY.md",
      "notes": ""
    }
  ],
  "defaults": { "executor_model": "sonnet", "executor_effort": "medium" },
  "adapters": { "tracker": null, "status": null }
}
```

**`program/work-root.gitignore`** (new):

```
# Review diff packages are regenerable. Everything else in the work root is committed here, to
# this nested repository -- and never to the product repository, which ignores this directory.
*.diff
```

**`gitignore-additions.txt`** — replace the whole file:

```
# Harness: regenerable review diff packages.
*.diff

# Harness work root: transient program state -- STATE.md, ledgers, briefs, reviews, plans,
# reports -- in a nested repository of its own, versioned there and never here. `git clean -fdx`
# deletes it, history included: -x removes ignored files.
/.foreman/

# Per-contributor: Claude Code writes local permission grants here. Never shared, never tracked.
.claude/settings.local.json
```

**`CLAUDE.md.tmpl`** — in "## Invariants", change `docs/dev/program/POLICY.md` to
`docs/dev/POLICY.md`. In "## How work is organised", replace the line
`- Current state: \`docs/dev/program/STATE.md\`.` with:

```
- Durable record — policy, rulings, history, specs — in `docs/dev/`, tracked. Transient state —
  `STATE.md`, ledgers, plans, reports — in `.foreman/`, a nested repository this one ignores.
- Current state: `.foreman/STATE.md`.
```

**`docs/README.md.tmpl`** — replace the table with:

```
| Path | Kind | Contents | Who reads it |
|---|---|---|---|
| `POLICY.md` | durable, per repository | gates, baseline, boundaries, invariants | all three tiers |
| `CONTEXT.md` | durable, per repository | standing facts that outlive any one plan | any session, when pointed at it |
| `backlog.md` | durable, per repository | deferred minors, tracked | the program manager, and any phase that can absorb one |
| `reference/` | durable, per repository | measurements and calibration findings | whoever needs a measured number |
| `specs/` | durable, per program | design of record — what and why | anyone implementing against a design |
| `RULINGS.md` | durable, per program | standing decisions | the program manager; a session when told |
| `HISTORY.md` | durable, per program | completed phases, distilled | rarely |
| `../.foreman/STATE.md` | transient | current state only, short by design | the program manager, every session |
| `../.foreman/DEFERRED.md` | transient | checks needing elapsed time or an event | the program manager, when one comes due |
| `../.foreman/phases/<slug>/` | transient | kickoff, ledger, briefs, reports, reviews | that phase's session |
| `../.foreman/plans/<slug>/` | transient | `README.md` for shared constraints, `task-N.md` per task | the session executing a task |
| `../.foreman/reports/` | transient | one file per session — the audit trail | whoever comes next |
```

and add after the naming paragraph:

```
**The split is by durability, not by tier.** Everything under `docs/dev/` outlives the program
and is tracked. Everything under `.foreman/` — the *work root* — is state a running program
needs and nobody needs afterwards; it is a git repository of its own, ignored by this one, so it
is versioned and recoverable without ever entering this repository's history. `git clean -fdx`
deletes it, history included. Kickoffs and plans are transient because what a phase was asked
to do survives as its `HISTORY.md` entry, and a plan is superseded by the code it produced.
```

Replace "## Who writes what" with:

```
## Who writes what

One writer per file. `POLICY.md`, `RULINGS.md` and `HISTORY.md` here, and `STATE.md`,
`DEFERRED.md` and every `kickoff.md` in the work root, are the program manager's. A phase's
`state.md`, its task artefacts, its plan and its report are that phase's, under the work root's
`phases/<slug>/`, `plans/<slug>/` and `reports/`. Every session commits to the work root's own
repository and stages only its own paths; the program manager reads a ledger with
`foreman-state`, which reads a file and touches no checkout.
```

**`program/kickoff.md.tmpl`** — replace the "## First" section's first paragraph with:

```
Record `<main-checkout>` (the directory `/foreman:phase` was invoked from — `git rev-parse
--show-toplevel`, not a worktree) and `<default>` (the default branch) before entering the
worktree — they are needed at gate 6 and are hard to reconstruct once inside a worktree.

**Work root** `{{WORK_ROOT}}` — absolute, at the main checkout, a nested repository. Your
ledger, briefs, reviews and report all live under it, and every commit of them goes to *its*
repository (`git -C {{WORK_ROOT}} add phases/{{PHASE_SLUG}}`, then commit), never to the product
repository. **Policy** `{{POLICY_PATH}}` — read the worktree's copy of the same file. Then:
```

In "## Read first", change the second bullet to `- \`{{POLICY_PATH}}\` — gate commands,
baseline, trust boundaries, invariants`. In "## Report back", replace the first paragraph with:

```
Write `{{WORK_ROOT}}/phases/{{PHASE_SLUG}}/state.md` as you go and commit it to the work root's
repository — the program manager reads it as a file with `foreman-state`.
```

**`program/STATE.md.tmpl`** — replace the paragraph beginning `One row per phase` with:

```
One row per phase, edited in place as its status changes across the phase's lifetime — never
appended to as a second row for the same phase. The `Branch` column is how the program manager
finds a phase's worktree to probe. `foreman-state` does not read this table: it reads the ledger
at `phases/<slug>/state.md`, beside this file.
```

Keep the header row `| Phase | Owner | Branch | Status | Next action |` exactly as it is.

**`plans/plan-README.md.tmpl`** line 3 → `**Plan directory:** \`{{WORK_ROOT}}/plans/{{PLAN_SLUG}}/\`
— this file plus one \`task-N.md\` per task.` **`plans/task-N.md.tmpl`** line 3 →
`**Plan:** \`{{WORK_ROOT}}/plans/{{PLAN_SLUG}}/README.md\` — shared constraints and the task table.`

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, roughly `+17` on the count before this task. If
`exactly one manifest row for program/work-root.gitignore` is red, the `find … ! -name
MANIFEST.tsv` loop found the new file and the manifest row's `template` cell does not match it
exactly. If `every manifest row's variables cell is well-formed` is red, a variables cell has a
space after a comma.

- [ ] **Step 5: Mutation-check**

Temporarily put `"mode": "{{MODE}}"` in `foreman.json.tmpl`: two assertions go red (`renders mode
single`, `no variable … unsubstituted`). Restore. Temporarily change one `.foreman/` destination
back to `docs/dev/program/`: the destination-table assertion goes red. Restore. Temporarily
remove `/.foreman/` from `gitignore-additions.txt`: its assertion goes red. Restore. Green.

- [ ] **Step 6: Commit**

```bash
git add skills/foreman-init/templates tests/test_templates.sh
git commit -m "templates: manifest on the spec 4.1 layout; foreman.json and work-root gitignore templates; kickoff carries the roots"
```
