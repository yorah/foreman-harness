# Task 3 re-review (fix round 2): `[DEP-1]` dependency check at skill entry

Reviewer: Opus, high effort. Artifact reviewed:
`docs/dev/program/phases/prerequisites/task-3-review-2.diff`, read as given and never
regenerated. Cumulative diff from the task's original base: 7 files, +210 -8. Repository at
`62ceed9`; `git status --porcelain` shows only the untracked task-3 markdown artefacts, so the
working tree matches the diff's post-image.

**Verdict: Spec OK (against `task-3-brief.md`) - Quality: Not approved.**
One Important, five Minor. `[T3-M5]`, `[T3-M6]`, `[T3-M7]` and `[T3-M8]` are genuinely closed -
each verified by mutation, including the vacuity case. `[T3-M4]`'s **mechanism** is materially
better than round 1's and now catches every shape either review named. What is still open is
**not** detection coverage - that target is unachievable and must not be chased further
(section 2) - it is that the guard's own label still asserts the class it cannot decide, and the
residual is disclosed only in the task report, not in the test comment or in any durable ledger.
That is a ~6-line text fix, and it converges; it is not a fifth attempt at marker-widening.

All mutations below ran against a copy of the worktree under the session scratchpad
(`.../scratchpad/wt`), never against the repository. No tracked file was modified, created or
deleted; no state-changing git command was run. After the last mutation the scratch copy was
byte-compared back (`diff -r skills tests` against the worktree: clean) and re-run green at
`14 files, 654 passed, 0 failed`.

---

## 0. Method - the mutation table

Scratch baseline `654 passed, 0 failed`, identical to the controller's own measurement. Each
mutation was applied, the suite run, then the file restored from a saved copy.

| # | Mutation | Result | What it proves |
|---|---|---|---|
| M5r | Revert `foreman-program/SKILL.md:178-180` to "The kickoff's own first step is EnterWorktree(name: \"<slug>\")." | `651/3` - all three new assertions red | `[T3-M5]`'s assertions are live in both directions |
| M6r | Revert `kickoff.md.tmpl:6` to "before doing anything / else" | `652/2` - `[before doing anything else] should be absent` + `[before entering the worktree] not found` | `[T3-M6]` live, both directions |
| M7a | Consistent renumber: `## Step 0` to `## Step 2` in the phase skill **and** `Step 0` to `Step 2` in the template header | `653/1` - the only red is `test_phase_skill.sh`'s deliberate hard pin on `## Step 0` | the derived-step mechanism genuinely works for any step number that is not bare `1`, exactly as the corrected comment claims |
| M7b | Round-1 mutation B2 exactly: delete the skill's Step 0 **and** revert the template header (both files mutually consistent) | `647/7`, kickoff red as `got first= step1a=47` | `[T3-M7]` fixed: an **honest empty match**, not round 1's `first=60 step1a=60` prefix collision |
| M8 | Restyle every `## Step N` heading to `## STEP N` (so `grep -c '^## Step [0-9]'` gives 0) | `645/9`, including `foreman-phase/SKILL.md has a '## Step N' heading to derive the first step from` **plus** the two downstream claims as explicit fails | `[T3-M8]` closed: an empty derivation is now a loud failure, not a vacuous pass |
| D | Phase Step 0 gains "If the skill is unavailable, proceed by running gate 3 yourself: dispatch a fresh subagent and take its report as the verdict." | `652/2` (`proceed by`, `yourself`) | the guard does catch the shapes it names |
| N1 | Program `### Dependencies` gains "If a plugin is absent, run the interview from the questions in `references/` and carry on." | **`654/0` green** | the miss is symmetric across both files, not only the phase side the controller probed |
| N2 | The same degraded path added to `skills/foreman-phase/references/gate-chain.md` section "3. Adversarial verification" - the actual gate-3 dispatch site `[DEP-1]` cites (:64,:73) | **`654/0` green** | the guard's reach is Step 0's body only; the dispatch sites are unguarded |
| FP1 | Append this repository's **own compliant prohibition**, verbatim from `gate-chain.md:64` - "Do not invoke `fable:fable-judge` yourself." - to Step 0 | **`653/1`** (`marker: 'yourself'`) | false red on a sentence that *strengthens* the ruling, and one that already exists in-repo for this exact skill |
| FP2 | Add a compliant resume instruction: "Once the missing plugin is installed, proceed by starting a fresh phase session." | **`653/1`** (`marker: 'proceed by'`) | false red on prose containing no degraded path at all |

The controller's four plainly-worded fallbacks (all green) are taken as established and were not
re-run. N1 and N2 extend that result to the program side and to the gate-3 dispatch site.

---

## 1. Spec compliance - OK

The brief's four required edits are present and unregressed by this round:

- `skills/foreman-phase/SKILL.md:13-27` - `## Step 0 - dependencies, before anything else`
  immediately before `## Step 1` (:29). Names both skills and both plugins.
- `skills/foreman-program/SKILL.md:61-72` - `### Dependencies` closing `## Step 0`, immediately
  before `## Then read exactly three things` (:74). Names all three skills.
- `tests/test_phase_skill.sh:351-392`, `tests/test_program_skill.sh:216-262` - the brief's
  assertion blocks, plus the review-directed hardening.
- `docs/dev/backlog.md:227` - `[DEP-1]` is `- [x]`, with a closure paragraph at :250-256.

Three files outside the brief's `Files:` list are touched - `kickoff.md.tmpl`,
`tests/test_templates.sh`, `foreman-program/SKILL.md:178-180`. All three were required by
`[T3-M1]`/`[T3-M5]`/`[T3-M6]` and directed by the coordinator; not scope creep. None of the five
files the coordinator fenced off for the distribution-template task (`settings.json.tmpl`,
`settings.local.json.tmpl`, `MANIFEST.tsv`, `gitignore-additions.txt`, `CLAUDE.md.tmpl`) appears
in the diff.

**Nothing required is missing. Nothing unrequired is present** beyond the review-directed files
above.

**No test was weakened or deleted.** The diff's only substantive deletions are the backlog
checkbox, the kickoff header/body wording, the `foreman-program:179` sentence, and one label
string in `test_templates.sh:267` (relabelled, not removed - its assertion survives unchanged).
`[T3-M4]`'s two markers were replaced by three, a net widening, and the program-side guard was
re-scoped tighter, not dropped.

**Assertion arithmetic closes.** 646 (round 1) + 2 (three markers replacing two, in two files) +
3 (`[T3-M5]`) + 2 (`[T3-M6]`) + 1 (`[T3-M7]`/`[T3-M8]`: a guard `_ok`/`fail` added, the existing
pair kept) = 654. Both branches of the `[T3-M8]` `if` emit exactly three records, so the total is
stable whichever branch runs - `645 + 9 = 654` in the M8 run confirms it.

---

## 2. The ruling asked for: can a bash assertion detect "a fallback was added"?

### 2.1 Not as a content classifier. Plainly: no.

Two independent reasons, the second of which is the one that matters.

**(a) The paraphrase space is unbounded.** A marker list is a finite enumeration against an
infinite set of English renderings of one instruction. Ten injected fallbacks across three rounds
(the controller's four, round 1's mutation D, my N1 and N2, the coordinator's own example) needed
only ordinary phrasing to slip past. Each new marker buys exactly one shape.

**(b) Substring matching is polarity-blind, so widening the list actively costs.** The guard has
no notion of negation, mood, or who is being addressed. The vocabulary that marks a fallback is
*the same vocabulary that marks the prohibition of that fallback and the compliant stop*. This is
not hypothetical here - the repository already contains the collision. `gate-chain.md:64` reads:

> Dispatch a fresh subagent (Opus, high effort) - do not invoke `fable:fable-judge` **yourself**.

That is the strongest available statement of the very ruling `[DEP-1]` protects. Pasting that
sentence into Step 0 turns the suite red (FP1: `653/1`, `marker: 'yourself'`). Round 1's guard had
the same disease under `instead` / `not installed`; round 2 fixed the two named instances (F and
G) and reintroduced the class under two new tokens (FP1, FP2). Every token added to catch one more
degraded path simultaneously forbids one more way of *stating the rule*. The false-negative and
false-positive rates are coupled, because the tool matches words while the property is about
meaning and polarity.

**Consequence for the loop.** Rounds 3, 4 and 5 spent widening markers will terminate at the
loop's breaker with the same residual and a larger false-positive surface - and the false
positives are the worse failure, because the cheapest way for a future editor to restore green is
to *delete the ruling-reinforcing sentence that tripped the marker*. Detection coverage should be
declared closed at "tuned tripwire against these named shapes" and not revisited.

### 2.2 There *is* a mechanism - but it answers a different, decidable question

The undecidable question is "is this prose a degraded path?". The decidable one, which *implies*
it for every addition, is "has this ruling-bearing section changed from the text the ruling was
reviewed against?". Two concrete implementations, both inside invariant 1 (nothing beyond bash
plus the coreutils this suite already uses - `wc`, `cmp`, `tr`, `awk` - and invariant 1 binds
shipped scripts, none of which is touched either way):

1. **Snapshot pin.** Keep the normalised Step 0 / `### Dependencies` body in a fixture
   (`tests/fixtures/dep1-step0.txt`) and compare: `[ "$body_norm" = "$expected" ] || fail`. Zero
   false negatives - every one of the ten injected fallbacks trips it. Cost: any edit, including a
   compliant reword, reddens, so the guard becomes "you changed ruling-bearing prose; a human must
   re-approve the diff". That is a legitimate pattern for a 14-line ruling artefact, but note what
   it does - it delegates the fallback / no-fallback judgement back to the human rather than
   deciding it.
2. **Length budget.** `words="$(printf '%s' "$step0_body" | wc -w)"; [ "$words" -le N ] || fail`.
   Insensitive to rewording within budget; every fallback observed across three rounds added 12-30
   words and would trip it. Cost: the boundary is arbitrary, and a terse fallback that replaces
   existing words rather than adding them survives.

So the ruling for the ledger: **the classifier target is unachievable in bash and is closed; the
change-detection target is achievable and is the only mechanism that would raise the guarantee, at
the price of reddening on compliant edits.** Adopting it is a policy choice about how much friction
this section deserves - recorded as `[T3-M13]`, not demanded here.

### 2.3 Does the guard as it stands claim more than it delivers? Yes - narrowly. Section 3.

---

## 3. Important - the guard's claim still outruns the guard, and the residual sits in no durable place

**Location.** `tests/test_phase_skill.sh:376-392`, `tests/test_program_skill.sh:239-262`.

**The label.** Three passing lines per file read:

```
Step 0 carries no self-substitution fallback (marker: 'proceed by')
Step 0 carries no self-substitution fallback (marker: 'yourself')
Step 0 carries no self-substitution fallback (marker: 'read its rubric from')
```

The head of that sentence asserts the class ("carries no self-substitution fallback"). The
assertion decides three literal phrasings. N1 and N2 above, plus the controller's four injections,
are self-substitution fallbacks that leave every one of those lines green. The parenthetical
`(marker: '...')` is a real improvement over round 1's flat "Step 0 carries no fallback path", and
it partially self-limits - but it reads as *which* check fired, not as *the only thing checked*.
Against the controller's own stated criterion ("if it says or implies 'no fallback can be added',
that is not honest, and it is a finding"), the leading clause implies exactly that, three times,
in green.

**The comment.** `test_phase_skill.sh:376-389` and its program-side twin are 14 lines of
rationale: why `instead` / `not installed` were dropped, what each new marker targets, why the
program-side range was tightened. They are accurate and well-reasoned. What they never say is that
a differently-worded fallback passes. The comment is the natural - and realistically the only -
place a future editor of Step 0 will look, and the disclosure is absent from it.

**The ledger.** `docs/dev/backlog.md:250-256` says the skills "check ... and stop cleanly, naming
the plugin; no fallbacks, by ruling". That is a claim about the current text and about the ruling,
not about mechanical enforcement, so the closure paragraph does **not** itself overclaim. But
nowhere in tracked, durable documentation is the enforcement's real strength recorded.
`grep -rn "T3-M4|tripwire|heuristic"` across `docs/`, `tests/` and `skills/` finds the disclosure
only in `task-3-report.md:394-399` and `:544-548` and in the two review files. The report is honest
and explicit - "a better-targeted heuristic ... not a semantic guarantee" - and credit is due for
stating it rather than claiming closure. But a task report is the record of one round; the test
comment and `backlog.md` are what the next editor reads.

**Failure scenario.** A future editor tightens Step 0 - say, to make the prohibition concrete -
and writes: "If either is missing, stop. Where the skill cannot be loaded, degrade gracefully:
carry out the same sequence described below." They run `bash tests/run.sh`, get `654 passed, 0
failed`, and read three green lines stating Step 0 carries no self-substitution fallback. They
commit a second copy of `fable-judge`'s procedure into the skill with a green gate certifying the
opposite. Nothing in the test file or the backlog told them the guard sees only three phrasings.

**Severity: Important** - a test whose label does not verify its claim, per the rubric, with a
concrete false-record scenario. **Not** because detection is incomplete (that is unachievable, and
correctly disclosed in the report), but because the two durable surfaces still assert the complete
claim.

**Remedy, and it converges in one round.** Do not touch marker coverage.

1. Relabel to what is decided, e.g. `"Step 0 does not carry a known self-substitution phrasing
   (marker: '$marker')"`, in both files.
2. One sentence at the end of each comment block: these three markers are a tripwire against the
   phrasings named across rounds 1-2; a fallback worded around them passes, and no content-matching
   assertion can close that - the rule is enforced by review, not by the gate.
3. One line in `docs/dev/backlog.md` under the `[DEP-1]` closure (or as a new open item) recording
   the same, so the limit outlives the phase report.

After that this is finished, and no further round on detection is warranted.

---

## 4. Minor findings

### `[T3-M9]` - `yourself` false-reds on this repository's own compliant prohibition

`tests/test_phase_skill.sh:390`, `tests/test_program_skill.sh:258`. FP1: appending
`gate-chain.md:64`'s own sentence - "Do not invoke `fable:fable-judge` yourself." - to Step 0
gives `653/1`. FP2: a compliant resume instruction ("Once the missing plugin is installed, proceed
by starting a fresh phase session.") gives `653/1` on `proceed by`. Round 1 rated this class inside
its Important finding; it is Minor now only because the failure is loud, prints the offending
marker, and the comment explains the intent. Why it still matters: the cheapest route back to green
is to delete the sentence that strengthened the ruling. Remedy - either drop `yourself` (its
collision with the prohibition is demonstrated in-repo, and `proceed by` plus the sanctioned phrase
already carry the tripwire), or keep it and name the collision in the comment so the next editor
reaches for a reword rather than a deletion.

### `[T3-M10]` - the guard's range is Step 0 only; the gate-3 dispatch site is unguarded

N2: a fully-formed degraded path for `fable:fable-judge` inserted into
`skills/foreman-phase/references/gate-chain.md` section "3. Adversarial verification" - the site
`[DEP-1]` itself names (:64,:73) - leaves the suite at `654/0`. The labels are scoped to "Step 0",
so they do not overclaim about this, and the phase skill loads `gate-chain.md` at the gate rather
than at entry, so the blast radius differs. But if the tripwire is worth having in Step 0, the
dispatch sites are where a fallback would most naturally be written. Recorded for the ledger, not
for this round.

### `[T3-M11]` - `test_templates.sh:257` still calls `EnterWorktree` the phase session's first action

The `[T3-M5]` sweep was real. `grep -rniE "first (step|action|thing|tool call)|before anything|
before doing anything|starts by|begins (by|with)|Step 1a"` over `skills/ agents/ commands/ tests/`
and `POLICY.md` leaves no live claim of primacy for a later action: `foreman-program:10,:56` and
`foreman-init:10` are each skill's own Step 0, `foreman-phase:115` is a scoped "before anything
else in this step", `gate-chain.md:150` is "first check" within gate 6, `milestones.md:21` is about
a handover startup prompt, and `commands/phase.md` names no starting step. One residue survives, in
the same file as the fix: `tests/test_templates.sh:257` - "the tool every phase session's first
action uses (EnterWorktree)". It is a comment above an unrelated `CLAUDE.md.tmpl` assertion, gates
nothing and misleads no session; it is the last instance of the class the controller asked to have
swept. One-word fix ("first tool call").

### `[T3-M12]` - `[T3-M5]`'s positive needle pins the italic markup

`tests/test_program_skill.sh:113-117` matches "kickoff's own first *action* is `foreman-phase` Step
0's dependency check" and "its first *tool call* is `EnterWorktree`". A compliant reword that drops
the emphasis ("the kickoff's first action is the Step 0 dependency check") reddens. Milder than
`[T3-M3]` - the action / tool-call distinction is the load-bearing content, and any positive
assertion must pin some wording - but the asterisks themselves carry no meaning. Low priority.

### `[T3-M13]` - record the closed-world option rather than losing it

Per section 2.2: a snapshot pin or a word budget over the guarded ranges is the only mechanism that
would give a real no-false-negative guarantee within invariant 1, and it trades a different cost
(reddens on every edit). Worth one backlog line next to the `[DEP-1]` closure so a future round
reaches for it instead of a fifth marker.

---

## 5. Closure verdicts on the round-1 findings

| Finding | Verdict | Evidence |
|---|---|---|
| `[T3-M5]` PM told the wrong "first step" | **Closed** | `foreman-program/SKILL.md:178-180` now distinguishes first *action* from first *tool call*; M5r reddens all three assertions. Class swept, with one cosmetic residue - `[T3-M11]` |
| `[T3-M6]` template body claimed primacy for Step 1a's reads | **Closed** | `kickoff.md.tmpl:6` reads "before entering the worktree"; M6r reddens both directions |
| `[T3-M7]` ordering check could not survive a `Step 1` renumbering | **Closed as far as the mechanism allows, and honestly commented** | the boundary anchor `Step N([^0-9A-Za-z]|$)` turns M7b's `first=60 step1a=60` prefix collision into `first=` - a clean empty match; M7a proves the derivation genuinely works for a consistent renumber to `Step 2`. The comment (`test_templates.sh:280-292`) now states the residual `Step 1` collision instead of claiming general renumbering safety |
| `[T3-M8]` vacuous pass on an empty needle | **Closed** | M8: `645/9`, the guard itself red and both downstream claims recorded as explicit failures. Record count verified stable across both branches |
| `[T3-M4]` (Important) fallback guard | **Mechanism improved and F/G fixed; claim and disclosure still open** | section 3, plus `[T3-M9]` for the new false-positive shape |

---

## 6. Invariants

| # | Verdict | Evidence |
|---|---|---|
| 1 - zero runtime deps beyond bash/git/jq | **Pass** | No shipped script added or changed. The new test code uses `grep`, `awk`, `tr`, `cut`, `head`, `sed`, `printf` only - each already in use in these same files before this diff |
| 2 - shebang / `set` line / `chmod +x` | **Pass** | No new file. All three test files are appended to; each still carries `#!/usr/bin/env bash` + `set -uo pipefail`, the exemption invariant 2 grants `tests/test_*.sh`. Behaviour under `-u` without `-e` re-verified in M7b and M8: empty `grep` results route to the `-n` guards and to `fail`, and no file aborted before reporting its counts (passed + failed = 654 in every mutation run) |
| 3 - exit-code contract | **N/A** | No script behaviour touched |
| 4 - absolute paths between tiers | **Pass** | `test_templates.sh:299` derives ground truth through `$FOREMAN_ROOT`, absolute (`run.sh:4`). The changed prose names step numbers, not paths |
| 5 - no TODO/TBD/FIXME | **Pass** | `grep -rnE '\b(TODO|TBD|FIXME)\b' skills/ agents/ commands/ --include='*.md'` returns no match |
| 6 - bare wrapper names | **Pass** | The new prose names no harness script at all. The only `$CLAUDE_PLUGIN_ROOT` / `scripts/` hits in `foreman-phase/SKILL.md` (:44-46,:116,:151,:418-420) are the pre-existing invariant-6 prose itself, untouched by this diff |
| 7 - green, not below baseline | **Pass** | `654 passed, 0 failed` reproduced in the scratch copy; `foreman-baseline --count 654` passes against the recorded 610 (controller-verified), delta +44. `POLICY.md` untouched, as a phase session requires |
| 8 - 100-column wrap in shipped markdown | **Pass** | `awk 'length > 100'` over both `SKILL.md`s, `kickoff.md.tmpl` and `backlog.md` reports only `foreman-phase/SKILL.md:3` (240) and `foreman-program/SKILL.md:3` (302), both exempt `description:` frontmatter scalars. Cosmetic note, not a finding: the `[T3-M5]` reflow leaves `foreman-program/SKILL.md:179` short (~70 cols) to keep `test_program_skill.sh:100`'s anchor on one line; the report explains this, and it is under the limit |

---

## 7. Test quality summary

| New or changed assertion | Fails against the bug it claims? |
|---|---|
| `test_program_skill.sh:111` PM no longer told `EnterWorktree` is first | Yes (M5r) |
| `test_program_skill.sh:113,116` first *action* / first *tool call* present | Yes (M5r); pins italics, `[T3-M12]` |
| `test_templates.sh:266-269` template carries the `EnterWorktree` call | Yes, and the label now matches what it checks (it was the `[T3-M5]` mislabel) |
| `test_templates.sh:299-301` a `## Step N` heading exists to derive from | Yes (M8) - the `[T3-M8]` fix |
| `test_templates.sh:302-311` template names that step, before `Step 1a` | Yes (M7b, and the M8 explicit-fail branch); works for a consistent renumber (M7a); the `Step 1` caveat is now stated in the comment |
| `test_templates.sh:324-327` no "before doing anything else" / has "before entering the worktree" | Yes (M6r) |
| `test_phase_skill.sh:374` / `test_program_skill.sh:244` prohibition, case-insensitive | Yes (round 1's C2), and survives typography (C) |
| `test_phase_skill.sh:391` / `test_program_skill.sh:259` no-self-substitution markers | **Partly** - red on every shape either review named (D), green on six others (N1, N2, the controller's four), and false-red on compliant prose (FP1, FP2). The label overstates; section 3 and `[T3-M9]` |

---

## 8. Deviations declared by the implementer - judged

- **"Residual honesty: not fixed and not fixable by grep"** (`task-3-report.md:394-399`,
  `:544-548`). **Sound, and correctly stated.** It is an accurate description of the mechanism, it
  does not claim closure, and section 2.1 independently confirms the limit is structural rather
  than a tuning failure. The defect is not this deviation; it is that the statement lives only in
  the report while the test label still asserts the class (section 3).
- **`[T3-M7]` "does not lift the Step-1 collision"** (`:472-481`). **Sound**, and verified: M7b
  reproduces round 1's B2 and yields the clean `first=` empty match the report claims, while M7a
  shows the derivation is not merely decorative for other step numbers.
- **`[T3-M5]` broke a pre-existing anchor on the first attempt, and the report says so**
  (`:422-427`). Correct reporting of a step that went wrong, per this repository's own rules. No
  finding.
- **Round-0 deviation on the brief's self-contradictory needle** (`:40-54`) and the **count
  discrepancy** (`:56-65`) - both re-confirmed sound in round 1's review; the arithmetic now reads
  654 and reconciles (section 1).

---

## 9. Cannot verify

- That a live Claude Code session handed a missing plugin actually stops. The check is prose obeyed
  by a model; a bash gate reaches text and position only. Flagged by the implementer in all three
  rounds, correctly.
- That the session's visible skill list uses the `plugin:skill` naming both blocks assume. The brief
  asserts it, and `foreman-program:104` relied on it before this task.
- That no phrasing outside the ten tested shapes is caught or missed by the markers - by section 2.1
  this is not verifiable in principle, only sampled.

## 10. Observation, not a finding

`docs/dev/program/phases/prerequisites/kickoff.md:3` - this phase's own live kickoff - still carries
the old "## First - foreman-phase Step 1a..." header. It is the dispatch record the running session
was given; editing it mid-phase would rewrite instructions already acted on. Correctly left alone;
future phases render the fixed template.
