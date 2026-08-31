# Task 3: `scripts/task-brief.sh`

Implements spec §11.1. Extracts one task from a plan directory into a brief a subagent can be
handed. Guards the two failure classes `dockbrr` hit in its Phase 7: a stale brief left over
from an earlier phase, and a relative path resolved against the wrong checkout.

**Files:**
- Create: `scripts/task-brief.sh`
- Test: `tests/test_task_brief.sh`

**Interfaces:**
- Consumes: `scripts/lib.sh` (`harness_die`, `harness_require_abs`) from Task 2.
- Produces, for Task 6:
  - `scripts/task-brief.sh --plan <abs-plan-dir> --task <N> --phase-dir <abs-dir>
    --worktree <abs-dir> [--policy <abs-path>]`
  - Writes `<phase-dir>/task-<N>-brief.md`, truncating any existing file.
  - Prints the absolute brief path on stdout. Exit `0` written, `2` any validation failure
    (and no file is written or modified on failure).


> **Historical reference code.** The code blocks below are the plan as written *before*
> execution. Several were superseded by fix rounds during execution and are **not** what shipped.
> For one example — from a sibling plan, not this file — `task-2.md`'s model check shows a
> substring match (`*opus*|*fable*`) that the shipped `resolve-gate.sh` replaced with whole-token
> matching because the substring form accepts `notopus` and `fabled`. **The files in the
> repository are authoritative; this document records intent, not current behaviour.** Tracked
> as `[T-PLAN]` in `docs/dev/backlog.md`.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_task_brief.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$HARNESS_ROOT/tests/lib_assert.sh"

tb="$HARNESS_ROOT/scripts/task-brief.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

plan="$tmp/plan"; phase="$tmp/phase"; wt="$tmp/worktree"
mkdir -p "$plan" "$phase" "$wt"

printf '%s\n' '# Example Plan' '## Global Constraints' '- Python 3.8 only.' > "$plan/README.md"
printf '%s\n' '# Task 1: first thing' '' 'Body of task one. UNIQUE_ONE' > "$plan/task-1.md"
printf '%s\n' '# Task 2: second thing' '' 'Body of task two. UNIQUE_TWO' > "$plan/task-2.md"
printf '%s\n' '# Task 9: mislabelled' '' 'Body nine.' > "$plan/task-8.md"

run() { "$tb" --plan "$plan" --phase-dir "$phase" --worktree "$wt" "$@" 2>/dev/null; }

# --- happy path -----------------------------------------------------------
out="$(run --task 1)"
assert_eq "$phase/task-1-brief.md" "$out" "stdout is the absolute brief path"
[ -f "$out" ] || fail "brief file was not created"
body="$(cat "$out")"
assert_contains "$body" "UNIQUE_ONE"      "brief carries the task body"
assert_contains "$body" "$wt"             "brief names the absolute worktree path"
assert_contains "$body" "$plan/README.md" "brief points at the plan README"
assert_not_contains "$body" "UNIQUE_TWO"  "brief does not leak a neighbouring task"

out2="$(run --task 2)"
assert_contains "$(cat "$out2")" "UNIQUE_TWO" "task 2 brief carries task 2"
assert_not_contains "$(cat "$out2")" "UNIQUE_ONE" "task 2 brief excludes task 1"

# --- stale-brief guard: regeneration truncates ----------------------------
printf '%s\n' 'STALE CONTENT FROM AN EARLIER PHASE' > "$phase/task-1-brief.md"
run --task 1 >/dev/null
assert_not_contains "$(cat "$phase/task-1-brief.md")" "STALE CONTENT" \
  "regenerating a brief truncates the stale one"
assert_contains "$(cat "$phase/task-1-brief.md")" "UNIQUE_ONE" \
  "regenerated brief has the current body"

# --- heading guard --------------------------------------------------------
assert_exit 2 "heading/number mismatch refuses" -- \
  "$tb" --plan "$plan" --phase-dir "$phase" --worktree "$wt" --task 8
[ -f "$phase/task-8-brief.md" ] && fail "a refused extraction must not write a file"
_ok_noop=1

# --- path validation ------------------------------------------------------
assert_exit 2 "relative --phase-dir refuses" -- \
  "$tb" --plan "$plan" --phase-dir "phase" --worktree "$wt" --task 1
assert_exit 2 "relative --plan refuses" -- \
  "$tb" --plan "plan" --phase-dir "$phase" --worktree "$wt" --task 1
assert_exit 2 "relative --worktree refuses" -- \
  "$tb" --plan "$plan" --phase-dir "$phase" --worktree "wt" --task 1

# --- missing inputs -------------------------------------------------------
assert_exit 2 "missing task file refuses" -- \
  "$tb" --plan "$plan" --phase-dir "$phase" --worktree "$wt" --task 42
assert_exit 2 "missing --task refuses" -- \
  "$tb" --plan "$plan" --phase-dir "$phase" --worktree "$wt"
assert_exit 2 "non-numeric --task refuses" -- \
  "$tb" --plan "$plan" --phase-dir "$phase" --worktree "$wt" --task abc

rm -f "$plan/README.md"
assert_exit 2 "plan without a README refuses" -- \
  "$tb" --plan "$plan" --phase-dir "$phase" --worktree "$wt" --task 1
```

Note the `_ok_noop=1` line: `[ -f ... ] && fail ...` would return non-zero when the file is
correctly absent, and under the runner that is harmless, but the assignment makes the intent
explicit and keeps the line's exit status zero.

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run.sh`
Expected: FAIL, naming `task-brief.sh`. Task 2's tests must still pass — confirm the summary
line shows the earlier suite green.

- [ ] **Step 3: Write `scripts/task-brief.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

plan=""; task=""; phase_dir=""; worktree=""; policy=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plan)      [ $# -ge 2 ] || harness_die "$1 requires a value" 2; plan="$2"; shift 2 ;;
    --task)      [ $# -ge 2 ] || harness_die "$1 requires a value" 2; task="$2"; shift 2 ;;
    --phase-dir) [ $# -ge 2 ] || harness_die "$1 requires a value" 2; phase_dir="$2"; shift 2 ;;
    --worktree)  [ $# -ge 2 ] || harness_die "$1 requires a value" 2; worktree="$2"; shift 2 ;;
    --policy)    [ $# -ge 2 ] || harness_die "$1 requires a value" 2; policy="$2"; shift 2 ;;
    *) harness_die "unknown argument: $1" 2 ;;
  esac
done

[ -n "$plan" ]      || harness_die "--plan is required" 2
[ -n "$task" ]      || harness_die "--task is required" 2
[ -n "$phase_dir" ] || harness_die "--phase-dir is required" 2
[ -n "$worktree" ]  || harness_die "--worktree is required" 2

case "$task" in
  ''|*[!0-9]*) harness_die "--task must be a number, got: $task" 2 ;;
esac

harness_require_abs "$plan" "--plan"
harness_require_abs "$phase_dir" "--phase-dir"
harness_require_abs "$worktree" "--worktree"
[ -n "$policy" ] && harness_require_abs "$policy" "--policy"

readme="$plan/README.md"
src="$plan/task-$task.md"
[ -d "$plan" ]     || harness_die "plan directory not found: $plan" 2
[ -f "$readme" ]   || harness_die "plan has no README.md: $readme" 2
[ -f "$src" ]      || harness_die "no such task file: $src" 2
[ -d "$phase_dir" ] || harness_die "phase directory not found: $phase_dir" 2

# Heading guard: the first heading must name this task number. A brief whose heading
# disagrees with the file it came from is the stale-brief bug wearing a disguise.
heading="$(grep -m1 -E '^#+[[:space:]]' "$src" || true)"
[ -n "$heading" ] || harness_die "task file has no heading: $src" 2
printf '%s' "$heading" | grep -qiE "^#+[[:space:]]+Task[[:space:]]+$task([^0-9]|$)" \
  || harness_die "heading does not name Task $task: $heading" 2

dest="$phase_dir/task-$task-brief.md"

{
  printf '# Brief: task %s\n\n' "$task"
  printf 'Generated from `%s`. Do not read the rest of the plan.\n\n' "$src"
  printf '| | |\n|---|---|\n'
  printf '| Worktree (absolute) | `%s` |\n' "$worktree"
  printf '| Plan constraints | `%s` |\n' "$readme"
  [ -n "$policy" ] && printf '| Policy and invariants | `%s` |\n' "$policy"
  printf '| Write your report to | `%s/task-%s-report.md` |\n' "$phase_dir" "$task"
  printf '\n'
  printf 'All paths above are absolute. Resolve every relative path in the task body\n'
  printf 'against the worktree, not against your working directory.\n\n'
  printf -- '---\n\n'
  cat "$src"
} > "$dest"

printf '%s\n' "$dest"
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
chmod +x scripts/task-brief.sh tests/test_task_brief.sh
bash tests/run.sh
```

Expected: `0 failed`, and the passing count strictly above Task 2's baseline.

- [ ] **Step 5: Verify the heading guard against this very plan**

```bash
mkdir -p /tmp/harness-brief-check
scripts/task-brief.sh \
  --plan "$PWD/docs/dev/plans/2026-08-28-harness-v1" \
  --task 3 --phase-dir /tmp/harness-brief-check --worktree "$PWD"
head -20 /tmp/harness-brief-check/task-3-brief.md
rm -rf /tmp/harness-brief-check
```

Expected: the brief is written, its header names `$PWD` as the worktree, and its body is this
file. Real input, not a fixture.

- [ ] **Step 6: Commit**

```bash
git add scripts/task-brief.sh tests/test_task_brief.sh
git commit -m "feat(brief): extract one plan task into a brief, with a stale-brief guard"
```
