# Task 3: `[DEP-1]` dependency check at skill entry

**Plan:** `docs/dev/plans/2026-09-02-prerequisites/README.md` — shared constraints and the task
table.

**Files:**
- Modify: `skills/foreman-phase/SKILL.md` — a new `## Step 0 — dependencies` section before
  `## Step 1`
- Modify: `skills/foreman-program/SKILL.md` — a new `### Dependencies` subsection at the end of
  `## Step 0 — the gate, before anything else`
- Modify: `tests/test_phase_skill.sh`, `tests/test_program_skill.sh` — new assertions
- Modify: `docs/dev/backlog.md` — close `[DEP-1]`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing another task consumes. The phase-C plan of the same program will edit
  `foreman-program`'s Step 0 again when `superpowers:writing-plans` leaves the PM; it will find
  the dependency list in one place.

**Ruling this task implements** (the program manager's, recorded in the kickoff): a presence
check that stops cleanly, not a fallback. A fallback restates another plugin's procedure inside
this one, and two copies of one procedure drift, which is the failure the whole program exists
to remove. `foreman-init` keeps its existing `claude-md-improver` fallback because that pass is
report-only and its rubric ships as a reference file here; nothing in this task touches it.

**What a session can check.** A Claude Code session sees the skills available to it as a list
in its own context (the harness lists them by `plugin:skill` name). The check is: read that
list, confirm each name below appears. There is no shell command for this in the shipped
scripts, and none is added: invariant 1 forbids a dependency on the `claude` CLI, and the
session already has the answer in front of it.

---

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_phase_skill.sh`:

```bash
# --- [DEP-1] the skills this one hands work to are checked at entry, not discovered at gate 3 -
# gate-chain.md dispatches fable:fable-judge (gate 3) and superpowers:finishing-a-development-
# branch (gate 7). Without a check up front, a session whose operator declined a plugin's trust
# prompt discovers the gap with a finished branch in hand. The check must name each skill it
# depends on, must sit before Step 1, and must tell the session to stop rather than improvise.
step0_line="$(grep -n '^## Step 0 ' "$s" | head -1 | cut -d: -f1)"
step1_line="$(grep -n '^## Step 1 ' "$s" | head -1 | cut -d: -f1)"
if [ -n "$step0_line" ] && [ -n "$step1_line" ] && [ "$step0_line" -lt "$step1_line" ]; then _ok
else fail "foreman-phase has a '## Step 0' heading before '## Step 1' (got step0=$step0_line step1=$step1_line)"; fi
step0_body="$(awk -v a="$step0_line" -v b="$step1_line" 'NR>a && NR<b' "$s" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$step0_body" 'fable:fable-judge' \
  "Step 0 names fable:fable-judge as a dependency"
assert_contains "$step0_body" 'superpowers:finishing-a-development-branch' \
  "Step 0 names superpowers:finishing-a-development-branch as a dependency"
assert_contains "$step0_body" 'fable@fable-method' \
  "Step 0 names the plugin fable-judge comes from, so the operator knows what to install"
assert_contains "$step0_body" 'superpowers@claude-plugins-official' \
  "Step 0 names the plugin the superpowers skills come from"
assert_contains "$step0_body" 'do not substitute your own procedure' \
  "Step 0 forbids improvising a missing skill's procedure"
```

Append to `tests/test_program_skill.sh`:

```bash
# --- [DEP-1] the PM's own dependencies are checked in Step 0, next to the refusal gate --------
# foreman-program sends the interview to superpowers:brainstorming, the plan to
# superpowers:writing-plans, and its operating loop to fable:fable-method. The check sits inside
# Step 0 (before "## Then read exactly three things") so a missing plugin stops the session
# before it has read STATE.md and formed intentions it cannot carry out.
step0_line="$(grep -n '^## Step 0 ' "$s" | head -1 | cut -d: -f1)"
next_line="$(grep -n '^## Then read exactly three things' "$s" | head -1 | cut -d: -f1)"
if [ -n "$step0_line" ] && [ -n "$next_line" ] && [ "$step0_line" -lt "$next_line" ]; then _ok
else fail "foreman-program Step 0 precedes the three-file read (got step0=$step0_line next=$next_line)"; fi
step0_body="$(awk -v a="$step0_line" -v b="$next_line" 'NR>a && NR<b' "$s" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$step0_body" '### Dependencies' \
  "Step 0 carries a Dependencies subsection"
for dep in 'fable:fable-method' 'superpowers:brainstorming' 'superpowers:writing-plans'; do
  assert_contains "$step0_body" "$dep" "Step 0 names $dep as a dependency"
done
assert_contains "$step0_body" 'do not substitute your own procedure' \
  "Step 0 forbids improvising a missing skill's procedure"
```

Mutation-check each needle against the shipped file once Step 3 is done: every needle must be
the longest unique form of the sentence it asserts, so deleting that sentence goes red.

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: `foreman-phase has a '## Step 0' heading before '## Step 1'` fails (no Step 0 exists),
the five phase `assert_contains` fail with `[...] not found`, and on the program side
`Step 0 carries a Dependencies subsection`, the three `names ... as a dependency` and the
`forbids improvising` assertions fail. Nothing else.

- [ ] **Step 3: Implement**

In `skills/foreman-phase/SKILL.md`, insert immediately before `## Step 1 — capture identity,
enter the worktree, baseline the tree`:

```markdown
## Step 0 — dependencies, before anything else

This skill hands work to two skills from other plugins, and the first of those calls is inside
the gate chain, where a stop costs a finished branch. Check them here, where a stop costs
nothing. The skills available to this session (the list the harness puts in your context) must
include:

- `fable:fable-judge`, from the plugin `fable@fable-method` — gate 3, adversarial verification.
- `superpowers:finishing-a-development-branch`, from the plugin
  `superpowers@claude-plugins-official` — gate 7, close.

If either is missing, stop: name the missing skill and the plugin it comes from, and end. **Do
not substitute your own procedure for it.** An improvised gate 3 is exactly the false completion
claim that gate exists to catch, and a phase that ran it on itself has verified nothing.
```

In `skills/foreman-program/SKILL.md`, insert immediately before `## Then read exactly three
things`, so it closes Step 0:

```markdown
### Dependencies

Three skills from other plugins carry parts of this role. The skills available to this session
(the list the harness puts in your context) must include:

- `fable:fable-method`, from the plugin `fable@fable-method` — your operating loop.
- `superpowers:brainstorming` and `superpowers:writing-plans`, from the plugin
  `superpowers@claude-plugins-official` — the spec interview and the plan.

If any is missing, say so, name the plugin, and stop before reading `STATE.md`. **Do not
substitute your own procedure for it**: an improvised interview asks the polite questions and
skips the expensive ones, which is the drift these skills exist to prevent.
```

Keep every line under 100 columns. In `docs/dev/backlog.md`, change `[DEP-1]`'s `- [ ]` to
`- [x]` and append one sentence to the item: `Closed by phase A task 3: each session skill
checks its dependencies at Step 0 and stops cleanly, naming the plugin; no fallbacks, by ruling
(a fallback is a second copy of another plugin's procedure).`

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `14 files, 630 passed, 0 failed` (618 after task 2, plus 6 phase-side and 6
program-side assertions), exit 0. Also confirm no placeholder crept in and the wrap holds:

```bash
grep -nE '\b(TODO|TBD|FIXME)\b' skills/foreman-phase/SKILL.md skills/foreman-program/SKILL.md
awk 'length > 100 {print FILENAME":"NR": "length}' skills/foreman-phase/SKILL.md skills/foreman-program/SKILL.md
```

Expected: both print nothing. (The second may print the `description:` frontmatter line, which
is exempt; anything else is a wrap violation to fix.)

- [ ] **Step 5: Mutation-check**

Delete the `fable:fable-judge` bullet from the phase skill's Step 0: its assertion must go red.
Restore. Delete the sentence containing `do not substitute your own procedure` from each skill
in turn: the matching assertion must go red each time. Restore. Move the phase skill's Step 0
below Step 1: the ordering assertion must go red. Restore. Run once more, green.

- [ ] **Step 6: Commit**

```bash
git add skills/foreman-phase/SKILL.md skills/foreman-program/SKILL.md \
  tests/test_phase_skill.sh tests/test_program_skill.sh docs/dev/backlog.md
git commit -m "skills: check plugin dependencies at Step 0 and stop cleanly when one is missing [DEP-1]"
```
