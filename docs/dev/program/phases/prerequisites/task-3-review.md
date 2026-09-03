# Task 3 review: `[DEP-1]` dependency check at skill entry

Reviewer: Opus, high effort. Artifact reviewed: `docs/dev/program/phases/prerequisites/task-3-review.diff`
(read as given; not regenerated). Commit under review: `07d0fd1`, whose `--stat` matches the
diff file exactly (5 files, +73 -1).

**Verdict: Spec OK - Quality: Approved.** Four Minor findings, none blocking.

---

## 1. Spec compliance

| Brief requirement | Status |
|---|---|
| `skills/foreman-phase/SKILL.md`: new `## Step 0 - dependencies` before `## Step 1` | PASS - lines 13-27, immediately before `## Step 1 - capture identity...` (line 29) |
| `skills/foreman-program/SKILL.md`: new `### Dependencies` at the end of `## Step 0 - the gate` | PASS - lines 61-72, immediately before `## Then read exactly three things` (line 74) |
| `tests/test_phase_skill.sh`, `tests/test_program_skill.sh`: new assertions | PASS - appended verbatim from the brief, 6 + 6 assertions |
| `docs/dev/backlog.md`: close `[DEP-1]` | PASS - `- [ ]` to `- [x]` (:228) plus a closing paragraph (:252-254) |
| Nothing present and unrequired | PASS - the diff is pure insertion apart from the one backlog checkbox character; no deletion, no restructuring of either skill |

Nothing required is missing. Nothing unrequired is present. `foreman-init`'s
`claude-md-improver` fallback was correctly left alone (`skills/foreman-init/SKILL.md:188-193`
unchanged).

## 2. The binding ruling - presence check, not a fallback

**Honoured.** Both blocks are pure presence checks with a clean stop.

- `skills/foreman-phase/SKILL.md:24-27` - "If either is missing, stop: name the missing skill
  and the plugin it comes from, and end - **do not substitute your own procedure for it**."
- `skills/foreman-program/SKILL.md:70-72` - "If any is missing, say so, name the plugin, and
  stop before reading `STATE.md` - **do not substitute your own procedure for it**: ..."

Neither block restates any part of `fable-judge`'s adversarial-verification procedure,
`finishing-a-development-branch`'s close, `brainstorming`'s interview or `writing-plans`'s
format. There is no degraded path, no "if you cannot install it, do X instead", and - unlike
the refusal gate three paragraphs above it in `foreman-program` - no user-override branch that
a session could analogise into "continue anyway". Read as instructions: the verb is `stop`, in
the imperative, followed by an explicit prohibition in bold. Neither can be read as "prefer to
stop, but continue if you can".

Asymmetry worth noting, not a defect: the phase version says "name the missing skill **and** the
plugin"; the program version says "say so, name the plugin" - the missing skill's name is
carried by "say so" and by the bullet list two lines above. Both satisfy the closure's claim
("stops cleanly, naming the plugin").

## 3. Position, not just presence - verified by mutation

I reproduced the suite against a scratchpad copy of the worktree (under the session scratchpad,
outside the repository; no tracked file was modified at any point). Baseline of the copy:
`14 files, 640 passed, 0 failed`.

| Mutation | Result | Verdict |
|---|---|---|
| A. Move the phase `## Step 0` block to just after the `## Step 1` heading | 634/6 - `FAIL: foreman-phase has a '## Step 0' heading before '## Step 1' (got step0=15 step1=13)` plus the five body assertions | **Position is genuinely tested.** The check goes red on a move, not merely on a deletion |
| B. Delete the `- fable:fable-judge` bullet | 638/2 (`fable:fable-judge`, `fable@fable-method`) | red as claimed |
| C. Delete the `superpowers:finishing-a-development-branch` bullet (both lines) | 638/2 (skill name, `superpowers@claude-plugins-official`) | red as claimed |
| D. Remove the prohibition clause from **both** skills | 638/2, one per file | red as claimed |
| E. Move the program `### Dependencies` block below `## Then read exactly three things` | 635/5 - all four content needles plus the subsection heading | **Position is tested on the program side too**, via the `awk` range, even though the ordering `if` there is trivially satisfied |
| F. Reflow both new blocks onto single long lines (paragraph rewrap) | 640/0, still green | **Reflow-tolerant**, as the plan requires |
| G. Restore the brief's own capitalised `**Do not substitute your own procedure for it.**` | 638/2 | confirms the implementer's deviation report exactly |

Notes on position:

- Phase side: the ordering `if` was red before the change (`got step0= step1=13`) and is the
  assertion that pins the block ahead of worktree entry - `EnterWorktree` lives in Step 1b, so
  `Step 0 < Step 1` implies "before the session touches anything".
- Program side: the ordering `if` passed **before** this change (`## Step 0` already preceded
  `## Then read exactly three things`), which is why the pre-change run showed 11 failures out
  of 12 new slots rather than 12. It is a boundary guard, not a test of the new text. The real
  position assertion there is the `awk NR>a && NR<b` scoping, and mutation E proves it bites.
- The three program-side needles (`fable:fable-method`, `superpowers:brainstorming`,
  `superpowers:writing-plans`) each occur a second time in the file at :104, :143 and :149 -
  all outside the `awk` range (10 < N < 74), so no cross-satisfaction. The implementer's
  uniqueness analysis is correct and I re-derived it.
- Nothing commits the session to work before either check. Ahead of the phase's Step 0 there is
  only the title, one framing paragraph and the `Announce:` line. Ahead of the program's
  `### Dependencies` there is only the refusal gate, which is itself a stop-check. (See
  `[T3-M1]` for the one competing "before anything else" claim, which lives in another file.)

## 4. The rephrasing deviation - sound

The implementer's account is exactly right, and mutation G proves it: implementing the brief's
Step 3 text verbatim (`**Do not substitute your own procedure for it.**`, sentence-initial)
leaves the brief's own Step 1 needle (`'do not substitute your own procedure'`, lowercase) red,
because `assert_contains` is a literal case-sensitive `case` match (`tests/lib_assert.sh:18-24`).
The brief contradicted itself; one of the two had to move.

Meaning survived intact. Compare:

- Brief: "...and end. **Do not substitute your own procedure for it.** An improvised gate 3 is..."
- Shipped: "...and end - **do not substitute your own procedure for it**. An improvised gate 3 is..."

Same modality (bare imperative), same scope ("for it" still binds to the missing skill), same
bold emphasis, same following justification. Joining the clause with an em dash arguably reads
*more* strongly to a model executing it: the prohibition is now part of the same sentence as
`stop`, so it cannot be skimmed as a separate optional aside. The program-side rephrase is the
same edit with the same result. I would have made the same call: the gate is the authority the
invariants point at, and the alternative (loosening the needle) would have weakened the test.

## 5. Invariants

| # | Verdict | Evidence |
|---|---|---|
| 1 - zero runtime deps beyond bash/git/jq | **Pass** | The diff adds no script. The new test code uses `grep`, `awk`, `tr`, `cut`, `head`; `awk` was already used by `scripts/phase-state.sh`, `scripts/baseline-check.sh` and four existing test files, so nothing new is introduced |
| 2 - shebang / `set` line / `chmod +x` | **Pass** | No new file; both edited test files are appended to only, headers untouched (`set -uo pipefail` intact) |
| 3 - exit-code contract | **N/A** | No script behaviour touched |
| 4 - absolute paths between tiers | **N/A** | No inter-tier path added |
| 5 - no TODO/TBD/FIXME | **Pass** | Confirmed by the controller; the new prose contains none |
| 6 - bare wrapper names | **Pass** | The new prose names no harness script at all, by path or otherwise |
| 7 - green, not below baseline | **Pass** | 640/0; `POLICY.md` baseline 610 untouched, which is correct - `POLICY.md:7-9` says a phase session never edits it |
| 8 - 100-column wrap | **Pass** | Confirmed by the controller; the only over-length lines are the exempt `description:` scalars. The new markdown lines are all <= 100 |

## 6. Test quality

Every new assertion was mutation-checked above and each goes red on the one thing it names. No
test was deleted, skipped or weakened - the diff contains no `-` line in either test file. The
new assertions match against a whitespace-flattened extract (`tr '\n' ' ' | tr -s ' '`), and
mutation F confirms a reflow does not break them; this matters concretely, because the program
skill's prohibition sentence *does* wrap mid-needle in the shipped file (`SKILL.md:70-71`), so
an unflattened assertion would have been red on arrival.

Behaviour under `set -uo pipefail` with no `-e` was checked: when `grep` finds nothing, the
assignment pipeline exits 1 but does not abort the file, the `-n` guards route to `fail`, and
the subsequent `awk` with empty `-v a= -v b=` produces an empty extract that fails the body
assertions rather than erroring. Observed directly in mutations A and B.

Using an inline `tr` pipeline instead of `test_program_skill.sh`'s `flow` helper is not a
defect: `flow` takes a filename, and the needle here must be matched against an `awk`-extracted
range, not a whole file.

## 7. Findings

### Minor `[T3-M1]` - the kickoff template still claims Step 1a is "first"

`skills/foreman-init/templates/program/kickoff.md.tmpl:3-7` opens every generated kickoff with:

> `## First - foreman-phase Step 1a, then Step 1b's EnterWorktree`
> Record `<main-checkout>` ... **before doing anything else**

The phase skill now opens with `## Step 0 - dependencies, before anything else`. Two files a
phase session reads at the same moment each claim to be what happens first, and the kickoff is
the one handed to the session by `/phase`.

Failure scenario: a session that takes the kickoff header as the ordering authority runs Step 1a
and `EnterWorktree` before Step 0, so a missing plugin is discovered with a worktree and a
branch already created rather than with nothing spent. Bounded, and far short of the gate-3
discovery `[DEP-1]` exists to prevent - which is why this is Minor and not Important. The fix
is one line in the template header (`Step 0, then Step 1a...`), plus its assertion in
`tests/test_templates.sh`; out of scope for this task's brief, and it touches a shipped template,
so it should be a tracked item rather than a drive-by edit.

### Minor `[T3-M2]` - `[DEP-1]` closed without a verdict on one reference it enumerates

`docs/dev/backlog.md:232-233` lists five cross-plugin references, and :244-246 says the fix is
to "decide **per reference** whether it is required or preferred". Four are now covered by the
two Step 0 blocks. The fifth - `plans/plan-README.md.tmpl`'s REQUIRED SUB-SKILL banner naming
`superpowers:subagent-driven-development` - is neither checked nor decided, and the closure
paragraph (:252-254) does not mention it. Marking the item `[x]` retires that reference silently.

This is real: the banner is live text. `docs/dev/plans/2026-09-02-prerequisites/README.md:6`
carries it, so the phase controller *is* instructed by every plan README to use a third
superpowers skill that its own Step 0 list does not name - while the block asserts "two skills
from other plugins". The design spec's section 13 wiring table
(`docs/dev/specs/2026-08-28-harness-plugin-design.md:687-695`) also assigns
`superpowers:subagent-driven-development` and `superpowers:verification-before-completion` to
the phase controller.

Why Minor rather than Important: all of these ship inside `superpowers@claude-plugins-official`,
and Step 0 already checks `superpowers:finishing-a-development-branch` from that same plugin, so
the whole-plugin-absent case - the failure mode `[DEP-1]` actually describes ("a contributor who
declines the trust prompt") - is caught regardless. Remedy: one clause in the closure paragraph
recording that the plan-README banner was judged covered by the same plugin check, or a new
backlog item carrying it forward. Also note the closure sentence sits *after* the "Unrelated,
but adjacent..." `resolve-gate.sh` aside, so a reader can briefly attach the closure to that aside.

### Minor `[T3-M3]` - the prohibition assertion pins sentence-initial lowercase

`tests/test_phase_skill.sh` and `tests/test_program_skill.sh` both assert the literal
`'do not substitute your own procedure'`. Mutation G shows the suite goes red on a purely
stylistic edit - an editor who starts that sentence with a capital `D`, which is ordinary
English and exactly what the brief wrote, breaks a green suite with no change in meaning. The
assertion currently protects a capitalisation accident alongside the meaning it is for. A needle
of `ot substitute your own procedure` (or a `tr '[:upper:]' '[:lower:]'` on the extract) would
test the claim without the style constraint. Not blocking - the current form is the one that
caught the brief's own inconsistency.

### Minor `[T3-M4]` - nothing detects a fallback added *alongside* the prohibition

The ruling is "no degraded path". The tests assert that the prohibition sentence is *present*;
they cannot fail if a future edit keeps that sentence and adds "if you cannot install it, run
gate 3 yourself as follows..." underneath it - which is the precise drift the ruling exists to
prevent. A companion `assert_not_contains` over the Step 0 extract for a fallback marker (for
instance `instead`, or `read its rubric from`, the phrasing `foreman-init` uses for its
sanctioned fallback) would close the other direction. Related and smaller: the program-side
dependency needles are scoped to the whole `## Step 0` section rather than to the
`### Dependencies` subsection, so they would also be satisfied by those names appearing anywhere
in the refusal-gate text above.

## 8. The 630 vs 640 count gap - confirmed not a defect

The implementer's reading is correct and the arithmetic closes exactly. The task adds 12
assertion slots (phase: 1 ordering + 5 content; program: 1 ordering + 1 subsection + 3 names +
1 prohibition). The brief's `630` assumed a 618 pre-change suite; the true pre-change count was
628, and 628 + 12 = 640, which is what the suite reports. The intermediate run in the report
(`629 passed, 11 failed`) corroborates it independently: 640 slots, 11 red, and the one new
assertion that was green before the change is the program-side ordering guard, exactly as
predicted by its being trivially satisfied pre-change. Stale arithmetic in the brief, not a
discrepancy in the work. No count was inflated: I counted the assertions in the shipped test
files myself and re-ran the suite from a clean copy.

## 9. Restructuring check

Neither skill was touched beyond the insertion. `git show --stat` and the diff hunks agree:
`skills/foreman-phase/SKILL.md +16 -0`, `skills/foreman-program/SKILL.md +13 -0`. No existing
heading, step number or cross-reference moved. I checked the whole repository for step-number
cross-references that a new `## Step 0` could invalidate; the only one that interacts is
`[T3-M1]`, and it is in a template, not in either edited file. `foreman-phase` had no `Step 0`
before, so no heading collision; `foreman-program:56` ("do not continue past Step 0 until you
have a verdict") still reads correctly now that Step 0 has a second, later subsection.

## 10. Cannot verify

- That a live Claude Code session, given a missing plugin, actually stops. The check is prose
  obeyed by a model; the tests verify text and position, which is the whole of what a bash gate
  can reach. The implementer flagged the same limit, correctly.
- That the session's visible skill list uses the `plugin:skill` naming the blocks assume. The
  brief asserts it and the existing text at `foreman-program:104` already relies on it, so the
  new blocks introduce no new assumption.
