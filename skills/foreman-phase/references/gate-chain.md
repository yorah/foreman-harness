# The gate chain

Run in order, after the last task's ledger entry is committed. Each gate is cheap relative to
the thing it protects, and they fail differently — a clean earlier gate is not a reason to skip
a later one.

## 1. Gate commands

Every command in `POLICY.md`'s gate table, in its stated order, all green. "Green" means each
command's own documented success signal — for `bash tests/run.sh` specifically, **exit 0**. The
exit code is authoritative and the summary line is not: the runner also gates on `POLICY.md`'s
recorded baseline *after* printing the summary, so a run below the baseline prints
`<N> files, <M> passed, 0 failed` and then fails, and the last line you see is the baseline
failure rather than the count. A run that shows `0 failed` has not necessarily passed.

Within a run that does exit 0, `0 failed` is sufficient on its own: the runner folds an aborted
or assertion-free test file into that failure count, so you do not need to separately audit for a
file that quietly aborted mid-run.

Paste the actual output into the ledger, including the test counts. A claim of green without
the count is not evidence. Commit the ledger now — gate 6 rebases and merges what is on the
branch, not what exists only in your working tree.

Then check the branch's own observed count against the baseline — not the per-task numbers
from Step 4, each of which only ever proved one task at a time:

```bash
foreman-baseline \
  --policy <abs-policy> --count <observed-branch-count>
```

**Exit 0:** proceed to gate 2. **Exit 1:** the branch itself is below baseline — stop here, do
not proceed to gate 2, and return to Step 4 to find and fix what regressed. **Exit 2:** the
baseline could not be established, for whatever reason the script's own stderr names — do not
infer which; the action is the same across every cause the script has. Stop and escalate; this
is a repo-level defect this phase cannot resolve on its own.

## 2. Whole-branch review

```bash
git diff origin/<default>...HEAD > <abs-phase-dir>/branch-review.diff
```

Dispatch `foreman-branch-reviewer` (Opus, high effort, always) with that file, the plan
directory, the spec path, the numbered invariants, and its findings-file path —
`<abs-phase-dir>/branch-review.md`; its contract requires one, exactly like the task
reviewer's. It looks for what the per-task reviews structurally could not see: cross-task
incoherence, interface drift, invariant erosion, and scope nobody asked for.

It returns `GO` or `NO-GO`, stated first.

- **`GO`:** proceed to gate 3.
- **`NO-GO`:** findings get **one** fix dispatch and one scoped re-review, against a
  regenerated diff and a new findings path, `<abs-phase-dir>/branch-review-2.md`. If that
  re-review returns `GO`, proceed. If it returns `NO-GO` again, adjudicate every residual
  finding yourself and ledger each ruling — but adjudicating is not automatically a pass: the
  ruling must say why that specific residual is safe to proceed past, not merely that it was
  looked at. If you cannot make that case for every open finding, commit the ledger now — the
  only halt in this chain that otherwise had no stated commit point — and stop. This is the
  last structural check the branch gets before merge.

## 3. Adversarial verification

Dispatch a fresh subagent (Opus, high effort) — do not invoke `fable:fable-judge` yourself.
This is the heaviest verification in the chain: it re-runs every claimed verification and
diffs actual change against claimed change, and that whole process, not just its outcome,
would otherwise land in your own context at the point that context is fullest. Its output is
small (a verdict, a few caveat lines, a path); its process is large. That asymmetry is exactly
what a subagent dispatch is for.

Give it four things: the branch name, the merge base (`origin/<default>`), the phase directory
(`<abs-phase-dir>`), and its findings-file path — `<abs-phase-dir>/branch-judge.md`. Instruct
it to invoke `fable:fable-judge` on the branch, write its complete findings to that path, and
return **only**:

- the verdict: `VERIFIED`, `VERIFIED WITH CAVEATS`, or `REFUTED`
- one line per caveat, or `none`
- the absolute path of its findings file, last

There is no dedicated agent definition for this dispatch, unlike the implementer and the two
reviewers — state this contract directly in the dispatch prompt, not as a reference to an
agent file that does not exist. (A named agent would be more consistent with the rest of this
skill. That is a design note for whoever next revises this file, not a Minor from this
phase's own work — it does not belong in `backlog.md` under gate 4, which is reserved for
what the reviews found in the branch under review.)

It treats "done" as a set of claims: it re-runs the claimed verifications, diffs what actually
changed against what was said to change, and hunts weakened tests and false completion claims.
The branch reviewer grades a diff; the judge checks whether the verification actually
happened. That is why both run.

Record the verdict itself in the ledger, whichever of the three it is — Step 6's summary
reports "gate results," and this gate's result is the verdict, not only its caveats:

- **`REFUTED`:** stops the merge.
- **`VERIFIED WITH CAVEATS`:** proceeds only if every caveat is recorded in the ledger, and any
  caveat that outlives the branch reaches `backlog.md`.
- **`VERIFIED`:** proceeds; record it and move on, there is nothing further this gate asks of
  you.

Commit the ledger now, whichever verdict it was.

## 4. Backlog flush — blocking

Every Minor the reviews deferred rather than fixed must appear in `docs/dev/backlog.md`,
tagged with its source (`[TN-MK]`), before this phase can finish. One line each, saying why it
was deferred and what it needs.

**You may not finish while the ledger names a deferred item absent from the backlog.** A
deferred item nobody wrote down is a forgotten one.

Commit `docs/dev/backlog.md` and the ledger now — a blocking gate whose output exists only in
your working tree has not actually been passed.

## 5. Context distillation — blocking

Anything learned in this phase that outlives the plan goes into `docs/dev/CONTEXT.md`: a
measured fact, a gotcha, a ruling that will constrain future work, a technique that worked.

Git history is the record of what changed. `CONTEXT.md` is the record of what was learned.
Nothing else preserves the second.

**This gate fails if you have written nothing here and recorded no ruling that nothing
durable applied.** Add at least one `CONTEXT.md` entry, or write, verbatim, in the ledger:
`Ruling: nothing in this phase outlived the plan — <why>.` A blank check is not a pass.

Commit `docs/dev/CONTEXT.md` and the ledger now, for the same reason gate 4 does.

If a ruling is durable enough to constrain future phases, promote it to
`docs/dev/program/RULINGS.md` and say so in your report so the PM sees it.

## 6. Integration

Everything above must already be committed — gates 1, 3, 4 and 5 each say so as you pass
them. If any was skipped, commit `<abs-phase-dir>`, `docs/dev/backlog.md` and
`docs/dev/CONTEXT.md` now: this gate rebases and merges what is on the branch.

```bash
git -C <worktree> fetch origin
git -C <worktree> rebase origin/<default>
```

This rebases the phase branch, in `<worktree>` — not `<main-checkout>`, which still has
`<default>` checked out and is not touched until the merge below. Then **re-run gate 1 in full
on the rebased tree**. This is the load-bearing step: a branch that was green before a rebase
proves nothing about the tree after it. A clean textual merge routinely hides a semantic
conflict, and with several people pushing that is the common case, not the exotic one.

Only then, and from `<main-checkout>` — the directory you recorded before ever entering the
worktree, in Step 1a, not from the worktree itself: first check whether this phase touched a
declared trust boundary, or whether `POLICY.md` otherwise says so. If it did, escalate to a
pull request instead of a direct merge — push the branch and open the PR with the gate
evidence in its body, and stop here; do not run the merge commands below.

Otherwise:

```bash
git -C <main-checkout> fetch origin
git -C <main-checkout> checkout <default>
git -C <main-checkout> merge --ff-only <branch>
git -C <main-checkout> push origin <default>
```

`git checkout <default>` fails from inside the worktree: git refuses to have the same branch
checked out in two working trees of one repository at once, and `<default>` is already checked
out in the main checkout — the ordinary case, since that is where the human ran `/phase` from.
`<main-checkout>` and `<branch>` are exactly the two facts Step 1 asked you to capture before
any of this started; this is where they get spent.

Never force-push.

## 7. Close

`superpowers:finishing-a-development-branch`. Because Step 4.6 commits the ledger, the briefs,
the reports and every review file with each task — not only at the very end — they are tracked
and travel with the merge, and nothing needs rescuing from scratch before the worktree goes.
