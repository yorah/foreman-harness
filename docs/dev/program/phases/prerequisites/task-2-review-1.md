# Task 2 re-review (fix round 1): runner pins git configuration

Reviewed artifact: `docs/dev/program/phases/prerequisites/task-2-review-1.diff`, read as given and
never regenerated. It is the cumulative diff from the task's base (`8273545`) through the fix-round
commit `57f5323`, i.e. both rounds together: `tests/run.sh` +19, `tests/test_bin.sh` +98, no other
file, modes `100755` on both, unchanged.

**Spec compliance: PASS. Quality: Approved.** Four Minors, no Critical, no Important. All four
previous-round Minors (`[T2-M1]` .. `[T2-M4]`) are genuinely closed, each confirmed by an
independent mutation rather than by reading the diff.

## How I verified

Same method as the previous round, and no tracked file was touched at any point. The worktree was
copied (minus its git directory) into the session scratchpad and every mutation was applied to the
copy only; after each mutation the copy was restored from a pre-mutation snapshot and `diff`-ed
byte-identical against the worktree's `tests/run.sh` and `tests/test_bin.sh`. The copy reproduces
the worktree exactly: `bash <copy>/tests/run.sh` gives `14 files, 628 passed, 0 failed`. The
worktree's own status is clean apart from the task's untracked `task-2-*.md` files, before and
after.

Environment facts I measured rather than assumed, because two of them change the reading of the
diff:

- `git version 2.43.0`.
- The ambient environment this project's gate actually runs in **already sets**
  `GIT_CONFIG_COUNT=2` with `GIT_CONFIG_KEY_0=credential.interactive`,
  `GIT_CONFIG_KEY_1=credential.guiPrompt` (values `false`). The env-config channel `[T2-M1]` is
  about is therefore live on every run here, not hypothetical.
- A `pre-commit` hook under git 2.43 runs with `GIT_DIR` **unset** and `GIT_INDEX_FILE=.git/index`
  (relative). This matters for finding [T2-R1-M4] below; it lowers the reachability of the residual
  `GIT_DIR` hazard well below what the previous round's write-up implied.

### Mutation log (all on the copy)

| # | Mutation | Result |
|---|---|---|
| A | comment out `unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT` | `627 passed, 1 failed` -- `run.sh neutralises an inherited GIT_CONFIG_PARAMETERS override`, alone |
| B | `unset GIT_CONFIG_PARAMETERS` only (drop the `GIT_CONFIG_COUNT` token) | `628 passed, 0 failed` -- **no assertion covers the COUNT half** (finding [T2-R1-M1]) |
| C | hostile `GIT_CONFIG_PARAMETERS` `commit.gpgsign=true` to `false` | `627 passed, 1 failed` -- `GIT_CONFIG_PARAMETERS did not make a plain commit fail (rc=0)...`, alone |
| D | drop `[safe] directory = *` from the pinned config | `627 passed, 1 failed` -- `run.sh pins safe.directory=* for every test's git commands`, alone |
| E | drop the pinned identity (`[user] name/email`) | `626 passed, 2 failed`; the M3-fixed assertion names the nested claim: `... (  FAIL: a commit inside a test succeeds regardless of the operator's git config: expected [0], got [128];)` |
| F | `defaultBranch = main` to `trunk` | `626 passed, 2 failed`; M3-fixed assertion names the *other* nested claim: `... (  FAIL: the runner pins init.defaultBranch=main for every scratch repository: expected [main], got [trunk];)` |

E and F together are the decisive check for `[T2-M3]`: the two nested claims now produce
*distinguishable* outer messages, which was exactly what the Minor said they did not.

### Behavioural check of the `safe.directory` pin (not just the config value)

The new test only asserts that `git config --global --get safe.directory` prints `*`. That is a
value check, not a behaviour check, so I ran the behaviour separately using git's own
`GIT_TEST_ASSUME_DIFFERENT_OWNER=1`, which forces the dubious-ownership path without needing a
second uid:

- Outside the runner: a plain `status` in a scratch repository gives `fatal: detected dubious
  ownership in repository at ...`, rc `128`. (This also establishes that the operator's real global
  config on this machine has **no** `safe.directory` entry, so nothing ambient masks the probe.)
- The same command inside a fixture run through `run.sh`: `1 files, 1 passed, 0 failed`, rc `0`.
- The same fixture through a copy of `run.sh` with the `[safe]` lines removed: `0 passed, 1 failed`,
  carrying the `fatal: detected dubious ownership` text in the message.

So the pin is load-bearing in behaviour, not only in the config file, and the regression it prevents
reproduces on demand.

### Leakage and cleanup, re-checked for the new code

`TMPDIR` pointed at an empty directory, full suite run, then `find <TMPDIR> -mindepth 1 | wc -l`
gives `0`. Nothing is left behind by the pinned config file, by the new `d2_log`, by `hostile_dir`
(which now also contains `tests_safe/`), or by `params_repo`. `export` is process-scoped and
`run.sh` is executed, never sourced, so nothing reaches the operator's shell.

## Spec compliance

The brief specified two edits and gave both verbatim; round 1 landed them verbatim and the previous
review confirmed that. This round modifies that same code in four places, all traceable to a
numbered review Minor and none outside the two files the brief names:

- `tests/run.sh:7-18` -- the comment, rewritten ([T2-M1], [T2-M2], [T2-M4]).
- `tests/run.sh:20-21` -- `commit.gpgsign=false` / `tag.gpgsign=false` removed ([T2-M2]);
  `[safe] directory = *` added ([T2-M4]).
- `tests/run.sh:23` -- `unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT` added ([T2-M1]).
- `tests/test_bin.sh:149-201` -- the M3 capture rewrite, plus the two new assertion pairs.

Against the brief's stated *Produces* interface, one item is now deliberately absent:
`commit.gpgsign=false` and `tag.gpgsign=false` are no longer written into the pinned config. I rule
this **sound**, and it is not a silent divergence -- the report declares it under [T2-M2] and the
comment records the reasoning. Evidence it is inert:

- With the global file replaced and `GIT_CONFIG_NOSYSTEM=1`, git's built-in default for
  `commit.gpgsign` is already `false`; the previous review verified a pinned config carrying only
  identity plus `init.defaultBranch` gives `commit_rc=0`, and the whole suite is green.
- `tag.gpgsign` could not matter either way: no `tag` invocation exists anywhere under `tests/`,
  `scripts/` or `bin/`.
- The only scope that could still assert `gpgsign=true` is repo-local, and a *global* `false` never
  beat repo-local anyway, so its removal cannot regress that case.
- The remaining theoretical case -- a hostile `GIT_CONFIG_SYSTEM` file, where global `false` would
  have won on precedence -- is closed by `GIT_CONFIG_NOSYSTEM=1`, which git documents as making
  `GIT_CONFIG_SYSTEM` ignored.

The `[safe] directory = *` addition is present-and-unrequired relative to the brief's interface
list, but it is required by review Minor [T2-M4], which the coordinator directed be addressed. Not a
scope violation.

Nothing else was added. `POLICY.md` is untouched; `baseline-count: 610` against an actual 628 keeps
invariant 7 satisfied without a baseline edit, which is correct at task level.

## The four Minors: closed, or edited near?

### [T2-M1] -- CLOSED (mechanism), and the comment is now honest about the mechanism

Mechanism: `unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT` at `tests/run.sh:23`. `GIT_CONFIG_COUNT`
is the switch for the whole `GIT_CONFIG_KEY_n`/`VALUE_n` family -- git reads no env pairs at all
when it is absent -- so unsetting the two names covers both env channels without enumerating
`KEY_n`. Mutation A proves the line is load-bearing and mutation C proves the probe that exercises
it is itself hostile. The coordinator independently confirmed that the `GIT_CONFIG_COUNT`
reproduction which previously produced `612 passed, 13 failed` now produces `628 passed, 0 failed`.

Comment, judged against "describes what is actually pinned, no more":

- The former unqualified claim ("sees THIS global configuration and not the operator's") is gone,
  replaced by a qualified one plus an explicit paragraph naming the two env variables and *why*
  they are neutralised. It no longer claims coverage it does not have on the env channel.
- It does not claim `GIT_AUTHOR_*`, `GIT_COMMITTER_*`, `GIT_DIR`, `GIT_WORK_TREE` or
  `GIT_INDEX_FILE` -- correctly, since none is neutralised.
- Residual, and the reason for [T2-R1-M3] below: the qualifier chosen is "as far as git's
  *file-based* config resolution goes", and file-based resolution includes the local and worktree
  scopes, which are deliberately *not* pinned (repo-local wins over the pinned global -- which is
  load-bearing; `test_phase_state.sh` relies on it). The qualifier under-describes the env coverage
  the next sentence adds, and over-describes the file coverage.
- Everything the comment asserts factually is true: the precedence order, git's default of not
  signing, and that a `-c` invocation exports `GIT_CONFIG_PARAMETERS` to child processes (confirmed
  directly: an `!env` alias shows `GIT_CONFIG_PARAMETERS` in the child environment).

Verdict: closed. The overclaim that motivated the Minor is gone; a smaller, different one remains
and is recorded as [T2-R1-M3].

### [T2-M2] -- CLOSED

Both inert lines were deleted rather than kept as decoration, and the reasoning moved into the
comment. This is the right resolution of "an element that cannot be mutation-checked": remove it, do
not annotate it. See the Spec-compliance section for the evidence that the deletion is inert in
every scope that could still matter. Assertion count unchanged, suite green.

### [T2-M3] -- CLOSED for the assertion it was raised against

`tests/test_bin.sh:153-161` replaces `assert_exit` with an explicit capture: combined output to a
temp log, `d2_rc=$?` taken immediately (verified correct -- mutations E and F both surface
`got [1]`), `grep '  FAIL:' | tr '\n' ';'` folded into the assertion label only when non-empty, log
removed unconditionally. Mutations E and F show the two nested claims now produce different,
self-naming messages. Mechanically safe:

- `_bad` uses `printf '  FAIL: %s\n' "$1"`, message in an argument, not the format string, so a `%`
  in captured nested text cannot misformat.
- `tr '\n' ';'` guarantees the label stays single-line; and in any case labels never enter the P/F
  results file, so the runner's per-assertion counting cannot be perturbed by label content.
- `d2_detail` can only be non-empty when the nested run also exits non-zero (every `FAIL:` line in
  the runner increments `total_fail`), so a passing run keeps the original message verbatim.
- No `exit`, no `set` change, no new `trap`; `grep`'s exit 1 on no-match is absorbed by the
  assignment and there is no `set -e`.

Not closed for the *new* call site added this round -- see [T2-R1-M2].

### [T2-M4] -- CLOSED, and the trade is the right one

Ruling as asked. The fixer **preserved** the capability rather than discarding it, by pinning a
hard-coded `[safe] directory = *`.

- It cannot smuggle in other global config. The value is a literal in the `printf`; the operator's
  `~/.gitconfig` is never read, parsed or copied. This is strictly better than the obvious
  alternative (reading `safe.directory` back out of the operator's config before the pin), which
  would have to perform a config read against unpinned config and would still miss a *system*-scope
  `safe.directory` that `GIT_CONFIG_NOSYSTEM=1` removes. The literal `*` covers both sources.
- It is behaviourally load-bearing, not cosmetic: see the `GIT_TEST_ASSUME_DIFFERENT_OWNER` probe
  above, where its absence turns a usable repository into `fatal: detected dubious ownership`.
- Cost. `safe.directory=*` disables git's dubious-ownership protection for the duration of the run.
  That protection exists because a repository owned by another user can carry config that executes
  code (`core.pager`, `core.fsmonitor`, hooks). Inside this suite the only repositories git touches
  are the checkout itself and repositories the suite created under `mktemp -d`; no test derives a
  repository path from untrusted input. The exposure is confined to the runner's own process for the
  length of a test run, and it does not widen what the *operator* is exposed to outside it.
- Against that: without it, a contributor on a Windows-mounted WSL path or a container/CI-as-root
  checkout -- precisely the contributor this task exists to help -- gets a suite that fails for a
  reason not in the tree, surfacing as `scripts/lib.sh`'s `rev-parse --show-toplevel` collapsing,
  i.e. maximally confusing.

The trade is right. I would make the same call.

## Invariant verdicts

1. **Zero runtime dependencies beyond bash/git/jq -- PASS.** New external in this round: `tr` (M3's
   newline join). Already used by shipped code (`scripts/resolve-gate.sh:49`) and by tests
   (`tests/test_plans.sh:22`), alongside `awk`, `sed`, `grep`, `mktemp`, `env`. No new class of
   dependency; nothing beyond the POSIX text utilities the suite already requires.
2. **Shebang / strict mode / chmod -- PASS.** `tests/run.sh:1-2` is still `#!/usr/bin/env bash` plus
   `set -uo pipefail`; exactly one `set` line, no `set -e` (the only other match is the word inside
   the comment at line 73). `tests/run.sh:24` is still the file's only `trap`. Both files are
   `100755` in the tree. No `set` line added to any sourced library.
3. **Exit codes are contract -- PASS.** The EXIT trap body is still only `rm -f`, so it never
   overrides the status; `unset` returns 0 and is not the last command in any path. Mutation runs
   exit 1 on failure and 0 when green; the baseline gate's 0/1/2 handling is untouched.
4. **All paths passed between tiers are absolute -- PASS.** `$rr`, the `mktemp` outputs,
   `FOREMAN_TESTS_DIR`, `FOREMAN_POLICY` and `d2_log` are all absolute. The pinned config path is an
   absolute `mktemp` path exported into `GIT_CONFIG_GLOBAL`, which matters: a relative value there
   would resolve per-process-cwd and silently vary.
5. **No TODO/TBD/FIXME under skills/agents/commands -- N/A.** No markdown in the diff.
6. **Bare wrapper names -- PASS (not engaged).** No `skills/`, `agents/` or `commands/` call site is
   touched. The new blocks invoke `bash "$rr"`, the same shape the pre-existing baseline-gate tests
   in this file already use; invariant 6 governs the prose tiers' call sites.
7. **Green, not below baseline -- PASS.** 628/0 in the worktree and in the isolated copy; the
   coordinator additionally confirmed 628/0 under a hostile `GIT_CONFIG_GLOBAL` and under
   `GIT_CONFIG_COUNT`-injected signing, and `foreman-baseline --count 628` passes against baseline
   610 (delta +18).
8. **100-column markdown -- N/A.** No shipped markdown in the diff. (Four shell lines exceed 100
   columns: `tests/test_bin.sh:130` (119, pre-existing), `:161` (101), `:167` (114), `:179` (118).
   Invariant 8 scopes to markdown body prose.)

## New coupling between the pinning and the per-assertion counting?

**None.** Checked specifically, because a defect here would be invisible.

- Everything new in `run.sh` is above the loop (lines 7-24; loop at 49). It sets no shell option,
  defines no function, and shadows none of `count_lines`, `total_pass`, `total_fail`, `files`,
  `results_file`, `completed`, `tests_dir`, `exit_code`.
- `unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT` removes only git env names; nothing in the scoring
  path reads them.
- The M3 rewrite touches only `tests/test_bin.sh` and changes one assertion's *label*, not the
  record. Labels never reach the results file; `count_lines` matches lines exactly equal to `P`,
  `F` or `D`.
- Assertion arithmetic is exactly as the report claims and independently consistent with every
  mutation above: 625 to 628 is +3 (direction-1 `_ok` for the params probe, its direction-2
  `assert_exit`, and the `safe.directory` `assert_exit`). M3 swapped one `assert_exit` for one
  `assert_eq`: net zero. M2's deletion: net zero.
- Nested runners still each write their own results files (`FOREMAN_RESULTS_FILE` is re-set per test
  file by every runner instance), and the fixture files' own assertions correctly never reach the
  outer total. Redirecting the nested run's output into `d2_log` keeps nested `FAIL:` lines off the
  outer runner's stdout, so a human grepping `FAIL` sees one line per outer assertion, not nested
  noise.

## Findings

### Minor [T2-R1-M1] -- the `GIT_CONFIG_COUNT` half of the [T2-M1] fix has no assertion

`tests/run.sh:23` unsets two variables; `tests/test_bin.sh:163-186` exercises only
`GIT_CONFIG_PARAMETERS`. Mutation B: change the line to `unset GIT_CONFIG_PARAMETERS` and the suite
is still `14 files, 628 passed, 0 failed`. So half of the line this round exists to add is inert
against the test suite -- the same defect class the reviewer raised as [T2-M2] and the fixer
accepted by deleting the untestable lines.

Failure scenario: someone tidying the runner shortens the `unset` to one name (or folds it into an
`export`-only line) and the suite stays green while the env-pair channel reopens. That channel is
not hypothetical here: this environment already ships `GIT_CONFIG_COUNT=2` with two
`GIT_CONFIG_KEY_n` entries on every run, and the coordinator reproduced `612 passed, 13 failed`
through it before the fix.

Remedy: one more direction-2 assertion reusing the existing `$hostile_dir/tests` fixture with
`GIT_CONFIG_COUNT=3 GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=true ...`, plus the matching
direction-1 hostility probe, mirroring the block immediately above it. Minor rather than Important
because the mechanism itself is correct and was verified end-to-end by the coordinator; only the
regression guard is missing.

### Minor [T2-R1-M2] -- the new `GIT_CONFIG_PARAMETERS` assertion re-creates the opacity [T2-M3] just removed

`tests/test_bin.sh:183-186` uses `assert_exit 0 ... -- env GIT_CONFIG_PARAMETERS=... bash "$rr"`
against `$hostile_dir/tests`, i.e. the *same two-claim fixture* (commit succeeds; branch is `main`)
whose collapsed reporting was the whole of [T2-M3], and `assert_exit` still discards the child's
output.

Demonstrated, not inferred. Under mutation E (pinned identity removed) the run prints:

```
  FAIL: run.sh isolates every test's git commands from a hostile global config (  FAIL: a commit inside a test succeeds regardless of the operator's git config: expected [0], got [128];): expected [0], got [1]
  FAIL: run.sh neutralises an inherited GIT_CONFIG_PARAMETERS override (exit code): expected [0], got [1]
```

The first line -- the one the M3 fix touched -- names the broken nested claim. The second, added
this round, is exactly the opaque message [T2-M3] was raised about, and it points at
`GIT_CONFIG_PARAMETERS`, which is not what broke. The fixer's own report notes this assertion goes
red under that mutation and does not draw the conclusion.

Diagnosability only; the assertion does fail when it should (mutation A), so nothing is unprotected.
Remedy: reuse the `d2_log` capture shape for this call site too, or point it at a single-claim
fixture. (The third new assertion, `safe.directory`, is fine as `assert_exit`: its fixture makes
exactly one claim, so the exit code is unambiguous.)

### Minor [T2-R1-M3] -- "file-based config resolution" still sweeps in the scopes that are deliberately not pinned

`tests/run.sh:7-8`. The qualifier added this round bounds the claim by *mechanism* (files) when the
real bound is *scope* (system and global). Git's file-based resolution also includes the local and
worktree scopes, which the pin does not and must not override -- `tests/test_phase_state.sh` sets
repo-local `user.email`/`user.name` in eight places and depends on local beating the pinned global.

Failure scenario: a maintainer adds a scratch repo whose local config sets `commit.gpgsign=true`
(mimicking a contributor with per-repo signing) and expects the runner's pin to neutralise it; it
will not, and the comment is what told them it would. Cost to fix: replace "git's *file-based*
config resolution" with "the global and system config files". Minor, and strictly smaller than the
[T2-M1] overclaim it replaced.

### Minor [T2-R1-M4] -- `GIT_DIR` in the environment still routes every scratch commit into the operator's repository

Pre-existing, not introduced by this diff, and explicitly out of the brief's scope; recorded here
because I now have the reproduction the previous round only reasoned about, and because
`tests/run.sh:13-14` cites a hook as one of the scenarios the new `unset` covers, which invites a
reader to treat that scenario as handled.

Reproduced on the copy, against a throwaway "victim" repository in the scratchpad:

```
env GIT_DIR=<victim>/.git bash <copy>/tests/run.sh   ->  14 files, 624 passed, 4 failed
<victim> branch -a    ->  * main  feat/alpha  feat/midstart  feat/noattr  feat/unterm  master
<victim> log --all    ->  ~20 commits: "state", "alpha state", "noattr state", "unterm state", ...
```

`test_phase_state.sh`'s scratch commits land in the victim, five branches are created there, HEAD is
moved and the index and worktree are left dirty -- while the run *looks* like a near-pass (624/4).
That is the failure mode this repository cares most about: a corrupted measurement that reads as
green-ish.

Reachability, measured rather than assumed, which is why this is Minor and not higher:

- Nothing in this repository installs a hook; the only mention of `pre-commit` anywhere is the
  previous review's own hypothetical.
- Under git 2.43 a `pre-commit` hook runs with `GIT_DIR` **unset** (I instrumented one:
  `HOOK GIT_DIR=[unset] GIT_INDEX_FILE=[.git/index]`), so the modern hook scenario the comment names
  does not by itself produce this. It requires someone to export `GIT_DIR` explicitly.
- The hook does export a *relative* `GIT_INDEX_FILE`. Every git call in the suite goes through
  `-C <scratch>`, so a relative index path resolves inside the scratch repo; I could not run the
  confirming probe (see "cannot verify" below), so I state this as reasoning, not measurement.

Remedy if the program wants the guarantee unconditional: extend the existing line to also unset
`GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL`. Nothing in `scripts/` or
`tests/` reads any of them (both script call sites use `-C "$repo"`), so the change is inert for
every current caller. Alternatively, drop the hook example from the comment. Doing neither leaves a
comment that reassures about the one scenario in which the biggest residual hole lives.

## Test quality

Every assertion the two rounds added is falsifiable and was mutation-checked here independently of
the report: mutations A, C, D, E and F each turn exactly the expected assertion(s) red and nothing
else. No test was weakened, disabled or deleted by this round; the only test-side removal is
`assert_exit` becoming an explicit capture for one assertion, which strengthens the same claim
rather than replacing it. Both new direction-1 probes are real guards (they fail loudly if the
hostile condition stops being hostile, e.g. on a git without SSH-signing support), and both were
shown to fail by mutation. The two coverage gaps are [T2-R1-M1] (COUNT) and [T2-R1-M2] (message
opacity at the new call site).

The report's claims that I re-derived all reproduce: the 628 total, the `627/1` shapes for each of
its mutation-checks, the M3 message text under an identity break (byte-identical to what I
obtained), and the `+3` assertion delta.

## Deviations declared by the report

Two, both **sound**.

1. Round 1's stale-arithmetic deviation (brief predicted 618, actual 625 because task 1 landed at
   623, not 616). Judged sound in the previous review; unchanged.
2. This round's implicit deviation from the brief's *Produces* list -- `commit.gpgsign=false` and
   `tag.gpgsign=false` are no longer written. Declared under [T2-M2], reasoned correctly, and
   verified inert above. Sound.

The report's scoping decision on `GIT_AUTHOR_*`/`GIT_COMMITTER_*`/`GIT_DIR`/`GIT_WORK_TREE`/
`GIT_INDEX_FILE` is stated plainly in both the fix-round text and its "what I could not verify"
section, which is faithful reporting. [T2-R1-M4] does not contradict that decision; it supplies the
missing evidence so the program can price it.

## Cannot verify from the diff

- The behaviour of the suite under a hook-injected **relative** `GIT_INDEX_FILE`. The session's
  worktree-isolation guard refuses any command that sets `GIT_INDEX_FILE` to a runtime-computed
  path, so the probe could not be run. Reasoned above as low risk, not measured.
- The ambient failure mode the task exists for -- an operator whose *real* global config mandates
  signing with no reachable agent -- still does not reproduce on this machine. Every demonstration
  in both rounds, mine included, is against a deliberately constructed hostile config or environment
  variable.
- Real dubious-ownership behaviour on an actual Windows-mounted WSL path or a foreign-uid checkout.
  Approximated with `GIT_TEST_ASSUME_DIFFERENT_OWNER=1`, which exercises git's same code path but is
  not the same filesystem condition.

## Verdict

**Spec compliance: PASS. Quality: Approved.** `[T2-M1]`, `[T2-M2]`, `[T2-M3]` and `[T2-M4]` are all
genuinely closed, each proven by a mutation that fails for the named reason. The runner's scoring
machinery is untouched and no new coupling exists between the pinning block and the per-assertion
counting. Four Minors carried forward: [T2-R1-M1] missing `GIT_CONFIG_COUNT` coverage, [T2-R1-M2]
the re-created opaque assertion, [T2-R1-M3] the "file-based" qualifier, [T2-R1-M4] the demonstrated
`GIT_DIR` residual.
