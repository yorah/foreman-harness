# Brief: task 2

Generated from `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites/docs/dev/plans/2026-09-02-prerequisites/task-2.md`. Do not read the rest of the plan.

| | |
|---|---|
| Worktree (absolute) | `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites` |
| Plan constraints | `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites/docs/dev/plans/2026-09-02-prerequisites/README.md` |
| Policy and invariants | `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites/docs/dev/program/POLICY.md` |
| Write your report to | `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites/docs/dev/program/phases/prerequisites/task-2-report.md` |

All paths above are absolute. Resolve every relative path in the task body
against the worktree, not against your working directory.

---

# Task 2: Runner pins git configuration

**Plan:** `docs/dev/plans/2026-09-02-prerequisites/README.md` — shared constraints and the task
table. Read its "Environment note" before running any gate command.

**Files:**
- Modify: `tests/run.sh` — after `export FOREMAN_ROOT`, before the test loop
- Modify: `tests/test_bin.sh` — a new section after the runner's baseline-gate section

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: every `git` command run by any test file, and by any script a test invokes, sees a
  global git config the runner wrote: identity `foreman-tests <foreman-tests@example.invalid>`,
  `commit.gpgsign=false`, `tag.gpgsign=false`, `init.defaultBranch=main`, and no system config
  (`GIT_CONFIG_NOSYSTEM=1`). Test files may still set repo-local config as they do today.

**Why this exists.** `tests/test_phase_state.sh` commits in scratch repositories. On a machine
whose global git config sets `commit.gpgsign=true` with an SSH signing key and no reachable
agent, every one of those commits fails and 12 assertions go red. Spec §12.1 requires the suite
green there. The runner is the one place that wraps every test, so the isolation lives in it,
not in each fixture.

---

- [ ] **Step 1: Write the failing test**

Append to `tests/test_bin.sh`, after the `rm -rf "$fix_dir"` line that closes the
baseline-gate section:

```bash
# --- the runner isolates git from the operator's configuration -----------------------------
# tests/test_phase_state.sh commits in scratch repositories. Under a global config that mandates
# signed commits with a key nobody can reach, every such commit fails and the suite goes red for
# a reason that is not in the tree. run.sh therefore pins GIT_CONFIG_GLOBAL for the whole run.
# Proven in both directions against the same hostile config: a commit run directly under it
# fails, and the same commit run through run.sh succeeds. Without the first direction, the
# second would pass on a config that was never hostile at all.
hostile_dir="$(mktemp -d)"
hostile_cfg="$hostile_dir/gitconfig"
printf '%s\n' '[user]' '	name = hostile' '	email = hostile@example.invalid' \
  '[gpg]' '	format = ssh' '[user]' '	signingkey = /nonexistent/foreman-hostile-signing-key' \
  '[commit]' '	gpgsign = true' > "$hostile_cfg"

# Direction 1: the hostile config really is hostile. A plain commit under it must fail.
hostile_repo="$hostile_dir/repo"
mkdir -p "$hostile_repo"
env GIT_CONFIG_GLOBAL="$hostile_cfg" GIT_CONFIG_NOSYSTEM=1 git -C "$hostile_repo" init -q
printf 'x\n' > "$hostile_repo/f"
env GIT_CONFIG_GLOBAL="$hostile_cfg" GIT_CONFIG_NOSYSTEM=1 git -C "$hostile_repo" add f
hostile_rc=0
env GIT_CONFIG_GLOBAL="$hostile_cfg" GIT_CONFIG_NOSYSTEM=1 \
  git -C "$hostile_repo" commit -qm "should fail" >/dev/null 2>&1 || hostile_rc=$?
if [ "$hostile_rc" -ne 0 ]; then _ok
else fail "the hostile git config did not make a plain commit fail (rc=0); the isolation test below proves nothing"; fi

# Direction 2: the same commit, inside a fixture test file run through run.sh, succeeds.
mkdir -p "$hostile_dir/tests"
cat > "$hostile_dir/tests/test_fixture.sh" <<'FIXTURE'
#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"
r="$(mktemp -d)"
git -C "$r" init -q
printf 'x\n' > "$r/f"
git -C "$r" add f
rc=0; git -C "$r" commit -qm "under the runner" >/dev/null 2>&1 || rc=$?
assert_eq "0" "$rc" "a commit inside a test succeeds regardless of the operator's git config"
assert_eq "main" "$(git -C "$r" symbolic-ref --short HEAD 2>/dev/null)" \
  "the runner pins init.defaultBranch=main for every scratch repository"
rm -rf "$r"
FIXTURE
printf '%s\n' 'no baseline recorded here' > "$hostile_dir/none.md"
assert_exit 0 "run.sh isolates every test's git commands from a hostile global config" -- \
  env GIT_CONFIG_GLOBAL="$hostile_cfg" GIT_CONFIG_NOSYSTEM=1 \
      FOREMAN_TESTS_DIR="$hostile_dir/tests" FOREMAN_POLICY="$hostile_dir/none.md" \
      bash "$rr"
rm -rf "$hostile_dir"
```

`rr` is already defined earlier in the file as `$FOREMAN_ROOT/tests/run.sh`.

- [ ] **Step 2: Run the test to verify it fails for the expected reason**

```bash
env PATH="/usr/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: exactly one new `FAIL`, `run.sh isolates every test's git commands from a hostile
global config (exit code): expected [0], got [1]`. The direction-1 assertion must already pass
(no `FAIL` naming "hostile git config did not make a plain commit fail"). If direction 1 fails,
the hostile config is not hostile on this machine; check that `/nonexistent/...` does not exist
and that `git --version` is at least 2.34 (SSH signing support).

- [ ] **Step 3: Implement the change in `tests/run.sh`**

Insert after the `export FOREMAN_ROOT` line:

```bash
# Every git command the suite runs, directly or through a script under test, sees THIS global
# configuration and not the operator's. A global config that mandates signed commits with a key
# this process cannot reach fails every scratch commit in test_phase_state.sh, twelve assertions
# on the machine this was written on, for a reason that is not in the tree. The identity is a
# placeholder so fixtures need not set one; the default branch is pinned so `git init` output is
# the same on every machine.
FOREMAN_GIT_CONFIG="$(mktemp)"
printf '%s\n' '[user]' '	name = foreman-tests' '	email = foreman-tests@example.invalid' \
  '[commit]' '	gpgsign = false' '[tag]' '	gpgsign = false' \
  '[init]' '	defaultBranch = main' > "$FOREMAN_GIT_CONFIG"
export GIT_CONFIG_GLOBAL="$FOREMAN_GIT_CONFIG" GIT_CONFIG_NOSYSTEM=1
trap 'rm -f "$FOREMAN_GIT_CONFIG"' EXIT
```

The tab characters inside the quoted strings are literal tabs (git's own indentation style);
spaces work too. `run.sh` has no `trap` today, so this one is the only one; do not add a second
`trap ... EXIT` elsewhere in the file, it would replace this one.

- [ ] **Step 4: Run the gate commands**

First the plain run. Task 1 has landed, so `PATH` no longer needs help, and this task removes
the need for `GIT_CONFIG_GLOBAL`:

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `14 files, 618 passed, 0 failed` (616 after task 1, plus 2: the direction-1 assertion
and the `assert_exit`; the fixture file's own two assertions are scored by the nested runner and
never reach this suite's total), exit 0. Then, to reproduce the condition §12.1 names, run once
with the signing agent unreachable:

```bash
env -u SSH_AUTH_SOCK bash tests/run.sh 2>&1 | tail -3
```

Expected: the same `618 passed, 0 failed`. Before this task, that command produced
`598 passed, 12 failed` on the planning machine.

- [ ] **Step 5: Mutation-check**

Temporarily comment out the `export GIT_CONFIG_GLOBAL=...` line in `run.sh` and run the suite:
`run.sh isolates every test's git commands from a hostile global config` must go red (and, with
the agent unreachable, the twelve `test_phase_state.sh` assertions with it). Restore. Run once
more, green.

- [ ] **Step 6: Commit**

```bash
git add tests/run.sh tests/test_bin.sh
git commit -m "tests: runner pins GIT_CONFIG_GLOBAL so scratch commits ignore the operator's signing config"
```
