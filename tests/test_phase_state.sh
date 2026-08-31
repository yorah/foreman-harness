#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

ps="$FOREMAN_ROOT/scripts/phase-state.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name test
git -C "$repo" symbolic-ref HEAD refs/heads/main

mkdir -p "$repo/docs/dev/program"
cat > "$repo/docs/dev/program/STATE.md" <<'MD'
# Program state

| Phase | Owner | Branch | Status | Next action |
|---|---|---|---|---|
| alpha | yorah | feat/alpha | executing | none |
| beta  | ana   | feat/beta  | planned   | write kickoff |
| dash  | x     | -evil      | executing | none |
MD
git -C "$repo" add -A
git -C "$repo" commit -qm "state"

git -C "$repo" checkout -qb feat/alpha
mkdir -p "$repo/docs/dev/program/phases/alpha"
cat > "$repo/docs/dev/program/phases/alpha/state.md" <<'MD'
---
phase: alpha
baseline: 100 at deadbee
---

Prose ledger. MARKER_BODY here.
MD
git -C "$repo" add -A
git -C "$repo" commit -qm "alpha state"
git -C "$repo" checkout -q main

# Fixtures for Fix round 1: --head on malformed frontmatter.
git -C "$repo" checkout -qb feat/noattr
mkdir -p "$repo/docs/dev/program/phases/noattr"
printf 'Just prose, no frontmatter at all.\n' > "$repo/docs/dev/program/phases/noattr/state.md"
git -C "$repo" add -A
git -C "$repo" commit -qm "noattr state"
git -C "$repo" checkout -q main

git -C "$repo" checkout -qb feat/midstart
mkdir -p "$repo/docs/dev/program/phases/midstart"
printf '\n---\nphase: midstart\n---\n\nBody.\n' > "$repo/docs/dev/program/phases/midstart/state.md"
git -C "$repo" add -A
git -C "$repo" commit -qm "midstart state"
git -C "$repo" checkout -q main

git -C "$repo" checkout -qb feat/unterm
mkdir -p "$repo/docs/dev/program/phases/unterm"
printf -- '---\nphase: unterm\nno closing marker\n' > "$repo/docs/dev/program/phases/unterm/state.md"
git -C "$repo" add -A
git -C "$repo" commit -qm "unterm state"
git -C "$repo" checkout -q main

run() { "$ps" --repo "$repo" "$@" 2>/dev/null; }

full="$(run --phase alpha)"
assert_contains "$full" "MARKER_BODY"  "reads the state file off its branch"
assert_contains "$full" "phase: alpha" "includes the frontmatter"

head="$(run --phase alpha --head)"
assert_contains     "$head" "baseline: 100 at deadbee" "--head keeps the frontmatter"
assert_not_contains "$head" "MARKER_BODY"              "--head drops the prose body"

assert_contains "$(run --phase alpha --branch feat/alpha)" "MARKER_BODY" \
  "explicit --branch works"

# The main checkout must be untouched by a read.
assert_eq "" "$(git -C "$repo" status --porcelain)" "reading a phase state dirties nothing"
assert_eq "main" "$(git -C "$repo" branch --show-current)" "reading does not switch branches"

assert_exit 2 "unknown phase exits 2"        -- "$ps" --repo "$repo" --phase gamma
assert_exit 2 "phase with no state exits 2"  -- "$ps" --repo "$repo" --phase beta
assert_exit 2 "bad branch exits 2"           -- "$ps" --repo "$repo" --phase alpha --branch nope
assert_exit 2 "relative --repo exits 2"      -- "$ps" --repo "repo" --phase alpha
assert_exit 2 "missing --phase exits 2"      -- "$ps" --repo "$repo"

# --- Fix round 1 ---

# CRITICAL 3: a dash-prefixed branch value must never reach `git show` unguarded, whether it
# comes from --branch directly or from STATE.md's (user-edited) Branch column.
assert_exit 2 "dash-prefixed --branch exits 2" \
  -- "$ps" --repo "$repo" --phase alpha --branch "-O/etc/passwd"
assert_exit 2 "dash-prefixed Branch cell in STATE.md exits 2" -- "$ps" --repo "$repo" --phase dash

# IMPORTANT 5: STATE.md column lookup is header-aware, not positional -- a reordered table
# still resolves the right branch.
repo_reordered="$tmp/repo_reordered"
mkdir -p "$repo_reordered"
git -C "$repo_reordered" init -q
git -C "$repo_reordered" config user.email t@example.com
git -C "$repo_reordered" config user.name test
git -C "$repo_reordered" symbolic-ref HEAD refs/heads/main
mkdir -p "$repo_reordered/docs/dev/program"
cat > "$repo_reordered/docs/dev/program/STATE.md" <<'MD'
# Program state

| Branch | Phase | Owner | Status | Next action |
|---|---|---|---|---|
| feat/alpha | alpha | yorah | executing | none |
MD
git -C "$repo_reordered" add -A
git -C "$repo_reordered" commit -qm "state"
git -C "$repo_reordered" checkout -qb feat/alpha
mkdir -p "$repo_reordered/docs/dev/program/phases/alpha"
printf -- '---\nphase: alpha\n---\n\nREORDERED_MARKER here.\n' \
  > "$repo_reordered/docs/dev/program/phases/alpha/state.md"
git -C "$repo_reordered" add -A
git -C "$repo_reordered" commit -qm "alpha state"
git -C "$repo_reordered" checkout -q main

assert_contains "$("$ps" --repo "$repo_reordered" --phase alpha 2>/dev/null)" "REORDERED_MARKER" \
  "header-aware column lookup resolves correctly when STATE.md's columns are reordered"

# IMPORTANT 5 (continued): no header row, or a header missing a required column, exits 2.
repo_nohdr="$tmp/repo_nohdr"
mkdir -p "$repo_nohdr"
git -C "$repo_nohdr" init -q
git -C "$repo_nohdr" config user.email t@example.com
git -C "$repo_nohdr" config user.name test
git -C "$repo_nohdr" symbolic-ref HEAD refs/heads/main
mkdir -p "$repo_nohdr/docs/dev/program"
printf '# Program state\n\nNo table here, just prose.\n' > "$repo_nohdr/docs/dev/program/STATE.md"
git -C "$repo_nohdr" add -A
git -C "$repo_nohdr" commit -qm "state"
assert_exit 2 "STATE.md with no header row exits 2" -- "$ps" --repo "$repo_nohdr" --phase alpha

repo_missingcol="$tmp/repo_missingcol"
mkdir -p "$repo_missingcol"
git -C "$repo_missingcol" init -q
git -C "$repo_missingcol" config user.email t@example.com
git -C "$repo_missingcol" config user.name test
git -C "$repo_missingcol" symbolic-ref HEAD refs/heads/main
mkdir -p "$repo_missingcol/docs/dev/program"
cat > "$repo_missingcol/docs/dev/program/STATE.md" <<'MD'
# Program state

| Owner | Status | Next action |
|---|---|---|
| yorah | executing | none |
MD
git -C "$repo_missingcol" add -A
git -C "$repo_missingcol" commit -qm "state"
assert_exit 2 "STATE.md header missing Phase/Branch columns exits 2" \
  -- "$ps" --repo "$repo_missingcol" --phase alpha

# IMPORTANT 6: duplicate rows for one phase are ambiguous, not "first one wins."
repo_dup="$tmp/repo_dup"
mkdir -p "$repo_dup"
git -C "$repo_dup" init -q
git -C "$repo_dup" config user.email t@example.com
git -C "$repo_dup" config user.name test
git -C "$repo_dup" symbolic-ref HEAD refs/heads/main
mkdir -p "$repo_dup/docs/dev/program"
cat > "$repo_dup/docs/dev/program/STATE.md" <<'MD'
# Program state

| Phase | Owner | Branch | Status | Next action |
|---|---|---|---|---|
| alpha | yorah | feat/alpha-1 | executing | none |
| alpha | ana   | feat/alpha-2 | executing | none |
MD
git -C "$repo_dup" add -A
git -C "$repo_dup" commit -qm "state"
assert_exit 2 "duplicate STATE.md rows for a phase exit 2" -- "$ps" --repo "$repo_dup" --phase alpha

# IMPORTANT 7: --head refuses (exit 2) rather than dumping the whole file when the frontmatter
# doesn't open on line 1, or never closes.
assert_exit 2 "--head on a file with no frontmatter exits 2" \
  -- "$ps" --repo "$repo" --phase noattr --branch feat/noattr --head
assert_exit 2 "--head on frontmatter not starting on line 1 exits 2" \
  -- "$ps" --repo "$repo" --phase midstart --branch feat/midstart --head
assert_exit 2 "--head on an unterminated frontmatter block exits 2" \
  -- "$ps" --repo "$repo" --phase unterm --branch feat/unterm --head

# --- Fix round 2 ---

# CRITICAL 1: a STATE.md row with fewer cells than the header resolves an empty branch. That
# must be a hard error -- not a fall-through to `git show ":path"`, which reads from the
# *index* rather than any ref. Prove this is meaningful by staging real uncommitted content at
# the exact path the index read would otherwise serve.
repo_indexread="$tmp/repo_indexread"
mkdir -p "$repo_indexread"
git -C "$repo_indexread" init -q
git -C "$repo_indexread" config user.email t@example.com
git -C "$repo_indexread" config user.name test
git -C "$repo_indexread" symbolic-ref HEAD refs/heads/main
mkdir -p "$repo_indexread/docs/dev/program"
cat > "$repo_indexread/docs/dev/program/STATE.md" <<'MD'
# Program state

| Phase | Owner | Branch | Status | Next action |
|---|---|---|---|---|
| alpha | yorah |
MD
git -C "$repo_indexread" add -A
git -C "$repo_indexread" commit -qm "state"

git -C "$repo_indexread" checkout -qb feat/alpha
mkdir -p "$repo_indexread/docs/dev/program/phases/alpha"
printf -- '---\nphase: alpha\n---\n\nCOMMITTED_LEDGER.\n' \
  > "$repo_indexread/docs/dev/program/phases/alpha/state.md"
git -C "$repo_indexread" add -A
git -C "$repo_indexread" commit -qm "alpha state"
git -C "$repo_indexread" checkout -q main

# Stage uncommitted scratch at the exact path an index read would resolve to.
mkdir -p "$repo_indexread/docs/dev/program/phases/alpha"
printf 'STAGED-SECRET-CONTENT\n' > "$repo_indexread/docs/dev/program/phases/alpha/state.md"
git -C "$repo_indexread" add "$repo_indexread/docs/dev/program/phases/alpha/state.md"

indexread_out="$("$ps" --repo "$repo_indexread" --phase alpha 2>/dev/null)"
assert_exit 2 "malformed STATE.md row (empty branch) exits 2, not a silent index read" \
  -- "$ps" --repo "$repo_indexread" --phase alpha
assert_not_contains "$indexread_out" "STAGED-SECRET-CONTENT" \
  "an empty-branch resolution never prints staged index content"

# CRITICAL 1 (continued): an explicit empty --branch is a hard error too, and must not silently
# fall through to the STATE.md lookup as if --branch had never been given.
assert_exit 2 "explicit --branch '' exits 2" -- "$ps" --repo "$repo" --phase alpha --branch ""

# Also fold in: a header naming Branch (or Phase) twice is the same ambiguity class as a
# duplicate row or a missing header -- refuse rather than silently using the last match.
repo_dupbranch="$tmp/repo_dupbranch"
mkdir -p "$repo_dupbranch"
git -C "$repo_dupbranch" init -q
git -C "$repo_dupbranch" config user.email t@example.com
git -C "$repo_dupbranch" config user.name test
git -C "$repo_dupbranch" symbolic-ref HEAD refs/heads/main
mkdir -p "$repo_dupbranch/docs/dev/program"
cat > "$repo_dupbranch/docs/dev/program/STATE.md" <<'MD'
# Program state

| Phase | Branch | Owner | Branch | Next action |
|---|---|---|---|---|
| alpha | feat/alpha | yorah | feat/alpha-dup | none |
MD
git -C "$repo_dupbranch" add -A
git -C "$repo_dupbranch" commit -qm "state"
assert_exit 2 "STATE.md header naming Branch twice exits 2" \
  -- "$ps" --repo "$repo_dupbranch" --phase alpha

repo_dupphase="$tmp/repo_dupphase"
mkdir -p "$repo_dupphase"
git -C "$repo_dupphase" init -q
git -C "$repo_dupphase" config user.email t@example.com
git -C "$repo_dupphase" config user.name test
git -C "$repo_dupphase" symbolic-ref HEAD refs/heads/main
mkdir -p "$repo_dupphase/docs/dev/program"
cat > "$repo_dupphase/docs/dev/program/STATE.md" <<'MD'
# Program state

| Phase | Phase | Owner | Branch | Next action |
|---|---|---|---|---|
| alpha | dup | yorah | feat/alpha | none |
MD
git -C "$repo_dupphase" add -A
git -C "$repo_dupphase" commit -qm "state"
assert_exit 2 "STATE.md header naming Phase twice exits 2" \
  -- "$ps" --repo "$repo_dupphase" --phase alpha

# --- Regression sweep (round 1, still holding) ---
assert_contains "$(run --phase alpha)" "MARKER_BODY" "sweep: full read still returns the body"
assert_not_contains "$(run --phase alpha --head)" "MARKER_BODY" \
  "sweep: --head still drops the prose body"
assert_contains "$(run --phase alpha --head)" "baseline: 100 at deadbee" \
  "sweep: --head still keeps the frontmatter"
assert_exit 2 "sweep: dash-prefixed --branch still exits 2" \
  -- "$ps" --repo "$repo" --phase alpha --branch "-O/etc/passwd"
assert_exit 2 "sweep: dash-prefixed Branch cell still exits 2" -- "$ps" --repo "$repo" --phase dash
assert_contains "$("$ps" --repo "$repo_reordered" --phase alpha 2>/dev/null)" "REORDERED_MARKER" \
  "sweep: reordered columns still resolve correctly"
assert_exit 2 "sweep: duplicate rows still exit 2" -- "$ps" --repo "$repo_dup" --phase alpha
assert_exit 2 "sweep: missing header still exits 2" -- "$ps" --repo "$repo_nohdr" --phase alpha
assert_exit 2 "sweep: --head on no-frontmatter still exits 2" \
  -- "$ps" --repo "$repo" --phase noattr --branch feat/noattr --head
assert_exit 2 "sweep: --head on unterminated frontmatter still exits 2" \
  -- "$ps" --repo "$repo" --phase unterm --branch feat/unterm --head

# Test gap: a read must not disturb *pre-existing* uncommitted work, not merely leave an
# already-clean tree clean. Dirty the main checkout first, then confirm a read changes nothing.
echo "dirty change" >> "$repo/docs/dev/program/STATE.md"
echo "scratch" > "$repo/untracked.txt"
before_status="$(git -C "$repo" status --porcelain)"
before_state_hash="$(git -C "$repo" hash-object "$repo/docs/dev/program/STATE.md")"
before_untracked_hash="$(sha256sum "$repo/untracked.txt" | awk '{print $1}')"

run --phase alpha >/dev/null

after_status="$(git -C "$repo" status --porcelain)"
after_state_hash="$(git -C "$repo" hash-object "$repo/docs/dev/program/STATE.md")"
after_untracked_hash="$(sha256sum "$repo/untracked.txt" | awk '{print $1}')"

assert_eq "$before_status" "$after_status" \
  "reading against a pre-dirtied tree leaves its status unchanged"
assert_eq "$before_state_hash" "$after_state_hash" \
  "a pre-existing modified tracked file is untouched by a read"
assert_eq "$before_untracked_hash" "$after_untracked_hash" \
  "a pre-existing untracked file is untouched by a read"
assert_eq "main" "$(git -C "$repo" branch --show-current)" \
  "reading against a pre-dirtied tree does not switch branches"

# --- Fix round 3 ---

# An explicitly empty --repo must not be indistinguishable from omitting the flag: omission
# legitimately falls back to the repo containing $PWD, but an explicit empty value is a caller
# error. Build a fixture where the fall-back would visibly succeed if the bug were still there.
repo_emptyflag_out="$(cd "$repo" && "$ps" --repo "" --phase alpha 2>/dev/null)"
repo_emptyflag_code=0
(cd "$repo" && "$ps" --repo "" --phase alpha >/dev/null 2>&1) || repo_emptyflag_code=$?
assert_eq "2" "$repo_emptyflag_code" \
  "--repo '' exits 2 even from inside a repo that would otherwise resolve the phase"
assert_eq "" "$repo_emptyflag_out" "--repo '' prints nothing (no fallback ledger content)"

# Omitting --repo entirely must keep resolving normally via $PWD.
repo_omitted_out="$(cd "$repo" && "$ps" --phase alpha 2>/dev/null)"
assert_contains "$repo_omitted_out" "MARKER_BODY" \
  "--repo omitted still resolves the phase via \$PWD"
