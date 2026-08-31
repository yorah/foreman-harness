# Task 6: the `harness-phase` skill and `/phase`

Implements spec §5.2, §8 and §9. The phase controller: a session that enters its own worktree,
executes one plan through subagents, runs the gate chain, and merges.

**Files:**
- Create: `skills/harness-phase/SKILL.md`
- Create: `skills/harness-phase/references/gate-chain.md`
- Create: `commands/phase.md`
- Test: `tests/test_phase_skill.sh`

**Interfaces:**
- Consumes: `scripts/task-brief.sh` (Task 3), `scripts/baseline-check.sh` (Task 4), the four
  agents (Task 5).
- Produces, for Task 10: `/phase <kickoff-path>` enters a worktree and runs a plan end to end.


> **Historical reference code.** The code blocks below are the plan as written *before*
> execution. Several were superseded by fix rounds during execution and are **not** what shipped.
> For one example — from a sibling plan, not this file — `task-2.md`'s model check shows a
> substring match (`*opus*|*fable*`) that the shipped `resolve-gate.sh` replaced with whole-token
> matching because the substring form accepts `notopus` and `fabled`. **The files in the
> repository are authoritative; this document records intent, not current behaviour.** Tracked
> as `[T-PLAN]` in `docs/dev/backlog.md`.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_phase_skill.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$HARNESS_ROOT/tests/lib_assert.sh"

s="$HARNESS_ROOT/skills/harness-phase/SKILL.md"
g="$HARNESS_ROOT/skills/harness-phase/references/gate-chain.md"
c="$HARNESS_ROOT/commands/phase.md"

for f in "$s" "$g" "$c"; do [ -f "$f" ] || fail "missing $f"; done

skill="$(cat "$s" 2>/dev/null || true)"
assert_contains "$skill" "EnterWorktree"        "step 1 enters a worktree"
assert_contains "$skill" "task-brief.sh"        "briefs come from the script"
assert_contains "$skill" "baseline-check.sh"    "baseline gate is wired"
assert_contains "$skill" "harness-implementer"  "dispatches the implementer agent"
assert_contains "$skill" "harness-task-reviewer" "dispatches the task reviewer"
assert_contains "$skill" "Ruling:"              "records rulings in the ledger format"
assert_contains "$skill" "state.md"             "writes the phase state file"
assert_contains "$skill" "trust boundary"       "the model table escalates at trust boundaries"
assert_contains "$skill" "Haiku"                "the model table covers the cheap tier"
assert_contains "$skill" "529"                  "the dead-subagent protocol is present"
assert_not_contains "$skill" "sabotage"         "the sabotage protocol is excluded by decision"

gate="$(cat "$g" 2>/dev/null || true)"
assert_contains "$gate" "fable-judge"           "adversarial verification is in the chain"
assert_contains "$gate" "harness-branch-reviewer" "whole-branch review is in the chain"
assert_contains "$gate" "backlog.md"            "backlog flush gate"
assert_contains "$gate" "CONTEXT.md"            "context distillation gate"
assert_contains "$gate" "rebase"                "rebase before merge"
assert_contains "$gate" "re-run"                "gates re-run on the rebased tree"

# Ordering: the rebase must precede the merge in the written chain.
rebase_line="$(grep -n 'rebase' "$g" | head -1 | cut -d: -f1)"
merge_line="$(grep -n 'merge' "$g" | tail -1 | cut -d: -f1)"
[ -n "$rebase_line" ] && [ -n "$merge_line" ] && [ "$rebase_line" -lt "$merge_line" ] \
  && _ok || fail "gate chain must place the rebase before the merge"

assert_contains "$(cat "$c" 2>/dev/null || true)" "harness-phase" "command invokes the skill"
```

Note `_ok` is the internal counter helper from `lib_assert.sh`; it is used directly here
because the assertion is a line-order comparison rather than a string match.

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run.sh` — FAIL, `missing .../harness-phase/SKILL.md`.

- [ ] **Step 3: Write `skills/harness-phase/SKILL.md`**

````markdown
---
name: harness-phase
description: Execute one harness phase — enter a worktree, run a plan task-by-task through implementer and reviewer subagents, run the gate chain, and merge. Use when handed a kickoff file by a program manager, or when the user says /phase.
---

# Phase controller

You execute **one plan**. You do not re-plan the program, and you do not decide what the next
phase should be — that is the program manager's job.

Announce: "Running phase `<slug>` from `<kickoff path>`."

## Step 1 — enter the worktree

```
EnterWorktree(name: "<phase-slug>")
```

This creates `.claude/worktrees/<phase-slug>` and branches from `origin/<default-branch>`
under `worktree.baseRef: fresh`, which is the correct base when other people are pushing.

If `EnterWorktree` is unavailable:

```bash
git worktree add .claude/worktrees/<slug> -b <branch> origin/main
```
then `EnterWorktree(path: "<abs path>")`.

Record the absolute worktree path. Every dispatch you make from here uses it.

## Step 2 — read exactly four things

The kickoff file, the plan's `README.md`, `docs/dev/program/POLICY.md`, and the spec section
the kickoff names. **Never read the plan's task bodies yourself** — that is what briefs are
for, and reading them is how a controller's context fills before the plan is half done.

From `POLICY.md` take: the gate commands, the baseline, the trust boundaries, and the
numbered invariants. The invariants are injected verbatim into every dispatch.

## Step 3 — open the ledger

Write `docs/dev/program/phases/<slug>/state.md`, starting with the machine-readable head:

```yaml
---
phase: <slug>
plan: docs/dev/plans/<slug>/
branch: <branch>
baseline: <N> at <sha>
tasks:
  - {n: 1, model: sonnet, effort: medium, status: pending, commits: "", verdict: "", minors: []}
---
```

Then the prose: resolved design forks from the kickoff, and a section per task as you go.
Commit it. Update and commit it after every task — the PM reads it off your branch with
`scripts/phase-state.sh`, so an uncommitted ledger is an invisible one.

## Step 4 — per task

1. **Generate the brief.** Never hand-write one, and never reuse one:

   ```bash
   scripts/task-brief.sh --plan <abs-plan-dir> --task N \
     --phase-dir <abs-phase-dir> --worktree <abs-worktree> --policy <abs-policy>
   ```

   The script regenerates from the current plan and refuses when the task file's heading
   disagrees with the number. Both guard the stale-brief class of bug.

2. **Dispatch the implementer** (`harness-implementer`), at the model and effort the plan's
   task table assigns. It receives the brief path, the absolute worktree path and the
   invariants. Nothing else — not the plan, not this conversation.

3. **Baseline gate, before any reviewer exists:**

   ```bash
   scripts/baseline-check.sh --policy <abs-policy> --count <reported-count>
   ```

   Exit 1 means the count fell below baseline: reject the task and send it back without
   spending a reviewer. Exit 2 means no baseline is recorded — say so, and treat the task as
   unverified rather than passed.

4. **Generate the review package** to a file, then dispatch `harness-task-reviewer`:

   ```bash
   git diff <base>..<head> > <abs-phase-dir>/review-<base>..<head>.diff
   ```

   The reviewer gets that file path, the brief path and the invariants.

5. **Fix loop, at most five rounds.** Rounds 1–3 resume the same implementer; rounds 4–5 use
   a fresh implementer on a more capable model. At round 5 the breaker trips: adjudicate each
   open finding yourself, park the non-load-bearing ones in the ledger with rulings, continue.

6. **Update the ledger.** Commit range, verdict, deviations, numbered Minors `[TN-MK]`, and
   the model and effort **actually used**. Commit.

## Rulings, not stalls

A running plan does not wait on a human. Conflicts, ambiguities, plan defects — decide them,
and record each in the ledger as:

```
Ruling: <what you decided> — <why> — <what it costs if wrong>
```

Four things stop you and only these: an irreversible or destructive operation; a
security-sensitive action; a side effect outside this worktree that norms say you ask about
first; and a plan so broken that every path forward is a guess.

A wrong ruling costs rework the human can see and undo. A session parked on a question costs
their whole day and buys nothing.

## Model and effort

The plan's task table assigns these. Where it does not, use this default table, and record the
model and effort **actually used** in the ledger — after a few phases the table stops being an
assumption and becomes evidence.

| Work | Model | Effort |
|---|---|---|
| You, the controller | Sonnet | medium |
| You, when the phase touches a trust boundary | Opus | high |
| Transcription — the plan carries the literal code | Haiku | low |
| Implementation | Sonnet | medium |
| Implementation at a trust boundary | Opus | high |
| Task review | Sonnet | medium |
| Task review at a trust boundary, or of a large diff | Opus | high |
| Whole-branch review | Opus | high |

Trust boundaries are named in `POLICY.md`, and `POLICY.md`'s model-override section wins over
this table where the two disagree.

## Failure protocols

- **A subagent dies mid-task** (a 529, a session limit). Verify the tests yourself, commit the
  completed work yourself, then dispatch the reviewer against the committed diff. If the agent
  is resumable, resuming it by message retains its context — prefer that.
- **A reviewer's finding conflicts with the plan text.** Rule on it, ledger the ruling, then
  dispatch the fix. The spec is the binding authority; the plan is its argument.
- **A task must be reordered** because a dependency demands it. Fine. Note it in the ledger.
- **A brief contradicts the codebase.** The implementer may deviate; the report must declare
  the deviation and the reviewer must judge it. A deviation that reaches the ledger unjudged is
  a defect in your process, not theirs.

## Step 5 — the gate chain

Read `references/gate-chain.md` and run it in order. Do not skip a gate because an earlier one
was clean; they fail differently.

## Step 6 — report

Write `docs/dev/reports/YYYY-MM-DD-<slug>.md`: the session-level record, for whoever comes
next. Then end with a summary **under 150 words** — status, commit range, gate results, open
Minors, what remains uncovered. The human pastes it to the program manager, so it must stand
alone.

## What you never do

- Read the plan's task bodies (briefs exist for that).
- Paste accumulated history into a dispatch. A fresh subagent gets its brief path, the
  interfaces it touches, the invariants, and nothing else.
- Use a relative path in a dispatch.
- Wait on elapsed time. Name the deferred check and end; the PM runs it.
- State a wall-clock time you have not read.
````

- [ ] **Step 4: Write `skills/harness-phase/references/gate-chain.md`**

````markdown
# The gate chain

Run in order, after the last task's ledger entry is committed. Each gate is cheap relative to
the thing it protects, and they fail differently — a clean earlier gate is not a reason to skip
a later one.

## 1. Gate commands

Every command in `POLICY.md`'s gate table, in its stated order, all green. Paste the actual
output into the ledger, including the test counts. A claim of green without the count is not
evidence.

## 2. Whole-branch review

```bash
git diff origin/<default>...HEAD > <abs-phase-dir>/review-branch.diff
```

Dispatch `harness-branch-reviewer` (Opus, high effort, always) with that file, the plan
directory, the spec path and the numbered invariants. It looks for what the per-task reviews
structurally could not see: cross-task incoherence, interface drift, invariant erosion, and
scope nobody asked for.

Findings get **one** fix dispatch and one scoped re-review. Adjudicate any residuals.

## 3. Adversarial verification

Invoke `fable:fable-judge` on the branch. It treats "done" as a set of claims: it re-runs the
claimed verifications, diffs what actually changed against what was said to change, and hunts
weakened tests and false completion claims.

The branch reviewer grades a diff; the judge checks whether the verification actually
happened. That is why both run.

A `REFUTED` verdict stops the merge. `VERIFIED WITH CAVEATS` proceeds only if every caveat is
recorded in the ledger and any that outlives the branch reaches `backlog.md`.

## 4. Backlog flush — blocking

Every Minor the reviews deferred rather than fixed must appear in `docs/dev/backlog.md`,
tagged with its source (`[TN-MK]`), before this phase can finish. One line each, saying why it
was deferred and what it needs.

**You may not finish while the ledger names a deferred item absent from the backlog.** A
deferred item nobody wrote down is a forgotten one.

## 5. Context distillation — blocking

Anything learned in this phase that outlives the plan goes into `docs/dev/CONTEXT.md`: a
measured fact, a gotcha, a ruling that will constrain future work, a technique that worked.

Git history is the record of what changed. `CONTEXT.md` is the record of what was learned.
Nothing else preserves the second.

If a ruling is durable enough to constrain future phases, promote it to
`docs/dev/program/RULINGS.md` and say so in your report so the PM sees it.

## 6. Integration

```bash
git fetch origin
git rebase origin/<default>
```

Then **re-run gate 1 in full on the rebased tree**. This is the load-bearing step: a branch
that was green before a rebase proves nothing about the tree after it. A clean textual merge
routinely hides a semantic conflict, and with several people pushing that is the common case,
not the exotic one.

Only then:

```bash
git checkout <default> && git merge --ff-only <branch> && git push origin <default>
```

Escalate to a pull request instead of a direct merge when the phase touched a declared trust
boundary, or whenever `POLICY.md` says so. In that case push the branch and open the PR with
the gate evidence in its body — do not merge.

Never force-push.

## 7. Close

`superpowers:finishing-a-development-branch`. The ledger and the reports are tracked and
travel with the merge, so nothing needs rescuing from scratch before the worktree goes.
````

- [ ] **Step 5: Write `commands/phase.md`**

```markdown
---
description: Execute one harness phase from its kickoff file
---

Run the phase whose kickoff file is: $ARGUMENTS

Use the `harness-phase` skill. If no kickoff path was given, read
`docs/dev/program/STATE.md`, list the phases whose status is `planned`, and ask which one.
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
bash tests/run.sh
```
Expected: `0 failed`, count above Task 5's baseline.

- [ ] **Step 7: Commit**

```bash
git add skills/harness-phase commands/phase.md tests/test_phase_skill.sh
git commit -m "feat(phase): phase controller skill and its gate chain"
```
