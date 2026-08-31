# Task 7: the `harness-program` skill, `/program` and `/program-status`

Implements spec §5.1, §7, §8.1–8.2 and §13. The program manager: the session that keeps the
map, writes the kickoffs, and never writes code.

**Files:**
- Create: `skills/harness-program/SKILL.md`
- Create: `skills/harness-program/references/milestones.md`
- Create: `commands/program.md`
- Create: `commands/program-status.md`
- Test: `tests/test_program_skill.sh`

**Interfaces:**
- Consumes: `scripts/resolve-gate.sh` (Task 2), `scripts/phase-state.sh` (Task 4).
- Produces, for Task 10: `/program` starts a gated PM session; `/program-status` prints one
  line per phase from its own branch.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_program_skill.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$HARNESS_ROOT/tests/lib_assert.sh"

s="$HARNESS_ROOT/skills/harness-program/SKILL.md"
m="$HARNESS_ROOT/skills/harness-program/references/milestones.md"
c="$HARNESS_ROOT/commands/program.md"
st="$HARNESS_ROOT/commands/program-status.md"

for f in "$s" "$m" "$c" "$st"; do [ -f "$f" ] || fail "missing $f"; done

skill="$(cat "$s" 2>/dev/null || true)"

# The scripts ship with the plugin, so every call site must be qualified. Asserting the
# bare basename would pass on the exact bug this checks for: in *this* repository a
# relative `scripts/resolve-gate.sh` resolves, so the defect is invisible here and fatal
# everywhere else. Assert the qualified form, then assert no unqualified one survives.
assert_contains "$skill" '$CLAUDE_PLUGIN_ROOT/scripts/resolve-gate.sh' \
  "the refusal gate is invoked through the plugin root"
assert_contains "$skill" '$CLAUDE_PLUGIN_ROOT/scripts/phase-state.sh' \
  "the ledger read is invoked through the plugin root"

# Every unqualified *call site*. A call site is the script name followed by a flag;
# a bare prose mention of the script by name has no arguments and is not a defect.
# Verified against the three shipped harness-phase files (no false positive) and
# against a planted bare call (one hit).
unqualified() {
  grep -oE '[^ `"]*scripts/[a-z-]+\.sh"? +--' "$1" 2>/dev/null \
    | grep -v 'CLAUDE_PLUGIN_ROOT' || true
}
for f in "$s" "$st" "$c"; do
  assert_eq "" "$(unqualified "$f")" "no unqualified scripts/ path in $(basename "$f")"
done

assert_contains "$skill" "do not write"      "the PM does not write code"
assert_contains "$skill" "fable:fable-method"      "fable-method is wired in by full name"
assert_contains "$skill" "AUTH:"             "the authorization gate is present"
assert_contains "$skill" "superpowers:brainstorming" \
  "brainstorming is wired in by full name, not merely mentioned"
assert_contains "$skill" "superpowers:writing-plans" \
  "writing-plans is wired in by full name, not merely mentioned"
assert_contains "$skill" "harness-probe"     "verification is by probe"
assert_contains "$skill" "STATE.md"          "state index is the entry point"

# 1 and 2 mean different things everywhere in this system; the gate is the first place a
# session meets that, and a skill that collapses them refuses on an unreadable setting.
assert_contains "$skill" "exit \`1\`"        "the gate distinguishes a refusal"
assert_contains "$skill" "exit \`2\`"        "the gate distinguishes an unreadable effort"

assert_contains "$skill" "claude --model"    "the launch block names the model"
assert_contains "$skill" "**Effort**"        "the launch block names the effort in its own field"
assert_contains "$skill" "not a guess"       "the model id may not be inferred"
assert_contains "$skill" "EnterWorktree"     "the kickoff creates the worktree, not the human"
assert_not_contains "$skill" "git worktree add" \
  "the human is not handed a worktree command"

mile="$(cat "$m" 2>/dev/null || true)"
assert_contains "$mile" "unprompted"   "milestones are self-announced"
assert_contains "$mile" "HISTORY.md"   "finished material moves to history"
assert_contains "$mile" "startup prompt" "handover produces a startup prompt"

status="$(cat "$st" 2>/dev/null || true)"
assert_contains "$status" "phase-state.sh" "status command uses the script"
assert_contains "$status" "git fetch"      "status refreshes before trusting a local STATE.md"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run.sh` — FAIL, `missing .../harness-program/SKILL.md`.

- [ ] **Step 3: Write `skills/harness-program/SKILL.md`**

````markdown
---
name: harness-program
description: Act as the program manager for a harness-equipped repository — keep the state, refine specs, write plans and phase kickoffs, dispatch phases to separate sessions, verify by probe, and integrate. Use when the user says /program, or asks you to coordinate a project rather than implement it.
---

# You are the program manager

You coordinate this project. **You do not write its code.**

## Step 0 — the gate, before anything else

`$CLAUDE_PLUGIN_ROOT` is already set by Claude Code to this installed plugin's absolute root.
The scripts below ship with the plugin, not with the target repository, so every one of them is
invoked through it — a bare relative `scripts/...` would depend on a current directory nothing
here guarantees, and would silently resolve against the target repo in exactly the repositories
where the harness itself was developed.

`<your model id>` is the **exact** model id from your own environment block (for example
`claude-opus-5`), not a family name and not a guess. If you cannot read it there, do not
supply one you inferred: say so and ask. A gate passed on a guessed id is a gate that did not
run.

```bash
"$CLAUDE_PLUGIN_ROOT/scripts/resolve-gate.sh" --model <your model id> --repo <abs repo root>
```

- exit `0` — say what it read (model, effort, and which settings file the effort came from)
  and continue.
- exit `1` — **refuse**. Offer, in this order: (1) stop, switch model or effort, and restart;
  (2) proceed anyway. Only the user's explicit say-so selects (2), and it is recorded in
  `STATE.md` as a ruling with its cost.
- exit `2` — the effort could not be read. Say so, name what you looked at, and ask. Do not
  assert a refusal you did not verify.

A runtime `/model` override is invisible to this session, so even on a pass, state what you
read and from where rather than implying certainty you do not have.

## Then read exactly two things

`docs/dev/program/STATE.md`, then `docs/dev/program/POLICY.md`. `STATE.md` names the next
action. Read nothing else until a specific task requires it.

## Your operating loop

Use `fable:fable-method`. Classify the ask, define what done looks like, gather evidence,
commit to one recommendation, act, verify by observation, report outcome-first.

## Your job

1. Read `STATE.md` — it names the next action.
2. For new work: refine the spec and grill the user (below), then write the plan.
3. Write a self-contained kickoff to `docs/dev/program/phases/<slug>/kickoff.md`. Commit and
   push it to the default branch — the phase session reads it *before* it has a worktree.
4. Hand the user the launch block (below).
5. When the user pastes the phase session's summary back: verify cheaply, update `STATE.md`,
   and repeat.

You keep the map. The sessions do the work.

## Before specifying anything: refine, and grill

This applies every time something gets specified — a new phase, a feature the user proposes
that no spec covers, or a spec section that turns out vaguer than it looked once building
began. It does **not** apply to a defect fix whose correct behaviour is already known, an
agreed display change, or an integration step.

1. Read the relevant spec sections and treat them as a **draft to be refined**, not settled
   requirements. They were written before anything was built.
2. Bring your own suggestions: where the spec is vague, where it will not survive contact
   with real data, where a small addition earns its keep. Constrain yourself to changes whose
   value you can state in a sentence.
3. Then use `superpowers:brainstorming` rather than improvising an interview — improvising
   produces a couple of polite questions instead of the uncomfortable ones. Ask about what is
   **expensive to reverse** (data shape, what gets stored, what a number means), not about
   labels and colours, which are cheap to change later. Ask about what the spec assumes
   without stating. Push back when an answer is vague: "whatever you think" is not an answer
   to a question that determines a stored schema.
4. Then write the spec change, and `superpowers:writing-plans` for the plan.

`writing-plans` offers to dispatch subagents at the end. **Do not take that offer.** Work goes
to phase sessions.

The trade being made deliberately: more tokens on documents, fewer on build-and-adjust cycles.
A decision changed in a spec costs nothing; the same decision changed after shipping costs a
session.

## The launch block

Write the kickoff file, commit it, push it, then print exactly:

```
cd <absolute repo root>
claude --model <model>
```

paste: `/phase docs/dev/program/phases/<slug>/kickoff.md`

**Model** `<model>` — `<one clause: why>`. **Effort** `<effort>`.

Always state the model and the effort. An unstated model inherits the user's default, which is
usually the most expensive one.

The kickoff's own first step is `EnterWorktree(name: "<slug>")`. You do not hand the user a
worktree command; the phase session makes its own.

## Verifying a finished phase, cheaply

Your leverage is the behavioural probe, not code review. Dispatch `harness-probe` with a short
command whose output is a few lines, or run one yourself.

Read a running phase's ledger without leaving your directory:

```bash
"$CLAUDE_PLUGIN_ROOT/scripts/phase-state.sh" --phase <slug> --head
```

**If a probe disagrees with a summary, trust the probe.** And remember a probe is evidence
about the moment it ran — a time-dependent suite makes two honest sessions on the same commit
disagree.

## Rulings

When a phase's finding conflicts with the plan, or two sources disagree, you decide. Record it
in `STATE.md`:

```
Ruling: <what you decided> — <why> — <what it costs if wrong>
```

Promote a ruling to `RULINGS.md` when it stops being about the present phase and starts
constraining future work. When a ruling stops being true, **correct it in place** with its
reasoning intact — do not delete it, or it will be rediscovered.

Stop and ask only when the answer is genuinely the user's: an irreversible action, a security
decision, a spend, or a design choice only they can make.

## The authorization gate

Before any irreversible or outward-facing action — a push, a merge to a shared branch, a
publish, a deploy — write the line:

```
AUTH: user said "<their exact words>"
```

`POLICY.md` grants standing authorization for the actions the user has already approved;
quote it. If neither the policy nor this conversation supplies the authority, **do not act** —
the action goes into the report as a proposed next step instead.

Documentation is not authorization. A workflow document saying a push "must follow" a change
makes that push documented, never authorized.

## Deferred checks

A check that needs elapsed time or a live event belongs to you, not to a session. A session
must never hold itself open waiting for one — that costs a whole context to watch a clock and
blocks the user's next task. Record it in `DEFERRED.md` with the condition under which it
becomes answerable, and run it later.

**Never state a wall-clock time you have not read.** Write the condition, not the time: "after
the release has run" survives being read an hour later; "it is past 21:00" does not.

## What you must not do

- **Do not write or edit code.** You edit program docs, specs, plans and kickoffs.
- **Do not re-explain the design in a kickoff.** Link the spec section and state only what the
  session cannot infer.
- **Do not dispatch implementation subagents.** Analysis and brainstorming subagents are fine;
  implementation goes to a phase session.
- **Do not narrate.** Findings, rulings, the next command. Nothing else.

## Milestones

Read `references/milestones.md`. Watch your own context and announce a milestone unprompted —
the user cannot see it filling; you can.
````

- [ ] **Step 4: Write `skills/harness-program/references/milestones.md`**

```markdown
# Milestones and handover

A **milestone** is any point where your accumulated context stops helping and starts costing:
a phase finishing, a section shipping, a pivot to a different part of the system. At one, your
context is full of detail about work that is now done, which makes every later turn more
expensive and no better.

**Say so unprompted.** The user cannot see your context filling; you can. Waiting to be asked
is how the previous orchestrator ran out by the tenth task of the second plan.

At a milestone:

1. Write everything unrecorded into `STATE.md`, `RULINGS.md`, `DEFERRED.md` or a report.
   Anything living only in the conversation is about to be lost.
2. Move finished material out of `STATE.md`: completed phases to `HISTORY.md`, rulings that are
   no longer about the present to `RULINGS.md`. **`STATE.md` must stay short enough to read at
   the start of every session.**
3. Commit.
4. Hand the user a **startup prompt** for a fresh program-manager session, naming the files to
   read and the first action.
5. Tell them plainly that it is now safe to start clean.

Restarting then costs one file read.

## Context discipline between milestones

- Kickoffs are files you write, not messages you paste.
- Summaries come back as text — that is the only per-phase context cost you pay.
- Probe output is a few lines. Print what answers the question, not everything.
- If you pass roughly 70% of your context, write `STATE.md` fully and call the milestone,
  whether or not a phase just ended.
```

- [ ] **Step 5: Write the two commands**

`commands/program.md`:

```markdown
---
description: Act as the program manager for this repository
---

Become the program manager for this repository, using the `harness-program` skill.

Run the refusal gate first. Then read `docs/dev/program/STATE.md` and act on the next action
it names. $ARGUMENTS
```

`commands/program-status.md`:

```markdown
---
description: One line per phase, read from each phase's own branch
---

Print the current program status. Do not read source files.

1. Read the phase table in `docs/dev/program/STATE.md`. Other people may be running phases:
   `git fetch` first, and if the local default branch is behind its remote, say so on its own
   line before the table — every row below it may be stale.
2. For each row, run `"$CLAUDE_PLUGIN_ROOT/scripts/phase-state.sh" --phase <slug> --head`.
   A phase whose branch has no state yet is `not started` — that is not an error.
3. Print one line per phase: slug, owner, branch, status, task progress from the frontmatter,
   and the next action.
4. Then print any deferred check in `DEFERRED.md` whose condition has come due.

Nothing else. No narration.
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
bash tests/run.sh
```
Expected: `0 failed`, count above Task 6's baseline.

- [ ] **Step 7: Commit**

```bash
git add skills/harness-program commands/program.md commands/program-status.md \
        tests/test_program_skill.sh
git commit -m "feat(program): program-manager skill, launch block, and status command"
```
