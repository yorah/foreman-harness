# Task 2 review: runner pins git configuration

Reviewed artifact: `docs/dev/program/phases/prerequisites/task-2-review.diff` (read as given; not
regenerated). Commit under review: `56eeb89`, `tests/run.sh` +13, `tests/test_bin.sh` +48, modes
`100755` on both, unchanged.

**Spec compliance: PASS. Quality: Approved** (four Minors, no Critical, no Important).

## How I verified

To mutation-check without touching a tracked file, I copied the worktree (minus `.git`) to the
session scratchpad and mutated the copy only. The copy is self-contained: `bash <copy>/tests/run.sh`
reports `14 files, 625 passed, 0 failed`, identical to the worktree, and `diff` confirms the copy's
`tests/run.sh` is byte-identical to the worktree's after every restore. `git status` in the worktree
is clean apart from the task's own untracked `task-2-brief.md` / `task-2-report.md`.

Hostile config used throughout (a hand-written file, `GIT_CONFIG_NOSYSTEM=1`):
`[gpg] format = ssh`, `[user] signingkey = /nonexistent/foreman-hostile-signing-key`,
`[commit] gpgsign = true`, `[tag] gpgsign = true`. Confirmed genuinely hostile on this machine:
a bare `commit` under it returns `128` with
`error: Couldn't load public key /nonexistent/...`, and `git init` under it lands on `master`.

## Spec compliance

The brief required exactly two edits, and gave both verbatim.

- `tests/run.sh:7-18` — inserted after `export FOREMAN_ROOT` (line 5), before the test loop
  (line 43), character-for-character as the brief's Step 3 dictated, tabs and all.
- `tests/test_bin.sh:110-152` — appended immediately after the `rm -rf "$fix_dir"` line that closes
  the baseline-gate section (line 108), character-for-character as the brief's Step 1 dictated.

Produced interface, as specified: every `git` command in the run sees a runner-written global config
with identity `foreman-tests <foreman-tests@example.invalid>`, `commit.gpgsign=false`,
`tag.gpgsign=false`, `init.defaultBranch=main`, and `GIT_CONFIG_NOSYSTEM=1`. Test files may still set
repo-local config, and `tests/test_phase_state.sh` still does (`git -C "$repo" config user.email ...`
at lines 12-13, 101-102, 129-130, 141-142, 161-162, 195-196, 237-238, 256-257) — repo-local wins over
the pinned global, so nothing the fixtures do was changed or silently overridden.

Nothing present and unrequired. No third file touched. `POLICY.md` `baseline-count: 610` is unchanged,
which is correct for a task-level commit (625 > 610; invariant 7 asks only that the suite not fall
below the record).

## Invariant verdicts

1. **Zero runtime dependencies beyond bash/git/jq — PASS.** The new code uses `mktemp`, `printf`,
   `trap`, `export`. `mktemp` and `printf` were already used by `tests/run.sh` (line 68) and `env` was
   already used by `tests/test_bin.sh` (line 104, `rt high env FOREMAN_SKIP_BASELINE=1`). No new
   external program is introduced.
2. **Shebang / strict mode / chmod — PASS.** `tests/run.sh:1-2` still `#!/usr/bin/env bash` and
   `set -uo pipefail`; grep confirms `set` appears exactly once in the file and `-e` is not added.
   `git ls-tree HEAD` shows `100755` for both files. No `set` line was added to any sourced library.
   The block introduces the file's *only* `trap` (grep: one `EXIT` line, `tests/run.sh:18`), as the
   brief required, so nothing pre-existing is displaced.
3. **Exit-code contract — PASS.** The EXIT trap body is `rm -f "$FOREMAN_GIT_CONFIG"` and never calls
   `exit`, so bash preserves the original status. Verified empirically in the copy: a run with one
   failing assertion exits `1`; a green run exits `0`; the baseline gate's `exit 1` path is unaffected.
4. **Absolute paths — PASS.** `$rr` is `$FOREMAN_ROOT/tests/run.sh`; `mktemp`/`mktemp -d` return
   absolute paths; `FOREMAN_TESTS_DIR` and `FOREMAN_POLICY` are passed absolute.
5. **No TODO/TBD/FIXME under skills/agents/commands — N/A.** No markdown in the diff.
6. **Bare wrapper names — PASS (not engaged).** No call site under `skills/`, `agents/` or
   `commands/` is touched. The new test invokes `bash "$rr"` directly, exactly as the pre-existing
   baseline-gate tests in the same file already do via their `rt` helper; invariant 6 governs the
   prose tiers' call sites, not the runner's self-tests.
7. **Green and not below baseline — PASS.** 625/0 in the worktree, 625/0 in the isolated copy,
   625/0 under the hostile config. Baseline 610, delta +15.
8. **100-column markdown — N/A.** No shipped markdown in the diff. (`tests/test_bin.sh:130` is 119
   columns, but it is shell, and invariant 8 scopes to markdown body prose.)

## The four questions the dispatch asked

### Does the pinned config leak out of the runner?

**No.** Three separate checks.

- *Into the operator's environment:* `export` is process-scoped and `tests/run.sh` is executed with
  `bash`, never sourced, by the documented gate command. A probe that runs the suite and then prints
  `GIT_CONFIG_GLOBAL` in the calling shell prints `unset`.
- *Into the operator's repository or config files:* nothing is written outside `$(mktemp)`. The
  pinned file is a fresh temp file; `~/.gitconfig` is only ever read, never touched. No test commits
  into `$FOREMAN_ROOT` — every scratch commit in the suite goes to a `mktemp -d` repository.
- *Temp-file cleanup:* verified by running the suite with `TMPDIR` pointed at an empty directory and
  listing it afterwards: `count=0`. Nothing is left behind, neither the pinned config nor (a nice
  side effect) the `.git_signing_key_tmp*` files that git leaves when the operator's real
  `user.signingkey = key::ssh-ed25519 ...` is in play — with the export commented out, that same
  probe left **14** such files in `TMPDIR`; with the export in place, zero.

Nested invocations are safe: each nested `run.sh` (the `rt` helper's, and the new direction-2 one)
creates its own temp file, exports over the parent's value for its own process tree, and cleans up
its own file via its own EXIT trap. `FOREMAN_GIT_CONFIG` itself is deliberately *not* exported, so it
cannot collide with anything in a test file's shell.

### Does it mask a real failure by making a git operation trivially succeed?

**No, on the evidence available.**

- No shipped script creates a commit. `grep -rn "git" scripts/` finds exactly two `git` call sites:
  `scripts/lib.sh:19` (`rev-parse --show-toplevel`) and `scripts/phase-state.sh:117` (`git show`).
  Neither writes. So the pinned identity cannot mask a "the script should have set an identity"
  defect, because no script is ever in that position.
- No existing assertion expects a `git` command to *fail* for a reason the pin would remove. The
  negative paths in `test_phase_state.sh` use non-existent branches and malformed frontmatter, which
  the config cannot affect.
- `init.defaultBranch=main` masks nothing: every scratch repository in `test_phase_state.sh` already
  pins its branch explicitly with `git -C "$repo" symbolic-ref HEAD refs/heads/main` (lines 14, 103,
  131, 143, 163, 197, 239, 258), so the pin is redundant for them and load-bearing only for the new
  fixture, which asserts on it directly.
- The one operation the pin *does* make trivially succeed is signing, which is the whole point, and
  the suite has no assertion about signing to lose.

### Does it disturb per-assertion counting, or introduce `set -e`?

**No.** The block sits entirely above the loop (lines 7-18; loop begins line 43). It sets no shell
option, defines no function, and shadows no name used by the scoring logic (`count_lines`,
`total_pass`, `total_fail`, `files`, `results_file`, `completed`). It adds the file's only `trap`,
and traps are reset in the `bash -c` child that sources each test file, so no test file can clobber
it and it cannot interfere with the `D` sentinel or the `wait` reaping. Counting is empirically
identical: 623 before, 625 after, +2 = the one `_ok` plus the one `assert_exit` the new block adds.
The fixture file's own two assertions are scored by the nested runner and correctly never reach the
outer total, exactly as the report claims.

### Does it pin what it claims to pin?

**Partly — see Minor T2-M1.** The mechanism pins the global config *file* and suppresses the system
file. That is exactly what the brief specified, and it covers every realistic operator configuration,
including this machine's (`~/.gitconfig` with `commit.gpgsign = true`, `gpg.format = ssh`,
`user.signingkey = key::ssh-ed25519 ...`). It does **not** cover `GIT_CONFIG_PARAMETERS` or
`GIT_CONFIG_COUNT`, which the run.sh comment's wording implies it does.

Component-by-component, which pinned settings actually carry weight:

| Pinned setting | Load-bearing? | Evidence |
|---|---|---|
| `user.name` / `user.email` | **Yes** | A pinned config with no identity gives `commit_rc=128`; the direction-2 fixture sets no local identity, so it depends on this. |
| `init.defaultBranch = main` | **Yes** | Changing it to `trunk` in the copy turns the new outer assertion red. Without it, `git init` yields `master`. |
| `commit.gpgsign` / `tag.gpgsign` | **No** | See T2-M2. |
| `GIT_CONFIG_NOSYSTEM=1` | Untestable here | `/etc/gitconfig` does not exist on this machine; correctness follows from git's documented precedence (NOSYSTEM beats `GIT_CONFIG_SYSTEM`). |

## Ruling on the 12-vs-13 discrepancy

**Neither a miscount nor unanticipated coverage. The two numbers count different sets, and both are
right.**

I reproduced the mutation independently on the copy: commented out the `export GIT_CONFIG_GLOBAL=...`
line only (the config file is still written, the trap still cleans it), ran the whole suite under the
hostile config. Result: `14 files, 612 passed, 13 failed`, and the 13 FAIL lines are byte-identical
to the list in the implementer's report — 1 × `run.sh isolates every test's git commands from a
hostile global config` plus 12 × `tests/test_phase_state.sh`. Restored, re-ran: `625 passed, 0 failed`.

The plan's "12" is the count of **pre-existing** assertions the fix restores — the ones that were red
on the planning machine before this task existed. The report's "13" is the count of **all** assertions
the mutation turns red, which necessarily includes the new isolation assertion this task itself adds.
The plan's own Step 5 names both sets separately: the new assertion "must go red (and, with the agent
unreachable, the twelve `test_phase_state.sh` assertions with it)". 12 + 1 = 13. The gap is
arithmetic bookkeeping, not a defect, and the report already states this correctly.

## Test quality

Both new assertions are falsifiable, and I mutation-checked each independently rather than trusting
the report. Neither test was weakened nor deleted; nothing existing was removed.

**Direction 1** (`tests/test_bin.sh:127-130`). Claim: the hostile config really is hostile. Mutation:
in the copy, changed the hostile config's `gpgsign = true` to `false`. Result:
`FAIL: the hostile git config did not make a plain commit fail (rc=0); the isolation test below
proves nothing`, `624 passed, 1 failed` — the assertion goes red, alone, and names exactly the thing
that broke. Restored, green. This is the guard that makes direction 2 mean something, and it works.
It also self-guards against an old git without SSH-signing support, which would make the whole block
vacuous otherwise.

**Direction 2** (`tests/test_bin.sh:132-151`). Claim: the same commit, under the same hostile config,
succeeds when run through `run.sh`. Three independent mutations, each red:

- Comment out `export GIT_CONFIG_GLOBAL=...` → red (part of the 13 above).
- Change the pinned `defaultBranch = main` to `trunk` → `624 passed, 1 failed`, the isolation
  assertion alone.
- Remove the pinned identity → the fixture's commit returns 128 (verified by direct probe), so the
  nested runner exits 1 and the assertion goes red.

The nesting is sound: the fixture is invoked through `FOREMAN_TESTS_DIR` with `FOREMAN_POLICY`
pointed at a baseline-free file, so the nested run's exit status reflects only the fixture's
assertions and not the baseline gate; the nested runner recomputes `FOREMAN_ROOT` from `BASH_SOURCE`,
so `scripts/baseline-check.sh` still resolves. `rm -rf "$hostile_dir"` runs unconditionally
(`test_bin.sh` has no `set -e`), so a failure leaves nothing behind.

**The two directions do prove isolation in both directions,** as the plan's global constraint
requires: Y (the commit succeeding) is shown present under the fix, and X-broken (the config being
hostile) is shown to produce not-Y when the runner is out of the picture.

## Findings

### Minor [T2-M1] — the pin covers the global config file only; the comment claims more

`tests/run.sh:7-8` states: *"Every git command the suite runs, directly or through a script under
test, sees THIS global configuration and not the operator's."* The mechanism does not deliver that.
`GIT_CONFIG_GLOBAL` sits **below** `GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT/KEY_n/VALUE_n` in
git's precedence order, so either of those in the environment overrides the pin entirely.

Failure scenario, reproduced against the committed code with the fix fully in place:

```
GIT_CONFIG_PARAMETERS="'commit.gpgsign=true' 'gpg.format=ssh' 'user.signingkey=/nonexistent/k'" \
  bash tests/run.sh
  -> 14 files, 612 passed, 13 failed
```

`GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=true GIT_CONFIG_KEY_1=gpg.format
GIT_CONFIG_VALUE_1=ssh` produces the identical 13-red list. That is exactly the failure list of the
*unfixed* runner: for these two variables, the task's fix buys nothing.

Why this is reachable rather than theoretical: git itself exports `GIT_CONFIG_PARAMETERS` to every
subprocess of `git -c <key>=<value> ...`, and git hooks inherit it. A contributor who wires
invariant 7 ("`bash tests/run.sh` is green before every commit") into a `pre-commit` hook, or who
runs the gate through a `git` alias, is running the suite in exactly that environment. The same
class of hole covers `GIT_AUTHOR_*`, `GIT_COMMITTER_*`, `GIT_DIR`, `GIT_WORK_TREE` and
`GIT_INDEX_FILE`, none of which the pin neutralises.

Severity Minor, not Important, because the brief specified exactly `GIT_CONFIG_GLOBAL` +
`GIT_CONFIG_NOSYSTEM` and the implementation matches it verbatim; every ordinary operator
configuration, including this machine's, is fully covered; and no current documented invocation of
the gate sets these variables. Promote it if the program wants the §12.1 "green there" guarantee to
hold unconditionally.

Remedy, one line beside the export: `unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT` (optionally the
`GIT_AUTHOR_*`/`GIT_COMMITTER_*`/`GIT_DIR` family too). Or, if the narrower guarantee is the intended
one, narrow the comment to say "the operator's global configuration **file**".

### Minor [T2-M2] — `commit.gpgsign=false` / `tag.gpgsign=false` are inert and unfalsifiable

`tests/run.sh:15`. Because `GIT_CONFIG_GLOBAL` *replaces* the whole global file rather than layering
over it, and `GIT_CONFIG_NOSYSTEM=1` removes the system file, git's built-in default already means
"do not sign". Verified directly: a pinned config containing only the identity and
`init.defaultBranch` gives `commit_rc=0`. Deleting both lines therefore turns no assertion red — the
plan's constraint that every new element be mutation-checked is not met for these two.

They are harmless, and defensible as self-documenting intent (they name the thing the task exists to
neutralise). Recorded because a future reader could mistake them for the load-bearing part of the
fix — the load-bearing part is the *replacement* of the global file, which is what T2-M1's residual
hole is about. No behaviour change is required.

### Minor [T2-M3] — direction 2 collapses two claims into one opaque assertion

`tests/test_bin.sh:143-151`. The outer `assert_exit` observes only the nested runner's exit code, and
`assert_exit` discards the child's stdout and stderr (`"$@" >/dev/null 2>&1`), so the fixture's own
`FAIL:` line never reaches the operator. Verified: breaking the commit path and breaking the
`init.defaultBranch` pin produce the *same* message,
`run.sh isolates every test's git commands from a hostile global config (exit code): expected [0],
got [1]`, with nothing to distinguish them.

Failure scenario: a future change drops the pinned identity. The maintainer sees a message about
"a hostile global config" and has no indication that identity, not signing, is what broke.
Diagnosability only — the assertion does fail when it should, so nothing is unprotected. A second
`assert_exit` against a second single-claim fixture, or letting the nested stderr through, would fix
it.

### Minor [T2-M4] — the pin also discards `safe.directory` and friends

`tests/run.sh:13-17` replaces the operator's whole global config, which drops `safe.directory`,
`core.excludesFile`, `credential.helper` and any `[include]` along with the signing settings. On a
checkout git flags as dubious ownership — repo owned by a different uid, routine in containers and
CI-as-root — a contributor's global `safe.directory` workaround no longer applies inside the suite,
and `scripts/lib.sh:19` (`git rev-parse --show-toplevel`) would start failing, taking every test that
resolves the repo root with it.

Not observed: this machine has no global `safe.directory` (`~/.gitconfig` contains only credential,
gpg, user.signingkey, commit and tag sections) and the checkout is single-uid, so I could not
reproduce it. Flagged as a reasoned scenario. If the program targets containerised CI, adding
`[safe] directory = *` to the pinned config closes it.

## Deviations declared by the report

One, and it is **sound**. The brief's Step 4 predicted `618 passed` on the arithmetic "616 after
task 1, plus 2"; the actual result is 625, because task 1 landed at 623, not 616 — a number the
brief's author could not have known, since the brief predates task 1's implementation. The `+2`
delta this task contributes is exactly as specified, and I confirmed it structurally: the new block
adds precisely one `_ok` (direction 1) and one `assert_exit` (direction 2), and the fixture's own two
assertions are scored by the nested runner and never reach the outer total. 623 + 2 = 625.

The report's "what I could not verify" section is also faithful: the ambient failure mode does not
reproduce on this machine (the operator's signing key is reachable), and the implementer says so
plainly instead of claiming an ambient reproduction. Building the hostile condition by hand was the
right call, and the constructed condition is genuinely hostile — I confirmed that independently
before trusting anything downstream of it.

Every command output quoted in the report reproduces on my independent copy of the tree, including
the 13-line mutation list, character for character.

## Verdict

**Spec compliance: PASS. Quality: Approved.** Four Minors, none blocking. The runner's scoring
machinery is untouched, `set -e` is not introduced, the pin does not escape the process, it masks no
existing assertion, and both new assertions are genuinely falsifiable for the reasons they name.
