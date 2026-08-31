#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

# Every other test file in this suite routes its assertions through lib_assert.sh, and until
# this file existed, nothing routed an assertion at lib_assert.sh itself. That made it the one
# place where making a red suite green leaves no trace: changing `_bad` to append a "P" instead
# of an "F" makes the runner report "12 files, 570 passed, 0 failed" and exit 0, with every
# real failure still silently printing to stderr where the gate chain never looks.
# Mutation-verified before this file was written: that single-character edit left the whole
# suite green. It does not any more.
#
# The library is exercised in a SUBSHELL with its own FOREMAN_RESULTS_FILE, so the records it
# writes under test are counted here as data rather than added to this file's own score.

# probe <snippet> -- prints the P/F record letters the library appended, joined, e.g. "F" or "PP".
probe() {
  local rf out
  rf="$(mktemp)"
  FOREMAN_RESULTS_FILE="$rf" bash -c '
    source "$FOREMAN_ROOT/tests/lib_assert.sh"
    eval "$1"
  ' _ "$1" >/dev/null 2>&1
  out="$(tr -d '\n' < "$rf")"
  rm -f "$rf"
  printf '%s' "$out"
}

# probe_err <snippet> -- prints what the library wrote to STDERR.
probe_err() {
  local rf out
  rf="$(mktemp)"
  out="$(FOREMAN_RESULTS_FILE="$rf" bash -c '
    source "$FOREMAN_ROOT/tests/lib_assert.sh"
    eval "$1"
  ' _ "$1" 2>&1 >/dev/null)"
  rm -f "$rf"
  printf '%s' "$out"
}

# must <expected> <actual> <label>  /  must_contains <haystack> <needle> <label>
#
# These deliberately do NOT route a mismatch through lib_assert.sh's own `fail`. This file
# tests that library, and the exact failure it exists to catch -- `_bad` recording a "P" --
# is the failure that would swallow a `fail` call made here.
#
# Mutation-verified, and the first version of this file got it wrong: with `_bad` mutated to
# append "P", routing these checks through `assert_eq` printed seven detections to stderr and
# still finished "13 files, 586 passed, 0 failed", rc=0 -- the detections were themselves
# scored as passes. A hard `exit 1` cannot be scored away: run.sh sees a non-zero test file and
# records "aborted before reporting counts", which fails the run whatever the library claims.
#
# A pass still goes through `_ok` so it counts toward the suite total. That direction is safe:
# an `_ok` that stopped recording would lower the count and trip the baseline gate.
must() {
  if [ "$1" = "$2" ]; then _ok; return; fi
  printf '  FAIL: %s: expected [%s], got [%s]\n' "$3" "$1" "$2" >&2
  printf '  FAIL: lib_assert.sh is not reporting failures; every count in this run is suspect\n' >&2
  exit 1
}

must_contains() {
  case "$1" in
    *"$2"*) _ok; return ;;
  esac
  printf '  FAIL: %s: [%s] not found in [%s]\n' "$3" "$2" "$1" >&2
  printf '  FAIL: lib_assert.sh is not reporting failures; every count in this run is suspect\n' >&2
  exit 1
}

# The probe is an instrument, and an instrument that cannot fire reports a clean bill of health
# for a broken library. Establish that it distinguishes the two letters before trusting either.
must "P" "$(probe '_ok')"            "the probe observes a recorded pass"
must "F" "$(probe 'fail "planted"')" "the probe observes a recorded failure"

# --- every assertion in the library, in BOTH directions ---------------------
# One direction alone proves nothing: a library that always records P satisfies every
# positive case, and one that always records F satisfies every negative case.
must "P" "$(probe 'assert_eq a a "x"')" "assert_eq records a pass when the values match"
must "F" "$(probe 'assert_eq a b "x"')" "assert_eq records a failure when the values differ"

must "P" "$(probe 'assert_contains haystack stack "x"')" \
  "assert_contains records a pass when the needle is present"
must "F" "$(probe 'assert_contains haystack absent "x"')" \
  "assert_contains records a failure when the needle is missing"

must "P" "$(probe 'assert_not_contains haystack absent "x"')" \
  "assert_not_contains records a pass when the needle is missing"
must "F" "$(probe 'assert_not_contains haystack stack "x"')" \
  "assert_not_contains records a failure when the needle is present"

must "P" "$(probe 'assert_exit 0 "x" -- true')" \
  "assert_exit records a pass when the command exits as expected"
must "F" "$(probe 'assert_exit 0 "x" -- false')" \
  "assert_exit records a failure when the command exits otherwise"

# 0, 1 and 2 mean different things throughout this system, so assert_exit must distinguish
# them rather than collapsing "not zero" into one bucket.
must "P" "$(probe 'assert_exit 2 "x" -- sh -c "exit 2"')" \
  "assert_exit matches a non-zero code exactly"
must "F" "$(probe 'assert_exit 1 "x" -- sh -c "exit 2"')" \
  "assert_exit does not accept one non-zero code for another"

# --- one assertion records exactly one letter -------------------------------
# A library that appended two letters, or none, would keep every check above green while
# making the runner's totals fiction.
must "PPF" "$(probe 'assert_eq a a "1"; assert_contains ab b "2"; fail "3"')" \
  "each assertion appends exactly one record, in order"

# --- a failure is reported, not merely counted ------------------------------
# The count is what the gate reads; the message is what a human debugging a red suite reads.
# A library that recorded F silently would pass every check above.
must_contains "$(probe_err 'assert_eq apple orange "the label"')" "FAIL: the label" \
  "a failure names its label on stderr"
must_contains "$(probe_err 'assert_eq apple orange "the label"')" "expected [apple], got [orange]" \
  "a failure reports both values, not just that it failed"
must "" "$(probe_err 'assert_eq a a "the label"')" \
  "a passing assertion is silent on stderr"
