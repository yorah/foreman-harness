# Standing context for foreman-harness

Facts and rules that outlive any one plan: measured values, environment quirks, gotchas found
the hard way, and deliberate deferrals with their reasons.

Git history is the record of what changed. **This file is the record of what was learned.**
Before a phase closes, anything it learned that outlives its plan is written here — that is a
blocking gate, not a courtesy.

Date every entry. Convert relative dates to absolute.

---

## Spec §15 verification — 2026-08-31

Run against `1c93ce3`/`597c565` on `feat/harness-v1`, as task 10's dogfood. Measured, not
asserted: each check below was run and its output read.

**§15.2 — the gate refuses.** A scratch repository pinned to `effortLevel: "medium"`, model
`claude-opus-5`:

```
{"verdict":"refuse","effort":"medium",
 "effort_source":"<scratch>/.claude/settings.json",
 "reason":"effort 'medium' is below high"}      exit=1
```

The control at `high` returns `"verdict":"pass"`, exit 0. Both directions, so the refusal is
the gate's judgement and not its only behaviour.

**§15.3 — the baseline check rejects.** Against this repository's own `POLICY.md`:

```
--count 0    -> {"verdict":"below","baseline":556,"count":0,"delta":-556}   exit=1
--count 556  -> {"verdict":"pass","delta":0}                                exit=0
```

**§15.4 — reviewer return size.** Not measurable here: it compares a reviewer's returned
message against the review file it wrote, and needs a live phase. Owed, and recorded in
`backlog.md`.

**§15.6 — `fable-judge` catches a planted weakened test. It did: REFUTED.** A canary branch
weakened `tests/test_baseline_check.sh:16` from
`assert_eq "pass" "$(run 819 | jq -r .verdict)"` to `assert_eq "x" "x"`, keeping the original
label. **The suite stayed at 556 passed, 0 failed** — which is the entire point: a weakened
assertion is invisible to the gate that is supposed to protect it.

The proof was taken in both directions rather than by reading the diff. `baseline-check.sh` was
sabotaged so every verdict is wrong, and the same suite run twice:

| assertion | sabotaged system under test |
|---|---|
| weakened (`"x"` vs `"x"`) | **silent** — no failure |
| original | `FAIL: equal to baseline passes: expected [pass], got [WRONG]` |

**A note on how that measurement was nearly wrong**, because it generalises: the first attempt
grepped `'equal to baseline passes'` and reported the weakened assertion as firing. It was not
— `tests/test_baseline_check.sh:139` carries a *second* assertion labelled `sweep: equal to
baseline passes`, and the unanchored pattern matched that instead. Anchoring to
`FAIL: equal to baseline passes` gave the honest answer. **A label that is a prefix of another
label is not a unique anchor**, and this is the same defect class as a self-satisfied assertion,
one level up: the measurement, not the thing measured, was what failed.

## What this branch learned that the code does not show

- **The mutation audit is the branch's central control**, and it works only as the *last* action
  before a commit. Nine self-satisfied assertions were found on v1; two were written by the
  controller, so seniority is no defence. When the audit causes any edit it is void and restarts.
- **Verify both directions of any behavioural claim.** "If X is broken you will see Y" is
  worthless until Y is confirmed absent when X works. One such claim shipped and was retracted.
- **A defect that is invisible from inside the repository needs a different kind of check.**
  `$CLAUDE_PLUGIN_ROOT` was enforced by guard assertions across five tasks and does not resolve
  in the Bash tool at all; the unqualified form also works *here*, so nothing written from
  inside this repository could tell a working call site from a broken one. Only installing the
  plugin and running it found that. Keep the dogfood.
- **A question whose answer is silently discarded is worse than no question.** The generated
  interview asked five things generation had no branch for, including a standing-authorization
  grant `foreman-program` explicitly reads.
- **Prose that bends around an assertion means the assertion is wrong**, not the prose.
- **A test cannot report a failure using the mechanism it is testing.** `lib_assert.sh` scores
  every assertion in this suite and was itself asserted against by nothing, so changing `_bad`
  to append a `P` left the run at "570 passed, 0 failed", rc=0. The first fix was written with
  `assert_eq` and failed identically: it detected the mutation, printed seven `FAIL` lines, and
  still finished green, because the broken scorer counted its own detections as passes. A
  self-test must escape to something the subject cannot influence — here a hard `exit 1`, which
  `run.sh` records as "aborted before reporting counts" whatever the library claims.
- **Escalate the reviewer for anything a live session reads as instructions.** Skills and
  templates are not data. The one v1 task scheduled with a Sonnet reviewer needed four rounds,
  and its defects were cross-file semantic contradictions invisible from inside the file.

## Phase A (`prerequisites`) — 2026-09-03

### Spec §12.11 / §15.4 — the reviewer return-size ratio, measured

Carried from the 2026-08-28 spec §15.4 and due during the first phase of this program. The claim
under test: a verdicts-only return contract keeps the controller's context small while the
reviewer's real analysis lands on disk.

Findings files written by the eleven reviewers and the judge, measured exactly:

| File | Bytes |
|---|---|
| `branch-review.md` | 68,012 |
| `task-1-review.md` / `-1` | 22,101 / 26,600 |
| `task-2-review.md` / `-1` | 19,151 / 25,682 |
| `task-3-review.md` / `-1` / `-2` / `-3` | 15,897 / 23,080 / 25,467 / 24,568 |
| `task-4-review.md` / `-1` | 22,893 / 25,957 |
| `branch-judge.md` | 18,157 |
| **total** | **317,565** |

The corresponding return blocks, read from this session's transcript, total roughly **12 KB** —
they run from about 400 bytes (a verdict pair plus three Minor labels) to about 1.9 KB (the branch
review's `GO` with thirteen findings). Aggregate ratio ≈ **1:26**, i.e. the controller absorbed
under 4% of what the reviewers actually wrote.

Read that as an order of magnitude, not a measurement to three figures: the file sizes are exact,
the return sizes are counted from transcript text and include the harness's own framing. The
contract holds, and holds by a wide margin — 300 KB of analysis would have consumed most of a
controller's usable context, and none of it was needed to decide what to do next. What the
controller did need, repeatedly, was a *path*: every ruling in the phase ledger was written from a
verdict line plus a targeted read of one section of one findings file.

### What this phase learned that the code does not show

- **Substring matching is polarity-blind, so a rule about prose cannot be enforced mechanically
  by grep.** The same vocabulary marks a violation, a prohibition of that violation, and a
  compliant instruction. Proved from both ends on `[DEP-1]`: the repository's own compliant
  sentence ("do not invoke `fable:fable-judge` yourself"), pasted into the guarded range, reddened
  the suite — while four plainly-worded fallbacks ("continue without it and apply the equivalent
  steps", "degrade gracefully", "improvise a substitute", "best-effort attempt instead of
  halting") all passed green. Widening the markers trades false negatives for false positives, and
  the false positives are worse: they train the next editor to delete the prose that states the
  rule. Where this bites, the honest move is a tripwire against known shapes with its limit
  written down — and the closed-world alternative (snapshot pin or word budget) recorded as the
  design choice it is.
- **A guard's label must not outrun the guard.** Three separate instances in one phase
  (`[T3-M4]`, `[T3-M10]`, `[T4R1-M1]`). An overclaiming guard is worse than no guard, because the
  next person trusts it. The opposite failure is real too and arrived one round after the first
  was fixed (`[BR-7]`): a disclosure that states its limit four times and its value once makes
  deletion look free.
- **Adding a step to a skill falsifies every other file's claim about what comes first.** Task 3's
  Step 0 broke that claim in five places across four rounds, and the last one found was the
  phase's own kickoff — the single file that authoritatively states what a phase does first, and
  the one nobody thought of as stating it. Assertions covered the *template*; nothing covered a
  *rendered* kickoff, so it shipped green.
- **Verify that a hostile environment is actually hostile before believing a green run under it.**
  The 12 signing failures this phase was convened to fix never occur ambiently on this machine, so
  the fix had to be demonstrated against a constructed global config — and the construction was
  only worth anything because a bare `git commit` was checked to fail under it first. A green run
  in an environment that turns out to be benign proves nothing and looks identical.
- **A token-reducing proxy on `git` silently abridges redirected output.** `git diff > file`
  under such a hook writes a *summary* — stat lines and a `... (N lines truncated)` footer — not
  the diff. 250 lines were withheld across ten review packages before anyone noticed, and the one
  reviewer who did notice compensated for the 9 lines its marker disclosed rather than the 73
  actually missing. Any artefact produced by redirecting a proxied command should be checked for
  a truncation marker before it is handed to something that will treat it as complete.
- **An assertion can pass vacuously, and a brief can ship one.** Task 4's `trust` needle was green
  against the *old* template, satisfied by an unrelated bullet containing the word — a needle
  green before the fix is not a test of the fix. `[T3-M8]` was the same shape: an assertion that
  passed when its input was empty. Watch for the needle that never had to fail.
- **A brief's absolute counts go stale; its deltas stay exact.** Briefs are generated before
  earlier tasks' fix rounds land, so every task from 2 onward met a predicted total that was
  wrong while its `+N` was right. Trust `foreman-baseline` against `POLICY.md`, never a brief's
  arithmetic. Task 4's brief was wrong twice over — stale base *and* a miscount, because deleting
  a template silently removes an assertion from a per-file loop.
- **When a dispatch dies mid-work, the tree is evidence, not garbage.** Two 529s left task 4's fix
  round staged and uncommitted. The recovery that worked: establish the gate, check the diff is a
  *complete* subset of the round's findings (arithmetic corroborated it exactly), run the mutation
  checks the dead agent never reached, then commit with the interruption recorded — and have the
  next reviewer re-derive every one of those claims, because the agent that judged the work
  coherent was the agent that committed it.
