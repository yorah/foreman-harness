#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

bc="$FOREMAN_ROOT/scripts/baseline-check.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

policy="$tmp/POLICY.md"
printf '%s\n' '# Program policy' '## Baseline' 'baseline-count: 819' \
  '`819 backend + 225 frontend` green at `abc1234`.' > "$policy"

run()  { "$bc" --policy "$policy" --count "$1" 2>/dev/null; }
code() { local c=0; run "$1" >/dev/null || c=$?; printf '%s' "$c"; }

assert_eq "pass"  "$(run 819 | jq -r .verdict)" "equal to baseline passes"
assert_eq "0"     "$(code 819)"                 "equal exits 0"
assert_eq "pass"  "$(run 900 | jq -r .verdict)" "above baseline passes"
assert_eq "5"     "$(run 824 | jq -r .delta)"   "delta is count minus baseline"
assert_eq "below" "$(run 818 | jq -r .verdict)" "one below baseline fails"
assert_eq "1"     "$(code 818)"                 "below exits 1"
assert_eq "-1"    "$(run 818 | jq -r .delta)"   "negative delta reported"
assert_eq "819"   "$(run 818 | jq -r .baseline)" "baseline echoed back"

empty="$tmp/no-baseline.md"
printf '%s\n' '# Program policy' '## Baseline' 'not recorded yet' > "$empty"
assert_eq "unknown" "$("$bc" --policy "$empty" --count 5 2>/dev/null | jq -r .verdict)" \
  "missing baseline is unknown"
assert_exit 2 "missing baseline exits 2" -- "$bc" --policy "$empty" --count 5

assert_exit 2 "missing policy file exits 2" -- "$bc" --policy "$tmp/nope.md" --count 5
assert_exit 2 "relative --policy exits 2"   -- "$bc" --policy "POLICY.md" --count 5
assert_exit 2 "non-numeric --count exits 2" -- "$bc" --policy "$policy" --count twelve
assert_exit 2 "missing --count exits 2"     -- "$bc" --policy "$policy"

# --- Fix round 1 ---

# CRITICAL 1: a fenced code block that merely documents the format must not be read as the
# real baseline. Only the non-fenced line is authoritative.
fenced="$tmp/fenced.md"
cat > "$fenced" <<'MD'
# Program policy
## Baseline
Example of the format:
```
baseline-count: 1
```
baseline-count: 500
MD
frun() { "$bc" --policy "$fenced" --count "$1" 2>/dev/null; }
fcode() { local c=0; frun "$1" >/dev/null || c=$?; printf '%s' "$c"; }
assert_eq "below" "$(frun 10 | jq -r .verdict)"   "fenced example line is not the real baseline"
assert_eq "500"   "$(frun 10 | jq -r .baseline)"  "real non-fenced baseline used, not the fenced example's 1"
assert_eq "1"     "$(fcode 10)"                   "fenced-example count regression exits 1, not a silent pass"

# CRITICAL 1 (continued): two disagreeing non-fenced lines are ambiguous, not "first one wins."
disagree="$tmp/disagree.md"
printf '%s\n' '# Program policy' '## Baseline' 'baseline-count: 100' 'baseline-count: 200' \
  > "$disagree"
assert_eq "unknown" "$("$bc" --policy "$disagree" --count 50 2>/dev/null | jq -r .verdict)" \
  "disagreeing baseline-count lines are unknown"
assert_exit 2 "disagreeing baseline-count lines exit 2" -- "$bc" --policy "$disagree" --count 50

# Two lines that resolve to the *same* baseline (including via leading zeros) are not ambiguous.
agree="$tmp/agree.md"
printf '%s\n' '# Program policy' '## Baseline' 'baseline-count: 0300' 'baseline-count: 300' \
  > "$agree"
assert_eq "pass" "$("$bc" --policy "$agree" --count 300 2>/dev/null | jq -r .verdict)" \
  "agreeing (normalized) baseline-count lines are not ambiguous"

# CRITICAL 2: a value with a separator, decimal point, or trailing prose must not resolve to a
# number at all -- refuse loudly (unknown/exit 2), never truncate to a leading digit run.
comma="$tmp/comma.md"
printf '%s\n' '# Program policy' '## Baseline' 'baseline-count: 1,200' > "$comma"
assert_eq "unknown" "$("$bc" --policy "$comma" --count 50 2>/dev/null | jq -r .verdict)" \
  "comma-separated baseline value is unknown, not truncated"
assert_exit 2 "comma-separated baseline value exits 2" -- "$bc" --policy "$comma" --count 50

decimal="$tmp/decimal.md"
printf '%s\n' '# Program policy' '## Baseline' 'baseline-count: 1200.5' > "$decimal"
assert_exit 2 "decimal-point baseline value exits 2" -- "$bc" --policy "$decimal" --count 50

trailing="$tmp/trailing.md"
printf '%s\n' '# Program policy' '## Baseline' 'baseline-count: 1200 tests' > "$trailing"
assert_exit 2 "trailing-prose baseline value exits 2" -- "$bc" --policy "$trailing" --count 50

# IMPORTANT 4: leading-zero baseline and --count values must not crash on bash's octal
# misparse; they resolve as base-10 and still produce valid JSON with a correct exit code.
lz="$tmp/leadingzero.md"
printf '%s\n' '# Program policy' '## Baseline' 'baseline-count: 0012' > "$lz"
assert_eq "12"   "$("$bc" --policy "$lz" --count 12 2>/dev/null | jq -r .baseline)" \
  "leading-zero baseline (0012) parses as decimal 12, not octal"
assert_eq "pass" "$("$bc" --policy "$lz" --count 12 2>/dev/null | jq -r .verdict)" \
  "equal to a leading-zero baseline still passes"

assert_eq "below" "$(run 008 | jq -r .verdict)" \
  "leading-zero --count (008) parses as decimal 8, no octal crash"
assert_eq "1"     "$(code 008)" "leading-zero --count exit is 1 (below), not an unsignaled crash"
assert_eq "8"     "$(run 008 | jq -r .count)" "leading-zero --count reported as decimal 8"
assert_eq "below" "$(run 09 | jq -r .verdict)" \
  "leading-zero --count (09) parses as decimal 9, no octal crash"

# --- Fix round 2 ---

# CRITICAL 2: a digit run over 18 digits must not silently overflow signed 64-bit arithmetic
# (which can wrap to a negative baseline and produce a false `pass`) -- it must be refused
# outright as unknown/exit 2, for both the policy-file baseline and the --count argument.
n19="9999999999999999999"            # 19 digits
n32="99999999999999999999999999999999"  # 32 digits
n18="999999999999999999"             # 18 digits -- must still work normally

over19="$tmp/over19.md"
printf '%s\n' '# Program policy' '## Baseline' "baseline-count: $n19" > "$over19"
assert_eq "unknown" "$("$bc" --policy "$over19" --count 5 2>/dev/null | jq -r .verdict)" \
  "19-digit baseline is unknown, not overflowed"
assert_exit 2 "19-digit baseline exits 2" -- "$bc" --policy "$over19" --count 5

over32="$tmp/over32.md"
printf '%s\n' '# Program policy' '## Baseline' "baseline-count: $n32" > "$over32"
assert_eq "unknown" "$("$bc" --policy "$over32" --count 5 2>/dev/null | jq -r .verdict)" \
  "32-digit baseline is unknown, not overflowed"
assert_exit 2 "32-digit baseline exits 2" -- "$bc" --policy "$over32" --count 5
# The overflow guard must reject before any wrap-to-negative could reach the verdict comparison:
# a catastrophically low reported count must never read back as "pass" against a mis-parsed
# giant baseline.
assert_eq "unknown" "$("$bc" --policy "$over32" --count 5 2>/dev/null | jq -r .verdict)" \
  "overflowing baseline never lets a tiny count read as pass"

ok18="$tmp/ok18.md"
printf '%s\n' '# Program policy' '## Baseline' "baseline-count: $n18" > "$ok18"
assert_eq "$n18" "$("$bc" --policy "$ok18" --count "$n18" 2>/dev/null | jq -r .baseline)" \
  "an 18-digit baseline still resolves normally"
assert_eq "pass" "$("$bc" --policy "$ok18" --count "$n18" 2>/dev/null | jq -r .verdict)" \
  "an 18-digit baseline at parity still passes"

assert_exit 2 "32-digit --count exits 2" -- "$bc" --policy "$ok18" --count "$n32"

# --- Regression sweep (round 1 + round 2, everything must still hold) ---
assert_eq "pass"  "$(run 819 | jq -r .verdict)"  "sweep: equal to baseline passes"
assert_eq "0"     "$(code 819)"                  "sweep: equal exits 0"
assert_eq "pass"  "$(run 900 | jq -r .verdict)"  "sweep: above baseline passes"
assert_eq "5"     "$(run 824 | jq -r .delta)"    "sweep: delta is count minus baseline"
assert_eq "below" "$(run 818 | jq -r .verdict)"  "sweep: one below baseline fails"
assert_eq "1"     "$(code 818)"                  "sweep: below exits 1"
assert_eq "unknown" "$("$bc" --policy "$empty" --count 5 2>/dev/null | jq -r .verdict)" \
  "sweep: missing baseline is still unknown"
assert_exit 2 "sweep: relative --policy exits 2" -- "$bc" --policy "POLICY.md" --count 5
assert_eq "below" "$(frun 10 | jq -r .verdict)" "sweep: fenced example still ignored"
assert_eq "unknown" "$("$bc" --policy "$comma" --count 50 2>/dev/null | jq -r .verdict)" \
  "sweep: comma-separated baseline still unknown"
assert_eq "unknown" "$("$bc" --policy "$disagree" --count 50 2>/dev/null | jq -r .verdict)" \
  "sweep: disagreeing lines still unknown"
assert_eq "below" "$(run 008 | jq -r .verdict)" "sweep: leading-zero --count still no crash"
