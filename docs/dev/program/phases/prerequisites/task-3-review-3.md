# Task 3 re-review (fix round 3): `[DEP-1]` dependency check at skill entry

Reviewer: Opus, high effort. Artifact reviewed:
`docs/dev/program/phases/prerequisites/task-3-review-3.diff`, read as given and never
regenerated. Cumulative diff from the task's original base: 7 files, +263 -10.

**Artifact/tree correspondence.** `git diff --stat a03a298 -- docs/dev/backlog.md skills tests`
(read-only) returns exactly the diff file's stat header — the same 7 files with the same
`+263 -10` and the same per-file counts — so the reviewed artifact is the post-image of `HEAD`
(`e50992b`). `git status --porcelain` shows only untracked task-3 markdown artefacts.

**Verdict: Spec ✅ — Quality: Approved.**
Round 2's Important is **closed**. `[T3-M9]`, `[T3-M10]`, `[T3-M11]`, `[T3-M12]` and `[T3-M13]`
are closed or correctly recorded. Two new Minors, both bounded and neither blocking:
`[T3-M14]` (the backlog's range sentence overstates the program-side range by one nesting level)
and `[T3-M15]` (`[T3-M12]`'s emphasis-stripping was applied to the positive needles only, so the
negative one still pins raw markup).

## Method

Every mutation ran against a copy of the worktree in the session scratchpad
(`.../scratchpad/wt`), never against the repository. No tracked file in the repository was
modified, created or deleted; no state-changing `git` command was run (`git show`, `git log`,
`git diff --stat`, `git status` only). After the last mutation both scratch skills were restored
and byte-compared with `cmp -s` (exit 0 for each) — note that this environment's `diff` wrapper
reported "Files are identical" for two files that provably differ (label extracts, `comm -3`
shows the difference), so all equality claims below rest on `cmp`, not on `diff`.

Scratch baseline: `14 files, 654 passed, 0 failed`, matching the controller's own measurement.
Scratch runs were invoked through the real scratch path, not the convenience symlink, because
`test_bin.sh`'s three `foreman-root` assertions legitimately fail under a symlinked root (an
artefact of my harness, not a defect: `foreman-root` resolves symlinks by design).

| # | Mutation | Result | What it proves |
|---|---|---|---|
| A | Round-1/2 mutation D into the phase Step 0: "If the skill is unavailable, proceed by running gate 3 yourself: dispatch a fresh subagent and take its report as the verdict." | `649/5` (3 unrelated symlink artefacts + `marker: 'proceed by running'` + `marker: 'yourself:'`) | the narrowed markers still catch the shape that defeated round 1 |
| B | Round-1 program-side D into `### Dependencies`: "Should the plugin be unavailable, run the interview yourself: ask the spec questions in your own voice and write the plan." | `653/1` (`marker: 'yourself:'`) | the program-side guard still catches its named shape |
| C | A self-substitution one word off the marker: "If the skill is unavailable, proceed by dispatching a fresh subagent yourself and taking its report as the gate verdict." | **`654/0` green** | the disclosed false negative is real and reachable — exactly what the new comment/backlog text says happens |
| D | The same round-1 program fallback, placed inside program Step 0 but **above** `### Dependencies` | **`654/0` green** | the program-side range is the `### Dependencies` subsection, not "Step 0's body" — evidence for `[T3-M14]` |
| E | FP2 on the program side: "Once the missing plugin is installed, proceed by starting a fresh program session." | **`654/0` green** | the round-2 false positive is gone on this side too |
| F | Round-1 mutation E: "If it is not installed, read its rubric from the marketplace cache instead." | `653/1` (`marker: 'read its rubric from'`) | the third marker is live |
| G | `[T3-M12]` compliant reword: strip `*action*`/`*tool call*` italics from `foreman-program/SKILL.md:178-179` | **`654/0` green** | the false red `[T3-M12]` named is gone |
| H | `[T3-M12]` meaning removal: revert to "The kickoff's own first step is `EnterWorktree(name: \"<slug>\")`." | `651/3` — all three `[T3-M5]` assertions red | the emphasis-stripped needles are not vacuous |
| I | Keep the corrected sentences and **add** the contradictory claim in italic form: "The kickoff's own first *step* is `EnterWorktree(name: \"<slug>\")`, so dispatch accordingly." | **`654/0` green** | `[T3-M15]`: the negative assertion still matches raw text |

The controller's own probes (FP1 now green, a compliant stop green, a tuned phrasing red at
`653/1`) are taken as established and were not re-run.

---

## 1. Spec compliance — ✅

The brief's four required edits are present and unregressed by this round:

- `skills/foreman-phase/SKILL.md:13-27` — `## Step 0 — dependencies, before anything else`
  immediately before `## Step 1` (:29); names both skills and both plugins and carries the
  prohibition sentence.
- `skills/foreman-program/SKILL.md:61-72` — `### Dependencies` closing `## Step 0`, immediately
  before `## Then read exactly three things` (:74); names all three skills.
- `tests/test_phase_skill.sh:349-407`, `tests/test_program_skill.sh:216-262` — the brief's
  assertion blocks plus three rounds of review-directed hardening.
- `docs/dev/backlog.md:227` — `[DEP-1]` is `- [x]`, closure at :252-274.

Three files outside the brief's `Files:` list are touched (`kickoff.md.tmpl`,
`tests/test_templates.sh`, `foreman-program/SKILL.md:178-180`); all three were required by
`[T3-M1]`/`[T3-M5]`/`[T3-M6]` and coordinator-directed. None of the five files fenced off for the
distribution-template task appears in the diff. Nothing required is missing; nothing unrequired
is present.

**No assertion was weakened or removed to keep the count level** (the controller's question 5).
Checked three ways, not by the total alone:

1. Primitive counts per file are identical between `62ceed9` (round 2) and `e50992b` (round 3):
   `test_phase_skill.sh` 76 `assert_contains`-family / 10 `assert_not_contains` / 5 `fail` / 3
   `_ok`; `test_program_skill.sh` 39 / 3 / 2 / 1; `test_templates.sh` 25 / 1 / 5 / 2.
2. `comm -3` over the sorted label strings of each file shows only relabels, one-for-one:
   phase `"Step 0 carries no self-substitution fallback"` → `"...does not carry a known
   self-substitution phrasing"`; program the `### Dependencies` twin plus the `[T3-M12]`
   de-italicised label; `test_templates.sh` unchanged (77 labels in, 77 out). No label
   disappeared without a replacement, and no assertion appears twice.
3. Each changed needle was mutation-proved live: markers (A, B, F red), `[T3-M12]` positives and
   negative (H red).

The one deliberate reduction in strength is the marker narrowing, judged in §3.

---

## 2. The Important from round 2 — **closed**

Round 2's finding was a disclosure failure on two durable surfaces: the label asserted the class
("Step 0 carries no self-substitution fallback") while the assertion decides three literal
phrasings, and the residual lived only in the phase report.

**The label.** `tests/test_phase_skill.sh:406` and `tests/test_program_skill.sh:260` now read
`"Step 0 does not carry a known self-substitution phrasing (marker: '$marker')"` and the
`### Dependencies` twin. That sentence is exactly what the assertion decides: a named phrasing is
absent. The word "known" carries the limit into the green line itself, which was the point.

**The comment.** `tests/test_phase_skill.sh:398-404` / `test_program_skill.sh:247-254` close with
a paragraph headed "What this is, stated plainly so the claim below does not outrun it", stating:
a tripwire against the phrasings named across rounds 1-2, not a detector for the class; a
fallback worded around the three phrases passes with a green suite; no content-matching assertion
can close the gap; the rule is enforced by review, not by the gate; and the range is the Step 0 /
`### Dependencies` body only. Mutation C is that paragraph's own claim reproduced: a
self-substitution one word off a marker passes at `654/0`. The disclosure is therefore accurate,
not decorative.

**The ledger.** `docs/dev/backlog.md:260-274` carries the same, in the item a future editor
reads: the polarity argument, the in-repo collision proof (`gate-chain.md:64`), "A
differently-worded fallback passes the gate green", "enforced by review, not mechanically", the
range statement, and the `[T3-M13]` record with its cost.

**Does it now underclaim?** This was the controller's specific question. My answer is no, for
three reasons. (a) The disclosure is bounded to what it disclaims — detection of the *class*;
neither surface says or implies that the assertions are worthless. (b) Each marker keeps a stated
provenance immediately above the loop (`'proceed by running'` = the phrase round 1's defeating
mutations used; `'yourself:'` = the colon-anchored shape every observed fallback takes;
`'read its rubric from'` = a literal copy of the one sanctioned fallback in the repo), which reads
as a regression pin against known-defeating shapes — the correct frame for keeping it. (c) The
comment states positively why the list must *not* be widened, which is an argument for its
current form rather than for its deletion. A reader who deletes the guard after reading this is
acting against what the text says, not on it.

**Verdict: closed.** The mechanism is unchanged and honest, both durable surfaces now state the
limit, and no green line asserts a property the suite cannot decide.

---

## 3. Closure verdicts on round 2's Minors

### `[T3-M9]` — **closed**, and the trade is the one the review offered

`'yourself'` → `'yourself:'` and `'proceed by'` → `'proceed by running'`. Both round-2 false
positives are gone (controller-verified for FP1 on the phase side; mutation E confirms the
symmetric case on the program side). Both markers still catch every shape named across rounds
1-2 that they previously caught: mutation A (phase, both markers) and mutation B (program,
`'yourself:'`) go red; mutation F confirms the third marker is untouched. Round 2's remedy
offered "drop `yourself`, or keep it and name the collision"; narrowing to a colon anchor is
strictly stronger than dropping it, and the collision is *also* named in the comment. Sound.

The cost is real and I measured it: mutation C — "proceed by dispatching a fresh subagent
yourself and taking its report as the gate verdict" — would have been caught by round 2's bare
markers and now passes at `654/0`. This is a deliberate exchange of one false negative for the
removal of a demonstrated false positive, it is exactly what the new disclosure says happens, and
round 2's §2.1 established that a false positive is the worse failure here. Not a finding.

### `[T3-M10]` — **closed** at the tests; imprecise in the ledger (see `[T3-M14]`)

The "state the limit" branch was chosen, not the "extend the range" branch — correct, since
extending the range would be the new detection surface this round was told not to chase. The
statements themselves:

- `test_phase_skill.sh:403-404`: "The range is this file's Step 0 body only: a degraded path
  written at a dispatch site the skill merely points to (for instance `references/gate-chain.md`'s
  gate-3 section) is entirely outside it." Accurate — the extract is `awk` between `## Step 0` and
  `## Step 1`, and mutations A/F (injected at the end of Step 0) redden, so the range is neither
  wider nor narrower than stated.
- `test_program_skill.sh:250-254`: "Scoped to the `### Dependencies` subsection itself, not the
  wider Step 0 extract ... a degraded path written anywhere this skill dispatches to (outside
  `### Dependencies`) is entirely outside this guard's range." Accurate, and mutation D is its
  proof.

Neither test comment implies coverage it lacks. The backlog's compressed restatement does, by one
nesting level — `[T3-M14]`.

### `[T3-M11]` — **closed**; swept independently, no third instance

`tests/test_templates.sh:254-256` now reads "the tool every phase session's first tool call uses
(EnterWorktree, since `[DEP-1]` Step 0's dependency check precedes it)".

I re-ran the class sweep myself rather than trusting the report:
`grep -rniE "first (step|action|thing|tool call)|before anything|before doing anything|starts by|begins (by|with)|Step 1a"` over `skills/ agents/ commands/ tests/` and
`docs/dev/program/POLICY.md`. Every surviving hit is legitimate:
`foreman-init/SKILL.md:3` and `test_init_skill.sh:37` ("before anything lands", about the diff);
`foreman-program/SKILL.md:10` and `foreman-phase/SKILL.md:13` (each skill's own Step 0);
`foreman-program/SKILL.md:139` ("written before anything was built", about requirements);
`foreman-phase/SKILL.md:115` (scoped "before anything else in this step");
`gate-chain.md:150` ("first check", inside gate 6);
`references/milestones.md:21` (a handover startup prompt's "files to read and the first action" —
about a *fresh* session's prompt, not about the phase's first step, so no primacy claim);
`kickoff.md.tmpl:3` (the corrected header); `test_phase_skill.sh:162` ("captured in Step 1a", a
location not an ordering claim); and the `test_templates.sh` / `test_program_skill.sh` comments
that exist to describe the fix. **No live claim of primacy for a later action remains** in any of
the five surfaces the controller named.

### `[T3-M12]` — **closed** in both directions; one asymmetry left (`[T3-M15]`)

Mutation G (drop the italics from the shipped sentence) is green — the false red is gone.
Mutation H (revert to the round-2 bug wording) reddens all three assertions, so the stripped
needles still track meaning. The implementer declared not re-running the meaning-removal
direction after the change ("already covered by round 2"); that skip was correctly declared, and
I ran it: the claim holds. The residual is that only the positives were de-italicised —
`[T3-M15]`.

### `[T3-M13]` — **recorded, not implemented**; confirmed

`docs/dev/backlog.md:269-274` names the snapshot pin and the word-count budget, states the cost
(reddens on any edit to the range, including a compliant reword), and says "Left unimplemented: a
policy choice for a future round, not this task's." Nobody implemented it: `grep -rn "wc -w"
tests/` returns nothing, no `tests/fixtures/` directory exists, and the only `fixture` hits in
`tests/` are pre-existing and unrelated (`test_bin.sh`'s runner-in-a-fixture-directory harness,
`test_phase_state.sh:317`). The suite total is unchanged at 654, which is consistent with no new
mechanism.

---

## 4. New findings from this round

### Minor `[T3-M14]` — the backlog's range sentence overstates the program-side range

**Location.** `docs/dev/backlog.md:267-269`: "The rule is enforced by review, not mechanically,
and **the guard's range is each skill's Step 0 body only** — a degraded path written at a dispatch
site such as `gate-chain.md`'s gate-3 section is outside it."

**Why it is wrong.** For `foreman-phase` that is exact. For `foreman-program` the guard is scoped
to the `### Dependencies` subsection, not to Step 0's body: `test_program_skill.sh:255-257`
extracts `deps_body` from `^### Dependencies` to `## Then read exactly three things`. Mutation D
proves the gap — the round-1 program-side fallback ("Should a plugin be unavailable, run the
interview yourself: ask the spec questions in your own voice.") placed inside `## Step 0` but
above `### Dependencies` leaves the suite at `654/0`, where the same sentence one heading lower
reddens (mutation B).

**Failure scenario.** A future editor consults the ledger (the surface round 2 said matters),
reads that the whole of each skill's Step 0 is tripwired, adds a degraded path to
`foreman-program`'s refusal-gate prose rather than to `### Dependencies`, sees green, and believes
the known-phrasing tripwire looked at it. It did not.

**Why Minor, not Important.** The direction of the error is a small over-, not under-, statement
of coverage, in the one surface where the same paragraph immediately afterwards names the real
program-side range ("compare the normalised Step 0 / `### Dependencies` body against a stored
fixture", :271-272), and the test comment that a Step-0 editor actually reads is exact. The
natural site for a plugin fallback is `### Dependencies` itself, which *is* guarded. Fix is four
words: "each skill's Step 0 / `### Dependencies` body only".

### Minor `[T3-M15]` — `[T3-M12]` de-italicised the positive needles but not the negative one

**Location.** `tests/test_program_skill.sh:115-122`. `skillf_noemph` is used for the two
`assert_contains` needles; the `assert_not_contains` on line 116 still matches the **raw**
`$skillf` for `"kickoff's own first step is \`EnterWorktree"`.

**Failure scenario.** Mutation I: keep both corrected sentences and add, three lines below, "The
kickoff's own first *step* is `EnterWorktree(name: \"<slug>\")`, so dispatch accordingly." Result
`654/0`. The italicised `*step*` defeats the raw needle while the two positives still pass, so the
file ships two contradictory primacy claims — the `[T3-M1]`/`[T3-M5]` defect restored, with a
green gate. The italic form is not contrived: the sentence two lines above uses `*action*` and
`*tool call*`, so an editor writing in this file's own style would plausibly italicise `*step*`.

**Why Minor.** The label already self-limits with "(unqualified)", the underlying defect is a
prose contradiction rather than a broken script (round 1 rated the parent finding `[T3-M5]`
Minor), and the positives keep the correct sentence pinned, so the wrong claim can only be *added*
alongside the right one, never silently substituted. Fix is one word: match the negative against
`$skillf_noemph` too — the needle does not occur in the stripped compliant text, so no false red
is introduced.

---

## 5. Invariants

| # | Verdict | Evidence |
|---|---|---|
| 1 — zero runtime deps beyond bash/git/jq | **Pass** | No shipped script added or changed in the cumulative diff (7 files: 1 backlog, 1 template `.md.tmpl`, 2 `SKILL.md`, 3 `tests/*.sh`). New test code uses `grep`, `awk`, `tr`, `cut`, `head`, `sed`, `printf` only, each already used in these same files before the diff. Round 3 added only `tr -d '*'`. |
| 2 — shebang / `set` line / `chmod +x` | **Pass** | No new file. `tests/test_phase_skill.sh`, `tests/test_program_skill.sh`, `tests/test_templates.sh` each still open `#!/usr/bin/env bash` + `set -uo pipefail` (the exemption invariant 2 grants `tests/test_*.sh`) and are mode 775. Behaviour under `-u` without `-e` re-exercised in every mutation above: `passed + failed` totalled 654 in each run, so no file aborted before reporting. |
| 3 — exit-code contract | **N/A** | No script behaviour touched; `scripts/` and `bin/` are absent from the diff. |
| 4 — absolute paths between tiers | **Pass** | `test_templates.sh:299` derives ground truth through `$FOREMAN_ROOT` (absolute, `run.sh:4`). The new skill prose names step numbers and `plugin:skill` names, no paths. |
| 5 — no TODO/TBD/FIXME | **Pass** | `grep -rnE '\b(TODO\|TBD\|FIXME)\b' skills/ agents/ commands/ --include='*.md'` returns nothing. |
| 6 — bare wrapper names | **Pass** | The new prose invokes no harness script; no path-form or `$CLAUDE_PLUGIN_ROOT`-prefixed call site is added anywhere in the diff. |
| 7 — green, not below baseline | **Pass** | `654 passed, 0 failed` reproduced independently in the scratch copy; controller-verified `foreman-baseline --count 654` against the recorded 610, delta +44. `POLICY.md` untouched. |
| 8 — 100-column wrap in shipped markdown | **Pass** | `awk 'length > 100 {print FILENAME":"FNR}'` over `foreman-phase/SKILL.md`, `foreman-program/SKILL.md`, `kickoff.md.tmpl` and `docs/dev/backlog.md` reports only the two `description:` frontmatter scalars (`:3` in each SKILL.md, 240 and 302 columns), both exempt. The over-100 lines in `tests/*.sh` are bash, not markdown, and all pre-existing. (Note for the record: round 2's report cited these as `SKILL.md:428` — that was `awk`'s cumulative `NR`, not `FNR`; the lines are :3 in both files.) |

---

## 6. Test-quality summary for this round's changes

| Changed assertion | Fails against the bug it claims? |
|---|---|
| `test_phase_skill.sh:406` known-phrasing markers (relabelled, narrowed) | **Yes for what it now claims.** Red on every shape named across rounds 1-2 (A, F); green on a phrasing one word off (C), which the label and comment now both say. The label no longer asserts the class. |
| `test_program_skill.sh:260` same, scoped to `### Dependencies` | **Yes** (B red, E green as intended). Range accurately stated in the comment; over-stated in the backlog only (`[T3-M14]`). |
| `test_program_skill.sh:118-122` `[T3-M12]` positives, emphasis-stripped | **Yes** — H reddens both; G no longer false-reds. Not vacuous. |
| `test_program_skill.sh:116` `[T3-M5]` negative, raw text | **Partly** — reddens on the unqualified revert (H) but not on the italicised reintroduction (I). `[T3-M15]`. |
| `test_templates.sh:254-256` comment reword | Comment only, no assertion; the assertion below it is unchanged and was already mutation-verified in round 2. |

## 7. Deviations declared by the implementer — judged

- **"Detection coverage is formally closed as unachievable; this round does not widen markers"**
  (`task-3-report.md:565-590`). **Sound.** It restates round 2's §2 accurately and is the basis on
  which I judge the Important closed rather than re-opened.
- **`[T3-M9]` narrowing trades a false negative for two removed false positives**
  (`:620-656`). **Sound**, and independently reproduced (A, B, E, F). The report's claim that the
  narrowed markers "still catch every fallback shape named across rounds 1-2" is true as stated: the
  shapes previously caught (round 1 D on both sides, round 1 E, round 2 D) all still redden; the
  shapes previously missed (round 2's N1, N2) were never caught and are still not, which the
  disclosure now says.
- **`[T3-M10]` "stated the range rather than extending it"** (`:658-670`). **Sound** for the two
  test comments. The ledger restatement is imprecise — `[T3-M14]`.
- **`[T3-M12]` meaning-removal direction "not re-run"** (`:694-697`). **Declared, and the claim
  holds** — mutation H reddens all three assertions. Correctly reported as a skip rather than
  presented as verified; I closed it myself.
- **`[T3-M11]` "a comment, nothing to mutation-check"** (`:674`). **Sound**, and the sweep the
  report says it re-ran, I re-ran independently with the same result.
- **`[T3-M13]` recorded, not implemented** (`:699-707`). **Sound**, and confirmed unimplemented.
- **Report's own accounting**: "654 — adds no new assertions and removes none". **Verified three
  ways** (§1). Accurate.

## 8. Cannot verify

- ⚠️ That a live Claude Code session handed a missing plugin actually stops and does not
  improvise. The check is prose obeyed by a model; a bash gate reaches text and position only.
  Correctly flagged by the implementer in all four rounds.
- ⚠️ That the session's visible skill list uses the `plugin:skill` naming both blocks assume. The
  brief asserts it; `foreman-program:104` relied on it before this task.
- ⚠️ That the narrowed markers do not collide with some other compliant sentence not yet written.
  By round 2's §2.1 this is unverifiable in principle, only sampled; I sampled two (mutations D
  and E on the compliant side, both green).

## 9. Observations, not findings

- `tests/test_templates.sh:277-280` still contains the round-1 sentence "means this goes red again
  if the skill's first step is ever renumbered" and then corrects it at :281-292 with the
  `[T3-M7]` paragraph, rather than fixing the sentence. Round 2 accepted this shape; a reader who
  stops after the first paragraph is briefly misled. Pre-existing, out of this round's scope.
- No test enforces invariant 8's 100-column wrap on shipped markdown; mutation G left a 150-column
  line in `foreman-program/SKILL.md` and the suite stayed green. That is a harness-wide gap, not
  this task's, and it is not claimed anywhere to be mechanical.
- `docs/dev/program/phases/prerequisites/kickoff.md:3` — this phase's own live kickoff — still
  carries the pre-`[DEP-1]` "Step 1a" header. Round 2 judged this correctly left alone (it is the
  dispatch record already acted on); future phases render the fixed template. Unchanged, still
  correct.
- An extra untracked artefact, `docs/dev/program/phases/prerequisites/task-3-review.md`, sits
  beside the numbered review files. Untracked, outside the diff, no action.
