#!/usr/bin/env bash
set -uo pipefail

FOREMAN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FOREMAN_ROOT

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

total_pass=0
total_fail=0
files=0

# Count lines exactly equal to $1 in file $2. grep -c always yields an
# integer on stdout, so no arithmetic here ever touches unvalidated text.
# grep exits 1 (not an error) on zero matches, and the file may not exist
# at all, so both cases are normalized to a count of 0.
count_lines() {
  local pattern="$1" file="$2" n
  [ -f "$file" ] || { printf '0'; return; }
  n="$(grep -c "^${pattern}\$" "$file" 2>/dev/null)" || true
  [ -n "$n" ] || n=0
  printf '%s' "$n"
}

# FOREMAN_TESTS_DIR lets a caller point the runner at a different set of test files. It exists
# so tests/test_bin.sh can exercise the baseline gate below against a one-file fixture directory
# instead of re-running this whole suite: a nested full run would execute test_bin.sh again and
# spawn another, and the earlier env-var guard against that could be silently switched off from
# outside, dropping three assertions while still reporting green.
tests_dir="${FOREMAN_TESTS_DIR:-$FOREMAN_ROOT/tests}"

for t in "$tests_dir"/test_*.sh; do
  [ -e "$t" ] || continue
  files=$((files + 1))
  printf '%s\n' "$(basename "$t")"

  # The runner scores the run itself, from a per-assertion record: one
  # "P" or "F" line per assertion, appended by lib_assert.sh as it runs
  # -- never a summary the test computes and reports back. The runner
  # also appends its own "D" sentinel line right after the test file
  # finishes sourcing (and after `wait`, see below); if the test calls
  # `exit` early (even `exit 0`), that line is never written, so an
  # early exit is caught even when the test's own explicit exit code
  # looks clean.
  #
  # `wait` reaps any jobs the test file backgrounded (e.g.
  # `( ... assert_eq ... ) &`) before the D sentinel is appended, so a
  # backgrounded assertion's P/F line is guaranteed on disk before
  # run.sh reads and removes the results file -- otherwise a failing
  # backgrounded assertion can lose its race against the parent already
  # scoring the file. `code=$?` is captured immediately after `source`
  # returns, and the wrapper re-exits with that exact value at the end,
  # so the status run.sh scores is still the test file's own -- not
  # `wait`'s (whose own status is discarded via `|| true` so a failed
  # background job can't itself abort the wrapper under a test's own
  # `set -e`, before the D sentinel gets written).
  results_file="$(mktemp)"

  FOREMAN_RESULTS_FILE="$results_file" bash -c '
    source "$1"
    code=$?
    wait || true
    printf "D\n" >> "$FOREMAN_RESULTS_FILE"
    exit "$code"
  ' _ "$t"
  exit_code=$?

  pass="$(count_lines P "$results_file")"
  fail="$(count_lines F "$results_file")"
  completed="$(count_lines D "$results_file")"
  rm -f "$results_file"

  if [ "$exit_code" -ne 0 ] || [ "$completed" -eq 0 ]; then
    printf '  FAIL: %s aborted before reporting counts\n' "$(basename "$t")" >&2
    total_fail=$((total_fail + 1))
    continue
  fi

  if [ "$((pass + fail))" -eq 0 ]; then
    printf '  FAIL: %s ran no assertions\n' "$(basename "$t")" >&2
    total_fail=$((total_fail + 1))
    continue
  fi

  total_pass=$((total_pass + pass))
  total_fail=$((total_fail + fail))
done

printf '\n%s files, %s passed, %s failed\n' "$files" "$total_pass" "$total_fail"

# --- the baseline gate ----------------------------------------------------
# Validating POLICY.md's recorded baseline against the suite's real total cannot live inside a
# test file: a test cannot know the suite's own total without re-running it. It belongs HERE --
# the runner is not a test, and total_pass is final at this point. Routing it into the gate
# chain instead would put the one check that validates the baseline into model prose, which is
# the trade this project says it does not make.
#
# No new comparison logic: it calls the already-tested scripts/baseline-check.sh and honours
# that script's exit contract. 1 is a definite "below" and fails the run; 2 is "cannot
# determine" and must NOT fail it, because an unreadable POLICY.md is not a test regression.
# FOREMAN_SKIP_BASELINE=1 exists for a deliberate below-baseline refactor; FOREMAN_POLICY
# points the check at another file, which is what makes this gate itself testable.
policy="${FOREMAN_POLICY:-$FOREMAN_ROOT/docs/dev/program/POLICY.md}"
if [ "$total_fail" -eq 0 ] && [ -f "$policy" ] && [ "${FOREMAN_SKIP_BASELINE:-0}" != "1" ]; then
  bl_code=0
  "$FOREMAN_ROOT/scripts/baseline-check.sh" --policy "$policy" --count "$total_pass" \
    >/dev/null 2>&1 || bl_code=$?
  if [ "$bl_code" -eq 1 ]; then
    printf '  FAIL: %s passed is below the baseline POLICY.md records\n' "$total_pass" >&2
    exit 1
  elif [ "$bl_code" -eq 2 ]; then
    printf '  WARNING: baseline could not be read from %s; not gating on it\n' "$policy" >&2
  fi
fi

[ "$total_fail" -eq 0 ]
