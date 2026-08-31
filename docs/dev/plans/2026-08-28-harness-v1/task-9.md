# Task 9: the `harness-init` skill and `/harness-init`

Implements spec §12. The creator: it audits a repository, interviews the user about only what
the audit could not settle, generates the harness into a scratch tree, runs a CLAUDE.md quality
pass it arbitrates itself, and shows the full diff before anything lands.

**Files:**
- Create: `skills/harness-init/SKILL.md`
- Create: `skills/harness-init/references/audit-checklist.md`
- Create: `skills/harness-init/references/interview.md`
- Create: `skills/harness-init/references/claude-md-rubric.md`
- Create: `commands/harness-init.md`
- Test: `tests/test_init_skill.sh`

**Interfaces:**
- Consumes: `scripts/resolve-gate.sh` (Task 2), `MANIFEST.tsv` and the templates (Task 8).
- Produces, for Task 10: `/harness-init` runs end to end on a repository.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_init_skill.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$HARNESS_ROOT/tests/lib_assert.sh"

d="$HARNESS_ROOT/skills/harness-init"
for f in SKILL.md references/audit-checklist.md references/interview.md \
         references/claude-md-rubric.md; do
  [ -f "$d/$f" ] || fail "missing $d/$f"
done
[ -f "$HARNESS_ROOT/commands/harness-init.md" ] || fail "missing commands/harness-init.md"

s="$(cat "$d/SKILL.md" 2>/dev/null || true)"
assert_contains "$s" '$CLAUDE_PLUGIN_ROOT/scripts/resolve-gate.sh" --model' \
  "the refusal gate runs first, from the plugin root"
assert_contains "$s" '$CLAUDE_PLUGIN_ROOT/skills/harness-init/templates/MANIFEST.tsv' \
  "generation is manifest-driven, from the plugin root"
assert_contains "$s" "never in place" "generation goes to a scratch tree first"
assert_contains "$s" "AskUserQuestion"  "the interview uses AskUserQuestion"
assert_contains "$s" "claude-md-improver" "the quality pass is wired"
assert_contains "$s" "report-only"      "the quality pass does not write"
assert_contains "$s" "full diff"        "the diff is shown before anything lands"
assert_contains "$s" "Nothing lands"    "the approval gate is explicit"

# Every scripts/*.sh *call site* must carry $CLAUDE_PLUGIN_ROOT. A call site is the script name
# followed by a flag; a bare prose mention of a script has no arguments and is not a defect.
# Verified against every shipped .md before this assertion was written: zero false positives.
unqualified="$(grep -oE '[^ `"]*scripts/[a-z-]+\.sh"? +--' "$d/SKILL.md" 2>/dev/null \
  | grep -v 'CLAUDE_PLUGIN_ROOT' || true)"
assert_eq "" "$unqualified" "no unqualified scripts/*.sh call site in SKILL.md"

# The three rules the plan was amended to add, each of which a plausible SKILL.md omits.
assert_contains "$s" "known_marketplaces.json" \
  "HARNESS_MARKETPLACE_PATH is sourced, not invented"
assert_contains "$s" "destination" \
  "the manifest carve-out is by destination, not by mode"
assert_contains "$s" "*{{*" \
  "the leak check covers path segments, not only file contents"

# Step order: gate, audit, interview, generate, quality, diff.
# Anchored to the *heading* of each step, not to the bare string "Step N": the body of one step
# legitimately refers to another by number ("say so in the Step 5 summary"), and matching that
# forward reference would order the steps by where they are mentioned rather than where they are.
order() { grep -n "$1" "$d/SKILL.md" | head -1 | cut -d: -f1; }
g="$(order 'resolve-gate.sh')"; a="$(order '^## Step 1')"; i="$(order '^## Step 2')"
gen="$(order '^## Step 3')"; q="$(order '^## Step 4')"; df="$(order '^## Step 5')"
if [ -n "$g$a$i$gen$q$df" ] && [ "$g" -lt "$a" ] && [ "$a" -lt "$i" ] \
   && [ "$i" -lt "$gen" ] && [ "$gen" -lt "$q" ] && [ "$q" -lt "$df" ]; then
  _ok
else
  fail "SKILL.md steps must run gate < audit < interview < generate < quality < diff"
fi

au="$(cat "$d/references/audit-checklist.md" 2>/dev/null || true)"
for k in "build system" "gate command" ".claude" "invariant" "test count" "default branch"; do
  assert_contains "$au" "$k" "audit covers: $k"
done
assert_contains "$au" "could not settle" "the audit reports its own gaps"

iv="$(cat "$d/references/interview.md" 2>/dev/null || true)"
assert_contains "$iv" "only what the audit" "interview asks only unsettled things"
for k in "trust boundar" "push" "Baseline" "AGENTS.md"; do
  assert_contains "$iv" "$k" "interview covers: $k"
done
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run.sh` — FAIL, `missing .../harness-init/SKILL.md`.

- [ ] **Step 3: Write `skills/harness-init/SKILL.md`**

````markdown
---
name: harness-init
description: Install the harness into a repository — audit its stack, docs and conventions, interview the user about what the audit cannot settle, generate CLAUDE.md, the docs/dev layout and the program state, run a CLAUDE.md quality pass, and show the full diff before anything lands. Use when the user says /harness-init or asks to set up the harness in a project.
---

# Install the harness into this repository

Six steps, in order. Nothing is written to the repository until Step 5 is approved.

## Step 0 — the gate

```bash
"$CLAUDE_PLUGIN_ROOT/scripts/resolve-gate.sh" --model <your model id> --repo <abs repo root>
```

`$CLAUDE_PLUGIN_ROOT` is already set by Claude Code to this installed plugin's absolute root.
Use it for **every** path under `scripts/` and `skills/` in this file — these ship with the
plugin, not with the repository being initialised, and a bare relative path resolves against
the target repo, where nothing of the sort exists.

`<your model id>` is the **exact model id** this session is running — not a family name and not
a guess. Source it from the session's own environment or from what the user states; if you
cannot establish it, that is an exit `2` situation, not a reason to pass something plausible.
The gate matches whole tokens, so a guess that happens to contain `opus` passes and certifies
nothing.

- exit `0` — state what it read (model, effort, and which settings file the effort came from),
  then continue.
- exit `1` — **refuse**. Offer, first: stop, switch model or effort, restart. Proceeding
  anyway requires the user's explicit say-so and is recorded in the generated `STATE.md` as a
  ruling with its cost.
- exit `2` — the effort could not be read. Say so, name what you looked at, ask. Do not assert
  a refusal you did not verify.

Even on a pass, say what you read and from where. A runtime `/model` override is invisible to
this session, and implying otherwise would overstate the check.

## Step 1 — audit

Read `references/audit-checklist.md`. Dispatch its concerns as **parallel read-only agents**,
one per concern — they are independent and each is a fan-out over many files.

Then report, briefly: what the repository is, what it already has, and — the part that matters
— **what the audit could not settle**. Only that list reaches the interview.

If the repository already has a `docs/dev/`-shaped layout or an existing harness install, say
so: this becomes an evolve, not a create, and the manifest's `mode` column governs.

## Step 2 — interview

Read `references/interview.md`. Ask **only** what the audit left open, via `AskUserQuestion`.
Where the audit produced a defensible answer, offer it as the first option, marked
`(Recommended)`.

Never ask about something the audit could have answered. That is the whole point of running
the audit first.

## Step 3 — generate

Into a **scratch tree**, never in place. Use the scratch directory this session was given.

Read `$CLAUDE_PLUGIN_ROOT/skills/harness-init/templates/MANIFEST.tsv`.

**Not every row is an init-time row.** A row whose **destination** contains `{{` names a
document that is instantiated later, once its subject exists — the phase kickoff, a plan
directory, a task file, a spec. `PHASE_SLUG`, `PLAN_SLUG`, `TASK_NUMBER` and `TOPIC` are not
knowable at init, and emitting a directory literally named `{{PHASE_SLUG}}` is the failure this
rule exists to prevent. Skip those rows here; say in the Step 5 summary that they live in the
plugin's `templates/` directory and are instantiated by `/program` and `/phase`.

For each remaining row:

- `mode: create` — emit only if the destination does not already exist in the repository. If
  it does, leave it and note it in the summary.
- `mode: evolve` — merge with what exists. For `CLAUDE.md` this means keeping the project's
  own content and voice and folding in the missing sections, not replacing the file. For
  `.gitignore` and `.claude/settings.json` it means adding what is absent and touching nothing
  else. `.claude/settings.local.json` is a fourth evolve destination and behaves differently
  from the other three: it is **untracked** (the `.gitignore` additions put it there), it is
  per-contributor, and it usually does not exist yet — so evolving it means creating it if
  absent and otherwise adding only the missing `extraKnownMarketplaces.harness` key. Never
  overwrite a contributor's other local settings, and never commit this file.

Substitute every `{{VARIABLE}}` from the audit and the interview — with one exception.
`{{HARNESS_MARKETPLACE_PATH}}` comes from neither: it is the local checkout of the harness
marketplace, recorded on this machine at

```bash
jq -r '.harness.source.path // empty' ~/.claude/plugins/known_marketplaces.json
```

If that prints nothing, the marketplace is not registered here yet — **ask the user for the
path**; do not invent one, and in particular do not use `$CLAUDE_PLUGIN_ROOT`, which points at
a version-pinned cache copy (`plugins/cache/harness/harness/<version>`) that goes stale on the
next upgrade. The value written into `settings.local.json` must be the source checkout.

**A `{{` surviving into the scratch tree is a defect** — and it can survive in a *path* as well
as in a file's contents, which is the harder half to see. Check both before continuing:

```bash
grep -rn '{{' <scratch-tree> && echo "UNSUBSTITUTED CONTENT" || echo "content clean"
find <scratch-tree> -name '*{{*' -print | grep . && echo "UNSUBSTITUTED PATH" || echo "paths clean"
```

Every `{{` in every template is a real variable — none is documentation of one — so a clean
scratch tree has zero hits on both checks. There is no legitimate exception to wave through.

`INVARIANTS` deserves care: prefer invariants the audit found **already enforced** by a test,
a lint rule or a CI check over anything invented in the interview. An invariant nothing
enforces is a wish.

## Step 4 — CLAUDE.md quality pass, report-only

Run `claude-md-improver` against the generated `CLAUDE.md`, stopping **before** its write
phase — it is **report-only** here. If the `claude-md-management` plugin is not installed,
read its rubric from the marketplace cache instead:

```
~/.claude/plugins/marketplaces/claude-plugins-official/plugins/claude-md-management/skills/claude-md-improver/references/quality-criteria.md
```

and apply it yourself. `references/claude-md-rubric.md` records what to weigh either way.

**You arbitrate.** Take each finding in turn and accept or reject it in **one line with a
reason**. Fold accepted findings into the generated file. Print the arbitration list.

Reject, by default, any finding that would strip a warning of its *why*: a reader who knows
the reason will not route around the rule, and a reader who does not, will.

## Step 5 — full diff, then the gate

Show the complete diff between the repository and the scratch tree — every file, no elision.
Summarise in one line per file what it does and why.

**Nothing lands until the user says yes.** They may accept some files and reject others; if
so, re-emit and show the diff again.

On approval: copy the scratch tree over the repository, then `git add` **the tracked files
only**. `.claude/settings.local.json` is deliberately ignored — write it, and leave it
untracked. Stage with `git add -A` (which honours `.gitignore`) or by naming paths; never
`git add -f`. Commit with a message naming the harness version.

Confirm before claiming success: `git status --short` shows the local settings file as ignored
or absent from the index, and every other generated file staged. Then print the first launch
block: `/program`.
````

- [ ] **Step 4: Write `references/audit-checklist.md`**

```markdown
# Audit checklist

One parallel read-only agent per concern. Each returns findings only — no recommendations, no
edits. The audit's most valuable output is the list of things it **could not settle**.

## 1. Stack and build system

Languages and versions, package manager, task runner (`Makefile`, `mise.toml`, `justfile`,
`package.json` scripts), version pins, and how dependencies are installed. Note anything the
project does that is unusual enough to trip a fresh session.

## 2. Gate commands

What CI runs (`.github/workflows/`, or equivalent). What the task runner exposes. **Which of
them actually pass right now** — run them. A gate command that is already red is a finding,
not a detail. Record the current green **test count**; it becomes the baseline.

## 3. Existing `.claude/` assets

`settings.json`, `settings.local.json`, permissions, agents, skills, commands, hooks, existing
worktrees. Note anything that would conflict with the harness, and any permission the gate
commands would otherwise prompt for.

## 4. Layer layout

The architectural boundaries the code already has, and — separately — **anything that enforces
them**: an architecture test, a lint rule, an import guard, a CI check. Enforced boundaries are
candidate invariants; unenforced ones are candidate conventions.

## 5. Spec, plan and test conventions

What documents exist and how they are named. Where tests live and what one looks like. Whether
the project already writes design docs, and in what voice.

## 6. Invariants already implied

Assertions the code or CI already makes about itself. Prefer these over anything invented: an
invariant with a test behind it is checkable, and one without is a wish. List each with the
file that enforces it.

## 7. Git

Remote, **default branch**, protection rules, whether the tree is clean, and who has been
committing recently — the last of these tells you whether this is a single-operator repository
or a shared one, which changes the integration policy.

## 8. Existing `CLAUDE.md` / `AGENTS.md`

Content, structure, and **voice**. The rewrite evolves this file; it must not flatten a
project's own way of saying things into template prose. Note any warning that carries a
*why* — those are the most valuable lines in the file and must survive.

## Reporting

Findings, then a separate list headed **"could not settle"**. Anything in the second list
becomes an interview question. Anything in the first does not.
```

- [ ] **Step 5: Write `references/interview.md`**

```markdown
# The interview

Ask **only what the audit could not settle**. Use `AskUserQuestion`. Where the audit produced a
defensible answer, offer it first and mark it `(Recommended)`.

Batch related questions into one call; four questions per call is the maximum, and fewer is
better than padding.

## Topics, in rough priority order

**Gate commands and order.** Which commands must be green before a merge, in which order.
Confirm the audit's list; ask about anything it found but could not run.

**Baseline.** Confirm the measured test count and the SHA. If the suite is currently red, ask
whether to record the count anyway or fix first.

**Trust boundaries.** Which surfaces escalate a task's model and its reviewer's: typically
authentication, secrets and keys, anything mutating state outside the process, anything
serving bytes to a browser. Offer the audit's guesses; the user knows the ones that bite.

**Invariants.** Present the enforced ones the audit found, and ask what is missing. Ask
specifically for rules that have been broken before — those are the ones worth numbering.

**Spec lifecycle.** Who writes a spec, who approves it, and whether a phase may amend one
mid-flight or must come back to the program manager.

**Pipeline scope.** What is big enough to be a phase rather than a single change.

**Commit, merge and push policy.** What a phase may do without asking. What escalates to a
pull request rather than a direct merge.

**`AGENTS.md` policy.** A three-line pointer (default, nothing drifts), a symlink to
`CLAUDE.md`, or real separate content because a tool in use requires it.

**Doc home.** Only if the audit found a conflicting existing convention. Otherwise
`docs/dev/`.

**Model overrides.** Anything about this repository that makes the default table wrong.

**Ownership.** Who else works here and which surfaces they own — two phases must not claim the
same surface.

## Rules

- One topic per question. Multiple choice where the options are genuinely distinct.
- Never ask about something the audit answered.
- Push back on a vague answer to a question that determines a stored convention. "Whatever you
  think" is not an answer to "what are the trust boundaries"; say why it matters and ask again.
- Record every answer into `POLICY.md`. An answer that stays in the conversation is lost.
```

- [ ] **Step 6: Write `references/claude-md-rubric.md`**

```markdown
# What a good CLAUDE.md does here

The quality pass grades against the standard rubric. These are the harness's additions to it,
and they win where the two disagree.

**A warning must carry its why.** "Use `npm run typecheck`, not `npx tsc`" is a rule to route
around. The same rule plus "the proxy reports a false 'No errors found' even when real type
errors exist" is one a reader will keep. Never accept a finding that strips a reason to save
lines.

**Invariants are numbered.** They are quoted verbatim into dispatches and answered one by one
by reviewers. Numbering is the interface, not decoration.

**Architecture is described by responsibility, not by directory listing.** "`store`: owns
SQLite — schema, migrations, all persistence. No business logic." tells a session where a
change belongs. A file tree does not.

**State what is deliberately absent, and why.** A missing feature that looks like an oversight
gets built by a helpful session. Naming it as a decision prevents that.

**Commands are copy-pasteable and real.** Every one must have been run.

**The worktree rule must be present.** `EnterWorktree` is available to a session only when the
user or the project instructions call for worktrees; if `CLAUDE.md` does not say so, phase
sessions cannot legitimately isolate themselves.

**Length is not the metric; relevance is.** The test is whether a session must read material
about work that is not its own.
```

- [ ] **Step 7: Write `commands/harness-init.md`**

```markdown
---
description: Audit this repository and install the harness into it
---

Install the harness into this repository using the `harness-init` skill. $ARGUMENTS

Run the refusal gate first. Audit before interviewing, interview before generating, and show
the full diff before writing anything.
```

- [ ] **Step 8: Run the tests to verify they pass**

```bash
bash tests/run.sh
```
Expected: `0 failed`, count above Task 8's baseline.

- [ ] **Step 9: Commit**

```bash
git add skills/harness-init/SKILL.md skills/harness-init/references \
        commands/harness-init.md tests/test_init_skill.sh
git commit -m "feat(init): audit, interview, generate, arbitrate, diff"
```
