---
name: foreman-phase
description: Execute one harness phase — enter a worktree, run a plan task-by-task through implementer and reviewer subagents, run the gate chain, and merge. Use when handed a kickoff file by a program manager, or when the user says /phase.
---

# Phase controller

You execute **one plan**. You do not re-plan the program, and you do not decide what the next
phase should be — that is the program manager's job.

Announce: "Running phase `<slug>` from `<kickoff path>`."

## Step 1 — capture identity, enter the worktree, baseline the tree

Do these three things in order, before any implementer touches anything.

### 1a. Record where you started

From the main checkout — the directory `/phase` was invoked from, not a worktree — record:

- `<main-checkout>`: its absolute path (`git rev-parse --show-toplevel`).
- `<default>`: the default branch name. `git symbolic-ref refs/remotes/origin/HEAD` gives
  `refs/remotes/origin/<default>`; strip the prefix. If that is unset, `git remote show
  origin` reports it under `HEAD branch:`. If neither resolves, the kickoff or `POLICY.md`
  names it — use that rather than guessing `main`.
- The harness's scripts: invoked by **bare name** (`foreman-gate`, `foreman-brief`,
  `foreman-baseline`, `foreman-state`), never by a path. Claude Code puts the plugin's `bin/`
  on `PATH`. `$CLAUDE_PLUGIN_ROOT` is **not** exported into the Bash tool's environment, so
  `$CLAUDE_PLUGIN_ROOT/scripts/...` expands to `/scripts/...` and fails; a bare relative
  `scripts/...` is worse still, because it resolves against the target repo in exactly the
  repositories where the harness was developed. `$(foreman-root)` prints the plugin root for
  the things that must be read rather than run.

`<main-checkout>` and `<default>` are spent at gate 6, at the end of the phase. Losing them
now means reconstructing them later from inside a worktree, where the git operation you would
use to do that (`git checkout <default>`) is exactly the one that no longer works there — see
gate 6.

### 1b. Enter the worktree

```
EnterWorktree(name: "<phase-slug>")
```

This creates `.claude/worktrees/<phase-slug>` and branches from `origin/<default>` under
`worktree.baseRef: fresh`, which is the correct base when other people are pushing.

If the `name:` form is unavailable, create the worktree yourself and register it:

```bash
git worktree add .claude/worktrees/<slug> -b <branch> origin/<default>
```
then `EnterWorktree(path: "<abs path>")` to register the worktree you just created. If the
`path:` form is also unavailable too, skip registration and track `<abs path>` yourself for
every dispatch from here on — the fallback is for when the tool cannot manage a worktree it is
handed, not for when it cannot be reached at all.

Record `<worktree>`, the absolute path. `<branch>` is **given to you by the kickoff**, not
discovered: the program manager chose it and already wrote it into `STATE.md`, which is how a
running phase's ledger is found at all. Confirm the worktree is on it
(`git -C <worktree> branch --show-current`) and rename if it is not
(`git -C <worktree> branch -m <branch>`); do not adopt whatever name the tool happened to pick
and report that back instead. If the kickoff names no branch, ask before proceeding — a phase
whose branch nobody agreed on cannot be read mid-flight. Every
dispatch you make from here uses `<worktree>`; `<branch>` goes into the ledger (Step 3) and
your closing report (Step 6) — the program manager's `foreman-state` resolves this
phase by that name, and a ledger committed under a branch nobody wrote down is unreadable no
matter how correct it is.

### 1c. Baseline the tree you inherited

Read `POLICY.md` now — at `<abs-policy>` = `<worktree>/docs/dev/program/POLICY.md`, absolute.
Step 2 reads the rest of your inputs, but the gate table and the baseline live here and you
need them immediately. Run every command in the gate table, here, against the fresh worktree,
before dispatching anything:

- **Green already:** record the observed count and `git -C <worktree> rev-parse HEAD` — this
  pair becomes the ledger's `baseline: <N> at <sha>` line in Step 3. It is the phase's own
  evidence for what it inherited, not a value copied from the plan's claims about it.
- **Not green:** stop. A red inherited tree means the *first* implementer's honest work fails a
  gate it did not cause, `baseline-check.sh` reports it as below baseline, and Step 4's rule
  ("reject the task and send it back") rejects correct work — repeatedly, and for a reason
  invisible to whoever reads the ledger later. Report the failure and the observed output; do
  not open the ledger over a tree you already know is red.

## Step 2 — read the rest

The kickoff file, the plan's `README.md`, and the spec section the kickoff names.
`<abs-plan-dir>` means `<worktree>/docs/dev/plans/<slug>/`, absolute, for the rest of this
skill. **Never read the plan's task bodies yourself** — that is what briefs are for, and
reading them is how a controller's context fills before the plan is half done.

From `POLICY.md` (already read, in Step 1c) also take: the trust boundaries and the numbered
invariants. The invariants are injected verbatim into every dispatch.

## Step 3 — open the ledger

`<abs-phase-dir>` means `<worktree>/docs/dev/program/phases/<slug>/` for the rest of this
skill and for `references/gate-chain.md`. Create it (`mkdir -p`) before anything else in this
step — `scripts/task-brief.sh` refuses outright if it does not already exist when Step 4 calls
it, and nothing else in this program creates it for you.

Write `state.md` inside it, starting with the machine-readable head:

```yaml
---
phase: <slug>
plan: docs/dev/plans/<slug>/
branch: <branch>
baseline: <N> at <sha>
tasks:
  - {n: 1, model: sonnet, effort: medium, status: pending, commits: "", verdict: "", minors: []}
---
```

`baseline` is the pair you recorded in Step 1c, not a value you look up separately. Populate
`tasks:` with one entry per task the plan's README names, every one starting `status:
pending` — this gives the PM a live view of the whole phase from the first commit, not only
of tasks you have already touched. `status` moves through `pending` (here) → `in-progress`
(Step 4, when you start a task) → `passed` (Step 4.6, the ordinary close), or one of three
other outcomes: `unverified` when the baseline cannot be established (item 3's Exit 2);
`deferred` when the fix loop's breaker parks only Minors (item 5); `blocked` at any of several
stop-conditions — a plan defect with no path forward (item 1), an unresolvable invariant
conflict (item 2), a capped reject loop tripping either at the task level or inside a fix
round (item 3), the fix loop's own breaker on an unresolved Critical or Important (item 5), or
a dead subagent's destructive-operation stop-condition (Failure protocols). Every value is
assigned somewhere in Step 4, never left for you to invent a use for, and **no path may commit
a halt while `status` still reads `in-progress`** — assign the real value first, always.
`verdict` is the task reviewer's final `Spec`/`Quality` pair, or `adjudicated` if the
fix-loop breaker tripped (Step 4.5).

Then the prose: resolved design forks from the kickoff, and a section per task as you go.
Commit it, together with everything else `<abs-phase-dir>` holds (Step 4.6 says exactly what
and when). Update and commit after every task — the PM reads it off your branch with
`scripts/phase-state.sh`, so an uncommitted ledger is an invisible one.

## Step 4 — per task

For each task, in the plan's order unless a dependency forces reordering (Failure protocols
covers that): set this task's ledger `status` to `in-progress` and commit `<abs-phase-dir>` —
this is what lets the PM tell a task in flight from one that has not started. Then:

1. **Generate the brief.** Never hand-write one, and never reuse one:

   ```bash
   foreman-brief --plan <abs-plan-dir> --task N \
     --phase-dir <abs-phase-dir> --worktree <worktree> --policy <abs-policy>
   ```

   **Exit 0:** the brief is written to `<abs-phase-dir>/task-N-brief.md`; continue to 2. The
   script never exits 1. **Exit 2** means the brief could not be written — the script's own
   stderr names the specific reason. Read it: if it names `<abs-phase-dir>` not existing, Step
   3 was skipped or run out of order — fix that and retry once. For every other reason it might
   name (a missing flag, a relative path, a plan with no `README.md` or no `task-N.md`, a
   heading that disagrees with `N`, an unwritable destination), this is the plan defect this
   skill's fourth stop-condition names ("a plan so broken that every path forward is a guess").
   Note the failure in this task's ledger section, set `status` to `blocked`, commit
   `<abs-phase-dir>` — a stop that is not committed is invisible to the PM (Step 3) — then stop
   and report; do not reconstruct a task body from memory to route around it.

2. **Dispatch the implementer** (`foreman-implementer`), at the model and effort the plan's
   task table assigns. It receives the brief path, `<worktree>` and the invariants. Nothing
   else — not the plan, not this conversation. Before dispatching, capture `<base>`:
   `git -C <worktree> rev-parse HEAD`.

   **`<base>` is captured exactly once per task, right here, before this first dispatch — and
   never recaptured.** Every re-dispatch this task ever needs (a baseline rejection in item 3,
   a fix-loop round in item 5, any of it) keeps this same `<base>`; only `<head>` moves.
   Item 4 depends on this: recapturing `<base>` after a retry silently drops that retry's own
   earlier commits from the diff — exactly the under-reporting item 4 warns against.

   It returns one of three statuses:
   - **`done`:** go to 3.
   - **`blocked`:** it refused to break an invariant you handed it. Read its report to learn
     which invariant and why — that invariant binds you exactly as it bound the implementer,
     and never dispatch a fresh one told to break it instead. If the conflict can be resolved
     by revising the brief's expectation, regenerate the brief (item 1 — `<base>` stays fixed),
     ledger the ruling, and retry from 1. If resolving it needs an irreversible or
     security-sensitive call, that is a stop-condition: ledger the ruling, set `status` to
     `blocked`, commit `<abs-phase-dir>` — a halt that is not committed is invisible to the PM
     (Step 3) — report it, and wait.
   - **`partial`:** part of the task landed. Read its report for the stated reason. If the
     missing part would trip an invariant, treat this exactly like `blocked`. Otherwise treat
     what landed as its own reviewable unit — `<head>` in item 4 below is whatever it actually
     committed — and ledger a Minor for the remainder now, so it reaches gate 4 rather than
     being forgotten.

3. **Baseline gate, before any reviewer exists — run it yourself:**

   ```bash
   bash <gate-command-from-POLICY.md>   # you run this; never trust the implementer's own count
   foreman-baseline \
     --policy <abs-policy> --count <count-you-observed>
   ```

   Never pass the count from the implementer's return line: an agent being graded is the last
   source to take its own grade from, and a deleted test can report the old, passing number.

   **Exit 0:** at or above baseline; continue to 4.

   **Exit 1:** below baseline. Where you re-enter depends on how you got here — `<base>` never
   changes either way, per item 2:

   - **On the initial pass (from item 2):** reject and re-dispatch the same task implementer
     (item 2, resumed by message — not a fresh brief, and never a re-captured `<base>`), with
     the observed count and a note that its own gate run regressed. Do not spend a reviewer.
     Cap this at three rejections for this task. A fourth still-below-baseline result is the
     plan-so-broken stop-condition, not another retry: set `status` to `blocked`, commit
     `<abs-phase-dir>` exactly as item 6 would, and stop.
   - **Inside a fix-loop round (item 5):** return to that round's own fixer, not to a fresh
     task implementer — the round's dispatch already exists, and this is a reason to redo it,
     not a new task-level rejection. Redo this same round from its top (fixer dispatch,
     recapture `<head>`, re-diff, re-run this gate) before continuing to the reviewer; this
     retry does not advance item 5's outer round counter. Cap it at three rejections within the
     round. A fourth still-below-baseline result trips the fix loop's breaker early, this
     round, exactly as item 5's unresolvable-`blocked` case does: set `status` to `blocked`
     and `verdict` to `adjudicated`, commit `<abs-phase-dir>` exactly as item 6 would, and
     stop.

   **Exit 2:** the baseline could not be established, for whatever reason the script's own
   stderr names — do not infer which; the action is the same across every cause the script
   has. Say so verbatim, set this task's ledger `status` to `unverified`, commit
   `<abs-phase-dir>` — a stop that is not committed is invisible to the PM (Step 3) — and stop
   rather than trust a count you cannot verify against anything.

4. **Generate the review package, on a precisely defined range, then dispatch
   `foreman-task-reviewer`:**

   ```bash
   head="$(git -C <worktree> rev-parse HEAD)"
   git -C <worktree> diff <base> "$head" > <abs-phase-dir>/task-N-review.diff
   ```

   `<base>` is the commit you captured in item 2 above, *before* dispatch — never the
   implementer's own reported commit range. A single-commit task returns a bare SHA with
   nothing to diff against; a multi-commit task's first reported SHA is typically its own
   first commit, and diffing from it drops the changes that commit made. Never use `HEAD~1`
   either — on a multi-commit task it silently excludes every commit before the last one. The
   base you captured before dispatch is the only source that cannot under-report the task.

   Dispatch the reviewer with: the diff file path, the brief path, the invariants, and the
   findings-file path its contract requires — `<abs-phase-dir>/task-N-review.md`. Without a
   path there is nowhere for its complete analysis to go but its own return block, which stays
   in your context for the rest of the session — exactly what the split return/file contract
   exists to prevent.

   It returns `Spec: ✅` or `❌`, and `Quality: Approved` or `Not approved`, plus findings by
   severity.

   - **Spec ✅ and Quality Approved:** go to 6.
   - **Anything else, down to a lone Minor:** enter the fix loop.

5. **Fix loop, at most five rounds.** The round counter starts at 1.

   Each round:
   - Dispatch a fixer with the findings-file path, the brief path and the invariants. Rounds
     1–3 resume the same implementer by message (this retains its context, and is cheaper
     than starting fresh); rounds 4–5 dispatch a fresh `foreman-implementer` on a more capable
     model. It returns the same three statuses as item 2, scoped to being mid-fix rather than
     mid-task:
     - **`done`:** continue below.
     - **`blocked`:** the fix itself now conflicts with an invariant. Read its report, rule on
       it exactly as item 2's `blocked` does — but never "retry from 1": the task's completed
       work stays, and only a fresh fixer dispatch for this same round follows a resolvable
       ruling. If the conflict cannot be resolved without an irreversible or
       security-sensitive call, the breaker trips now, this round, rather than waiting for
       round 5 — set `status` to `blocked`, commit `<abs-phase-dir>` exactly as item 6 would,
       and stop.
     - **`partial`:** some findings addressed, not all, for a stated reason in its report.
       Continue below exactly as `done` — the next reviewer pass re-surfaces whatever is still
       open as a finding, which carries the same information a fuller report would.
   - Recapture `head="$(git -C <worktree> rev-parse HEAD)"`, and regenerate the diff from the
     **same original `<base>`** to a new file, `<abs-phase-dir>/task-N-review-<round>.diff`.
     Never reuse the previous diff file: the reviewer's contract forbids it from regenerating
     the diff itself, so a stale file makes every round review the pre-fix tree, and the loop
     cannot converge — it would just exhaust all five rounds re-finding the same defect.
   - Re-run the baseline gate (item 3 above) against the new tree, before re-dispatching the
     reviewer. A fix round that deletes a test must be caught here, not three rounds later.
   - Dispatch `foreman-task-reviewer` again against the new diff, with a new findings path,
     `<abs-phase-dir>/task-N-review-<round>.md`.
   - **Spec ✅ and Quality Approved:** exit the loop, go to 6. **Anything else**, and the round
     counter is below 5: increment it and repeat.

   **At round 5, if still not approved, the breaker trips:** stop looping. Adjudicate every
   open finding yourself, and set `verdict` to `adjudicated` — the ledger's declared value for
   exactly this case — regardless of which branch below applies:
   - Every open finding is a Minor: park each in the ledger with a ruling, deferred to
     `backlog.md` (gate 4). Set `status` to `deferred` and continue to item 6 as normal — this
     is not a stop, the task proceeds with its deferrals recorded.
   - A Critical or Important survives unresolved: the plan-so-broken stop-condition from
     "Rulings, not stalls." Set `status` to `blocked`, commit `<abs-phase-dir>` exactly as
     item 6 would, and stop rather than ledger it as passed.

6. **Update the ledger.** If the fix loop's breaker (item 5) already set `status` to
   `deferred` or `blocked`, with `verdict: adjudicated`, leave those exactly as they are —
   this step never overwrites them. Otherwise (the ordinary close, item 4's first pass or a
   fix-loop round that reached `Approved`), set `status` to `passed`.

   Either way, commit range (`<base>..<head>` of the final round), verdict, numbered Minors
   `[TN-MK]`, and the model and effort **actually used**. For deviations, read only the
   **Deviations** section of `<abs-phase-dir>/task-N-report.md` — not the rest of it; the
   report exists for exactly this bounded lookup, and reading it end to end fills your context
   the same way a task body would.

   Then commit the whole of `<abs-phase-dir>` — the ledger, the brief, the report, and every
   round's findings file. `.diff` files are gitignored; everything else under `docs/dev/` is
   tracked on purpose, and gate 7's claim that these travel with the merge is only true if this
   commit happens now, every task, not once at the very end.

## Rulings, not stalls

A running plan does not wait on a human. Conflicts, ambiguities, plan defects — decide them,
and record each in the ledger as:

```
Ruling: <what you decided> — <why> — <what it costs if wrong>
```

Four things stop you and only these: an irreversible or destructive operation; a
security-sensitive action; a side effect outside this worktree that norms say you ask about
first; and a plan so broken that every path forward is a guess.

A wrong ruling costs rework the human can see and undo. A session parked on a question costs
their whole day and buys nothing.

## Model and effort

The plan's task table assigns these. Where it does not, use this default table, and record the
model and effort **actually used** in the ledger — after a few phases the table stops being an
assumption and becomes evidence.

| Work | Model | Effort |
|---|---|---|
| You, the controller | Sonnet | medium |
| You, when the phase touches a trust boundary | Opus | high |
| Transcription — the plan carries the literal code | Haiku | low |
| Implementation | Sonnet | medium |
| Implementation at a trust boundary | Opus | high |
| Task review | Sonnet | medium |
| Task review at a trust boundary, or of a large diff | Opus | high |
| Whole-branch review | Opus | high |

Trust boundaries are named in `POLICY.md`, and `POLICY.md`'s model-override section wins over
this table where the two disagree.

## Failure protocols

- **A subagent dies mid-task** (a 529, a session limit). If it is resumable, resuming it by
  message retains its context — prefer that over everything below. If it is not resumable:
  read the brief you generated for this task, not the task body — the one place this skill
  reads a brief's own content, because there is no live subagent left to read it for you. Run
  item 3's baseline gate yourself against the worktree, exactly as item 3 specifies — all
  three exit codes apply here too, not just green-or-red. On Exit 0, if the diff also reads as
  a coherent subset of the brief's own acceptance material, commit it yourself, noting the
  interrupted dispatch in the commit message, then generate the diff and dispatch the reviewer
  as usual. On Exit 1 or Exit 2, or if the tree looks like an incoherent partial edit even
  where the gate passed, do not discard it yourself — that is this skill's
  destructive-operation stop-condition, not a ruling you make alone. Note it in this task's
  ledger section, set `status` to `blocked`, commit `<abs-phase-dir>` (a stop that is not
  committed is invisible to the PM — Step 3), report it, and wait before re-dispatching a
  fresh implementer on the same brief.
- **A reviewer's finding conflicts with the plan text.** Rule on it, ledger the ruling, then
  dispatch the fix. The spec is the binding authority; the plan is its argument.
- **A task must be reordered** because a dependency demands it. Fine. Note it in the ledger.
- **A brief contradicts the codebase.** The implementer may deviate; the report must declare
  the deviation and the reviewer must judge it. A deviation that reaches the ledger unjudged is
  a defect in your process, not theirs.

## Step 5 — the gate chain

Read `references/gate-chain.md` and run it in order. Do not skip a gate because an earlier one
was clean; they fail differently.

## Step 6 — verify the PM's read path, then report

Before writing anything else, confirm that what you have committed is actually readable the
way the program manager will read it:

```bash
foreman-state \
  --phase <slug> --branch <branch> --repo <main-checkout> --head
```

**Exit 0:** the ledger's machine-readable head comes back exactly as the PM will retrieve it;
proceed. **Exit 2:** something is broken — an uncommitted `state.md`, a malformed frontmatter
block, or a branch name that does not match what `docs/dev/program/STATE.md` expects. Fix it
and re-check before reporting anything as finished; a phase that "passed" but cannot be read
back by the one script built to read it has not actually finished.

Write `docs/dev/reports/YYYY-MM-DD-<slug>.md` (`mkdir -p` its parent first — nothing else in
this program creates that directory): the session-level record, for whoever comes next. Then
end with a summary **under 150 words** — status, the branch name, commit range, gate results,
open Minors, what remains uncovered. The human pastes it to the program manager, so it must
stand alone.

## What you never do

- Read the plan's task bodies (briefs exist for that).
- Paste accumulated history into a dispatch. A fresh subagent gets its brief path, the
  interfaces it touches, the invariants, and nothing else.
- Use a relative path in a dispatch.
- Invoke a harness script by any path at all, relative or `$CLAUDE_PLUGIN_ROOT`-prefixed. Use
  the bare wrapper names above; `$CLAUDE_PLUGIN_ROOT` does not resolve in the Bash tool, and a
  relative `scripts/...` resolves against the target repo.
- Treat a non-zero exit code as generic failure. `1` and `2` mean different things everywhere
  in this system; every script above is handled by which code it returned, never by whether it
  returned zero.
- Wait on elapsed time. Name the deferred check and end; the PM runs it.
- State a wall-clock time you have not read.
