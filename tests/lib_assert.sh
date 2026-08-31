#!/usr/bin/env bash
# Sourced by every test file. Requires $FOREMAN_ROOT and $FOREMAN_RESULTS_FILE.
# Deliberately no `set -euo pipefail` here: this file is sourced into the
# test file's shell, and adding strict mode here would change the test
# file's own error-handling semantics. That exemption is intentional.

_ok()   { printf 'P\n' >> "$FOREMAN_RESULTS_FILE"; }
_bad()  { printf 'F\n' >> "$FOREMAN_RESULTS_FILE"; printf '  FAIL: %s\n' "$1" >&2; }

fail() { _bad "$1"; }

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then _ok
  else _bad "$label: expected [$expected], got [$actual]"; fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  case "$haystack" in
    *"$needle"*) _ok ;;
    *) _bad "$label: [$needle] not found" ;;
  esac
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  case "$haystack" in
    *"$needle"*) _bad "$label: [$needle] should be absent" ;;
    *) _ok ;;
  esac
}

# assert_exit <expected-code> <label> -- <command...>
assert_exit() {
  local expected="$1" label="$2"; shift 2
  [ "$1" = "--" ] && shift
  local code=0
  "$@" >/dev/null 2>&1 || code=$?
  assert_eq "$expected" "$code" "$label (exit code)"
}
