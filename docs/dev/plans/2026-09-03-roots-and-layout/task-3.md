# Task 3: The runner isolates `GIT_DIR` and `GIT_CONFIG_COUNT` `[T2-R1-M4]` `[T2-R1-M1]`

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Modify: `tests/run.sh` — the one `unset` line and the comment above it
- Modify: `tests/test_bin.sh` — append one block at the end
- Modify: `docs/dev/backlog.md` — close `[T2-R1-M1]` and `[T2-R1-M4]`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing other tasks call. `tests/run.sh` unsets `GIT_DIR`, `GIT_WORK_TREE` and
  `GIT_INDEX_FILE` alongside the two variables it already unsets.

**Why this exists.** Phase A's task 2 reviewer reproduced the suite **committing five branches
into a victim repository while reporting 624 passed, 4 failed**: with `GIT_DIR` in the
environment, every `git -C <scratch>` in every fixture writes to the repository `GIT_DIR` names.
This phase adds two more test files full of scratch repositories (tasks 1 and 2) and one that
creates a linked worktree, so the exposure grows before it shrinks. One line fixes it; the
assertions are what stop it coming back. `[T2-R1-M1]` is the same file's other gap: the
`GIT_CONFIG_COUNT` half of the existing `unset` had no assertion, so removing it left the suite
green.

---

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_bin.sh`:

```bash

# --- [T2-R1-M4] an inherited GIT_DIR must not redirect the suite's git commands -----------------
# With GIT_DIR (and GIT_WORK_TREE) exported, `git -C <scratch> commit` writes into the repository
# GIT_DIR names, not the scratch one -- the reviewer saw this suite commit five branches into a
# victim repository while reporting a nearly clean run. Both directions, against a real victim.
gd_dir="$(mktemp -d)"
victim="$gd_dir/victim"
mkdir -p "$victim"
git -C "$victim" init -q
git -C "$victim" commit -q --allow-empty -m "victim base"
victim_before="$(git -C "$victim" rev-parse HEAD)"

# Direction 1: the exposure is real. A commit aimed at an unrelated scratch directory lands in
# the victim when GIT_DIR points there.
gd_scratch="$gd_dir/scratch"
mkdir -p "$gd_scratch"
env GIT_DIR="$victim/.git" GIT_WORK_TREE="$victim" \
  git -C "$gd_scratch" commit -q --allow-empty -m "leaked" >/dev/null 2>&1 || true
if [ "$(git -C "$victim" rev-parse HEAD)" != "$victim_before" ]; then _ok
else fail "GIT_DIR did not redirect a commit into the victim; the isolation test below proves nothing"; fi
git -C "$victim" reset -q --hard "$victim_before"

# Direction 2: the same environment, inherited by run.sh, reaches no test's git commands.
mkdir -p "$gd_dir/tests"
cat > "$gd_dir/tests/test_fixture.sh" <<'FIXTURE_GITDIR'
#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"
r="$(mktemp -d)"
git -C "$r" init -q
rc=0; git -C "$r" commit -q --allow-empty -m "under the runner" >/dev/null 2>&1 || rc=$?
assert_eq "0" "$rc" "a commit inside a test succeeds with GIT_DIR exported outside the runner"
assert_eq "$(cd "$r" && pwd -P)" "$(git -C "$r" rev-parse --show-toplevel 2>/dev/null)" \
  "the commit's repository is the scratch one, not the one GIT_DIR named"
rm -rf "$r"
FIXTURE_GITDIR
printf '%s\n' 'no baseline recorded here' > "$gd_dir/none.md"
assert_exit 0 "run.sh neutralises an inherited GIT_DIR and GIT_WORK_TREE" -- \
  env GIT_DIR="$victim/.git" GIT_WORK_TREE="$victim" \
      FOREMAN_TESTS_DIR="$gd_dir/tests" FOREMAN_POLICY="$gd_dir/none.md" bash "$rr"
assert_eq "$victim_before" "$(git -C "$victim" rev-parse HEAD)" \
  "the victim repository is untouched by a whole run under an inherited GIT_DIR"

# --- [T2-R1-M1] the GIT_CONFIG_COUNT half of the unset, asserted in both directions -----------
# GIT_CONFIG_COUNT/KEY_n/VALUE_n is the other environment-level config override; it sits above
# the global file in precedence exactly as GIT_CONFIG_PARAMETERS does, and until now removing it
# from run.sh's unset left the suite green.
cc_env=(GIT_CONFIG_COUNT=3
        GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=true
        GIT_CONFIG_KEY_1=gpg.format     GIT_CONFIG_VALUE_1=ssh
        GIT_CONFIG_KEY_2=user.signingkey GIT_CONFIG_VALUE_2=/nonexistent/foreman-hostile-signing-key)
cc_repo="$gd_dir/cc"
mkdir -p "$cc_repo"
git -C "$cc_repo" init -q
printf 'x\n' > "$cc_repo/f"
git -C "$cc_repo" add f
cc_rc=0
env "${cc_env[@]}" git -C "$cc_repo" commit -qm "should fail" >/dev/null 2>&1 || cc_rc=$?
if [ "$cc_rc" -ne 0 ]; then _ok
else fail "GIT_CONFIG_COUNT did not make a plain commit fail (rc=0); the isolation test below proves nothing"; fi
assert_exit 0 "run.sh neutralises an inherited GIT_CONFIG_COUNT override" -- \
  env "${cc_env[@]}" FOREMAN_TESTS_DIR="$gd_dir/tests" FOREMAN_POLICY="$gd_dir/none.md" bash "$rr"
rm -rf "$gd_dir"
```

`$rr` is already defined earlier in the file as `$FOREMAN_ROOT/tests/run.sh`.

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: exactly one red line, `run.sh neutralises an inherited GIT_DIR and GIT_WORK_TREE`
(the nested run's fixture assertion `the commit's repository is the scratch one` fails inside it,
and `the victim repository is untouched` may go red too). The `GIT_CONFIG_COUNT` assertions are
green already — that is the point of `[T2-R1-M1]`: they exist so that removing the variable from
the `unset` goes red, which Step 5 confirms.

- [ ] **Step 3: Implement**

In `tests/run.sh`, change

```bash
unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
```

to

```bash
unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
```

and in the comment block above it, after the sentence ending `so both are unset here too.`, add:

```
# GIT_DIR, GIT_WORK_TREE and GIT_INDEX_FILE are unset for a different reason: they redirect
# *every* git command in every fixture at one repository, so a suite run with GIT_DIR inherited
# commits its scratch branches into whatever that variable names while reporting a nearly clean
# run -- observed, not hypothetical (phase A, [T2-R1-M4]).
```

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, `+5` on the count before this task.

- [ ] **Step 5: Mutation-check the new assertions**

Temporarily remove `GIT_DIR GIT_WORK_TREE` from the `unset`: both `GIT_DIR` direction-2
assertions go red. Restore. Temporarily remove `GIT_CONFIG_COUNT` from the `unset`:
`run.sh neutralises an inherited GIT_CONFIG_COUNT override` goes red. Restore. Run the suite
once more, green.

- [ ] **Step 6: Close the backlog items and commit**

In `docs/dev/backlog.md`, change `- [ ] [T2-R1-M1]` and `- [ ] [T2-R1-M4]` to `- [x]`, and
append to each a sentence: `**Closed 2026-09-03, phase B task 3:** run.sh unsets GIT_DIR,
GIT_WORK_TREE and GIT_INDEX_FILE; both halves of the unset are asserted in both directions in
tests/test_bin.sh.` (wrapped at 100 columns).

```bash
git add tests/run.sh tests/test_bin.sh docs/dev/backlog.md
git commit -m "tests: runner unsets GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE; both unset halves asserted [T2-R1-M4] [T2-R1-M1]"
```
