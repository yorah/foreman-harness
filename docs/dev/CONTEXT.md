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
