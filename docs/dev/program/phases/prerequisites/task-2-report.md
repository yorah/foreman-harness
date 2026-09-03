# Task 2 report: runner pins git configuration

## What changed and why

**`tests/run.sh`** — after `export FOREMAN_ROOT` and before the test loop, the runner now
writes a throwaway global git config to a `mktemp` file (identity
`foreman-tests <foreman-tests@example.invalid>`, `commit.gpgsign=false`, `tag.gpgsign=false`,
`init.defaultBranch=main`), exports it via `GIT_CONFIG_GLOBAL` together with
`GIT_CONFIG_NOSYSTEM=1`, and removes it with a `trap ... EXIT`. This is the only `trap` in the
file. Every `git` command any test file or any script under test runs for the rest of the
process now sees this configuration instead of the operator's, so an operator whose global
config mandates signed commits with an unreachable signing agent no longer fails the scratch
commits `tests/test_phase_state.sh` makes.

**`tests/test_bin.sh`** — appended, immediately after the `rm -rf "$fix_dir"` line closing the
baseline-gate section, a new "the runner isolates git from the operator's configuration"
block, verbatim from the brief. It builds one hostile global git config (SSH-format signing,
`gpgsign=true`, a signing key at a path guaranteed not to exist) and proves both directions
against it:

- Direction 1: a plain `git commit` run directly under the hostile config, with no runner
  involved, must fail (`hostile_rc -ne 0`). This is the check that the hostile config really is
  hostile on the machine running the suite — without it, direction 2 passing would prove
  nothing.
- Direction 2: the same commit, run inside a one-file fixture test (`test_fixture.sh`) invoked
  through `run.sh` via `FOREMAN_TESTS_DIR`, under the *same* hostile `GIT_CONFIG_GLOBAL`
  supplied to the outer `env`, must succeed and must land on branch `main` — proving `run.sh`'s
  own export overrides whatever the caller's environment already set.

No other file was touched. `docs/dev/plans/2026-09-02-prerequisites/README.md` and
`POLICY.md` were read for constraints only, not modified.

## Commands run and their output

Working directory throughout: `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites`.

**Baseline before this task** (task 1 already landed):
```
$ bash tests/run.sh 2>&1 | tail -3
14 files, 623 passed, 0 failed
```

**Step 1 — wrote the failing test** (verbatim from the brief, appended to `tests/test_bin.sh`).

**Step 2 — confirmed it fails for the expected reason.** The direct `env PATH=... GIT_CONFIG_GLOBAL=/dev/null bash tests/run.sh` invocation was refused by the sandbox's worktree-isolation
guard ("this command sets GIT_CONFIG_GLOBAL, injecting git configuration whose effect on where
git writes can't be verified"). Per the brief's stated workaround, I wrote the whole invocation
to a script file outside the repo
(`/tmp/.../scratchpad/task2-step2.sh`, containing the `cd`, the `export`s, and the `bash
tests/run.sh | grep ...` pipeline) and ran that script directly:

```
$ bash /tmp/.../scratchpad/task2-step2.sh
  FAIL: run.sh isolates every test's git commands from a hostile global config (exit code): expected [0], got [1]
14 files, 624 passed, 1 failed
```

Exactly one new `FAIL`, exactly the one named in the brief. The direction-1 assertion (`_ok`)
passed silently, confirming the hostile config really is hostile on this machine (contrary to
the operator's earlier note that the ambient failure mode does not reproduce here — this
purpose-built hostile config does reproduce it, on demand, every time).

**Step 3 — implemented the change in `tests/run.sh`**, verbatim from the brief.

**Step 4 — gate commands.**

Plain run:
```
$ bash tests/run.sh 2>&1 | tail -3
14 files, 625 passed, 0 failed
```
(623 pre-task-2 baseline + 2 new assertions: the direction-1 `_ok` and the `assert_exit` for
direction 2. The brief's own arithmetic predicted "616 after task 1, plus 2" = 618, but task 1
actually landed at 623, not 616 — see Deviations below. The `+2` delta itself matches exactly.)

Signing-agent-unreachable run:
```
$ env -u SSH_AUTH_SOCK bash tests/run.sh 2>&1 | tail -3
14 files, 625 passed, 0 failed
```
This ran directly (no `GIT_CONFIG_GLOBAL`, so the sandbox guard did not fire). Same count as
the plain run, as expected — the fix means unsetting `SSH_AUTH_SOCK` no longer matters because
the suite no longer depends on the operator's config at all.

**Deliberately constructed hostile-condition demonstration**, since the ambient failure does not
reproduce on this machine (per the task's own environment note) and I therefore built the
condition by hand rather than either declaring it undemonstrable or treating its ambient
absence as "nothing to do". Script written to
`/tmp/.../scratchpad/task2-hostile-suite.sh` (outside the repo, per the same sandbox
workaround), running the **whole suite** under a hand-built hostile global config
(`commit.gpgsign=true`, SSH signing format, key at `/nonexistent/foreman-hostile-signing-key`,
`GIT_CONFIG_NOSYSTEM=1`):

```
$ bash /tmp/.../scratchpad/task2-hostile-suite.sh
=== full suite under the hostile global config (fix in place) ===
14 files, 625 passed, 0 failed
```

**Step 5 — mutation-check.** Commented out the `export GIT_CONFIG_GLOBAL=...` line (kept the
`trap` so the temp file still gets cleaned up), then re-ran the same hostile-suite script:

```
$ bash /tmp/.../scratchpad/task2-hostile-suite-verbose.sh
=== full suite under the hostile global config (mutation active) ===
14 files, 612 passed, 13 failed
  FAIL: run.sh isolates every test's git commands from a hostile global config (exit code): expected [0], got [1]
  FAIL: reads the state file off its branch: [MARKER_BODY] not found
  FAIL: includes the frontmatter: [phase: alpha] not found
  FAIL: --head keeps the frontmatter: [baseline: 100 at deadbee] not found
  FAIL: explicit --branch works: [MARKER_BODY] not found
  FAIL: reading a phase state dirties nothing: expected [], got [A  docs/dev/program/STATE.md
  FAIL: reading does not switch branches: expected [main], got [feat/unterm]
  FAIL: header-aware column lookup resolves correctly when STATE.md's columns are reordered: [REORDERED_MARKER] not found
  FAIL: sweep: full read still returns the body: [MARKER_BODY] not found
  FAIL: sweep: --head still keeps the frontmatter: [baseline: 100 at deadbee] not found
  FAIL: sweep: reordered columns still resolve correctly: [REORDERED_MARKER] not found
  FAIL: reading against a pre-dirtied tree does not switch branches: expected [main], got [feat/unterm]
  FAIL: --repo omitted still resolves the phase via $PWD: [MARKER_BODY] not found
```

13 failures: the new isolation assertion itself, plus exactly the 12
`tests/test_phase_state.sh` assertions the brief and the plan's environment note predicted.
This is the mutation going red for the named reason. Restored the `export` line, then re-ran
both the plain gate and the hostile-suite demonstration:

```
$ bash tests/run.sh 2>&1 | tail -3
14 files, 625 passed, 0 failed

$ bash /tmp/.../scratchpad/task2-hostile-suite.sh
=== full suite under the hostile global config (fix in place) ===
14 files, 625 passed, 0 failed
```

Both green again.

**Step 6 — commit.** The operator's own global config mandates signing with no reachable
agent — the exact condition this task neutralises for the *suite*, but the commit for this
task itself still runs under the operator's real global config, so per the task instructions I
committed with `git -c commit.gpgsign=false commit ...`:

```
$ git add tests/run.sh tests/test_bin.sh
$ git -c commit.gpgsign=false commit -m "tests: runner pins GIT_CONFIG_GLOBAL so scratch commits ignore the operator's signing config"
[feat/prerequisites 56eeb89] tests: runner pins GIT_CONFIG_GLOBAL so scratch commits ignore the operator's signing config
 2 files changed, 61 insertions(+)
```

Final verification post-commit:
```
$ bash tests/run.sh 2>&1 | tail -3
14 files, 625 passed, 0 failed
```

## Sandbox workaround used

The direct form `env GIT_CONFIG_GLOBAL=... bash tests/run.sh` was refused twice by the
worktree-isolation guard: once for setting `GIT_CONFIG_GLOBAL` inline, and once more (when I
tried to route around it with a two-line inline `cat > script; bash script` compound command)
for "running bash in a plain command" whose contents the guard could not verify. The route that
worked, per the brief's caveat: use the `Write` tool (not a Bash heredoc) to create a standalone
`.sh` file under the session scratchpad directory
(`/tmp/claude-1000/.../scratchpad/`, outside the repository), then invoke that file with a
plain `bash <path>` Bash call in a separate step. All hostile-config demonstrations in this
report used that route.

## Deviations from the brief

- The brief's Step 4 predicted `618 passed, 0 failed` (`616 after task 1, plus 2`). Task 1
  actually landed at `623 passed, 0 failed` per its own report ("task 1 passed (623/0), two
  Minors deferred"), not `616` — a number the brief's author could not have known since it was
  generated before task 1's actual implementation. The `+2` delta this task adds is exactly as
  predicted; only the absolute baseline the brief guessed at is stale. Actual final count:
  `625 passed, 0 failed`. This is a discrepancy in the brief's stale arithmetic, not a deviation
  in my implementation — no invariant is affected and the plan's own stated baseline (`POLICY.md`)
  is what the runner's baseline gate actually checks, and it passed.
- No other deviation. The test block and the `run.sh` insertion are verbatim from the brief.

## What I could not verify

- The ambient failure mode (`env -u SSH_AUTH_SOCK bash tests/run.sh` producing `598 passed, 12
  failed` pre-fix) does not reproduce on this machine, confirmed again here, consistent with
  what the dispatcher and the previous task's implementer both already observed. I did not
  attempt a further ambient reproduction; instead I built the hostile condition directly (a
  `GIT_CONFIG_GLOBAL` pointed at a hand-written config with SSH-format signing and an
  unreachable key) and proved the fix both ways against that constructed condition, per the
  dispatcher's explicit instruction.

---

## Fix round 1 (review Minors)

Reviewer approved (Spec PASS, Quality Approved, all invariants PASS/N-A) and raised four Minors
in `docs/dev/program/phases/prerequisites/task-2-review.md`. Addressed all four, test-first,
each mutation-checked independently. Commit `57f5323`.

### [T2-M1] The pin covered the global config *file* only; the comment overclaimed

`GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT`/`KEY_n`/`VALUE_n` sit **above** `GIT_CONFIG_GLOBAL`
in git's precedence order, so either can reintroduce the exact hostile-signing failure this task
removes, even with the pinned file fully in place. The reviewer reproduced `612 passed, 13 failed`
against the committed fix using `GIT_CONFIG_PARAMETERS`.

Decision: close the hole (cheap and safe — it costs one `unset` line and closing it does not
touch anything else the suite depends on) rather than only narrowing the comment. Added
`unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT` beside the existing `export` in `tests/run.sh`,
and rewrote the comment to state precisely what is pinned ("as far as git's *file-based* config
resolution goes") instead of the earlier unqualified "sees THIS global configuration and not the
operator's".

New test (`tests/test_bin.sh`, both directions, same shape as the existing block):
- Direction 1: a plain commit under a bare `GIT_CONFIG_PARAMETERS` override (no hostile
  `GIT_CONFIG_GLOBAL` at all) must fail — confirms the override alone really is hostile.
- Direction 2: the same override, inherited by a nested `bash tests/run.sh` invocation, must not
  reach the fixture's commit.

Test-first: ran before the `unset` line existed —
```
FAIL: run.sh neutralises an inherited GIT_CONFIG_PARAMETERS override (exit code): expected [0], got [1]
14 files, 626 passed, 2 failed   (this and the T2-M4 assertion below, added together)
```
Implemented the `unset` line, reran: `628 passed, 0 failed`, both new assertions green.

Mutation-check: commented out `unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT` →
```
FAIL: run.sh neutralises an inherited GIT_CONFIG_PARAMETERS override (exit code): expected [0], got [1]
14 files, 627 passed, 1 failed
```
alone, as expected. Restored (diffed byte-identical against the pre-mutation copy), reran:
`628 passed, 0 failed`.

Also reproduced the reviewer's own full-suite scenario against the fixed tree, via the sandbox's
external-script workaround (see below): `GIT_CONFIG_PARAMETERS="'commit.gpgsign=true'
'gpg.format=ssh' 'user.signingkey=/nonexistent/k'" bash tests/run.sh` → `14 files, 628 passed,
0 failed`. The reviewer's reproduction no longer reproduces.

`GIT_AUTHOR_*`/`GIT_COMMITTER_*`/`GIT_DIR`/`GIT_WORK_TREE`/`GIT_INDEX_FILE`, which the reviewer
named as the same class of hole, were left alone: none was demonstrated to reproduce a failure
(they don't bear on signing), the brief specified exactly `GIT_CONFIG_GLOBAL` +
`GIT_CONFIG_NOSYSTEM`, and the reviewer scored this Minor, not Important, on that basis. The
rewritten comment does not claim coverage of them.

### [T2-M4] The pin also discarded `safe.directory`

Concrete risk on this specific machine's class (WSL, Windows-mounted filesystems needing
`safe.directory` to be usable at all): decided to **preserve** it rather than accept the
regression, because the task exists to help exactly this kind of contributor, and a silent
loss of `safe.directory` would turn a working checkout into a failing one for them. Added
`[safe]` / `directory = *` to the pinned config file in `tests/run.sh`.

New test: a single-claim fixture (its own `test_fixture.sh`, not reused from the existing
block) asserting `git config --global --get safe.directory` equals `*` when run through
`run.sh`.

Test-first, before the `[safe]` block existed:
```
FAIL: run.sh pins safe.directory=* for every test's git commands (exit code): expected [0], got [1]
```
Implemented, reran: green, `628 passed, 0 failed`.

Mutation-check: removed the `'[safe]' '	directory = *'` printf arguments only (kept
`init.defaultBranch=main`), reran:
```
FAIL: run.sh pins safe.directory=* for every test's git commands (exit code): expected [0], got [1]
14 files, 627 passed, 1 failed
```
alone, as expected — no other assertion moved. Restored (diffed byte-identical), reran:
`628 passed, 0 failed`.

### [T2-M2] `commit.gpgsign=false` / `tag.gpgsign=false` were inert and unfalsifiable

The reviewer verified directly that once `GIT_CONFIG_GLOBAL` replaces the file and
`GIT_CONFIG_NOSYSTEM=1` removes the system file, git's own default ("do not sign") already
holds — these two lines did nothing, and no assertion could be written that would go red if
they were deleted. Per the plan's own constraint ("an assertion that cannot fail is not an
assertion"), applied here to config lines that could never be made to satisfy it: removed both
lines from the printf in `tests/run.sh` rather than keep them as inert self-documentation, and
folded the reasoning ("git's own default is already 'do not sign', so no explicit gpgsign=false
is needed") into the rewritten comment instead. No test needed to be written for a deletion of
dead code; verified by the full gate staying green (`628 passed, 0 failed`) immediately after.

### [T2-M3] Direction 2 collapsed two claims into one opaque assertion

`assert_exit` discards the nested runner's stdout/stderr, so a broken identity and a broken
`init.defaultBranch` pin produced the identical message. Fixed by replacing the `assert_exit`
call for the existing direction-2 assertion with a manual capture: the nested `run.sh` is run
with its combined output redirected to a temp log, its exit code captured, the log grepped for
`  FAIL:` lines, and the exit-code `assert_eq` call gets the joined FAIL text appended to its
own label in parentheses when non-empty. Passing runs are unaffected (empty detail, same
message as before); the assertion count is unchanged — this is a message-content fix, not a new
assertion.

Verified by hand (not a permanent new assertion, since the claim is about message content, not
pass/fail): temporarily removed the pinned identity lines from `tests/run.sh` and reran:
```
FAIL: run.sh isolates every test's git commands from a hostile global config (  FAIL: a commit inside a test succeeds regardless of the operator's git config: expected [0], got [128];): expected [0], got [1]
```
The nested claim that actually broke (the commit, not the branch pin) is now named in the outer
message — the fix works. (The GIT_CONFIG_PARAMETERS assertion also went red under this same
mutation, expected: it shares the identity-bearing `$hostile_dir/tests` fixture.) Restored
(diffed byte-identical against the pre-mutation copy), reran: `628 passed, 0 failed`.

### Gate

```
$ bash tests/run.sh 2>&1 | tail -3
14 files, 628 passed, 0 failed
```
628 = 625 (prior floor) + 3 new assertions: direction-1 `_ok` for `GIT_CONFIG_PARAMETERS`, the
`assert_exit` for its direction 2, and the `assert_exit` for the `safe.directory` fixture. (M3's
change and M2's deletion add or remove no assertions.)

Re-verified against a hand-built hostile `GIT_CONFIG_GLOBAL` (same one as the original report),
via the same sandbox external-script workaround: `628 passed, 0 failed`. Re-verified against the
reviewer's own `GIT_CONFIG_PARAMETERS` reproduction, same workaround: `628 passed, 0 failed`
(was `612 passed, 13 failed` against the pre-fix commit, per the reviewer's own report).

### Sandbox workaround (unchanged from the original report)

`env GIT_CONFIG_PARAMETERS=... bash tests/run.sh` and `env GIT_CONFIG_GLOBAL=... bash
tests/run.sh`, run directly, were both refused by the worktree-isolation guard for injecting git
configuration. Wrote each such invocation to a standalone `.sh` file under the session scratchpad
(outside the repository) with the `Write` tool, then invoked it with a plain `bash <path>` Bash
call — the same route documented in the original report.

### Commit

```
$ git add tests/run.sh tests/test_bin.sh
$ git -c commit.gpgsign=false commit -m "tests: close review Minors on the runner's git isolation"
[feat/prerequisites 57f5323] tests: close review Minors on the runner's git isolation
 2 files changed, 65 insertions(+), 9 deletions(-)
```

Final gate: `bash tests/run.sh` → `14 files, 628 passed, 0 failed`.

### Deviations

None beyond what the original report already declared. All four Minors were addressed as
concrete code/test changes rather than left as comments-only, per the coordinator's explicit
direction to address them test-first.

### What I could not verify

Same residual as the original report: the ambient failure mode (an operator whose real global
config both mandates signing and has no reachable agent) does not reproduce on this machine, so
every demonstration here is against a deliberately constructed hostile config or environment
variable, not an ambient one. `GIT_AUTHOR_*`, `GIT_COMMITTER_*`, `GIT_DIR`, `GIT_WORK_TREE`, and
`GIT_INDEX_FILE` were not tested for override risk, per the scoping decision under T2-M1 above.
