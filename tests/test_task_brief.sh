#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

tb="$FOREMAN_ROOT/scripts/task-brief.sh"
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

# --- write-failure guards --------------------------------------------------
# A --phase-dir that exists but is not writable must not silently succeed, and must not be
# reported as exit 1 (a definite negative) -- it's an environment problem, so exit 2.
nowrite_phase="$tmp/nowrite_phase"
mkdir -p "$nowrite_phase"
chmod 500 "$nowrite_phase"
assert_exit 2 "non-writable --phase-dir refuses" -- \
  "$tb" --plan "$plan" --phase-dir "$nowrite_phase" --worktree "$wt" --task 1
chmod 700 "$nowrite_phase"
[ -e "$nowrite_phase/task-1-brief.md" ] && fail "non-writable phase-dir must not create a file"
_ok_noop=1

# A destination file that already exists and holds a good brief must survive byte-for-byte if
# it, specifically, is not writable (even though its parent directory is) -- a refusal must
# never damage a pre-existing good brief.
protect_phase="$tmp/protect_phase"
mkdir -p "$protect_phase"
"$tb" --plan "$plan" --phase-dir "$protect_phase" --worktree "$wt" --task 1 >/dev/null 2>&1
before="$(cat "$protect_phase/task-1-brief.md")"
chmod 400 "$protect_phase/task-1-brief.md"
assert_exit 2 "non-writable existing brief file refuses" -- \
  "$tb" --plan "$plan" --phase-dir "$protect_phase" --worktree "$wt" --task 1
chmod 600 "$protect_phase/task-1-brief.md"
after="$(cat "$protect_phase/task-1-brief.md")"
assert_eq "$before" "$after" "non-writable existing brief is byte-identical afterwards"

# A destination path that is itself a directory must refuse, not clobber.
dirdest_phase="$tmp/dirdest_phase"
mkdir -p "$dirdest_phase/task-1-brief.md"
assert_exit 2 "destination path being a directory refuses" -- \
  "$tb" --plan "$plan" --phase-dir "$dirdest_phase" --worktree "$wt" --task 1

# --- mid-write failure guard -------------------------------------------------
# The pre-flight write-ability checks above cannot catch a failure that only shows up partway
# through the write itself (a full filesystem, a disk quota, a ulimit, a signal). Forced here
# with `ulimit -f` against a deliberately large task body: the cap is sized well below the
# brief's total size (so the write is genuinely interrupted mid-stream, not merely refused up
# front) but comfortably above the length of any diagnostic bash itself might print about the
# interruption, so that message can never itself collide with the same limit and produce a
# misleading result. A failure here must still exit 2, not whatever raw status an interrupted
# write happens to produce, and the pre-existing good brief must survive byte-identical.
ulimit_plan="$tmp/ulimit_plan"; ulimit_phase="$tmp/ulimit_phase"
mkdir -p "$ulimit_plan" "$ulimit_phase"
printf '%s\n' '# Example Plan' '## Global Constraints' '- x' > "$ulimit_plan/README.md"
{
  printf '%s\n' '# Task 1: first thing' '' 'Body of task one. UNIQUE_ONE'
  for i in $(seq 1 600); do printf '%0100d\n' "$i"; done
} > "$ulimit_plan/task-1.md"
"$tb" --plan "$ulimit_plan" --phase-dir "$ulimit_phase" --worktree "$wt" --task 1 >/dev/null 2>&1
before_ul="$(cat "$ulimit_phase/task-1-brief.md")"
(
  ulimit -f 40
  "$tb" --plan "$ulimit_plan" --phase-dir "$ulimit_phase" --worktree "$wt" --task 1
) >/dev/null 2>&1
ul_code=$?
assert_eq 2 "$ul_code" "mid-write failure under a tight ulimit exits 2"
after_ul="$(cat "$ulimit_phase/task-1-brief.md")"
assert_eq "$before_ul" "$after_ul" "mid-write failure leaves the existing brief byte-identical"
ul_leftover="$(find "$ulimit_phase" -maxdepth 1 -name '.task-*' | wc -l)"
assert_eq "0" "$ul_leftover" "mid-write failure leaves no temp file behind"

rm -f "$plan/README.md"
assert_exit 2 "plan without a README refuses" -- \
  "$tb" --plan "$plan" --phase-dir "$phase" --worktree "$wt" --task 1
