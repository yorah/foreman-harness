---
phase: prerequisites
plan: docs/dev/plans/2026-09-02-prerequisites/
branch: feat/prerequisites
baseline: 610 at cc489e9a0f0be85829ba288cf089ba28037fdcbb
tasks:
  - {n: 1, model: opus, effort: high, status: passed, commits: "13dce8e..0c6f90d", verdict: "Spec ✅ / Quality Approved", minors: [T1-M4, T1-M5]}
  - {n: 2, model: sonnet, effort: medium, status: passed, commits: "8273545..57f5323", verdict: "Spec ✅ / Quality Approved", minors: [T2-R1-M1, T2-R1-M2, T2-R1-M3, T2-R1-M4]}
  - {n: 3, model: sonnet, effort: medium, status: pending, commits: "", verdict: "", minors: []}
  - {n: 4, model: opus, effort: high, status: pending, commits: "", verdict: "", minors: []}
---

# Phase `prerequisites` — ledger

Phase A of `docs/dev/specs/2026-09-02-program-layer-merge.md` §10. Controller at Opus, high
effort, as the kickoff directs: the phase touches two declared trust boundaries
(`scripts/lib.sh`'s settings chain in task 1, `MANIFEST.tsv` in task 4).

## Setup, as observed

- `<main-checkout>`: `/home/yorah/projects/foreman-harness`. `<default>`: `main`, from
  `git symbolic-ref refs/remotes/origin/HEAD`.
- `<worktree>`: `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites`,
  branched from `origin/main` at `cc489e9`. `EnterWorktree` created it on
  `worktree-prerequisites`; renamed to `feat/prerequisites`, the name the kickoff supplies and
  `STATE.md` already carries.
- Baseline, Step 1c, run against the fresh worktree with the prefix the kickoff mandates:
  **610 passed, 0 failed**, exit 0, at `cc489e9`. This equals `POLICY.md`'s recorded
  `baseline-count: 610`.

## Rulings

Ruling: gate 1 runs as `env PATH="/usr/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null bash tests/run.sh`
until task 2 has landed, and plain from task 2's Step 4 onward — carried from the kickoff, where
it is marked not to be relitigated. Verified rather than assumed before adopting it: the plain
run on this machine reports **522 passed, 88 failed**, the prefixed run **610 passed, 0 failed**,
both at `cc489e9`. The 88 are `tests/test_resolve_gate.sh` redirecting `HOME`, which breaks the
mise shim that serves `jq`; they are a property of this machine, not of the tree, and they are
what tasks 1 and 2 exist to remove. — Costs if wrong: the phase stops at Step 1c on a tree it
was convened to fix, and nothing in the program can be measured behind it.

Ruling: the plain run's own count is recorded at each task's Step 4 from task 2 onward, and the
plain run reaching 0 failed is treated as the phase's evidence for spec §12.1 item 1 — not the
prefixed run's count. — Because §12.1 item 1 is a claim about an unprefixed suite on a hostile
machine; a prefixed green proves only that the prefix works. — Costs if wrong: the phase
reports a fix it has not demonstrated.

Rulings carried from the kickoff, recorded here so a later reader needs one file:

- `[DEP-1]` is a presence check that stops cleanly, not a fallback — two copies of another
  plugin's procedure drift.
- `.claude/settings.local.json` stays in `gitignore-additions.txt`; only the comment's
  rationale changes.
- The marketplace source is `github`, repository `yorah/foreman-harness` — not a directory and
  not a path variable.
- Task order is 1, 2, 3, 4, forced by the environment; no reordering.
- The phase does not install, remove or re-register a plugin, and does not touch this
  repository's `.claude/settings.local.json`.
- Gate 6 ends in a pull request, not a merge (spec D5, `POLICY.md`'s integration rule).

## Tasks

Filled in as each task closes.

### Task 1 — user settings tier through `CLAUDE_CONFIG_DIR`

**Status** passed. **Commits** `13dce8e..0c6f90d` (`611675a` implementation, `0c6f90d` fix round
1). **Model and effort actually used** implementer Opus/high, reviewer Opus/high — as the plan's
table assigns, because `scripts/lib.sh`'s settings-precedence chain is a declared trust boundary.
**Verdict** Spec ✅ / Quality Approved (round 1).

**Gate, as the controller observed it** — never the implementer's own count. At the first pass:
prefixed 616/0, plain 616/0, `foreman-baseline --count 616` → pass, delta +6. After fix round 1:
plain 623/0, `foreman-baseline --count 623` → pass, delta +13. The plain unprefixed run moving
from 522 passed/88 failed to 623/0 is this task's real result and the evidence for the
`HOME`-shim half of spec §12.1 item 1.

**Findings.** Round 0 raised three Minors; round 1 closed all three, each verified by the
reviewer in situ rather than by inspection — `[T1-M1]` (an assertion that did not check the
clause its own label claimed), `[T1-M2]` (a relative `CLAUDE_CONFIG_DIR` reaching the gate's JSON
`effort_source` as a relative path), `[T1-M3]` (the `no test file redirects HOME` guard's regex
narrower than its claim). Round 1 raised two new Minors, carried open — see below.

Ruling: a relative `CLAUDE_CONFIG_DIR` makes the gate answer `unknown` / exit 2 rather than
resolve the value against the cwd. — The gate's cwd is not Claude Code's launch cwd, so
absolutising would emit a confident guess at a possibly different file; that is precisely the
"cannot determine" invariant 3 reserves exit 2 for, and invariant 4 forbids emitting the relative
form. The reviewer confirmed the choice is monotonically safe: the user tier is last in the
chain, so dropping it can turn an answer into no answer but never into a laxer one, whereas the
fallback would flip `refuse` into `pass`. — Costs if wrong: a contributor with a relative
`CLAUDE_CONFIG_DIR` and no repo-tier `effortLevel` is asked a question instead of being given an
answer. No `foreman-init` repository is in that position, since the repo tier is always written.

Ruling: the fix loop exits on the reviewer's verdict pair, not on the absence of Minors, so task
1 closes `passed` with `[T1-M4]` and `[T1-M5]` open and deferred to `backlog.md` at gate 4. —
`foreman-phase` Step 4 item 4 enters the loop for "a lone Minor" while item 5 exits it on "Spec ✅
and Quality Approved"; the two readings differ, and the observed round-over-round behaviour
settles it — round 0's three Minors closed and produced two more, which is a loop that converges
on the reviewer's attention rather than on the defect. Both open items are diagnosability and
test-guard completeness, neither Critical nor Important. — Costs if wrong: two small quality
items land in the backlog instead of this branch, where the next phase must pick them up.

**Open Minors, deferred to `backlog.md` at gate 4:**

- `[T1-M4]` The `no test file redirects HOME` guard misses the indented per-command redirect
  shapes (`  HOME=/x cmd`, `env HOME=`, `readonly`/`typeset -x`) while its opening clause still
  claims whole-command scope. The guard is a meta-test protecting every future test file, so an
  uncovered shape is a hole in a hole-detector.
- `[T1-M5]` A user tier dropped for being non-absolute is invisible in the gate's `reason`, which
  still reads "no effortLevel found in any settings file".

**Declared deviations, judged.** The implementer could not run the ruled prefix verbatim — its
sandbox refuses any command setting `GIT_CONFIG_GLOBAL` — and ran `PATH`-only, observing 610/0 at
base, identical to the full prefix. Accepted: it did not relitigate the ruling, it reported that
it could not execute it, and the controller's own runs did include `GIT_CONFIG_GLOBAL`. Also
accepted: a comment reflow in `tests/test_templates.sh` (comment-only, no assertion touched); a
brief that predicted a failing assertion under a label no assertion carries, where the
implementer followed the assertion text the brief actually specifies; `chain_third` restructured
rather than relabelled, which additionally removed the last external command running under a
fake `HOME`. `POLICY.md`'s `baseline-count` was correctly left alone — a phase session never
edits that file.

**Uncovered, and not fixable from a diff.** Behaviour where `jq` is served by an `asdf` rather
than a `mise` shim: the fix removes the `HOME` dependency entirely, so the mechanism is
machine-independent, but only the mise case was observed here. And Claude Code's own resolution
of edge-value `CLAUDE_CONFIG_DIR`. Both belong in the phase report, not in the backlog — they are
limits of observation, not defects.

### Task 2 — the runner pins git configuration

**Status** passed. **Commits** `8273545..57f5323` (`56eeb89` implementation, `57f5323` fix round
1). **Model and effort actually used** implementer Sonnet/medium, reviewer Opus/high — the plan's
table, and `POLICY.md`'s model rule that the runner scoring every other test takes an Opus
reviewer. **Verdict** Spec ✅ / Quality Approved (round 1).

**Gate, as the controller observed it.** First pass: plain 625/0, `foreman-baseline --count 625`
→ pass, delta +15. After fix round 1, three environments, each **628 passed, 0 failed**:

| Environment | Before the round | After |
|---|---|---|
| plain `bash tests/run.sh` | 625/0 | 628/0 |
| hostile `GIT_CONFIG_GLOBAL` (signing mandatory, key absent) | 625/0 | 628/0 |
| env-injected signing via `GIT_CONFIG_COUNT` — the `[T2-M1]` hole | 612/13 | 628/0 |

`foreman-baseline --count 628` → pass, delta +18. Each hostile environment was probed before its
green run was believed: a bare `git commit` fails under both, so neither green is vacuous. This
is the signing half of spec §12.1 item 1, demonstrated rather than asserted — and note it had to
be *constructed*, because the 12 failures the plan predicts do not occur ambiently on this
machine.

Ruling: the 12 failures task 2 removes do not reproduce ambiently here, so the task was required
to construct the hostile condition deliberately and show the failures present without the fix and
absent with it, rather than record the fix as undemonstrable. — A fix nobody can see working is
indistinguishable from no fix, and this one guards a condition every future contributor may hit.
— Costs if wrong: effort spent building a harness for a failure mode that never occurs in the
wild; cheap, and the constructed check is reusable.

**Findings.** Round 0 raised four Minors, all closed in round 1 and each verified by the reviewer
through an independent mutation on a scratchpad copy rather than by reading the diff. Of these
the substantive one was `[T2-M1]`: the pin covered the global config *file* only, so
`GIT_CONFIG_PARAMETERS`/`GIT_CONFIG_COUNT` overrode it — 612 passed, 13 failed with the fix
nominally in place — and the comment in `run.sh` overclaimed the guarantee. Both mechanism and
comment were corrected.

Ruling: the runner pins `safe.directory=*`. — `[T2-M4]` asked whether discarding the operator's
global `safe.directory` could break a working checkout; on WSL, repositories on Windows-mounted
filesystems routinely need it. The reviewer verified the pin behaviourally with
`GIT_TEST_ASSUME_DIFFERENT_OWNER=1`: usable under the runner, `fatal: detected dubious ownership`
without it. It is a hard-coded literal, so it smuggles in no operator configuration. — Costs if
wrong: the suite tolerates an ownership condition a contributor's real git would reject, which
is the safe direction for a test runner and the wrong direction for a shipped script — this pin
is confined to `tests/run.sh`.

Ruling: the plan's predicted 12 failures and the implementer's observed 13 are both correct and
neither is a defect. — They count different sets: 13 is the 12 pre-existing `test_phase_state.sh`
assertions the plan names plus the one new isolation assertion this task adds, which the plan's
own Step 5 names separately. — Costs if wrong: nothing; the reviewer reproduced the split
independently.

**Open Minors, deferred to `backlog.md` at gate 4:**

- `[T2-R1-M1]` The `GIT_CONFIG_COUNT` half of the unset has no assertion — dropping it still
  leaves 628/0, so that half of the isolation is unguarded against future regression.
- `[T2-R1-M2]` The new `GIT_CONFIG_PARAMETERS` assertion re-creates the opacity `[T2-M3]` was
  raised about.
- `[T2-R1-M3]` The comment's phrase "file-based config resolution" still sweeps in local and
  worktree scope, which the pin does not govern.
- `[T2-R1-M4]` **`GIT_DIR` residual — the largest thing this phase found and did not fix.** The
  reviewer reproduced the suite committing five branches into a victim repository while
  reporting 624 passed, 4 failed. It is pre-existing and outside task 2's brief, so it was
  correctly not fixed here, but it means the suite can write into a repository outside itself
  when `GIT_DIR` is set in the environment, and report a nearly-clean run while doing it. It
  should not sit in the backlog at the same weight as a comment nit; flagged to the program
  manager in the phase report.

**Declared deviations, judged.** The brief's Step 4 predicted `618 passed, 0 failed`, computed
from a pre-task-1 baseline of 616; task 1 actually landed at 623, so the brief's absolute
arithmetic was stale while its `+2` delta was exact. Accepted — the brief was generated before
task 1's fix round existed, `foreman-baseline` checks `POLICY.md`'s recorded baseline rather than
a brief's guess, and the implementer flagged it rather than quietly matching the stale number.
No other deviation; the test block and the `run.sh` insertion are verbatim from the brief.

**Uncovered.** Suite behaviour under a hook-injected relative `GIT_INDEX_FILE`; an ambient
(rather than constructed) hostile signing config on this machine; and a real WSL foreign-uid
dubious-ownership path, as opposed to the `GIT_TEST_ASSUME_DIFFERENT_OWNER=1` simulation used
to verify it.
