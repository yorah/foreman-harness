# Task 3 report: `[DEP-1]` dependency check at skill entry

## Summary

Added a `## Step 0 — dependencies, before anything else` section to
`skills/foreman-phase/SKILL.md`, immediately before `## Step 1`, and a `### Dependencies`
subsection to `skills/foreman-program/SKILL.md`, immediately before `## Then read exactly three
things` (closing the existing `## Step 0 — the gate, before anything else`). Both are presence
checks against the skill list the harness puts in the session's context, and both instruct the
session to stop and name the missing skill/plugin rather than improvise — per the kickoff's
ruling that `[DEP-1]` is a presence check, not a fallback. Added matching test assertions to
`tests/test_phase_skill.sh` and `tests/test_program_skill.sh`, and closed `[DEP-1]` in
`docs/dev/backlog.md`.

## Files changed

- `skills/foreman-phase/SKILL.md` — new `## Step 0 — dependencies, before anything else`
  section, before `## Step 1 — capture identity, enter the worktree, baseline the tree`. Names
  `fable:fable-judge` (from `fable@fable-method`, gate 3) and
  `superpowers:finishing-a-development-branch` (from `superpowers@claude-plugins-official`,
  gate 7) as required. Tells the session to stop and name the missing skill/plugin, "do not
  substitute your own procedure for it."
- `skills/foreman-program/SKILL.md` — new `### Dependencies` subsection at the end of the
  existing `## Step 0 — the gate, before anything else` (i.e. immediately before `## Then read
  exactly three things`). Names `fable:fable-method` (operating loop), and
  `superpowers:brainstorming` / `superpowers:writing-plans` (from
  `superpowers@claude-plugins-official`) as required. Same stop-and-name wording.
- `tests/test_phase_skill.sh` — appended the block from the brief verbatim: asserts the `##
  Step 0` heading line-number precedes `## Step 1`, then extracts the text strictly between
  those two headings and asserts it names each dependency, each plugin, and the "do not
  substitute your own procedure" prohibition.
- `tests/test_program_skill.sh` — appended the block from the brief verbatim: asserts `## Step
  0` precedes `## Then read exactly three things`, extracts the text between them, and asserts
  the `### Dependencies` heading, all three dependencies, and the prohibition sentence.
- `docs/dev/backlog.md` — `[DEP-1]`'s `- [ ]` became `- [x]`, and one closing sentence was
  appended to the item (before the unrelated `resolve-gate.sh` note stays where it was; the new
  sentence sits after it, as the last paragraph of the item, right before `### Closed on
  fix/triage-and-plan-banner`).

## Deviation from the brief (wording, not substance)

The brief's Step 1 test snippet asserts the needle `'do not substitute your own procedure'`
(lowercase `do`), but the brief's Step 3 implementation text opens the sentence with `**Do not
substitute your own procedure for it.**` — capitalized, sentence-initial. `assert_contains` is a
literal, case-sensitive bash `case` match, so the capitalized form as given would not satisfy the
lowercase needle; confirmed this by implementing the brief's text verbatim first and watching the
two "forbids improvising" assertions fail after everything else passed. I resolved this by
rephrasing both sentences so the prohibition is not sentence-initial (`"...and end — **do not
substitute your own procedure for it**."` / `"...before reading `STATE.md` — **do not substitute
your own procedure for it**:..."`), preserving the bold emphasis and the meaning, and making the
literal substring lowercase to match the test. This is a wording change only; the two policies
(stop cleanly, name the plugin, do not improvise) are unchanged. Called out here since the brief
and its own test disagreed and I had to pick one — I kept the test's literal string because the
gate is the authority the invariants point to.

## Count discrepancy (not corrected, just noted)

The brief's Step 4 expected `14 files, 630 passed, 0 failed` computed as "618 after task 2, plus
6 phase-side and 6 program-side assertions." The task instructions (and my own pre-change run)
confirmed the actual baseline at this worktree's base commit is `628 passed, 0 failed`, not 618.
628 + 12 new assertions = 640, which is what the suite reports after this change. I did not
force a resub-630 count — the floor stated by the dispatching instructions (628, confirmed
independently) is what I gated against, and 640 ≥ 628 satisfies invariant 7. The `630` figure in
the brief appears to be arithmetic against a stale baseline snapshot, not a discrepancy in my
work.

## Commands run and output

Baseline before any change:
```
$ bash tests/run.sh 2>&1 | tail -5
...
14 files, 628 passed, 0 failed
```

After appending failing tests (Step 2 of the brief):
```
$ bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
  FAIL: foreman-phase has a '## Step 0' heading before '## Step 1' (got step0= step1=13)
  FAIL: Step 0 names fable:fable-judge as a dependency: [fable:fable-judge] not found
  FAIL: Step 0 names superpowers:finishing-a-development-branch as a dependency: [...] not found
  FAIL: Step 0 names the plugin fable-judge comes from, so the operator knows what to install: [...] not found
  FAIL: Step 0 names the plugin the superpowers skills come from: [...] not found
  FAIL: Step 0 forbids improvising a missing skill's procedure: [...] not found
  FAIL: Step 0 carries a Dependencies subsection: [### Dependencies] not found
  FAIL: Step 0 names fable:fable-method as a dependency: [...] not found
  FAIL: Step 0 names superpowers:brainstorming as a dependency: [...] not found
  FAIL: Step 0 names superpowers:writing-plans as a dependency: [...] not found
  FAIL: Step 0 forbids improvising a missing skill's procedure: [...] not found
14 files, 629 passed, 11 failed
```
Exactly the 11 failures the brief predicted (5 phase assertions + the phase ordering check + 5
program assertions), nothing else — confirms the tests fail for the expected reason.

After implementing (Step 4), before the wording fix, two failures remained (both "forbids
improvising..." — the case mismatch described above). After the wording fix:
```
$ bash tests/run.sh 2>&1 | tail -3
14 files, 640 passed, 0 failed
```

Placeholder / wrap checks:
```
$ grep -nE '\b(TODO|TBD|FIXME)\b' skills/foreman-phase/SKILL.md skills/foreman-program/SKILL.md
(no output, exit 1)
$ awk 'length > 100 {print FILENAME":"FNR": "length}' skills/foreman-phase/SKILL.md skills/foreman-program/SKILL.md
skills/foreman-phase/SKILL.md:3: 240
skills/foreman-program/SKILL.md:3: 302
```
Both hits are the `description:` frontmatter line (exempt per invariant 8 and the brief).
Nothing else exceeds 100 columns.

## Mutation checks (Step 5), each done and restored

1. Deleted the `fable:fable-judge` bullet from the phase skill's Step 0 → both "Step 0 names
   fable:fable-judge as a dependency" and "Step 0 names the plugin fable-judge comes from..."
   went red (638 passed, 2 failed) — correct, since the deleted bullet line carried both the
   skill name and its plugin (`fable@fable-method`) together. Restored from a saved copy → back
   to 640/0.
2. Deleted the sentence containing "do not substitute your own procedure" from the phase skill
   → that skill's "forbids improvising" assertion went red (639 passed, 1 failed). Restored →
   640/0.
3. Deleted the equivalent sentence from the program skill → that skill's "forbids improvising"
   assertion went red (639 passed, 1 failed). Restored → 640/0.
4. Moved the phase skill's entire Step 0 block (heading + body) to just after the `## Step 1`
   heading line → the ordering assertion went red (`got step0=15 step1=13`), and the five
   phase-side body assertions also failed as a side effect (the `awk` extraction range becomes
   empty/invalid when step0_line > step1_line, which is correct behaviour, not a test bug).
   Restored from the saved copy → 640/0.

All four mutations produced the expected single (or side-effect-explained) red, and every
restoration returned the suite to `14 files, 640 passed, 0 failed`.

## Uniqueness check of new needles

Confirmed each new literal needle occurs exactly once in the file it targets, except
`fable:fable-method`, `superpowers:brainstorming`, and `superpowers:writing-plans` in
`skills/foreman-program/SKILL.md`, which each occur twice — once in the new `### Dependencies`
block and once elsewhere in the file (the operating-loop line and the brainstorming/writing-plans
prose in "Before specifying anything"). This is not a hazard: the test scopes its search to the
text strictly between the `## Step 0` and `## Then read exactly three things` headings via
`awk`, so the second, unrelated occurrence outside that range cannot cross-satisfy the assertion.
Verified this scoping directly via mutation check 1 and 3 above (deleting the in-scope text
still went red).

## Gate

```
$ bash tests/run.sh
14 files, 640 passed, 0 failed
```

## Invariants

No invariant was broken. Invariant 5 (no TODO/TBD/FIXME) and invariant 8 (100-column wrap,
frontmatter exempt) verified directly above. Invariant 7 (green before commit, no regression
below baseline) satisfied: 640 ≥ 628 floor.

## Ruling followed

Both new sections are presence checks only: read the skill list, confirm each name appears, stop
and name what's missing if not — no reimplementation of `fable-judge`'s adversarial-verification
procedure or of `finishing-a-development-branch`'s close procedure, and no reimplementation of
`brainstorming`'s interview or `writing-plans`'s plan format. No tension with the ruling was
found; the brief's own text already frames the task this way and the ruling given in the
dispatch matches it exactly.

## What I could not verify

I could not verify this against a live Claude Code session (i.e. that a session reading these
skills mid-task actually produces the intended stop behavior) — that is inherently outside what
a bash-only gate can check. The tests verify text presence and position, which is what the brief
asked for.

## Commit

```
07d0fd1 skills: check plugin dependencies at Step 0 and stop cleanly when one is missing [DEP-1]
```
5 files changed: `docs/dev/backlog.md`, `skills/foreman-phase/SKILL.md`,
`skills/foreman-program/SKILL.md`, `tests/test_phase_skill.sh`, `tests/test_program_skill.sh`.

---

# Fix round 1

Findings file: `docs/dev/program/phases/prerequisites/task-3-review.md`. Reviewer verdict on the
original commit was Spec OK / Quality Approved with four Minors, none blocking. This round
addresses all four.

## [T3-M1] — kickoff template's header contradicted the new Step 0

`skills/foreman-init/templates/program/kickoff.md.tmpl` opened with `## First — foreman-phase
Step 1a, then Step 1b's EnterWorktree`, unchanged by the original task even though it added a
`## Step 0` ahead of Step 1a. A phase session that trusts the kickoff header over the skill file
would run Step 1a and `EnterWorktree` before the dependency check — bounded (the review rated it
Minor, well short of the gate-3 discovery `[DEP-1]` targets), but a genuine cross-file
disagreement of exactly the kind `POLICY.md`'s model table warns about.

**Test-first.** Added an assertion to `tests/test_templates.sh` that derives the expected first
step from `foreman-phase/SKILL.md` itself (`grep -m1 -oE '^## Step [0-9]+'`), rather than
hard-coding `"Step 0"` — so the check survives a future renumbering and still catches drift if
the template is not updated to match. Two parts: (1) the kickoff template contains that step's
name, (2) it appears before `Step 1a`. Ran before the template fix:
```
FAIL: kickoff template names foreman-phase's actual first step (Step 0): [Step 0] not found
FAIL: kickoff template names Step 0 before Step 1a (got first= step1a=47)
14 files, 640 passed, 2 failed
```
Fails for the expected reason (both, not some unrelated break). **Fix**: changed the template
header to `## First — foreman-phase Step 0, then Step 1a, then Step 1b's EnterWorktree` — the
one-line header edit the review named, nothing else in the template touched, per the
coordinator's constraint that another task owns the distribution templates. Verified: `14
files, 642 passed, 0 failed`.

**Mutation-checked**, both directions: (a) reverted the header to the old text → both
assertions red, restored → green; (b) reordered the header to name `Step 0` after `Step 1a` →
only the ordering assertion red (`got first=93 step1a=47`), restored → green.

## [T3-M4] — no guard against a fallback added alongside the prohibition

The ruling (`[DEP-1]` is a presence check, never a fallback) was asserted only by checking the
prohibition sentence is *present*; nothing would fail if a later edit kept that sentence and
added a degraded path under it. Added `assert_not_contains` guards in both
`tests/test_phase_skill.sh` and `tests/test_program_skill.sh`, against the marker phrasing
`foreman-init`'s own *sanctioned* `claude-md-improver` fallback uses ("is not installed ... read
its rubric from the marketplace cache **instead**") — `instead` and `not installed`, matched
against a lowercased extract so capitalisation can't dodge it. On the program side the guard is
scoped to the `### Dependencies` subsection specifically (`awk` range from `### Dependencies` to
`## Then read exactly three things`), not the wider `## Step 0` extract the other assertions
use — closing the "Related and smaller" cross-satisfaction gap the review flagged, where a
program-side needle could in principle be satisfied by unrelated text in the refusal-gate prose
above the `### Dependencies` heading. Left the original brief-inherited content assertions on
the wider Step 0 range unchanged, to keep this round's diff to what the four findings ask for.

**Mutation-checked**: injected `"If fable:fable-judge is not installed, run gate 3 yourself
instead."` into the phase skill's Step 0 → both new guards red
(`[instead] should be absent`, `[not installed] should be absent`), restored → green. Same for
the program skill's `### Dependencies` (`"If fable:fable-method is not installed, follow its
loop from memory instead."`) → both guards red, restored → green. Additionally verified the
scoping itself: injected the same fallback phrasing into the program skill's `## Step 0` text
*outside* `### Dependencies` (in the refusal-gate prose) → suite stayed green (`646 passed, 0
failed`), confirming the tightened guard cannot be satisfied by unrelated Step 0 content,
restored.

## [T3-M3] — the prohibition needle pinned sentence-initial lowercase

The needle `'do not substitute your own procedure'` (from the brief, unchanged since the
original commit) is a literal case-sensitive match; it only reads as robust because the shipped
text happens to have "do" lowercase after an em dash. Any editor recapitalising that sentence —
ordinary English, and exactly what the brief's own Step 3 text originally did — breaks a green
suite with no change in meaning. Replaced the raw-case assertion in both test files with one
matched against a lowercased extract (`tr '[:upper:]' '[:lower:]'` over the already
whitespace-flattened `step0_body`), so the assertion tests the claim, not its typography.
Deviation from the letter of the coordinator's suggestion: the brief named `test_program_skill.
sh`'s `flow` helper, which flattens a *file* by name; the text under test here is an
`awk`-extracted range, not a file, so I applied the same normalisation (whitespace-flatten, now
also lower-cased) directly to the extracted string rather than routing it through `flow`. Same
effect, different plumbing — noted per the deviation-reporting rule.

**Mutation-checked**, both directions: (a) recapitalised the shipped sentence to `**Do Not
Substitute Your Own Procedure For It**` (title case, harder than the brief's simple
sentence-initial form) → suite stayed green (`646 passed, 0 failed`), proving the new assertion
survives typography changes; restored. (b) replaced the sentence's *words* with `"keep going
anyway"` (meaning actually removed) → the case-insensitive assertion still went red
(`[do not substitute your own procedure] not found`), proving it is not vacuously true;
restored.

## [T3-M2] — `[DEP-1]`'s closure was silent on the `subagent-driven-development` reference

The backlog item enumerated five cross-plugin references and asked the fix to "decide per
reference"; the original closure paragraph covered four (via the two Step 0 checks) but said
nothing about the fifth — `plans/plan-README.md.tmpl`'s `superpowers:subagent-driven-development`
banner. Appended one sentence to the closure paragraph in `docs/dev/backlog.md`: the banner ships
inside the same `superpowers@claude-plugins-official` plugin that Step 0 already checks (via
`superpowers:finishing-a-development-branch`), so the whole-plugin-absent failure mode `[DEP-1]`
actually describes is caught regardless — judged covered, not overlooked. No test was added for
this: `backlog.md` prose is not gated by any assertion in the suite (checked — the only
`backlog.md` references in `tests/` are about the phase gate's *procedural* mention of the file,
`test_dogfood.sh`'s scaffolding-only allowlist, and `test_templates.sh`'s manifest row; none
inspect its content), so there is no existing pattern to extend and no invariant this needs to
satisfy beyond the wrap/placeholder checks below.

## Gate and invariant checks, this round

```
$ bash tests/run.sh 2>&1 | tail -3
14 files, 646 passed, 0 failed
```
646 = 640 (end of the previous round) + 2 (M1's new assertions) + 2 (M3/M4 net: M3 replaced 1
assertion 1-for-1 in each file, M4 added 2 new assertions in each file) — 640 + 2 + 4 = 646,
confirmed by direct count of `assert_contains`/`assert_not_contains`/`_ok` additions in the diff.

```
$ grep -nE '\b(TODO|TBD|FIXME)\b' skills/foreman-phase/SKILL.md skills/foreman-program/SKILL.md \
    skills/foreman-init/templates/program/kickoff.md.tmpl
clean (no output)
$ awk 'length > 100 {print FILENAME":"FNR": "length}' skills/foreman-phase/SKILL.md \
    skills/foreman-program/SKILL.md skills/foreman-init/templates/program/kickoff.md.tmpl
skills/foreman-phase/SKILL.md:3: 240
skills/foreman-program/SKILL.md:3: 302
```
Both wrap hits are the exempt `description:` frontmatter scalar, and both files show no content
diff this round (`git status` confirms — this round only touched test files, the kickoff
template, and the backlog). `docs/dev/backlog.md` and the touched test files were also checked
for the 100-column wrap on every line I added; none exceed it.

## The binding ruling — not relitigated, still honoured

No fix in this round adds a degraded path. M4's guard exists specifically to keep that true
going forward; M1, M2 and M3 are ordering, documentation and test-robustness fixes with no
procedural content. Re-read both skills' new prose after this round's edits (unchanged from the
previous round) — no fallback language of any kind, matching the review's own finding in
section 2.

## What I could not verify

Same limit as the previous round: a live Claude Code session's actual behavior on encountering
the checks is not something a bash gate can observe. This round is entirely text-and-position
verification, consistent with what the reviewer's own findings asked for.

## Commit

```
bd02151 skills+tests: fix round 1 on [DEP-1] -- kickoff/skill agreement, fallback guard, robust needle
```
5 files changed: `docs/dev/backlog.md`,
`skills/foreman-init/templates/program/kickoff.md.tmpl`, `tests/test_phase_skill.sh`,
`tests/test_program_skill.sh`, `tests/test_templates.sh`.

---

# Fix round 2

Findings file: `docs/dev/program/phases/prerequisites/task-3-review-1.md`. Reviewer verdict was
Spec OK, Quality **Not approved** — one Important (`[T3-M4]`) plus four Minors (`[T3-M5]`
through `[T3-M8]`), all proved by mutation rather than by reading. This round clears all five.

## `[T3-M4]` (Important) — the fallback guard did not guard, in either direction

The review's mutation table proved round 1's guard (`assert_not_contains ... 'instead'` /
`'not installed'`) both **misses a real fallback** (mutation D: a fully-formed degraded path
added to both skills, suite stayed `646/0` green) and **false-reds on compliant prose**
(mutations F and G: strengthening the prohibition, or rewording "missing" to "not installed",
both broke a green suite). The two tokens tested typography that happens to co-occur with a
fallback and a stop respectively, not the thing itself.

**Redesigned the markers around the actual shape of a self-substitution**, rather than any
single word the sanctioned fallback happens to use: a degraded path tells the session to *carry
out the missing skill's job itself*. Three markers, all lowercase-matched against the same
`step0_body_lc` / `deps_body_lc` extracts as before:

- `'proceed by'` — forbids continuing past the stop with a next action; the direct inverse of
  stopping.
- `'yourself'` — forbids delegating the missing skill's job to the session ("run it yourself",
  "do the interview yourself"). Both of the review's mutation-D texts use this exact word, and
  it does not occur anywhere in the compliant prohibition sentence or, checked directly, inside
  either skill's guarded `Step 0` / `Dependencies` range today (`grep` finds `yourself` many
  times elsewhere in both files, e.g. "create the worktree yourself" in Step 1b of
  `foreman-phase` — all outside the guarded ranges, confirmed by line number before relying on
  it).
- `'read its rubric from'` — the literal phrase `foreman-init`'s own *sanctioned* fallback for
  `claude-md-management` uses. Keeps a targeted catch for a literal copy of the one fallback
  this program allows, without keying on the bare word "instead" that caused the F/G false
  positives.

**Test-first and mutation-checked**, reproducing the review's own D, F, G plus the
coordinator's own suggested phrasing, on both skills:

1. Confirmed the new markers still pass against the unmodified shipped text: `648/0` (net +2
   assertions per file over round 1's 2: three markers replacing two, `646 - 4 + 6 = 648`).
2. **Mutation D** (false negative, the Important finding's core claim) — injected the review's
   exact degraded-path text into both skills' guarded ranges (phase: "If the skill is
   unavailable, proceed by running gate 3 yourself: dispatch a fresh subagent ...";
   program: "Should the plugin be unavailable, run the interview yourself: ..."). Result:
   `645/3` — `proceed by` and `yourself` both red on the phase side, `yourself` red on the
   program side. **The guard now catches what it was built to catch.** Restored, back to
   `648/0`.
3. **Mutation F** (false positive) — reproduced on both skills: strengthened the prohibition to
   `"...for it** - report the gap and stop instead."` (phase) and the equivalent wrapped form on
   the program skill. Result: `648/0`, unchanged — no false positive. Restored.
4. **Mutation G** (false positive, "the likeliest rewording of all") — reproduced on both
   skills: `"If either is missing, stop:"` → `"If either is not installed, stop:"` (phase),
   `"If any is missing, ..."` → `"If any is not installed, ..."` (program). Result: `648/0`,
   unchanged. Restored.
5. **Coordinator's own suggested phrasing** — "if the skill is unavailable, proceed by asking
   the operator for a summary of what it would have checked" injected into the phase skill.
   Result: `647/1`, red on `proceed by`. Restored.

All five reproductions behaved as required: the two false-negative shapes (D, and the
coordinator's own example) now redden; the two false-positive shapes (F, G) stay green.

**Residual honesty, not fixed and not fixable by `grep`**: the review's own remedy discussion
says plainly that "no `grep` can decide 'is this prose a degraded path'". These three markers
are a better-targeted heuristic, verified against every concrete shape named in this round and
the last, not a semantic guarantee. A sufficiently creative fallback that avoids "proceed by",
"yourself" and the literal sanctioned-fallback phrase (e.g. "in that case, carry out the
missing check by hand") would still pass. This is the residual limit named in both reviews'
"Cannot verify" sections, carried forward rather than concealed by the marker choice.

## `[T3-M5]` — `foreman-program/SKILL.md:179` told the PM the wrong "first step"

The same cross-file contradiction `[T3-M1]` found in the template, one file over:
`foreman-program/SKILL.md` said "the kickoff's own first step is `EnterWorktree(name:
\"<slug>\")`", which stopped being true the moment `[DEP-1]` gave `foreman-phase` a Step 0. A PM
who trusts this line writes a **self-contained** kickoff (the skill's own dispatch path for
every phase after the first, `SKILL.md:117-118,:160`) whose first action is `EnterWorktree` and
which never mentions Step 0 — the `[T3-M1]` failure, reached through the PM's own prose instead
of the template's.

**Swept for the rest of the class** rather than fixing only this line, per the coordinator's
instruction: `grep -rn "Step 1a\|Step 0\|before anything else\|before doing anything\|## First"
skills/ agents/ commands/`. Six hits beyond the ones already being fixed: `foreman-init/
SKILL.md:10` and `foreman-program/SKILL.md:10,56` are each skill's own (correct) Step 0;
`foreman-phase/SKILL.md:115` is a scoped "before anything else in this step", not a global
primacy claim; `foreman-program/references/milestones.md:21` ("read and the first action") is
about a handover startup prompt, unrelated to phase ordering. Nothing else in the class was
found.

**Fix**: reworded `SKILL.md:179` to distinguish the kickoff's first *action* (`foreman-phase`
Step 0's dependency check) from its first *tool call* (`EnterWorktree`) — matching the language
the review's own remedy proposed almost verbatim. Rewrapped the surrounding paragraph so the
existing test anchor (`"worktree command; the phase session makes its own"`,
`test_program_skill.sh:100`) stays on one un-split line; the first attempt broke that anchor
across a line boundary and the existing assertion caught it immediately (`14 files, 648 passed,
1 failed`) — left as evidence in this report rather than silently fixed, since it demonstrates
the pre-existing test doing its job.

Also corrected `test_templates.sh:267`'s label, which the review flagged as now false: it
claimed to check the kickoff's "first step" while only checking that `EnterWorktree(...)` is
*present somewhere*. Relabelled to "kickoff template carries the EnterWorktree call foreman-
program promises the PM" — states what is actually checked, matching the corrected `:179`
wording's "first tool call" framing.

**New test, test-first**: added three assertions to `tests/test_program_skill.sh` — the old
unqualified claim is absent, the "first *action* ... Step 0's dependency check" wording is
present, and the "first *tool call* ... EnterWorktree" wording is present. Verified they fail
against the pre-fix text (reverted `SKILL.md:179` to the old sentence on a scratch copy, ran):
```
FAIL: the PM is no longer told EnterWorktree is the kickoff's first step (unqualified): [...]
FAIL: the PM is told Step 0's dependency check is the kickoff's first action: [...] not found
FAIL: the PM is told EnterWorktree is only the kickoff's first *tool call*...: [...] not found
```
Restored, green (`652/0` at that point in the round).

## `[T3-M6]` — the template body still claimed primacy for Step 1a's reads

`kickoff.md.tmpl:5-7`, unchanged by `[T3-M1]`: "Record `<main-checkout>` ... **before doing
anything else**" — three lines under a header that, since `[T3-M1]`, says Step 0 runs first.
Two orderings in one file, the miniature of `[T3-M1]` itself. Reworded to "before entering the
worktree" — the real constraint (the reads are needed at gate 6 and are hard to reconstruct
once inside a worktree; they do not need to precede Step 0, only `EnterWorktree`).

**Test-first**: added two assertions in `tests/test_templates.sh` against a whitespace-
flattened copy of the template (the phrase wraps across a line break in the shipped file, so a
raw multi-line match would not see it) — the old phrase is absent, the new phrase is present.
Mutation-checked: reverted the wording on a scratch copy → both assertions red
(`[before doing anything else] should be absent`, `[before entering the worktree] not found`,
`654 → 652/2`). Restored, green.

## `[T3-M7]` — the kickoff ordering check could not survive a "Step 1" renumbering

The review's mutation B2 proved that with `foreman-phase`'s `## Step 0` removed **and** the
template header correctly reverted to match (both files mutually consistent, the exact
pre-task state), the ordering assertion still failed — not because it correctly detected
drift, but because the derived `first_step` degrades to `"Step 1"`, which is a literal
substring of `"Step 1a"`, so the byte-offset comparison could never find `first_pos < step1a_pos`
even when the two files fully agree. The assertion's own comment overstated this as "goes red
again if renumbered", without the caveat that renumbering *to `Step 1` specifically* breaks the
mechanism, not just the claim under test.

**Fix**: anchored the byte-offset search so a step number must be followed by a
non-alphanumeric character or end of line (`grep -boE "Step ${first_num}([^0-9A-Za-z]|\$)"`),
so `"Step 1"` can no longer match *inside* `"Step 1a"`. This does not "lift" the Step-1 collision
— a genuine renumbering to `Step 1` still cannot find a preceding, correctly-bounded occurrence
of `"Step 1"` in the current template text, so the check still fails in that case — but now it
fails **cleanly and diagnostically** (`got first= step1a=47`, an honestly empty match) rather
than by the accidental byte-offset collision the review documented (`got first=60 step1a=60`).
Corrected the comment to state exactly this: the derivation works for any step number that is
not a literal prefix of `"1a"` (i.e. not bare `"1"`), and reverting to `"Step 1"` is understood
to keep failing, honestly, rather than passing by geometry.

**Mutation-checked**, reproducing the review's B2 exactly: removed `foreman-phase`'s `## Step 0`
block and reverted the template header on scratch copies of both files. Result: `647/7` —
the phase-side ordering and content assertions red (as `[DEP-1]`'s own checks require), and
`kickoff template names Step 1 before Step 1a (got first= step1a=47)` — a clean empty-match
failure, not the prefix-collision one the review found under the old mechanism. Restored, green.

## `[T3-M8]` — the same block passed vacuously on an empty needle

If `grep -m1 -oE '^## Step [0-9]+'` matched nothing (the skill file renamed, restyled, or its
headings changed shape), `first_step` came out empty; `assert_contains "$kickoff_tmpl" ""`
matches by construction (a `case *""* ` glob matches everything), and the byte-offset search for
an empty string returns offset `0`, which trivially precedes `Step 1a`'s later offset — both
assertions passed on a missing ground truth.

**Fix**: added an explicit `[ -n "$first_step" ]` guard, structured as its own pass/fail before
either downstream assertion runs; on failure, both downstream claims are recorded as explicit
failures (not skipped silently) with a message naming the empty derivation as the cause.

**Mutation-checked**: restyled every `## Step N` heading in `foreman-phase/SKILL.md` to
`## STEP N` on a scratch copy (breaking the `^## Step [0-9]+` pattern entirely, confirmed
`grep -c '^## Step [0-9]' skills/foreman-phase/SKILL.md` → `0`). Result: `645/9` — the new
guard itself red (`foreman-phase/SKILL.md has a '## Step N' heading to derive the first step
from`), plus the two downstream claims red as explicit failures rather than silent passes,
plus the six phase-side assertions that independently require the same heading. Restored,
green.

## Gate and invariant checks, this round

```
$ bash tests/run.sh 2>&1 | tail -3
14 files, 654 passed, 0 failed
```
654 = 646 (floor stated for this round) + 2 (`[T3-M4]`: 3 markers replacing 2, net +1 per file
× 2 files) + 3 (`[T3-M5]`'s three new assertions) + 2 (`[T3-M6]`'s two new assertions) + 1
(`[T3-M7]`/`[T3-M8]`: the presence/ordering pair became a guard `_ok`/`fail` plus the same pair,
net +1) = 654, matching what the suite reports.

```
$ grep -nE '\b(TODO|TBD|FIXME)\b' skills/foreman-program/SKILL.md \
    skills/foreman-init/templates/program/kickoff.md.tmpl
clean (no output)
$ awk 'length > 100 {print FILENAME":"FNR": "length}' skills/foreman-program/SKILL.md \
    skills/foreman-init/templates/program/kickoff.md.tmpl
skills/foreman-program/SKILL.md:3: 302
```
Only the exempt `description:` frontmatter scalar. `foreman-phase/SKILL.md` carries no diff
this round (confirmed via `git status`) — `[T3-M4]`'s fix lives entirely in the test files, not
in either skill's prose. Verified none of the five files the coordinator named as out of scope
(`settings.json.tmpl`, `settings.local.json.tmpl`, `MANIFEST.tsv`, `gitignore-additions.txt`,
`CLAUDE.md.tmpl`) appear in `git diff --stat` for this round.

## The binding ruling — not relitigated, still honoured

No fix in this round adds a degraded path; `[T3-M4]`'s whole purpose this round was to make the
*enforcement* of "never a fallback" actually bite, not to soften it. `[T3-M5]` and `[T3-M6]`
correct claims about ordering, not procedure. `[T3-M7]` and `[T3-M8]` are test-mechanism fixes
with no prose change at all.

## What I could not verify

Same limit as both previous rounds — a live session's actual behavior is outside what a bash
gate reaches. Additionally, and specific to this round: `[T3-M4]`'s guard is a heuristic over
literal English phrasing, not a semantic check; I can verify it against every concrete mutation
named across both reviews (and did), but I cannot verify it against every way a fallback could
be phrased, and said so above rather than implying a stronger guarantee than the mechanism
provides.

## Commit

```
62ceed9 skills+tests: fix round 2 on [DEP-1] -- working fallback guard, cross-file sweep, test rigor
```
5 files changed: `skills/foreman-init/templates/program/kickoff.md.tmpl`,
`skills/foreman-program/SKILL.md`, `tests/test_phase_skill.sh`, `tests/test_program_skill.sh`,
`tests/test_templates.sh`.

---

# Fix round 3

Findings file: `docs/dev/program/phases/prerequisites/task-3-review-2.md`. Reviewer verdict:
Spec OK, Quality **Not approved** — one Important, five Minor. The coordinator's framing for
this round, quoting the review's §2: **detection coverage for `[T3-M4]`'s fallback guard is
formally closed as unachievable**, and this round is not a fourth attempt at widening markers.
It is disclosure and honesty work: make the guard's claims match what it decides, narrow two
demonstrated false positives, and finish two small residues from earlier rounds.

## Why detection is closed (§2 of the review, accepted without dispute)

Substring matching is polarity-blind: it has no notion of negation, mood, or who is being
addressed, and the vocabulary that marks a fallback is the same vocabulary that marks a
prohibition of that fallback and a compliant stop. The review proved this **in-repo**, not
hypothetically: `skills/foreman-phase/references/gate-chain.md:64` already carries the sentence
"Dispatch a fresh subagent ... — do not invoke `fable:fable-judge` **yourself**." — the
strongest possible statement of `[DEP-1]`'s own ruling — and pasting it into Step 0 turned round
2's guard red on the bare `'yourself'` marker (FP1). A compliant resume instruction ("proceed by
starting a fresh phase session") did the same to `'proceed by'` (FP2). Every marker added across
three rounds to catch one more fallback shape simultaneously forbids one more way of *stating
the rule*, because the tool matches words while the property is about meaning and polarity. I
accept this without qualification: it is not a tuning failure, it is structural, and no fourth
round of marker-widening would converge — it would only trade the current false negatives for a
larger false-positive surface, and a false positive is the worse failure, because the cheapest
route back to green is deleting the sentence that just reinforced the ruling.

The review's §2.2 also names the one mechanism that *would* remove the false-negative risk
within invariant 1 — a snapshot pin or a word-count budget over the guarded range — at the cost
of reddening on every edit to that range, including a compliant one. That is `[T3-M13]`: record
it, do not implement it (below).

## `[T3-M4]` (Important) — the guard's claim outran what it decides; the residual sat in no
durable place

**The problem, precisely.** The three passing lines per file read "Step 0 carries no
self-substitution fallback (marker: '...')". The head clause asserts the *class*; the guard
decides three literal phrasings. Every fallback the review or I injected that avoided those
three phrasings left the suite green while those lines kept asserting the class was absent. The
disclosure that this is a heuristic, not a guarantee, existed — but only in my own round-2
report, which nobody reviewing the shipped test or the backlog would ever read.

**Fix, exactly the ~6 lines the review scoped, in both `tests/test_phase_skill.sh` and
`tests/test_program_skill.sh`:**

1. Relabelled: `"Step 0 carries no self-substitution fallback (marker: '$marker')"` →
   `"Step 0 does not carry a known self-substitution phrasing (marker: '$marker')"` (and the
   `### Dependencies`-scoped equivalent on the program side). The new label claims exactly what
   the assertion decides — a specific phrasing is absent — not the absence of the class.
2. Added a closing paragraph to each comment block, stated plainly: *"a tripwire against the
   specific phrasings named across rounds 1-2, not a detector for the class. A fallback worded
   around these three phrases passes this check with a green suite — no content-matching
   assertion can close that gap, so the rule is enforced by review, not by the gate."*
3. Added the same disclosure, plus the scope note (`[T3-M10]`, below) and the `[T3-M13]`
   record, to `docs/dev/backlog.md`'s `[DEP-1]` closure — the durable ledger, not a per-round
   report.

No marker was added or removed for coverage in this step; the marker *set* only changed under
`[T3-M9]`, below, and that change removes false positives, not widens detection.

## `[T3-M9]` — narrowed the two markers that collided with compliant, in-repo prose

**`'yourself'` → `'yourself:'`** (colon-anchored). Every fallback shape observed across three
rounds phrases the self-substitution as `"... yourself: <steps that follow>"` (both of round 1's
mutation-D texts, on the phase and program sides, end the trigger word with a colon
immediately introducing the degraded procedure). `gate-chain.md:64`'s compliant sentence ends
the same word with a period ("yourself."). Anchoring on the colon removes the FP1 collision
without losing the shapes the marker was built to catch.

**`'proceed by'` → `'proceed by running'`.** Round 1's phase mutation D used exactly this
three-word phrase to describe carrying out `fable-judge`'s job in the session's own voice. FP2's
compliant resume instruction ("proceed by starting a fresh phase session") does not contain
"running" — narrowing removes that collision. `'read its rubric from'` was not implicated in
either false positive and is unchanged.

**Test-first and mutation-checked, on both skills:**

1. Ran the suite unmodified after the edit: `654/0` — same total as before (three markers
   replacing three, one-for-one; no assertion count change).
2. **FP1 reproduction** — appended `"Do not invoke \`fable:fable-judge\` yourself."` (the
   `gate-chain.md:64` sentence, verbatim) to the phase skill's Step 0. Result: `654/0`, green —
   the false positive is gone. Restored.
3. **FP2 reproduction** — appended `"Once the missing plugin is installed, proceed by starting
   a fresh phase session."` to the phase skill's Step 0. Result: `654/0`, green. Restored.
4. **Mutation D reproduction** (must still redden — this is the shape the markers exist for) —
   reapplied round 2's exact injected texts to both skills (phase: "...proceed by running gate
   3 yourself: dispatch a fresh subagent..."; program: "...run the interview yourself: ask for
   the problem..."). Result: `651/3` —
   `Step 0 does not carry a known self-substitution phrasing (marker: 'proceed by running')`,
   `(marker: 'yourself:')` on the phase side, `(marker: 'yourself:')` on the program side. Both
   skills' guards still catch the mutation that originally motivated them. Restored.
5. **Sanctioned-phrase marker sanity check** — appended `"If not installed, read its rubric
   from the marketplace cache instead."` to the phase skill. Result: `653/1` on
   `marker: 'read its rubric from'`. Restored, back to `654/0`.

All five behaved as required; the round converges rather than opening a fourth marker
iteration.

## `[T3-M10]` — stated the guard's range explicitly, rather than extending it

The review's own mutation N2 (inserting a degraded path into `gate-chain.md`'s gate-3 dispatch
section, outside Step 0 entirely) left the suite green — the guard's range is the Step 0 /
`### Dependencies` body only. Extending the range to cover dispatch sites like `gate-chain.md`
would be new detection surface, which the ruling for this round forbids chasing. Chose the
"state it" branch of the review's either/or: both assertion labels already name their scope
(`"Step 0 does not carry..."` / `"Dependencies subsection does not carry..."`), and both
comment blocks now add an explicit sentence — *"a degraded path written at a dispatch site the
skill merely points to (for instance `references/gate-chain.md`'s gate-3 section) is entirely
outside it"* (phase) and the symmetric statement on the program side. `backlog.md`'s new
paragraph states the same limit for the durable ledger. No test change beyond the comment text
this finding required, since it is a disclosure fix, not a coverage fix.

## `[T3-M11]` — the last residue of the `[T3-M1]`/`[T3-M5]` sweep

`tests/test_templates.sh:257`'s comment (not an assertion string — nothing to mutation-check)
still called `EnterWorktree` the phase session's "first action" in prose, three commits after
`[T3-M1]` established that Step 0 runs first. Reworded to "first tool call", matching the
`[T3-M5]` language already shipped in `foreman-program/SKILL.md`. Re-ran the sweep regex the
review used
(`grep -rniE "first (step|action|thing|tool call)|before anything|before doing anything|starts
by|begins (by|with)|Step 1a"` over `skills/ agents/ commands/ tests/` and `POLICY.md`) after the
edit — no further live claim of primacy for a later action found.

## `[T3-M12]` — `[T3-M5]`'s positive needles pinned markdown emphasis

`tests/test_program_skill.sh`'s two positive `[T3-M5]` assertions matched the literal
`*action*` / `*tool call*` asterisks; a compliant reword that drops the emphasis (e.g. "the
kickoff's first action is...", no italics) would have reddened a correct sentence. Fixed by
stripping `*` from both the extract and the needle before matching: added
`skillf_noemph="$(printf '%s' "$skillf" | tr -d '*')"` and rewrote both needles without
asterisks, matched against that stripped copy.

**Test-first and mutation-checked**: on a scratch copy, dropped the emphasis markup from
`foreman-program/SKILL.md:178-180` (`*action*` → `action`, `*tool\ncall*` → `tool\ncall`).
Result: `654/0`, unchanged — the compliant reword no longer reddens. Restored. (The meaning-
removal direction was already covered by the pre-existing `[T3-M5]` mutation checks from round
2, which used the same underlying sentences; not re-run, since `[T3-M12]`'s change only affects
how emphasis markup is normalised before matching, not what content is required.)

## `[T3-M13]` — recorded the closed-world option, not implemented

Per the coordinator's explicit instruction, this is a record, not a build. Added one paragraph
to `docs/dev/backlog.md`'s `[DEP-1]` closure naming the review's §2.2 mechanism: a snapshot pin
(compare the normalised guarded-range body against a stored fixture) or a word-count budget,
either of which gives a genuine no-false-negative guarantee within invariant 1 at the cost of
reddening on *any* edit to the range, including a compliant reword — trading detection for
friction rather than deciding the question. Left unimplemented, flagged as a policy choice for
a future round.

## Gate and invariant checks, this round

```
$ bash tests/run.sh 2>&1 | tail -3
14 files, 654 passed, 0 failed
```
654 — unchanged from the round-3 floor. This round relabels, narrows (one-for-one, not
additive), and comments; it adds no new assertions and removes none, so the total is exactly
the floor the coordinator verified.

```
$ grep -nE '\b(TODO|TBD|FIXME)\b' tests/test_phase_skill.sh tests/test_program_skill.sh \
    tests/test_templates.sh docs/dev/backlog.md
tests/test_templates.sh:470:assert_eq "" "$(grep -rlE '\b(TODO|TBD|FIXME)\b' "$t" || true)" ...
```
The one hit is a pre-existing assertion whose own *pattern string* contains those tokens as a
regex to detect them elsewhere — not a placeholder in this diff. No other match, in this round's
changed files or otherwise.

```
$ awk 'length > 100 {print FILENAME":"FNR": "length}' tests/test_phase_skill.sh \
    tests/test_program_skill.sh tests/test_templates.sh docs/dev/backlog.md
(33 lines, all pre-existing bash lines in tests/*.sh untouched by this round's diff, plus
tests/test_program_skill.sh:118 at 110 columns — found in my own new code and wrapped onto two
lines before the final run, confirmed gone from the list afterward)
```
`docs/dev/backlog.md`'s new paragraph and every new comment line I wrote in the three test files
were individually checked and are all ≤ 100 columns; the over-100 lines that remain are the same
pre-existing bash lines the round-2 review already noted as out of invariant 8's scope (shipped
markdown, not bash). `skills/foreman-phase/SKILL.md`, `skills/foreman-program/SKILL.md`, and
`skills/foreman-init/templates/program/kickoff.md.tmpl` carry **no diff at all** this round
(confirmed via `git status`) — every fix this round lives in test comments/labels and
`backlog.md`, none in shipped skill or template prose. Confirmed none of the five
coordinator-fenced files (`settings.json.tmpl`, `settings.local.json.tmpl`, `MANIFEST.tsv`,
`gitignore-additions.txt`, `CLAUDE.md.tmpl`) appear in `git diff --stat` for this round.

## The binding ruling — not relitigated, still honoured

Nothing in this round adds a degraded path or softens the prohibition text in either skill —
both skills carry no diff this round at all. The work here is entirely about making the test
suite's *claims* about the ruling's enforcement match its *actual* enforcement strength, which
is the opposite of weakening the ruling: an honest "tripwire, not a detector, enforced by
review" is a stronger position than an overclaiming "no fallback can be added" that a future
editor would trust past its actual reach.

## What I could not verify

Same structural limits as all three rounds: a live session's behavior is outside a bash gate's
reach. Specific to this round: I cannot verify that the narrowed markers (`'proceed by
running'`, `'yourself:'`) do not themselves collide with some *other* compliant sentence not
yet written — only that they no longer collide with the two the review found, and still catch
every fallback shape named across rounds 1 and 2. This is the same closed-detection limit named
in the review's §2.1 and now recorded in `backlog.md` rather than only in this report.

## Commit

```
e50992b tests+backlog: fix round 3 on [DEP-1] -- disclose the guard's limit, stop chasing coverage
```
4 files changed: `docs/dev/backlog.md`, `tests/test_phase_skill.sh`,
`tests/test_program_skill.sh`, `tests/test_templates.sh`.
