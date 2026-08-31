#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

gate="$FOREMAN_ROOT/scripts/resolve-gate.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A fake repo and a fake HOME, so the chain is fully controlled.
mkdir -p "$tmp/repo/.claude" "$tmp/home/.claude"
export HOME="$tmp/home"

write_user()    { printf '%s\n' "{\"effortLevel\":\"$1\"}" > "$tmp/home/.claude/settings.json"; }
write_project() { printf '%s\n' "{\"effortLevel\":\"$1\"}" > "$tmp/repo/.claude/settings.json"; }
write_local()   { printf '%s\n' "{\"effortLevel\":\"$1\"}" > "$tmp/repo/.claude/settings.local.json"; }
clear_all()     { rm -f "$tmp/home/.claude/settings.json" "$tmp/repo/.claude/settings.json" \
                       "$tmp/repo/.claude/settings.local.json"; }

run() { "$gate" --model "$1" --repo "$tmp/repo" 2>/dev/null; }
code() { local c=0; run "$1" >/dev/null || c=$?; printf '%s' "$c"; }

# --- passes ---------------------------------------------------------------
clear_all; write_user high
assert_eq "pass" "$(run opus | jq -r .verdict)"          "opus + high passes"
assert_eq "0"    "$(code opus)"                          "opus + high exits 0"
assert_eq "pass" "$(run claude-opus-5 | jq -r .verdict)" "full opus model id passes"
assert_eq "pass" "$(run fable | jq -r .verdict)"         "fable passes"
assert_eq "pass" "$(run claude-fable-5 | jq -r .verdict)" "full fable model id passes"

clear_all; write_user max
assert_eq "pass" "$(run opus | jq -r .verdict)" "max is above high"
clear_all; write_user xhigh
assert_eq "pass" "$(run opus | jq -r .verdict)" "xhigh is above high"

# --- refusals -------------------------------------------------------------
clear_all; write_user medium
assert_eq "refuse" "$(run opus | jq -r .verdict)" "opus + medium refuses"
assert_eq "1"      "$(code opus)"                 "refusal exits 1"
assert_contains "$(run opus | jq -r .reason)" "effort" "refusal reason names effort"

clear_all; write_user high
assert_eq "refuse" "$(run sonnet | jq -r .verdict)"  "sonnet refuses even at high"
assert_eq "refuse" "$(run haiku  | jq -r .verdict)"  "haiku refuses"
assert_contains "$(run sonnet | jq -r .reason)" "model" "refusal reason names model"

clear_all; write_user low
assert_eq "refuse" "$(run sonnet | jq -r .verdict)" "both wrong still refuses"

# --- cannot determine -----------------------------------------------------
clear_all
assert_eq "unknown" "$(run opus | jq -r .verdict)" "no settings anywhere is unknown"
assert_eq "2"       "$(code opus)"                 "unknown exits 2"

clear_all; printf '%s\n' '{"effortLevel":"turbo"}' > "$tmp/home/.claude/settings.json"
assert_eq "unknown" "$(run opus | jq -r .verdict)" "unrecognised effort is unknown, not refuse"
assert_eq "2"       "$(code opus)"                 "unrecognised effort exits 2"

# --- precedence: most specific wins ---------------------------------------
clear_all; write_user high; write_project medium
assert_eq "refuse" "$(run opus | jq -r .verdict)" "project settings beat user settings"
assert_contains "$(run opus | jq -r .effort_source)" "repo/.claude/settings.json" \
  "source names the project file"

write_local high
assert_eq "pass" "$(run opus | jq -r .verdict)" "settings.local beats settings.json"
assert_contains "$(run opus | jq -r .effort_source)" "settings.local.json" \
  "source names the local file"

# --- argument handling ----------------------------------------------------
assert_exit 2 "missing --model is exit 2" -- "$gate" --repo "$tmp/repo"
assert_exit 2 "unknown flag is exit 2" -- "$gate" --model opus --bogus

# --- fix round 1 / round 2: model matching must be whole-token, not substring, and must not
# be a bare id whitelist either (round 1's "opus|fable|claude-opus-*|claude-fable-*" whitelist
# over-corrected: it wrongly refused real ids like "claude-3-opus-20240229"). "opus-",
# "-opus" and "--opus--" carry a degenerate empty segment and must still refuse even though
# splitting naively on '-' would otherwise expose an "opus" token in "opus-".
#
# Round-1 deviation note, corrected here: "opus-mini-nonexistent" was asserted `refuse` under
# round 1's whitelist. Under the round-2 directed rule (split on '-', accept any id where some
# token is exactly "opus"/"fable"), it is structurally identical in shape to the real ids this
# round explicitly requires to pass ("claude-3-opus-20240229" is also "arbitrary-token +
# opus-token + arbitrary-token"), so it now legitimately passes — there is no token-only rule
# that can accept the latter while refusing the former. Moved to the pass list rather than
# silently dropped, so the coverage isn't lost, just corrected to match the directed rule.
clear_all; write_user high
for bad in notopus opusless xfablex fabled corpuscle opus- -opus --opus--; do
  assert_eq "refuse" "$(run "$bad" | jq -r .verdict)" "$bad is not a real opus/fable id, refuses"
done
for good in claude-opus-5 opus claude-fable-5 fable \
            claude-3-opus-20240229 us.anthropic.claude-opus-4-latest \
            anthropic.claude-opus-4-1-20250805-v1:0 claude-opus-4-5 \
            opus-mini-nonexistent; do
  assert_eq "pass" "$(run "$good" | jq -r .verdict)" "$good is a real opus/fable id, passes"
done

# --- fix round 1: a present-but-unusable value ends the search, never falls
# through to a laxer file, and never yields pass ---------------------------
clear_all; write_user high
printf '%s\n' '{"effortLevel":false}' > "$tmp/repo/.claude/settings.local.json"
assert_eq "unknown" "$(run opus | jq -r .verdict)" \
  "boolean effortLevel at local tier is unknown, not a fall-through pass"
assert_eq "2" "$(code opus)" "boolean effortLevel at local tier exits 2"
assert_contains "$(run opus | jq -r .effort_source)" "settings.local.json" \
  "unusable value still attributes source to the file that defined it"

clear_all; write_user high
printf '%s\n' '{"effortLevel":null}' > "$tmp/repo/.claude/settings.local.json"
assert_eq "unknown" "$(run opus | jq -r .verdict)" \
  "null effortLevel at local tier is unknown, not a fall-through pass"
assert_eq "2" "$(code opus)" "null effortLevel at local tier exits 2"

clear_all; write_user high; write_local ""
assert_eq "unknown" "$(run opus | jq -r .verdict)" \
  "empty-string effortLevel at local tier is unknown, not a fall-through pass"
assert_eq "2" "$(code opus)" "empty-string effortLevel at local tier exits 2"

clear_all; write_user high
printf '%s\n' '{ not valid json' > "$tmp/repo/.claude/settings.local.json"
assert_eq "unknown" "$(run opus | jq -r .verdict)" \
  "malformed JSON at local tier is unknown, not a fall-through pass"
assert_eq "2" "$(code opus)" "malformed JSON at local tier exits 2"

# --- fix round 1: unset HOME must not break the chain for repo-scoped tiers
clear_all; write_project high
(
  unset HOME
  assert_eq "pass" "$(run opus | jq -r .verdict)" \
    "HOME unset still resolves a valid project-tier effort"
  assert_eq "0" "$(code opus)" "HOME unset with a valid project effort still exits 0"
)

# --- fix round 2: file-level brokenness ends the search too, not just a broken value at a
# key that's present. A non-object top level (array/string/number) or a zero-length file must
# never be silently skipped in favor of a laxer tier's opinion. ------------------------------
local_file="$tmp/repo/.claude/settings.local.json"

clear_all; write_user high
printf '%s\n' '[1,2,3]' > "$local_file"
assert_eq "unknown" "$(run opus | jq -r .verdict)" \
  "array top level at local tier is unknown, not a fall-through pass"
assert_eq "2" "$(code opus)" "array top level at local tier exits 2"

clear_all; write_user high
printf '%s\n' '"str"' > "$local_file"
assert_eq "unknown" "$(run opus | jq -r .verdict)" \
  "string top level at local tier is unknown, not a fall-through pass"
assert_eq "2" "$(code opus)" "string top level at local tier exits 2"

clear_all; write_user high
printf '%s\n' '42' > "$local_file"
assert_eq "unknown" "$(run opus | jq -r .verdict)" \
  "number top level at local tier is unknown, not a fall-through pass"
assert_eq "2" "$(code opus)" "number top level at local tier exits 2"

clear_all; write_user high
: > "$local_file"
assert_eq "unknown" "$(run opus | jq -r .verdict)" \
  "zero-length file at local tier is unknown, not a fall-through pass"
assert_eq "2" "$(code opus)" "zero-length file at local tier exits 2"

clear_all; write_user high
printf '%s\n' '{ not valid json' > "$local_file"
assert_eq "unknown" "$(run opus | jq -r .verdict)" \
  "malformed JSON at local tier is still unknown, not a fall-through pass"
assert_eq "2" "$(code opus)" "malformed JSON at local tier still exits 2"

# The corresponding fall-through must still work: a well-formed object simply lacking the key
# at the most specific tier defers to the next tier, exactly as before.
clear_all; write_project high
printf '%s\n' '{}' > "$local_file"
assert_eq "pass" "$(run opus | jq -r .verdict)" \
  "well-formed object without the key at local tier still falls through to project tier"
assert_contains "$(run opus | jq -r .effort_source)" "repo/.claude/settings.json" \
  "fall-through source still names the project file, not the local one"

# --- fix round 3: validity must be judged from jq's exit code, never its stdout, and the
# presence check must account for non-regular files (directories, broken symlinks, unreadable
# files) rather than just testing `[ -f ]`. All scenarios below sit at the local tier with a
# valid `high` at the project tier behind it, and every one must be `unknown`/exit 2 — never a
# fall-through `pass` sourced from the project file. -----------------------------------------
reset_local_file() { rm -rf "$local_file" 2>/dev/null || true; }

assert_local_unusable() {
  local label="$1"
  assert_eq "unknown" "$(run opus | jq -r .verdict)" \
    "$label at local tier is unknown, not a fall-through pass"
  assert_eq "2" "$(code opus)" "$label at local tier exits 2"
}

clear_all; write_project high; reset_local_file
printf '%s\n' '{"effortLevel":"high"}' > "$local_file"
printf '%s\n' 'garbage garbage' >> "$local_file"
assert_local_unusable "trailing garbage after a valid object"

clear_all; write_project high; reset_local_file
printf '%s' '{"a":1}{"b":2}' > "$local_file"
assert_local_unusable "two concatenated objects"

clear_all; write_project high; reset_local_file
printf '%s\n' '[1,2,3]' > "$local_file"
assert_local_unusable "top-level array"

clear_all; write_project high; reset_local_file
printf '%s\n' '"str"' > "$local_file"
assert_local_unusable "top-level string"

clear_all; write_project high; reset_local_file
printf '%s\n' '42' > "$local_file"
assert_local_unusable "top-level number"

clear_all; write_project high; reset_local_file
: > "$local_file"
assert_local_unusable "zero-length file"

clear_all; write_project high; reset_local_file
printf '   \n\t \n' > "$local_file"
assert_local_unusable "whitespace-only file"

clear_all; write_project high; reset_local_file
printf '%s\n' '{ not valid json' > "$local_file"
assert_local_unusable "malformed JSON"

clear_all; write_project high; reset_local_file
mkdir -p "$local_file"
assert_local_unusable "a directory"
reset_local_file

clear_all; write_project high; reset_local_file
ln -s "/nonexistent-target-for-foreman-gate-test" "$local_file"
assert_local_unusable "a broken symlink"
reset_local_file

clear_all; write_project high; reset_local_file
printf '%s\n' '{"effortLevel":"high"}' > "$local_file"
chmod 000 "$local_file"
assert_local_unusable "a file with permissions removed"
chmod 644 "$local_file"

# --- fix round 3: the paths that must still work were not broken by the above ---------------

# A valid object lacking the key at the local tier still defers to the project tier.
clear_all; write_project high; reset_local_file
printf '%s\n' '{}' > "$local_file"
assert_eq "pass" "$(run opus | jq -r .verdict)" \
  "well-formed object without the key at local tier still falls through to project tier"
assert_contains "$(run opus | jq -r .effort_source)" "repo/.claude/settings.json" \
  "fall-through source still names the project file, not the local one"

# A symlink pointing at a valid settings file resolves normally, using the target's value
# rather than falling through past it.
clear_all; write_project medium; reset_local_file
real_target="$tmp/real-settings.json"
printf '%s\n' '{"effortLevel":"high"}' > "$real_target"
ln -s "$real_target" "$local_file"
assert_eq "pass" "$(run opus | jq -r .verdict)" \
  "a symlink to a valid settings file resolves normally"
assert_eq "high" "$(run opus | jq -r .effort)" \
  "a symlink to a valid settings file reads the target's value"
assert_contains "$(run opus | jq -r .effort_source)" "settings.local.json" \
  "a symlink's source is reported at the tier's canonical path"
reset_local_file

# --- task 4 fix round 3: --repo '' must not fall back to $PWD like an omitted --repo -------

# An explicitly empty --repo is a caller error, not "no --repo given": it must never silently
# read whatever repository happens to contain the current directory (which here would mean
# skipping the project's own settings.json and letting a laxer file decide the verdict).
clear_all; write_project low; write_user high
repo_empty_out="$(cd "$tmp/repo" && "$gate" --model opus --repo "" 2>/dev/null)"
repo_empty_code=0
(cd "$tmp/repo" && "$gate" --model opus --repo "" >/dev/null 2>&1) || repo_empty_code=$?
assert_eq "2" "$repo_empty_code" "--repo '' exits 2 even though the project settings would refuse"
assert_eq "" "$repo_empty_out"   "--repo '' prints nothing on stdout (no verdict, pass or refuse)"

# Omitting --repo entirely must keep resolving normally (project settings win over user's).
clear_all; write_project low; write_user high
omitted_out="$(cd "$tmp/repo" && "$gate" --model opus 2>/dev/null)"
assert_eq "refuse" "$(printf '%s' "$omitted_out" | jq -r .verdict)" \
  "--repo omitted still resolves via \$PWD and refuses on the project's low effort"
assert_contains "$(printf '%s' "$omitted_out" | jq -r .effort_source)" "repo/.claude/settings.json" \
  "--repo omitted reads the project settings, not the user's"
