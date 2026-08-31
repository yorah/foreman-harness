# Task 8: Templates and their manifest

Implements spec §6 and §4.1 — everything `harness-init` writes into a target repository. The
manifest makes generation mechanical: a template with no manifest row is never emitted, and a
variable used but not declared is a test failure rather than an unreplaced `{{...}}` in
somebody's repo.

**Files:**
- Create: `skills/harness-init/templates/MANIFEST.tsv`
- Create: 17 template files (listed in the manifest below)
- Test: `tests/test_templates.sh`

**Interfaces:**
- Produces, for Task 9: `MANIFEST.tsv`, tab-separated, four columns and a header row:
  `template<TAB>destination<TAB>variables<TAB>mode`
  - `template` — path relative to `skills/harness-init/templates/`
  - `destination` — path relative to the target repo root
  - `variables` — comma-separated `{{NAME}}` variables, or `-` for none
  - `mode` — `create` (never overwrite an existing file) or `evolve` (merge with what exists)
- Placeholder syntax is `{{UPPER_SNAKE}}`. No other substitution syntax exists.
- **Emitted-at rule.** A row whose `destination` itself contains `{{...}}` is emitted **on
  demand**, by the tier that authors that specific document (a phase kickoff, a plan's
  `README.md`, one task file, one spec) — not by `/harness-init` at generation time, since the
  path variable (e.g. `{{PHASE_SLUG}}`) has no value until that document is about to be written.
  Every row whose `destination` has no `{{...}}` is emitted once, at init. No fifth column is
  needed: the manifest already encodes the distinction in `destination` itself. As of this
  manifest the on-demand rows are exactly `program/kickoff.md.tmpl`, `plans/plan-README.md.tmpl`,
  `plans/task-N.md.tmpl`, and `specs/spec.md.tmpl`; `tests/test_templates.sh` asserts this in
  both directions — those four and only those four have a `{{` in their destination.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_templates.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$HARNESS_ROOT/tests/lib_assert.sh"

t="$HARNESS_ROOT/skills/harness-init/templates"
mf="$t/MANIFEST.tsv"
[ -f "$mf" ] || fail "missing $mf"

# Header shape. Built with printf: a literal tab in this file is one keystroke away from
# being saved as spaces, and the resulting failure would look like a manifest defect.
assert_eq "$(printf 'template\tdestination\tvariables\tmode')" "$(head -1 "$mf")" \
  "manifest header"

# Every template file has a manifest row.
while IFS= read -r f; do
  rel="${f#"$t"/}"
  [ "$rel" = "MANIFEST.tsv" ] && continue
  assert_eq "1" "$(awk -F'\t' -v r="$rel" 'NR>1 && $1==r {n++} END{print n+0}' "$mf")" \
    "exactly one manifest row for $rel"
done < <(find "$t" -type f ! -name MANIFEST.tsv)

# Every manifest row points at a template that exists, and a sane mode.
errs="$(mktemp)"
tail -n +2 "$mf" | while IFS=$'\t' read -r tpl dest vars mode; do
  [ -n "$tpl" ] || continue
  [ -f "$t/$tpl" ] || printf 'MISSING_TEMPLATE %s\n' "$tpl"
  [ -n "$dest" ] || printf 'NO_DEST %s\n' "$tpl"
  case "$mode" in create|evolve) : ;; *) printf 'BAD_MODE %s %s\n' "$tpl" "$mode" ;; esac
done > "$errs"
assert_eq "" "$(cat "$errs")" "manifest rows are well formed"
rm -f "$errs"

# Every {{VAR}} used in a template is declared in its row.
undeclared=""
while IFS=$'\t' read -r tpl dest vars mode; do
  [ -n "$tpl" ] && [ -f "$t/$tpl" ] || continue
  used="$(grep -oE '\{\{[A-Z0-9_]+\}\}' "$t/$tpl" | tr -d '{}' | sort -u || true)"
  for u in $used; do
    case ",$vars," in
      *",$u,"*) : ;;
      *) undeclared="$undeclared $tpl:$u" ;;
    esac
  done
done < <(tail -n +2 "$mf")
assert_eq "" "$undeclared" "every used variable is declared"

# Every declared variable is actually used (no dead declarations).
unused=""
while IFS=$'\t' read -r tpl dest vars mode; do
  [ -n "$tpl" ] && [ -f "$t/$tpl" ] || continue
  [ "$vars" = "-" ] && continue
  for d in $(printf '%s' "$vars" | tr ',' ' '); do
    grep -q "{{$d}}" "$t/$tpl" || unused="$unused $tpl:$d"
  done
done < <(tail -n +2 "$mf")
assert_eq "" "$unused" "every declared variable is used"

# Spec §6 destinations are all covered.
for d in CLAUDE.md AGENTS.md docs/dev/README.md docs/dev/CONTEXT.md docs/dev/backlog.md \
         docs/dev/program/POLICY.md docs/dev/program/STATE.md docs/dev/program/RULINGS.md \
         docs/dev/program/DEFERRED.md docs/dev/program/HISTORY.md; do
  assert_eq "1" "$(awk -F'\t' -v d="$d" 'NR>1 && $2==d {n++} END{print n+0}' "$mf")" \
    "manifest covers $d"
done

# POLICY must carry the machine-readable baseline line baseline-check.sh reads.
assert_contains "$(cat "$t/program/POLICY.md.tmpl" 2>/dev/null || true)" "baseline-count:" \
  "POLICY template carries baseline-count:"

# Every scripts/*.sh a template names must be qualified with $CLAUDE_PLUGIN_ROOT. These files
# are emitted into a target repository, where nothing under scripts/ exists -- the plugin ships
# it. Unlike the shipped skills, a template has no legitimate unqualified prose mention either,
# so this check is stricter than the one in tests/test_program_skill.sh: any occurrence at all,
# with or without arguments, is a defect.
# Verified before shipping, against planted templates: the three qualified forms (inline
# backtick, quoted, and a `\`-continued call) produce no hit; a bare mention in prose and a
# bare invocation each produce exactly one, named by file.
unqualified_tpl=""
while IFS= read -r tf; do
  hit="$(sed -E ':a; /\\$/{N; s/\\\n[[:space:]]*/ /; ba}' "$tf" \
        | grep -oE '[^ `"]*scripts/[a-z-]+\.sh' | grep -v 'CLAUDE_PLUGIN_ROOT' || true)"
  [ -n "$hit" ] && unqualified_tpl="$unqualified_tpl ${tf#"$t"/}:$(printf '%s' "$hit" | tr '\n' ',')"
done < <(find "$t" -type f ! -name MANIFEST.tsv)
assert_eq "" "$unqualified_tpl" "every scripts/*.sh in a template is qualified"

# The phase-table status vocabulary must cover the outcomes a phase can actually halt on --
# harness-program branches on all three, and a status column that cannot express them forces
# the PM to record a halted phase as running.
state_tmpl="$(cat "$t/program/STATE.md.tmpl" 2>/dev/null || true)"
for st in blocked deferred unverified; do
  assert_contains "$state_tmpl" "\`$st\`" "STATE.md template's statuses include $st"
done

# POLICY.md is the program manager's to edit; harness-program instructs exactly that when a
# baseline-count line is wrong. The template must not forbid what the skill requires.
assert_contains "$(cat "$t/program/POLICY.md.tmpl" 2>/dev/null || true)" \
  "The program manager owns this file" "POLICY template names its writer"

# No placeholders-of-the-wrong-kind in templates.
assert_eq "" "$(grep -rlE '\b(TODO|TBD|FIXME)\b' "$t" || true)" "no TODO/TBD/FIXME in templates"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run.sh` — FAIL, `missing .../MANIFEST.tsv`.

- [ ] **Step 3: Write `MANIFEST.tsv`**

Tab-separated. Use literal tabs, not spaces.

```
template	destination	variables	mode
CLAUDE.md.tmpl	CLAUDE.md	PROJECT_NAME,ONE_LINER,COMMANDS,ARCHITECTURE,INVARIANTS,DEFAULT_BRANCH	evolve
AGENTS.md.tmpl	AGENTS.md	PROJECT_NAME	create
settings.json.tmpl	.claude/settings.json	GATE_PERMISSIONS	evolve
gitignore-additions.txt	.gitignore	-	evolve
docs/README.md.tmpl	docs/dev/README.md	PROJECT_NAME	create
docs/CONTEXT.md.tmpl	docs/dev/CONTEXT.md	PROJECT_NAME	create
docs/backlog.md.tmpl	docs/dev/backlog.md	-	create
program/POLICY.md.tmpl	docs/dev/program/POLICY.md	GATE_TABLE,BASELINE_COUNT,BASELINE_SHA,TODAY,TRUST_BOUNDARIES,INVARIANTS,DEFAULT_BRANCH,PR_RULE,MODEL_OVERRIDES,OWNERSHIP	create
program/STATE.md.tmpl	docs/dev/program/STATE.md	PROJECT_NAME,TODAY	create
program/RULINGS.md.tmpl	docs/dev/program/RULINGS.md	-	create
program/DEFERRED.md.tmpl	docs/dev/program/DEFERRED.md	-	create
program/HISTORY.md.tmpl	docs/dev/program/HISTORY.md	-	create
program/kickoff.md.tmpl	docs/dev/program/phases/PHASE_SLUG/kickoff.md	PHASE_SLUG,PHASE_NAME,CONTEXT,PLAN_PATH,SPEC_REF,RULINGS,MODEL,EFFORT	create
plans/plan-README.md.tmpl	docs/dev/plans/PLAN_SLUG/README.md	PLAN_NAME,GOAL,ARCHITECTURE,STACK,SPEC_PATH,GLOBAL_CONSTRAINTS,BASELINE_COUNT,BASELINE_SHA,TASK_TABLE	create
plans/task-N.md.tmpl	docs/dev/plans/PLAN_SLUG/task-N.md	TASK_NUMBER,TASK_NAME,FILES,INTERFACES	create
specs/spec.md.tmpl	docs/dev/specs/TODAY-TOPIC.md	TOPIC,TODAY,PURPOSE	create
```

`PHASE_SLUG`, `PLAN_SLUG`, `TODAY-TOPIC` and `task-N` in the destination column are
substituted by the caller at emit time; they are path variables, not file-content variables,
which is why they are absent from the `variables` column.

- [ ] **Step 4: Write the program templates**

`program/POLICY.md.tmpl`:

```markdown
# Program policy

The repository's answers. Read by the program manager, every phase controller, and every
reviewer.

**The program manager owns this file** and edits it directly — correcting a wrong
`baseline-count:` is its job, not a reason to re-run anything. **A phase session never edits it**:
a phase that believes this file is wrong says so in its summary and stops. Structural changes —
new gates, new trust boundaries — come from re-running `/harness-init`.

## Gate commands

Run in this order. All must be green before a phase may merge.

{{GATE_TABLE}}

## Baseline

baseline-count: {{BASELINE_COUNT}}

Green at `{{BASELINE_SHA}}`, recorded {{TODAY}}. A task report whose test count falls below
this is rejected before a reviewer is spawned. Raise it when a phase merges; never lower it
without a ruling that says why.

## Trust boundaries

Touching any of these escalates the task's model and its reviewer's model, per the model table.

{{TRUST_BOUNDARIES}}

## Invariants

Numbered, and injected verbatim into every implementer and reviewer dispatch. A reviewer
returns one verdict per invariant the diff could plausibly touch.

{{INVARIANTS}}

## Integration

- Phase branches base on `origin/{{DEFAULT_BRANCH}}` (`worktree.baseRef: fresh`).
- On completion: rebase, **re-run the full gate chain on the rebased tree**, merge, push.
- Escalate to a pull request instead of a direct merge when: {{PR_RULE}}
- Force-push: never.

## Model table

Defaults are in the `harness-phase` and `harness-program` skills. Overrides for this
repository, each with its reason:

{{MODEL_OVERRIDES}}

## Ownership

Who else works here, and which surfaces they own. Two phases must not claim the same surface.

{{OWNERSHIP}}
```

`program/STATE.md.tmpl`:

```markdown
# {{PROJECT_NAME}} — program state

The program manager's working memory, read at the start of every session. **Kept short
deliberately** — completed phases live in `HISTORY.md`, standing decisions in `RULINGS.md`,
time-gated checks in `DEFERRED.md`.

Last updated {{TODAY}}.

## Phases

| Phase | Owner | Branch | Status | Next action |
|---|---|---|---|---|

One row per phase. This table is parsed by `$CLAUDE_PLUGIN_ROOT/scripts/phase-state.sh` — keep
the column order.

Statuses: `planned`, `executing`, `gates`, `awaiting rebase`, `merged`, and the three a phase can
halt on — `blocked`, `deferred`, `unverified`. The last three are what a phase's own summary
reports; record the one you were told rather than leaving a halted phase reading `executing`,
which is the same untruth as a ledger that says `in-progress` at a stop.

## Next action

Nothing scheduled yet. Run `/program` and refine the first spec.

## Open rulings

Rulings about the present. When one stops being about the present, move it to `RULINGS.md`.
```

`program/RULINGS.md.tmpl`:

```markdown
# Standing rulings

Decisions that constrain future work. The program manager reads this when a decision touches
one of them; a session reads it when told to. **Not** read every session — `STATE.md` is.

Each entry states what was decided, why, and what it costs if wrong.

**When a ruling stops being true, correct it here rather than deleting it**, so the reasoning
survives and the wrong belief is not rediscovered.
```

`program/DEFERRED.md.tmpl`:

```markdown
# Deferred checks

Checks that need elapsed time, a live event, or an integration before they can be answered.
**Read this when one comes due, not at every session start** — `STATE.md` names which are close.

A session must never hold itself open waiting for one; the program manager runs them.

Each entry: what is being checked, the exact command or query, and the **condition** under
which it becomes answerable — never a wall-clock time nobody has read.
```

`program/HISTORY.md.tmpl`:

```markdown
# Completed phases

Background, not working memory. Rarely read — move material here so `STATE.md` can stay short.

One section per completed phase: what it delivered, its commit range, the gate results, and
anything it deferred.
```

`program/kickoff.md.tmpl`:

```markdown
# {{PHASE_NAME}}

## First

`EnterWorktree(name: "{{PHASE_SLUG}}")` — branches from `origin/<default>`.

## Context

{{CONTEXT}}

## Read first

- `{{PLAN_PATH}}/README.md` — constraints and the task table
- `docs/dev/program/POLICY.md` — gate commands, baseline, trust boundaries, invariants
- {{SPEC_REF}} — the requirements this argues from

Read nothing else until a task requires it. **Do not read the plan's task bodies** — generate
briefs with `"$CLAUDE_PLUGIN_ROOT/scripts/task-brief.sh"`.

## Rulings that must not be relitigated

{{RULINGS}}

## Method

`harness-phase`. Subagent-driven execution against the plan, then the gate chain in
`references/gate-chain.md`.

## Report back

Write `docs/dev/program/phases/{{PHASE_SLUG}}/state.md` as you go and commit it — the program
manager reads it off your branch.

End with a summary under 150 words: status, commit range, gate results, open Minors, what
remains uncovered. The human pastes it to the program manager, so it must stand alone.

**Model** {{MODEL}}. **Effort** {{EFFORT}}.
```

- [ ] **Step 5: Write the root and docs templates**

`CLAUDE.md.tmpl`:

```markdown
# {{PROJECT_NAME}}

{{ONE_LINER}}

## Commands

{{COMMANDS}}

## Architecture

{{ARCHITECTURE}}

## Invariants

Check every change and every review against these. They are also in
`docs/dev/program/POLICY.md`, which is the copy dispatches quote.

{{INVARIANTS}}

## How work is organised

Non-trivial work runs as a **program**: one program-manager session coordinates and does not
write code; each phase goes to a **separate session** the human starts, which enters its own
worktree and executes one plan through subagents.

**This repository works in git worktrees.** A phase session creates its own under
`.claude/worktrees/<phase>`, branched from `origin/{{DEFAULT_BRANCH}}`.

- Program manager: `/program`. Phase: `/phase <kickoff>`. Status: `/program-status`.
- Documentation layout and who reads what: `docs/dev/README.md`.
- Current state: `docs/dev/program/STATE.md`.

## Rules every session follows

- **Document what you did, on disk.** Chat scrollback is not storage.
- **Test-first.** Write the failing test, confirm it fails for the reason you expect, then
  implement. A test that would pass against the bug you are fixing is not a test of your fix.
- **Verify against reality, not against the tests**, where the two can differ.
- **Never wait on elapsed time.** Report what you did, name the check and its condition, end.
- **Report faithfully.** If a step was skipped, say so.
```

`AGENTS.md.tmpl`:

```markdown
# {{PROJECT_NAME}}

Agent instructions for this repository live in `CLAUDE.md`. Read that file.

This file exists so tools that look for `AGENTS.md` find the pointer; it is deliberately not a
second copy, because a second copy drifts.
```

`docs/README.md.tmpl`:

```markdown
# docs/dev

The design record for {{PROJECT_NAME}}. Tracked in git — a second person, and a future
session, can both read it.

Each directory has **one audience**. Never read a whole directory; read the file you were
pointed at. This structure exists so that a session working on one component does not load the
whole system.

| Path | Contents | Who reads it |
|---|---|---|
| `specs/` | design of record — what and why | anyone implementing against a design |
| `plans/<slug>/` | `README.md` for shared constraints, `task-N.md` per task | the session executing a task |
| `reports/` | one file per session — the audit trail | whoever comes next |
| `reference/` | measurements and calibration findings | whoever needs a measured number |
| `CONTEXT.md` | standing facts that outlive any one plan | any session, when pointed at it |
| `backlog.md` | deferred minors, tracked | the program manager, and any phase that can absorb one |
| `program/STATE.md` | current state only, short by design | the program manager, every session |
| `program/POLICY.md` | gates, baseline, boundaries, invariants | all three tiers |
| `program/RULINGS.md` | standing decisions | the program manager; a session when told |
| `program/DEFERRED.md` | checks needing elapsed time or an event | the program manager, when one comes due |
| `program/HISTORY.md` | completed phases | rarely |
| `program/phases/<slug>/` | kickoff, ledger, briefs, reports, reviews | that phase's session |

Naming for `specs/` and `plans/`: `YYYY-MM-DD-<topic>`. The date is when the document was
written, not when the work finishes. One spec may spawn several plans.

**A plan is a directory.** `README.md` carries what every task shares; `task-N.md` carries one
task. A session opens one file.

**Cite the smallest file that answers the question, or a symbol name to grep for — never a
line range.** A line range in a file under active edit goes stale within a day.

## Who writes what

One writer per file. `program/STATE.md`, `RULINGS.md`, `DEFERRED.md`, `HISTORY.md`, `POLICY.md`
and every `kickoff.md` are the program manager's, on the default branch. A phase's `state.md`,
its task artifacts and its reports are that phase's, on its own branch — the program manager
reads them with `$CLAUDE_PLUGIN_ROOT/scripts/phase-state.sh`, which never dirties this
checkout.
```

`docs/CONTEXT.md.tmpl`:

```markdown
# Standing context for {{PROJECT_NAME}}

Facts and rules that outlive any one plan: measured values, environment quirks, gotchas found
the hard way, and deliberate deferrals with their reasons.

Git history is the record of what changed. **This file is the record of what was learned.**
Before a phase closes, anything it learned that outlives its plan is written here — that is a
blocking gate, not a courtesy.

Date every entry. Convert relative dates to absolute.
```

`docs/backlog.md.tmpl`:

```markdown
# Deferred backlog

Durable home for Minors and follow-ups a review deferred rather than fixing in-branch.

A phase may not finish while its ledger names a deferred item that is absent from this file.

Format: `- [ ] [source-tag] short description — why deferred, what it needs`

## Open
```

- [ ] **Step 6: Write the plan and spec templates**

`plans/plan-README.md.tmpl`:

```markdown
# {{PLAN_NAME}} Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** {{GOAL}}

**Architecture:** {{ARCHITECTURE}}

**Tech Stack:** {{STACK}}

**Spec:** `{{SPEC_PATH}}` — read it first. Where the plan and the spec disagree, the spec wins.

## Global Constraints

Every task's requirements implicitly include this section.

{{GLOBAL_CONSTRAINTS}}

## Baseline

`{{BASELINE_COUNT}}` green at `{{BASELINE_SHA}}`. No task may leave the suite below it.

## Task table

{{TASK_TABLE}}
```

`plans/task-N.md.tmpl`:

```markdown
# Task {{TASK_NUMBER}}: {{TASK_NAME}}

**Files:**
{{FILES}}

**Interfaces:**
{{INTERFACES}}

---

- [ ] **Step 1: Write the failing test**

- [ ] **Step 2: Run it to verify it fails for the expected reason**

- [ ] **Step 3: Implement the minimal change**

- [ ] **Step 4: Run the gate commands**

- [ ] **Step 5: Commit**
```

`specs/spec.md.tmpl`:

```markdown
# {{TOPIC}} — design spec

**Status:** draft, {{TODAY}}.

## Purpose

{{PURPOSE}}

## Non-goals

## Design

## Open questions

Every question here must be ruled before a plan is written against this spec. A plan that
inherits an open question stalls a session.

## Verification

How anyone will know this works, stated as observations rather than intentions.
```

- [ ] **Step 7: Write `settings.json.tmpl` and `gitignore-additions.txt`**

`settings.json.tmpl`:

```json
{
  "enabledPlugins": {
    "harness@harness": true,
    "superpowers@claude-plugins-official": true,
    "fable@fable-method": true,
    "claude-md-management@claude-plugins-official": true
  },
  "worktree": {
    "baseRef": "fresh"
  },
  "permissions": {
    "allow": [
{{GATE_PERMISSIONS}}
    ]
  }
}
```

`gitignore-additions.txt`:

```
# Harness: regenerable review diff packages. Everything else under docs/dev/ is tracked
# on purpose — a ledger a second person cannot read is not a ledger.
*.diff
```

- [ ] **Step 8: Run the tests to verify they pass**

```bash
bash tests/run.sh
```

Expected: `0 failed`. If "every declared variable is used" fails, a manifest row lists a
variable its template does not contain — fix the row or the template, do not delete the check.

- [ ] **Step 9: Commit**

```bash
git add skills/harness-init/templates tests/test_templates.sh
git commit -m "feat(templates): target-repo template set with a validated manifest"
```
