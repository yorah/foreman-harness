---
phase: prerequisites
plan: docs/dev/plans/2026-09-02-prerequisites/
branch: feat/prerequisites
baseline: 610 at cc489e9a0f0be85829ba288cf089ba28037fdcbb
tasks:
  - {n: 1, model: opus, effort: high, status: passed, commits: "13dce8e..0c6f90d", verdict: "Spec ✅ / Quality Approved", minors: [T1-M4, T1-M5]}
  - {n: 2, model: sonnet, effort: medium, status: passed, commits: "8273545..57f5323", verdict: "Spec ✅ / Quality Approved", minors: [T2-R1-M1, T2-R1-M2, T2-R1-M3, T2-R1-M4]}
  - {n: 3, model: sonnet, effort: medium, status: passed, commits: "a03a298..e50992b", verdict: "Spec ✅ / Quality Approved", minors: [T3-M14, T3-M15]}
  - {n: 4, model: opus, effort: high, status: passed, commits: "c033155..fd90e51", verdict: "Spec ✅ / Quality Approved", minors: [T4R1-M1, T4R1-M2, T4R1-M3]}
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

### Task 3 — `[DEP-1]` dependency check at skill entry

**Status** passed, after **three fix rounds** — the only task in this phase to need more than one.
**Commits** `a03a298..e50992b` (`07d0fd1` implementation, then `bd02151`, `62ceed9`, `e50992b`).
**Model and effort actually used** implementer Sonnet/medium throughout, including all three fix
rounds (rounds 1–3 resume the same implementer by message, so no escalation was reached);
reviewer Opus/high on all four passes, per `POLICY.md`'s rule that any skill or template takes an
Opus reviewer regardless of who implemented it. **Verdict** Spec ✅ / Quality Approved (round 3).

That rule earned its keep here. Every finding that mattered in this task was a **cross-file
semantic contradiction, invisible from inside the file being read** — which is exactly the
measured reason `POLICY.md` gives for the Opus-reviewer override.

**Gate, as the controller observed it.** 640/0 (delta +30) → 646/0 (+36) → 654/0 (+44) → 654/0
(+44, relabelling round). `foreman-baseline` pass at each. Invariants 5 and 8 also checked
directly by the controller: no `TODO`/`TBD`/`FIXME` under `skills/`, `agents/`, `commands/`, and
the only >100-column lines in the edited skills are frontmatter `description:` scalars, which
invariant 8 exempts.

**The `[T3-M5]` class — "what a phase does first".** Task 3 added a Step 0 check, which silently
falsified every other file's claim that a phase begins at Step 1a. Three separate instances
surfaced across three rounds: the kickoff template's header (`[T3-M1]`), `foreman-program`'s own
instruction to the PM plus a false test label (`[T3-M5]`), and a last `tests/test_templates.sh`
label calling `EnterWorktree` the "first action" (`[T3-M11]`). Patching instances one at a time
lost to it twice before the class was swept.

**The `[T3-M4]` fallback guard — the substantive finding of this phase.** Round 1's review
returned the phase's only **Not approved**, on an Important: the guard meant to protect the
`[DEP-1]` ruling failed in *both* directions — it missed a real fallback and false-redded on
compliant prose. Round 2 fixed the false positives but not detection, and round 2's review
returned Not approved again, this time for a disclosure failure rather than a detection failure.

Ruling: mechanical detection of "a fallback was added" is **declared closed as impossible**, and
the guard rests as a tripwire against known drift shapes with its limit disclosed in the test
comment, the assertion label and `backlog.md`. — Substring matching is polarity-blind: the same
vocabulary marks a fallback, a prohibition of one, and a compliant stop. Both directions were
proved rather than argued. The reviewer pasted `references/gate-chain.md:64`'s own compliant
sentence into Step 0 and reddened the suite; the controller injected four plainly-worded
fallbacks ("continue without it and apply the equivalent steps", "degrade gracefully",
"improvise a substitute", "best-effort attempt … instead of halting") and all four left the suite
at 654/0. Widening the markers only trades false negatives for false positives, and those false
positives push a future editor to delete the prose that reinforces the ruling — worse than no
guard. — Costs if wrong: the rule is enforced by review rather than mechanically, so a
differently-worded fallback can land and only a reviewer will catch it. This is recorded in three
durable places so no one mistakes the tripwire for a detector.

Ruling: rounds 3 was spent on disclosure, not on a fourth detection attempt. — The reviewer
scoped the remedy at roughly six lines (relabel, one comment sentence, one backlog line) and
called it convergent, against a detection target it had just proved unachievable; rounds 4 and 5
would have ended at the loop's breaker with the same residual. — Costs if wrong: one round spent
on wording. Verified after the fact: the compliant prohibition that used to false-red is now
green, a compliant stop is green, and a tuned phrasing still reddens at 653/1, so the tripwire
still guards its known shapes.

Ruling: the closed-world alternative — a snapshot pin or word budget over the guarded range, which
would give zero false negatives within invariant 1 — is **recorded, not implemented** (`[T3-M13]`).
— It changes the question from "is this a fallback" to "has this range changed at all", reddening
on every legitimate edit; that trade belongs to a phase that can weigh it, not to a fix round. —
Costs if wrong: a future phase re-derives the option from the backlog note.

**Open Minors, deferred to `backlog.md` at gate 4:**

- `[T3-M14]` The backlog's range sentence overstates the program-side range — Step 0 body versus
  the `### Dependencies` subsection.
- `[T3-M15]` `[T3-M12]` de-italicised the positive needles only, so an *italicised* reintroduction
  of the wrong primacy claim still passes green. The `[T3-M5]` class therefore remains partly
  unguarded against one formatting variant.

**Declared deviation, judged.** The brief's Step 1 test needle was lowercase-initial while its own
Step 3 implementation text opened the sentence capitalised, and `assert_contains` is a
case-sensitive literal match — so the brief contradicted itself and the implementer had to choose.
It kept the test's literal string and rephrased so the prohibition is not sentence-initial,
preserving meaning and emphasis. Accepted, and the reasoning was right: the gate is the authority
the invariants point to. The brittleness that forced the choice was then removed in round 1 as
`[T3-M3]`, so the next editor is not trapped by it. A helper gap was identified in passing and is
not a defect in this task: `flow()` takes a filename and does not lowercase, so it cannot serve an
extracted range.

**Assertion integrity.** The relabelling round left the count level at 654, which is consistent
with pure relabelling but equally with an assertion being swapped to keep the number flat. The
reviewer confirmed the honest reading — identical primitive counts per file, `comm -3` over label
sets showing relabels only, each changed needle mutation-proved live. Nothing was weakened or
removed.

**Uncovered.** A live session actually stopping on a missing plugin — the behaviour `[DEP-1]`
exists to produce — cannot be verified from a diff, and was not verified in this phase. Nor was
the `plugin:skill` naming of a session's visible skill list, nor marker collisions with compliant
sentences not yet written.

### Task 4 — `[DIST-1]` GitHub marketplace source, `settings.local.json` retired

**Status** passed. **Commits** `c033155..fd90e51` (`1f73631` implementation, `fd90e51` fix round
1). **Model and effort actually used** implementer Opus/high, reviewer Opus/high — the plan's
table, because `MANIFEST.tsv` is a declared trust boundary. **Verdict** Spec ✅ / Quality Approved
(round 1).

**Gate, as the controller observed it.** 657/0 (delta +47) → 660/0 (delta +50). The trust
boundary's facts were checked directly rather than read off the report: `MANIFEST.tsv` carries no
`settings.local` row; `settings.local.json.tmpl` is genuinely deleted rather than emptied; both
changes are in the single commit `1f73631`, as the plan required; the template and this
repository's own `.claude/settings.json` both declare `"source": "github"`, `"repo":
"yorah/foreman-harness"`; `gitignore-additions.txt` still ignores `.claude/settings.local.json`
and `*.diff`, its comment now citing per-contributor permission grants with no marketplace path.

Ruling: `evolve` mode's guarantee for `.claude/settings.json` is sound but rests on prose, not
code, and its behaviour is **not verified by this phase**. — The near-Critical question was
whether a fresh `foreman-init` into a repository that already has `.claude/settings.json` would
clobber it. Nothing mechanically consumes `MANIFEST.tsv` — `bin/foreman-root` only uses its path
as a sentinel to locate the plugin root — so there is no code path that could overwrite anything;
`foreman-init`'s Step 5 prose states `evolve` means "adding what is absent and touching nothing
else", which is correct and explicit. Confirming the behaviour requires running `/foreman-init`
end to end, which this phase is forbidden to do (it may not install, remove or re-register a
plugin). — Costs if wrong: a live session could still misread the prose and overwrite a
contributor's settings; the manifest cannot stop it, because the manifest is not executable.
Recorded as uncovered, not as checked.

**The dead-subagent episode.** The fix round's dispatch was interrupted **twice by API 529s**, the
second attempt making no progress at all, with five files staged and uncommitted. Adopted under
`foreman-phase`'s dead-subagent protocol rather than re-dispatched or discarded.

Ruling: the controller adopted and committed the dead fixer's staged work as `fd90e51`. — The
protocol's conditions were met and each was established rather than assumed: the gate was Exit 0
at 660/0 (floor 657, `foreman-baseline` delta +50); the diff read as a **complete** subset of the
round's three findings, corroborated by arithmetic that lands exactly (`test_templates.sh` +1,
`test_dogfood.sh` one assertion replaced by three, net +3 over 657); and because the fixer never
reached its own mutation check, the controller ran it — all four assertions reddened, including a
differently-cased variant of the `[T4-M1]` claim, proving that guard is case-insensitive as its
comment says rather than green by luck. The interrupted dispatch is recorded in the commit
message. Discarding the work would have been this skill's destructive-operation stop-condition,
and was neither necessary nor taken. — Costs if wrong: a half-applied edit lands green; mitigated
by having the round-1 reviewer re-derive every controller claim rather than accept it, since the
agent that judged the work coherent was the agent that committed it. It re-derived all of them and
confirmed each, and separately confirmed the machine state the kickoff fenced off — the `foreman`
marketplace registration and the main checkout's `.claude/settings.local.json` are both untouched.

**Open Minors, deferred to `backlog.md` at gate 4:**

- `[T4R1-M1]` The `[T4-M1]` guard's comment and label overclaim its reach; a reworded conflation
  ships green. Third instance in this phase of a guard claiming more than it checks.
- `[T4R1-M2]` The dogfood `--scope local` needle matches the raw haystack, so a line-wrapped
  reintroduction escapes it — the plan's own "assert meaning, not line breaks" constraint.
- `[T4R1-M3]` The `[T10-1]` note understates the duplication: two new lines beside three stale
  ones, not one beside two.

**Declared deviations, all judged sound.** The brief's predicted count was wrong twice over — its
absolute numbers were stale, and its arithmetic missed that `tests/test_templates.sh` emits one
assertion per file under `templates/`, so deleting a template silently removes an assertion (654
+ 4 − 1 = 657, confirmed empirically). The brief's `trust` needle was **self-satisfied**: it
passed against the *old* template, because an unrelated "new gates, new trust boundaries" bullet
contains the word — a needle green before the fix is not a test of the fix, and the brief expected
it to fail. Lengthened to its longest unique form. Two stale comments repaired ("the file above"
after the block it referenced was deleted; "three rules" above two assertions). And this
repository's `.gitignore` was edited though the brief did not list it, because it carried the same
now-false rationale verbatim — the dispatch's own "sweep the class, do not patch one instance"
caution, correctly applied.

**Uncovered.** Claude Code actually resolving the `github` marketplace source and presenting its
trust prompt; `/foreman-init` end-to-end generation including the executed `evolve` merge into an
existing `.claude/settings.json`. Both need a live run this phase may not perform.

## Phase-level finding — the review packages were abridged, and nothing said so

Discovered at task 4's round-1 review, which noticed a truncation marker in its own diff file and
read the committed file instead. Investigated by the controller rather than accepted as an
artifact quirk, because it bears on every review this phase ran.

`foreman-phase` Step 4 item 4 specifies the review package as
`git -C <worktree> diff <base> "$head" > <abs-phase-dir>/task-N-review.diff`. On this machine a
hook rewrites `git` to `rtk git`, a token-reducing proxy, so that redirection captures rtk's
**summarised** rendering — a `--- Changes ---` header, per-file stat lines, and a literal
`... (N lines truncated)` footer — not the diff. Every reviewer in this phase therefore received
an abridged package, and the shortfall was measured after the fact:

| Package | Delivered | Actual | Withheld |
|---|---|---|---|
| task-1-review.diff | 120 | 132 | 12 |
| task-1-review-1.diff | 189 | 201 | 12 |
| task-2-review.diff | 77 | 80 | 3 |
| task-2-review-1.diff | 133 | 136 | 3 |
| task-3-review.diff | 115 | 130 | 15 |
| task-3-review-1.diff | 191 | 211 | 20 |
| task-3-review-2.diff | 287 | 313 | 26 |
| task-3-review-3.diff | 346 | 372 | 26 |
| task-4-review.diff | 415 | 475 | 60 |
| task-4-review-1.diff | 437 | 510 | 73 |
| **total** | | | **250** |

All ten files have been regenerated raw via `rtk proxy git diff`, which bypasses the filter, and
none now carries a truncation marker.

Ruling: the task verdicts stand, and the whole-branch review at gate 2 is treated as the first
complete read of this branch. — Three things keep the verdicts credible: every reviewer
mutation-checked against the **live tree** rather than reasoning from the diff alone, so its
evidence came from the real files; the reviews demonstrably found real defects, including one
Important and the phase's only Not-approved; and the reviewer whose package lost the most
compensated explicitly. But that compensation is the reason not to stop here — the marker
disclosed **9** lines while the true loss was **73**, so it patched what it was told about, not
what was missing. The honest remedy is a complete read of the whole branch, which gate 2 performs
anyway at Opus, against a raw diff, with this disclosed in its dispatch. — Costs if wrong: a
defect that lived only in withheld lines survived four task reviews; gate 2 is the backstop and is
told exactly that.

**This is a defect in the harness itself, and it is the program manager's to fix, not this
phase's.** `foreman-phase`'s own instruction produces a silently incomplete review package under a
`git`-rewriting hook — the review looks complete and is not, which is precisely the class of
silent failure `POLICY.md` cites when it explains why the refusal gate is a trust boundary. The
fix belongs in the skill's Step 4 text (capture the diff through an invocation the proxy does not
rewrite, and assert the artifact has no truncation marker before dispatching), which is a
structural change to the harness and therefore `/foreman-init` or a program decision. Filed for
the program manager; deliberately **not** patched here, since a phase session does not amend the
skill it is running.

## Gate chain

### Gate 1 — gate commands

`POLICY.md`'s gate table has one row, `bash tests/run.sh`, run plain from the worktree root.
Actual output:

```
test_agents.sh
test_baseline_check.sh
test_bin.sh
test_dogfood.sh
test_init_skill.sh
test_lib_assert.sh
test_manifests.sh
test_phase_skill.sh
test_phase_state.sh
test_plans.sh
test_program_skill.sh
test_resolve_gate.sh
test_task_brief.sh
test_templates.sh

14 files, 660 passed, 0 failed
GATE1_EXIT=0
```

Exit 0, which is the authoritative signal — `gate-chain.md` warns that the runner gates on the
recorded baseline *after* printing its summary, so a sub-baseline run can print `0 failed` and
still fail. The exit code was captured deliberately for that reason rather than inferred from the
summary line.

Branch-level baseline check, on the branch's own observed count rather than any per-task number:

```
foreman-baseline --policy <abs-policy> --count 660
{ "verdict": "pass", "baseline": 610, "count": 660, "delta": 50 }
BASELINE_EXIT=0
```

**Gate 1: green.** 610 → 660, fifty net assertions added across four tasks, nothing below
baseline at any point in the phase.

Note for the record: this run is **plain**, with no environment prefix. That is the phase's own
acceptance evidence, not a convenience — the Step 1c baseline needed
`env PATH="/usr/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null` to reach 610/0 and the plain run was
522/88. Tasks 1 and 2 removed both crutches, so spec §12.1 item 1 is satisfied on this machine:
the suite is green with `jq` served by a tool-manager shim resolving through `$HOME`, and green
under a global git config mandating unsatisfiable commit signing (verified separately against a
constructed hostile config whose hostility was itself probed).

### Gate 2 — whole-branch review: NOT REACHED

Dispatched five times to `foreman-branch-reviewer` (Opus, high). Every attempt terminated on a
server-side `API Error: 529 Overloaded` — request ids `req_011CeggDkqfHE3pbCqhWmSMV`,
`req_011CeggYCRngcHH7ZTb9QfY7`, `req_011Ceggr3LbVhb6fumkUJfVD` among them. The first attempt died
after its opening line; the rest died before producing any output. **No findings file was ever
written**, and `branch-review.md` does not exist. The review package itself is ready and correct:
`branch-review.diff`, raw and complete at 7659 lines, `origin/main...HEAD`.

Between attempts the dispatch was restructured to survive interruption — write the findings file
as a stub first, work the areas in descending order of risk, append each conclusion as it lands,
and record the `GO`/`NO-GO` the moment it is reached. It never got far enough for that to help.

Ruling: the phase stops here rather than substituting its own procedure for the missing gate. —
Three alternatives were available and each was rejected. **Downgrading the reviewer's model:**
`gate-chain.md` specifies "Opus, high effort, always" for this gate, and API load is not a reason
to weaken the last structural check before a merge — least of all on a branch whose per-task
reviews are already known to have run on abridged diffs. **Reviewing the branch myself:** the gate
exists precisely to keep a 7659-line analysis out of the controller's context, and a controller
grading its own phase — including a fix round it committed itself — is not the independent read
the gate is for. **Skipping to gate 3:** `gate-chain.md` is explicit that a clean earlier gate is
not a reason to skip a later one, and gates 2 and 3 check different things (the reviewer grades
the diff; the judge checks whether the claimed verification happened). — Costs if wrong: the
branch waits for capacity that will return. That is the cheap error. Merging on four abridged
task reviews with no whole-branch read would be the expensive one.

This is the same principle the phase's own `[DEP-1]` ruling states, applied to the controller: a
required dependency is unavailable, so the session **stops cleanly and says so** rather than
improvising a substitute for it. A fallback here would be a second, worse copy of the branch
review, written by the least independent reader available.

**Gates 3, 4, 5, 6 and 7 are consequently unreached.** Nothing has been pushed; no pull request
has been opened; `main` is untouched. The branch `feat/prerequisites` is complete, committed, and
green at gate 1.

**To resume:** re-run `/phase docs/dev/program/phases/prerequisites/kickoff.md` when Opus capacity
returns. A resuming session should skip Step 4 entirely — all four tasks are `passed` in the head
above, with their commit ranges and verdicts — and re-enter at Step 5 gate 1 (cheap, and
`gate-chain.md` requires the branch's own count anyway), then gate 2 against the existing
`branch-review.diff`. The worktree, the branch and every artefact are on disk and committed.

### Resumption — 2026-09-03

Re-entered on the operator's instruction: resume at gate 1, and update the two program-manager
files this phase had deliberately left stale.

Ruling: the phase session edited `POLICY.md` and `STATE.md`, which `POLICY.md`'s own opening
paragraph forbids it to do. — The operator instructed it directly, and a direct instruction
outranks the skill's and the policy's defaults; the operator is also the program manager here, so
the file's owner is the party that asked. The edits were made **on the phase branch**, not on the
default branch, so they travel with the merge and never assert a count `main` cannot meet — `main`
still measures 610. The provenance is recorded both here and in `POLICY.md`'s own baseline
paragraph, so a later reader does not have to reconstruct who wrote it or why the ownership rule
appears broken. — Costs if wrong: a phase-authored edit to a file the program manager owns, which
the program manager can see in the diff and revert in one commit.

`POLICY.md`: `baseline-count: 610` → `660`, provenance restated as green at `e8dc48e`, recorded
2026-09-03, with the raise attributed to this phase and the reason it is recorded on the branch.
Verified after the edit that `baseline-check.sh` still parses the line and that the raised value
is live: `{"verdict":"pass","baseline":660,"count":660,"delta":0}`, exit 0 — the baseline now has
no headroom, which is the point of raising it.

`STATE.md`: the phase row moved `planned` → `gates` with its real position; the **Next action**
section rewritten from "launch phase A" to the resumption procedure, since the phase is
mid-gate-chain rather than awaiting launch; the stale expected count **634 corrected to 660**; the
`[DIST-1]` marketplace ruling marked superseded-on-the-branch-not-on-`main`, with the point that
the plugin this session ran is still the directory-sourced one and the re-registration
`DEFERRED.md` schedules is what closes the gap; and phase B warned about both of this phase's
carry-forward findings (the abridged review package, and `[T2-R1-M4]`'s `GIT_DIR` residual).

Checked rather than assumed, before and after: no test constrains the literal `610` or this
repository's real `STATE.md` — every relevant assertion uses fixtures — so the edits could not
green or red the suite by touching what it measures. Gate 1 re-run **after** the edits: `14 files,
660 passed, 0 failed`, exit 0. Invariant 8 holds in both files; the one over-length line is the
`STATE.md` table row, which cannot wrap without breaking the table and which was already 145
columns before this phase touched it — trimmed to 141 rather than left at the 253 the first draft
produced.

### Gate 2 — whole-branch review: **GO**

Verdict `GO` on the seventh dispatch, after six consecutive server-side 529s. Findings:
`docs/dev/program/phases/prerequisites/branch-review.md`. Two Important, thirteen findings total,
against a raw complete 7952-line diff. **Both Importants were the controller's own work, and both
are fixed on the branch before proceeding** — a `GO` is not a licence to leave an Important
standing when the fix is four lines.

**`[BR-1]` — this phase's own kickoff still routed the next session past the check task 3 added.**
`docs/dev/program/phases/prerequisites/kickoff.md` still opened "First — `foreman-phase` Step 1a"
with "before doing anything else", the two claims `[T3-M1]` and `[T3-M6]` corrected in the
template. The controller saw this at task 3's round 1 and **dismissed it as a historical
artefact** — an already-issued kickoff, harmless. That reasoning was wrong, and the controller's
own `STATE.md` resumption instruction is what made it wrong: it points the next session directly
at that file, so the stale wording became a live instruction to skip `[DEP-1]`'s Step 0 — the
dependency check whose whole purpose is to stop cleanly rather than proceed without a required
plugin. Fixed: the heading now reads "Step 0, then Step 1a, then Step 1b's `EnterWorktree`", with
the correction and its date stated in the file so a reader knows why it changed.

The lesson is the phase's own, turned on itself. The "what a phase does first" class was swept
three times in shipped files (`[T3-M1]`, `[T3-M5]`, `[T3-M11]`) and missed in the phase's
governing document, because a kickoff did not feel like a file that states what a phase does
first. It is the *only* file that does so authoritatively. `[BR-3]` names the reason it shipped
green: no assertion checks a rendered kickoff, only the template.

**`[BR-2]` — the last surviving stale `634`, in a live instruction.** `DEFERRED.md`'s "Raise the
baseline" entry still told the program manager the plan expects 634. The operator's instruction
was to fix the stale 634; the controller fixed `STATE.md`'s instance and missed this one — the
same patch-one-instance failure, in the same session that had just written the lesson down.
Rewritten as a **re-attribution** entry, since the raise itself is already done on this branch:
confirm 660 on the merged `main`, re-attribute to the merge SHA, and trust the run over the entry
if they disagree — while noting that a disagreement is itself a signal, because this branch is
green at 660 with zero headroom.

**`[BR-9]` and `[BR-10]`, corrections to the controller's own record**, fixed rather than
deferred because they are inaccuracies in claims the controller made:

- `[BR-9]` The ledger claimed the `STATE.md` table row was "trimmed to 141"; it measured **146** —
  wrong value, and wrong direction, since 146 is one column *longer* than the 145 it replaced. The
  row is now genuinely 128, and this sentence replaces the false claim rather than sitting beside
  it.
- `[BR-10]` `POLICY.md` attributed `baseline-count: 660` to `e8dc48e` as "the head", which it was
  not — the head moves with every ledger commit. Restated as a provisional branch-internal
  observation, with the authoritative attribution deferred to the merge commit, which is exactly
  what `DEFERRED.md`'s rewritten entry now schedules.

Gate 1 re-run after all four fixes: `14 files, 660 passed, 0 failed`, exit 0. Invariant 8 holds
across all four edited files. `baseline-check.sh` still parses the `baseline-count:` line.

**Eleven findings carried to gate 4**, with the twelve task Minors: `[BR-3]` through `[BR-8]` and
`[BR-11]` through `[BR-13]`. Three deserve flagging above the rest:

- `[BR-3]` **no assertion checks a rendered kickoff** — the structural gap that let `[BR-1]` ship
  green, and the reason the next such drift will also ship green.
- `[BR-7]` the `[DEP-1]` disclosure states its limit four times and its residual value once, so
  **deletion looks free** to a future editor. That is the underclaiming failure the controller
  asked round 3's reviewer to watch for; it was introduced anyway, one round later.
- `[BR-8]` the vendor-name rule: `Sahir619/fable-method` is pre-existing and sits inside
  `skills/`. The reviewer recommends **widening the exception to `extraKnownMarketplaces`** rather
  than enforcing the rule against it — a program-level ruling, not a phase edit.

The reviewer also confirmed what the controller could not confirm about itself: **none of the
twelve task Minors had reached `docs/dev/backlog.md`** — zero tag hits, correctly deferred "at
gate 4", which had never been reached. Gate 4 is blocking and must flush all of them.
