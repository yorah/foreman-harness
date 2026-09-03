# Task 3 re-review (fix round 1): `[DEP-1]` dependency check at skill entry

Reviewer: Opus, high effort. Artifact reviewed:
`docs/dev/program/phases/prerequisites/task-3-review-1.diff`, read as given and never
regenerated. Cumulative diff from the task's original base: 7 files, +132 -2. Working tree at
`bd02151` (fix round) on top of `07d0fd1` (original task); `git status` shows only the three
untracked task-3 markdown artifacts, so the tree matches the diff's post-image.

**Verdict: Spec OK (against `task-3-brief.md`) - Quality: Not approved.**
One Important, four Minor. `[T3-M2]` and `[T3-M3]` are genuinely closed. `[T3-M1]` is closed at
the surface it names but has two live siblings and one mechanism caveat. **`[T3-M4]` is not
closed in substance** - proved by mutation.

Everything below was reproduced against a copy of the worktree under the session scratchpad
(`.../scratchpad/wt`), never against the repository. No tracked file was modified, created or
deleted; no state-changing `git` command was run. The scratch copy was byte-compared back to
`/home/yorah/.../worktrees/prerequisites/skills` after the last mutation (`diff -r` clean) and
re-run green at `14 files, 646 passed, 0 failed`.

---

## 0. Method - the mutation table

Scratch baseline: `646 passed, 0 failed`.

| # | Mutation | Result | What it proves |
|---|---|---|---|
| A | Revert `kickoff.md.tmpl:3` to `## First - foreman-phase Step 1a, then Step 1b's EnterWorktree` | `644/2` - `names foreman-phase's actual first step (Step 0): [Step 0] not found` + `names Step 0 before Step 1a (got first= step1a=47)` | `[T3-M1]`'s new assertion is live; a header revert is caught twice |
| B | Inverse drift: delete `## Step 0` from `foreman-phase/SKILL.md`, leave the template naming Step 0 | `639/7`, including `kickoff template names Step 1 before Step 1a (got first=60 step1a=60)` | the inverse drift **is** caught - the skill-derived needle degrades to `Step 1`, whose first byte offset collides with `Step 1a`, so the ordering check fails |
| B2 | B, plus revert the template header (both files consistently back to the pre-task state) | still `639/7`, same kickoff red | the ordering check cannot go green when the skill's first step is `Step 1`. See `[T3-M7]` |
| C | Title-case **and** reflow both prohibitions (`**Do Not Substitute Your Own Procedure For It.**` on one long line) | `646/0` green | `[T3-M3]` closed: the assertion survives recapitalisation and rewrapping |
| C2 | From C, replace the prohibition's words with `Keep Going Anyway` | `644/2`, one per file | `[T3-M3]`'s assertion is not vacuous - it still tracks meaning |
| D | Add a degraded path with no marker words: phase Step 0 gains "If the skill is unavailable, proceed by running gate 3 yourself: dispatch a fresh subagent ... take its report as the gate verdict."; program `### Dependencies` gains "Should the plugin be unavailable, run the interview yourself: ..." | **`646/0` green** | `[T3-M4]`'s guard does **not** detect a fallback. See the Important finding |
| E | Add the sanctioned marker phrasing (`is not installed, read its rubric from the marketplace cache instead`) to both | `642/4` | the guard does exactly and only what the implementer's report claims: it detects that one phrasing |
| F | Strengthen the phase prohibition in a ruling-compliant way: `**do not substitute your own procedure for it** - report the gap and stop instead.` | `645/1` - `Step 0 carries no fallback path ... [instead] should be absent` | false positive on compliant prose |
| G | Reword the stop clause `If either is missing, stop:` to `If either is not installed, stop:` (semantically identical, ruling-compliant) | `645/1` - `Step 0 carries no not-installed fallback clause` | second false positive, on the most natural rewording of the sentence the check protects |

---

## 1. Spec compliance

The brief (`task-3-brief.md`) was already satisfied in round 0 and nothing in this round
regressed it: `foreman-phase/SKILL.md:13-27` still carries `## Step 0 - dependencies, before
anything else` immediately before `## Step 1` (:29); `foreman-program/SKILL.md:61-72` still
carries `### Dependencies` immediately before `## Then read exactly three things` (:74); both
test files carry the assertions; `docs/dev/backlog.md:227` is `- [x]`.

This round additionally touched two files the brief's file list does not name -
`skills/foreman-init/templates/program/kickoff.md.tmpl` and `tests/test_templates.sh`. Both
were required by the previous review's `[T3-M1]` and directed by the coordinator, so they are
not scope creep. Recorded here because a reader comparing the diff to the brief's `Files:`
block will notice the difference.

**No overlap with the distribution-template task.** The diff touches none of
`settings.json.tmpl`, `settings.local.json.tmpl`, `MANIFEST.tsv`, `gitignore-additions.txt`,
`CLAUDE.md.tmpl`. `MANIFEST.tsv` is untouched, so `kickoff.md.tmpl`'s row (destination
`docs/dev/program/phases/{{PHASE_SLUG}}/kickoff.md`, verified at `MANIFEST.tsv:15`) is
unaffected - the edit is content-only.

**No restructuring of either skill.** `skills/foreman-phase/SKILL.md` and
`skills/foreman-program/SKILL.md` show no diff at all in this round (the +16/+13 hunks in the
cumulative diff are round 0's insertions). Neither skill's headings, step numbers or
cross-references moved. `gate-chain.md:150` ("worktree, in Step 1a") is still correct because
Step 1a did not move. `foreman-program:56` ("do not continue past Step 0 until you have a
verdict") still reads correctly with `### Dependencies` appended inside Step 0.

**No test weakened or deleted.** The cumulative diff's only two deleted lines are the backlog
checkbox and the kickoff header. `[T3-M3]` replaced one assertion 1-for-1 in each test file
(`grep -n "substitute your own procedure" tests/*.sh` returns exactly one hit per file,
`test_phase_skill.sh:374` and `test_program_skill.sh:223`, both against the lowercased
extract), so no coverage was dropped and none duplicated.

**Assertion arithmetic closes.** New slots: `test_phase_skill.sh` 8 (1 ordering `_ok`/`fail` +
4 names + 1 prohibition + 2 `assert_not_contains`), `test_program_skill.sh` 8 (1 ordering + 1
subsection + 3 names + 1 prohibition + 2 `assert_not_contains`), `test_templates.sh` 2. Total
18; 628 pre-task + 18 = 646, which is what the suite reports and what the controller measured.
The report's own accounting (640 + 2 + 4) reaches the same number by a different route.

---

## 2. `[T3-M1]` - closed at the header, two siblings live, one mechanism caveat

### Closed, and the assertion bites in both directions

`kickoff.md.tmpl:3` now reads ``## First - `foreman-phase` Step 0, then Step 1a, then Step 1b's
`EnterWorktree` ``. Mutation A shows a revert goes red twice. Mutation B shows the **inverse**
drift - a template naming a Step 0 the skill no longer has - also goes red, which is the harder
half of the controller's question. Worth recording exactly *why* it goes red, because it is not
the mechanism the test's comment describes: when Step 0 disappears, `first_step` degrades to
`Step 1`, the `assert_contains` passes **vacuously** (`Step 1` is a prefix of `Step 1a`), and it
is the byte-offset comparison that fails, with `first=60 step1a=60`. The drift is caught by
accident of substring geometry rather than by the derivation the comment credits. It works; it
is fragile reasoning to inherit.

### Nothing else in the two skills or `gate-chain.md` makes Step 0 optional

`grep -rn "Step 1a\|Step 0\|before anything else\|## First" skills/ agents/ commands/` returns
seven hits, all consistent: `foreman-init/SKILL.md:10` and `foreman-program/SKILL.md:10,:56`
are that skill's own Step 0, `foreman-phase/SKILL.md:13` is the new section,
`foreman-phase/SKILL.md:115` is an unrelated "before anything else in this step", and
`gate-chain.md:150` is about *where* to check something in Step 1a, not about what comes first.
`commands/phase.md` says only "Use the `foreman-phase` skill" and names no starting step.

But two claims elsewhere still name a *later* action as the phase's first, and both are now
further from the truth than they were before this round.

### Minor `[T3-M5]` - the PM is still told the kickoff's first step is `EnterWorktree`

`skills/foreman-program/SKILL.md:179`:

> The kickoff's own first step is `EnterWorktree(name: "<slug>")`. You do not hand the user a
> worktree command; the phase session makes its own.

And `tests/test_templates.sh:263-267` pins that agreement, with the label:

> "kickoff template's first step matches what foreman-program promises the PM"

That label is now false. The template's first step is Step 0; `EnterWorktree` is its third. The
assertion still passes because it only checks the literal `EnterWorktree(name:
"{{PHASE_SLUG}}")` is present *somewhere*, so nothing went red - a green assertion now
certifies a statement that is not true.

Failure scenario, concrete: `foreman-program/SKILL.md:117-118` and `:160` have the PM write a
**self-contained kickoff** for every phase after the first (the template is rendered once by
`foreman-init`, per `MANIFEST.tsv:15`). A PM working from `:179` writes a kickoff whose first
step is `EnterWorktree` and which never mentions Step 0. The phase session handed that kickoff
creates a worktree and a branch before checking its plugins - the exact `[T3-M1]` failure,
reached through the PM path instead of the template path. Same bounded cost as `[T3-M1]` (a
worktree and a branch, not a finished branch), so Minor for the same reason `[T3-M1]` was
Minor. Remedy: one clause at `:179` ("the kickoff's own first *action* is `foreman-phase`
Step 0's dependency check; its first *tool call* is `EnterWorktree(name: "<slug>")`") plus a
label correction at `test_templates.sh:267`.

### Minor `[T3-M6]` - the template body still claims primacy for Step 1a's content

`kickoff.md.tmpl:5-7`, unchanged: "Record `<main-checkout>` ... and `<default>` ... **before
doing anything else**". Read against the new header three lines above it, the same file now
says both "Step 0 first" and "record these before anything else". Consequence is small - the
Step 1a work is two read-only git invocations that spend nothing and create nothing, so a
session that does them first has not skipped the stop-check in any costly sense - but it is the
same phrase `[T3-M1]` was raised about, in the same file, three lines from the fix. Remedy:
"before entering the worktree" instead of "before doing anything else".

### Minor `[T3-M7]` - the kickoff ordering assertion cannot go green without a Step 0

`tests/test_templates.sh:277-284`. The comment claims the derivation "goes red again if the
skill's first step is ever renumbered and the template is not updated to match". Mutation B2
falsifies the second half: with Step 0 removed from the skill **and** the template header
correctly reverted - both files mutually consistent, and exactly the state the repository was
in before this task - the assertion is still red, because `first_step` is then `Step 1` and
`grep -bo 'Step 1'` reports the same byte offset as `grep -bo 'Step 1a'`, so
`first_pos -lt step1a_pos` can never hold. In practice the assertion hard-requires a step whose
literal name is not a prefix of `Step 1a`, i.e. a Step 0. That is fine while `[DEP-1]` stands
(and `test_phase_skill.sh:357-360` independently requires the Step 0 heading), but it means the
"derive it from the skill" cleverness buys nothing over a hard-coded `Step 0`, and its comment
overstates what it does. Remedy: compare against the whole heading text, or match `Step 1\b`.

### Minor `[T3-M8]` - the same block passes vacuously if the grep finds nothing

`tests/test_templates.sh:277-283`. If `grep -m1 -oE '^## Step [0-9]+'` matches nothing (the
skill file renamed, moved, or its headings restyled), `first_step` is empty. Then
`assert_contains "$kickoff_tmpl" ""` matches by construction (`lib_assert.sh:20-23` is a `case`
glob, and `*""*` matches everything), and `grep -bo -- ""` yields offset `0` for the first line
- verified: `printf 'alpha\nStep 1a beta\n' | grep -bo -- "" | head -1` prints `0:alpha` - so
`0 -lt 47` and the ordering check passes too. Both new assertions go green on a missing ground
truth. Bounded (a vanished `foreman-phase/SKILL.md` reddens most of `test_phase_skill.sh`), but
the guard's own failure mode is silence. Remedy: `[ -n "$first_step" ] || fail "..."` before
using it.

---

## 3. `[T3-M2]` - closed

`docs/dev/backlog.md:250-256` now records an actual verdict on the fifth reference:

> The fifth reference named above, `plans/plan-README.md.tmpl`'s
> `superpowers:subagent-driven-development` banner, was not given a check of its own: it ships
> inside the same `superpowers@claude-plugins-official` plugin that Step 0 already checks via
> `superpowers:finishing-a-development-branch`, so the failure mode this item describes - a
> whole plugin absent - is caught regardless. Judged covered, not overlooked.

That is a decision, with a stated reason and a stated scope limit, which is what the item's own
"decide **per reference**" (`:244-246`) asked for. The reasoning is sound as far as it goes: the
banner and the checked skill do ship in one plugin, so the whole-plugin-absent case is covered;
a single-skill absence is not, and the paragraph does not pretend otherwise. Marking `- [x]` in
place matches this backlog's existing convention (`[T1-M1]`, `[T2-M1]`, `[T5-M4]` are all `[x]`
in situ under their own sections) and was what the brief instructed.

The previous review's cosmetic aside - that the closure paragraph sits after the "Unrelated, but
adjacent..." `resolve-gate.sh` note - is now harmless: the paragraph opens with "Closed by phase
A task 3", which disambiguates what it closes. No finding.

---

## 4. `[T3-M3]` - closed, and the declared deviation is sound

**Closed.** Mutation C: title-casing the prohibition to `**Do Not Substitute Your Own Procedure
For It.**` *and* reflowing the whole paragraph onto one long line leaves the suite at `646/0`.
Mutation C2: replacing the sentence's words with `Keep Going Anyway` reddens both files. So the
assertion survives reflowing and recapitalisation and still fails when the meaning is removed -
which is the plan's constraint stated exactly.

**Ruling on the deviation: sound, and the alternative was not available.**
`tests/test_program_skill.sh:18` defines `flow() { tr '\n' ' ' < "$1" | tr -s ' '; }`. The
`< "$1"` redirection means it takes a *filename*; there is no string-input variant anywhere in
`tests/`. The text under test is an `awk NR>a && NR<b` range, not a file, so `flow` genuinely
cannot serve it without being changed. Beyond that, `flow` does not lowercase, so even a
string-taking `flow` would not have satisfied `[T3-M3]` on its own. Stating it plainly, as the
controller asked: **this is a gap in the helper, not a defect in this task.** The residue is
that the same normalisation is now inlined in two test files; a
`flow_str() { printf '%s' "$1" | tr '\n' ' ' | tr -s ' ' | tr '[:upper:]' '[:lower:]'; }` in
`lib_assert.sh` would remove the duplication. Not numbered - a helper improvement, not a defect
in this diff.

---

## 5. `[T3-M4]` - **not closed.** Important

### The claim

`tests/test_phase_skill.sh:383-386` and `tests/test_program_skill.sh:237-240`:

```bash
assert_not_contains "$step0_body_lc" 'instead' \
  "Step 0 carries no fallback path (ruling: presence check only, never a fallback)"
assert_not_contains "$step0_body_lc" 'not installed' \
  "Step 0 carries no not-installed fallback clause"
```

The binding ruling is that `[DEP-1]` is a presence check that stops cleanly, **never** a
fallback. The finding asked for a guard that goes red if a fallback is added alongside the
prohibition.

### False negative - the guard does not guard

Mutation D added a fully-formed degraded path to **both** skills, inside both guarded ranges,
leaving the prohibition sentence in place:

- phase Step 0: "If the skill is unavailable, proceed by running gate 3 yourself: dispatch a
  fresh subagent with the plan and the diff, ask it to argue the work is not done, and take its
  report as the gate verdict."
- program `### Dependencies`: "Should the plugin be unavailable, run the interview yourself: ask
  for the problem, the constraints and the acceptance test, then write the plan in the same
  shape."

Result: **`14 files, 646 passed, 0 failed`.** The phase-side insertion is precisely the
improvised gate 3 the ruling exists to forbid - a second copy of `fable-judge`'s procedure,
inside the skill - and the suite is green. This is the scenario the controller named in advance
("a guard that only detects the word 'fallback' while missing 'if the skill is unavailable,
proceed by ...' is not a guard"). Mutation E confirms the guard fires only on the one phrasing
the implementer copied from `foreman-init`'s sanctioned fallback, which is the phrasing least
likely to be reinvented by an editor who never read that fallback.

Why Important rather than Minor: the assertion's own label states a claim ("Step 0 carries no
fallback path") that the assertion demonstrably does not verify, which is the rubric's "a test
that does not test its claim". The concrete harm is a false record - the implementer's report
and the now-closed `[DEP-1]` item both read as though the ruling is mechanically enforced going
forward, so the next editor to touch Step 0 has a green suite telling them a degraded path was
rejected when nothing checked.

To be fair to the implementer: the report describes the guard accurately ("against the marker
phrasing `foreman-init`'s own sanctioned fallback uses"). It is the two **labels** and the
`[T3-M4]`-closed status that overclaim. And no `grep` can decide "is this prose a degraded
path" - which is why the honest remedy is (a) relabel both assertions to what they check ("Step
0 does not carry `foreman-init`'s sanctioned-fallback phrasing") and carry `[T3-M4]` forward as
a rule `grep` cannot close, rather than (b) widening the marker list, which trades the false
negative for more of the false positives below.

### False positives - and they are the `[T3-M3]` disease, reintroduced

Mutation F: strengthening the phase prohibition to `**do not substitute your own procedure for
it** - report the gap and stop instead.` gives `645/1`, red on `[instead] should be absent`. A
compliant, ruling-*reinforcing* edit breaks a green suite.

Mutation G, worse because it is the likeliest rewording of all: `If either is missing, stop:` to
`If either is not installed, stop:` gives `645/1`, red on `Step 0 carries no not-installed
fallback clause`. "Not installed" is the plainest English for the condition this section tests,
and the sentence remains a clean stop with no degraded path anywhere. The suite calls it a
fallback.

So this round closed one instance of "the assertion pins typography, not meaning" (`[T3-M3]`)
and opened two more in the same two files. Both directions of the same two assertions are
wrong: they pass on a fallback and fail on a stop.

---

## 6. Invariants

| # | Verdict | Evidence |
|---|---|---|
| 1 - zero runtime deps beyond bash/git/jq | **Pass** | No shipped script added or changed. The new test code uses `grep`, `awk`, `tr`, `cut`, `head`, `sed`, `printf`; `sed` was already used in this same file (`test_templates.sh`'s `render_settings`), `awk` in `scripts/phase-state.sh` and `scripts/baseline-check.sh`. Nothing new is introduced |
| 2 - shebang / `set` line / `chmod +x` | **Pass** | No new file. All three test files are appended to only; `test_templates.sh:1-2`, `test_phase_skill.sh:1-2`, `test_program_skill.sh:1-2` still carry `#!/usr/bin/env bash` + `set -uo pipefail`, the exemption invariant 2 grants `tests/test_*.sh`. Behaviour under `-u` without `-e` re-checked in mutations A/B: a `grep` that matches nothing leaves the assignment empty, the `-n` guards route to `fail`, and `awk -v a= -v b=` yields an empty extract that fails the body assertions rather than aborting the file (the `D` sentinel was written every time - no `aborted before reporting counts`) |
| 3 - exit-code contract | **N/A** | No script behaviour touched |
| 4 - absolute paths between tiers | **N/A** | The changed header names step numbers, not paths. `test_templates.sh:277` reads through `$FOREMAN_ROOT`, absolute |
| 5 - no TODO/TBD/FIXME | **Pass** | `grep -rnE '\b(TODO|TBD|FIXME)\b' skills/ agents/ commands/ --include='*.md'` returns no match |
| 6 - bare wrapper names | **Pass** | The new prose and the new header name no harness script at all, by path or otherwise |
| 7 - green, not below baseline | **Pass** | `646/0` reproduced independently in the scratch copy; `POLICY.md`'s baseline 610 untouched (a phase session must not edit it, `POLICY.md:7-9`), delta +36 |
| 8 - 100-column wrap in shipped markdown | **Pass** | `awk 'length > 100'` over `kickoff.md.tmpl`, both `SKILL.md`s and `backlog.md` reports only `foreman-phase/SKILL.md:3` (240) and `foreman-program/SKILL.md:3` (302), both exempt `description:` frontmatter scalars. The new header line is 79 columns. The over-100 lines in the three `.sh` files are bash, not shipped markdown, and the same pattern predates this diff (e.g. `test_phase_skill.sh:68`, `:161`) |

---

## 7. Test quality summary

| New assertion | Goes red on the bug it claims? |
|---|---|
| `test_templates.sh:279` names the skill's actual first step | Yes (mutation A) |
| `test_templates.sh:283` that step precedes `Step 1a` | Yes (A, B), but see `[T3-M7]` (cannot go green without a Step 0) and `[T3-M8]` (vacuous on an empty needle) |
| `test_phase_skill.sh:374` / `test_program_skill.sh:223` prohibition, case-insensitive | Yes (C2), and survives typography (C) |
| `test_phase_skill.sh:383,385` / `test_program_skill.sh:237,239` no-fallback guards | **No** (mutation D) - and false-red on compliant prose (F, G) |

The program-side re-scoping to the `### Dependencies` subsection
(`test_program_skill.sh:234-240`) is a genuine tightening of the cross-satisfaction gap the
previous review noted, and the implementer's own scoping mutation is credible; it just tightens
a check that does not detect what its label says.

---

## 8. Cannot verify

- That a live Claude Code session, handed a missing plugin, actually stops. The check is prose
  obeyed by a model; a bash gate reaches text and position only. Flagged by the implementer in
  both rounds, correctly.
- That the session's visible skill list uses the `plugin:skill` naming both blocks assume. The
  brief asserts it and `foreman-program:104` already relied on it before this task.

## 9. Observation, not a finding

`docs/dev/program/phases/prerequisites/kickoff.md:3` - this repository's own live kickoff for
the phase now running - still carries the old `## First - foreman-phase Step 1a...` header. That
file is the dispatch record the running session was actually given; editing it mid-phase would
rewrite instructions already acted on, and the session is long past Step 0. Correctly left
alone. Future phases pick up the fixed template.
