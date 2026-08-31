#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

policy=""; count=""
while [ $# -gt 0 ]; do
  case "$1" in
    --policy) [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; policy="$2"; shift 2 ;;
    --count)  [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; count="$2"; shift 2 ;;
    *) foreman_die "unknown argument: $1" 2 ;;
  esac
done

[ -n "$policy" ] || foreman_die "--policy is required" 2
[ -n "$count" ]  || foreman_die "--count is required" 2
case "$count" in ''|*[!0-9]*) foreman_die "--count must be a number, got: $count" 2 ;; esac

# Reject a digit run too long to fit safely in signed 64-bit arithmetic (over 18 digits) before
# any arithmetic touches it. A longer run can silently wrap negative via bash's `10#` parsing
# below, turning a catastrophic test-count regression into a false `pass` -- refuse it outright
# instead.
if [ "${#count}" -gt 18 ]; then
  foreman_die "--count has too many digits to represent safely (max 18): $count" 2
fi

foreman_require_abs "$policy" "--policy"
[ -f "$policy" ] || foreman_die "policy file not found: $policy" 2

# Force base-10 everywhere arithmetic touches a digit string. Bash arithmetic treats a
# leading-zero numeral as octal, which crashes (or misparses) on values like "008" or "09" --
# `10#...` pins the interpretation to decimal regardless of leading zeros. Safe here because the
# 18-digit cap above already ruled out overflow.
count_n=$((10#$count))

emit() {  # emit <verdict> <baseline-jq-literal> <delta-jq-literal>
  jq -n --arg v "$1" --argjson b "$2" --argjson c "$count_n" --argjson d "$3" \
    '{verdict:$v, baseline:$b, count:$c, delta:$d}'
}

# Only a "baseline-count: <N>" line outside a fenced (``` ... ```) code block is authoritative --
# a block that merely documents the required format must not be read as the real baseline. The
# value must be digits-only to end of line (aside from trailing whitespace): a thousands
# separator, a decimal point, or trailing prose makes the line unparseable rather than silently
# truncated to its leading digit run.
matches="$(awk '
  /^[[:space:]]*```/ { infence = !infence; next }
  infence { next }
  /^[[:space:]]*baseline-count:[[:space:]]*[0-9]+[[:space:]]*$/ { print }
' "$policy")"

if [ -z "$matches" ]; then
  emit unknown null null
  printf 'no "baseline-count: <N>" line in %s (outside any fenced code block, digits only)\n' \
    "$policy" >&2
  exit 2
fi

# Reject any matching line whose value is a digit run over 18 digits long, for the same
# overflow reason as the --count guard above -- before normalization ever runs `10#` on it.
overflow="$(printf '%s\n' "$matches" | grep -E '[0-9]{19,}' || true)"
if [ -n "$overflow" ]; then
  emit unknown null null
  printf 'baseline-count value in %s has too many digits to represent safely (max 18):\n%s\n' \
    "$policy" "$overflow" >&2
  exit 2
fi

# Normalize every matching line's value to base-10 before comparing: lines must agree on the
# resolved baseline, not merely on their literal text (`0012` and `12` are the same baseline;
# `100` and `200` are not). Two or more lines that disagree make the baseline unresolvable --
# taking the first one silently is exactly the "guess instead of refuse" failure mode to avoid.
values="$(printf '%s\n' "$matches" \
  | sed -E 's/^[[:space:]]*baseline-count:[[:space:]]*([0-9]+)[[:space:]]*$/\1/' \
  | while IFS= read -r v; do printf '%s\n' "$((10#$v))"; done)"
uniq_values="$(printf '%s\n' "$values" | sort -un)"

if [ "$(printf '%s\n' "$uniq_values" | wc -l)" -gt 1 ]; then
  emit unknown null null
  printf 'ambiguous "baseline-count:" lines in %s (they disagree on the value):\n%s\n' \
    "$policy" "$matches" >&2
  exit 2
fi

baseline_n="$uniq_values"

delta=$((count_n - baseline_n))
if [ "$count_n" -ge "$baseline_n" ]; then
  emit pass "$baseline_n" "$delta"
  exit 0
fi
emit below "$baseline_n" "$delta"
printf 'test count %s is below baseline %s\n' "$count_n" "$baseline_n" >&2
exit 1
