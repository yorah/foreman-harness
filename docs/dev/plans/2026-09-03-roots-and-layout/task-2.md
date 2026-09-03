# Task 2: `foreman-diff` writes a review package and proves it complete `[JUDGE-1]`

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Create: `scripts/diff-package.sh`
- Create: `bin/foreman-diff` — the wrapper, same shape as `bin/foreman-state`
- Create: `tests/test_diff.sh`
- Modify: `tests/test_bin.sh` — the two wrapper lists, plus one plumbing assertion

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `foreman-diff --repo <abs> --base <rev> --head <rev> --out <abs-file>
  [--verify-only]`. Writes `git -C <repo> diff <base> <head>` to `<out>` (atomically, temp file
  then rename), then verifies the file is the complete diff. Exit `0`: complete; stdout is the
  path. Exit `1`: incomplete; stderr says `incomplete diff at <out>:` followed by which check
  failed. Exit `2`: bad arguments, an unknown revision, an unwritable destination. With
  `--verify-only` nothing is written and an existing `<out>` is checked against the range. Task 9
  makes `foreman-phase` Step 4 and gate-chain §2 call this instead of `git diff … > file`.

**Why this exists.** `[JUDGE-1]`: on the machine phase A ran on, a command-rewriting hook on
`git` silently summarised every `git diff > file` the controller wrote — 250 lines withheld
across ten review packages, worst on a trust-boundary task. A prose instruction to avoid the hook
cannot name it without naming a vendor (spec §2), and a script invoked by bare wrapper name is
not a `git` invocation in the Bash tool's command string, so no hook on `git` rewrites it — the
same immunity `bin/` already gives every other script. The completeness check is **structural**,
not a search for one tool's marker: git's own `--numstat` says how many files and how many
added and removed lines the range has, and the file must agree; and a unified diff has a small,
closed set of line shapes, so any line outside it is foreign. That catches every summariser,
including ones nobody has met yet.

---

- [ ] **Step 1: Write the failing tests**

Create `tests/test_diff.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

dp="$FOREMAN_ROOT/scripts/diff-package.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A range with every ordinary shape: a modified file with adds and removes, a modified file with
# adds only, a deleted file, a new file. Four files, four added lines, two removed lines.
repo="$tmp/repo"
mkdir -p "$repo/dir"
git -C "$repo" init -q
printf 'one\ntwo\nthree\n' > "$repo/a.txt"
printf 'keep\n' > "$repo/dir/b.txt"
printf 'gone\n' > "$repo/c.txt"
git -C "$repo" add -A
git -C "$repo" commit -qm base
base="$(git -C "$repo" rev-parse HEAD)"
printf 'one\n2\nthree\nfour\n' > "$repo/a.txt"
printf 'keep\nmore\n' > "$repo/dir/b.txt"
git -C "$repo" rm -q c.txt
printf 'new\n' > "$repo/d.txt"
git -C "$repo" add -A
git -C "$repo" commit -qm change
head="$(git -C "$repo" rev-parse HEAD)"

mkdir -p "$tmp/pkg"
out="$tmp/pkg/review.diff"
gen() { "$dp" --repo "$repo" --base "$base" --head "$head" --out "$out" "$@"; }

# --- a complete package is written, verified, and identical to git's own output ---------------
assert_exit 0 "a complete diff verifies" -- gen
assert_eq "$out" "$(gen 2>/dev/null)" "prints the package path on stdout"
assert_eq "4" "$(grep -c '^diff --git ' "$out")" "the package holds every changed file"
assert_eq "$(git -C "$repo" diff "$base" "$head")" "$(cat "$out")" \
  "the package is byte-identical to git's own diff"
assert_exit 0 "--verify-only accepts the file it just wrote" -- gen --verify-only

# --- the other direction: the same file, made incomplete three ways, is refused --------------
cp "$out" "$tmp/whole.diff"

head -n -3 "$tmp/whole.diff" > "$out"
assert_exit 1 "a diff missing its last lines exits 1" -- gen --verify-only
assert_contains "$(gen --verify-only 2>&1 >/dev/null)" "incomplete diff at $out" \
  "the refusal names the file and says it is incomplete"
assert_contains "$(gen --verify-only 2>&1 >/dev/null)" "added:" \
  "the refusal names which count disagreed"

awk '/^diff --git a\/d.txt/ {skip=1} !skip {print}' "$tmp/whole.diff" > "$out"
assert_exit 1 "a diff missing a whole file exits 1" -- gen --verify-only
assert_contains "$(gen --verify-only 2>&1 >/dev/null)" "files:3/4" \
  "a missing file is reported as a file-count mismatch"

# Counts intact, one foreign line inserted: only the line-shape rule can catch this. It is the
# shape a summariser leaves behind, but the rule does not know any summariser -- it knows what
# a unified diff may contain, and this is not on the list.
{ head -n 5 "$tmp/whole.diff"; printf '... 12 lines omitted ...\n'; tail -n +6 "$tmp/whole.diff"; } > "$out"
assert_exit 1 "a diff carrying a line no unified diff can contain exits 1" -- gen --verify-only
assert_contains "$(gen --verify-only 2>&1 >/dev/null)" "foreign-lines:1" \
  "the foreign line is counted and reported"

# A fresh write over a corrupted package repairs it.
assert_exit 0 "a fresh write replaces a corrupted package" -- gen
assert_eq "$(cat "$tmp/whole.diff")" "$(cat "$out")" "and the replacement is complete again"

# --- a content line that looks like a header is not mistaken for one ---------------------------
# "--- a/..." and "+++ b/..." are file headers; a *content* line of dashes or pluses arrives
# prefixed ("+---") and must be counted as content. Same for a content line that is just "...".
printf 'x\n---\n+++\n...\n' > "$repo/e.txt"
git -C "$repo" add -A
git -C "$repo" commit -qm "header-lookalike content"
head2="$(git -C "$repo" rev-parse HEAD)"
assert_exit 0 "content lines that resemble headers or ellipses still verify" -- \
  "$dp" --repo "$repo" --base "$head" --head "$head2" --out "$tmp/pkg/lookalike.diff"

# --- binary changes have their own known shape ------------------------------------------------
printf '\000\001\002\003' > "$repo/bin.dat"
git -C "$repo" add -A
git -C "$repo" commit -qm binary
head3="$(git -C "$repo" rev-parse HEAD)"
assert_exit 0 "a binary change verifies" -- \
  "$dp" --repo "$repo" --base "$head2" --head "$head3" --out "$tmp/pkg/bin.diff"
assert_contains "$(cat "$tmp/pkg/bin.diff")" "Binary files" \
  "fixture: the binary change really produced the Binary files line"

# --- an empty range is a complete empty diff --------------------------------------------------
assert_exit 0 "an empty range verifies" -- \
  "$dp" --repo "$repo" --base "$head" --head "$head" --out "$tmp/pkg/empty.diff"
assert_eq "" "$(cat "$tmp/pkg/empty.diff")" "an empty range writes an empty file"

# --- exit 2: arguments and destinations -----------------------------------------------------------
assert_exit 2 "relative --repo exits 2" -- "$dp" --repo repo --base "$base" --head "$head" --out "$out"
assert_exit 2 "relative --out exits 2"  -- "$dp" --repo "$repo" --base "$base" --head "$head" --out pkg/x.diff
assert_exit 2 "an unknown --base exits 2" -- "$dp" --repo "$repo" --base nope --head "$head" --out "$out"
assert_exit 2 "a dash-prefixed --head exits 2" -- \
  "$dp" --repo "$repo" --base "$base" --head "--output=$tmp/x" --out "$out"
assert_exit 2 "a missing --out exits 2" -- "$dp" --repo "$repo" --base "$base" --head "$head"
assert_exit 2 "an --out whose directory does not exist exits 2" -- \
  "$dp" --repo "$repo" --base "$base" --head "$head" --out "$tmp/nodir/x.diff"
assert_exit 2 "--verify-only with no file to verify exits 2" -- \
  "$dp" --repo "$repo" --base "$base" --head "$head" --out "$tmp/pkg/none.diff" --verify-only
assert_exit 2 "an unknown flag exits 2" -- gen --stat
assert_eq "" "$("$dp" --repo repo --base "$base" --head "$head" --out "$out" 2>/dev/null)" \
  "exit 2 prints nothing on stdout"
```

In `tests/test_bin.sh`, add `foreman-diff` to both `for w in …` wrapper lists (after
`foreman-roots` if task 1 has landed, after `foreman-root` if not), and after the
`foreman-brief exits 2 for a relative plan path` assertion add

```bash
assert_exit 2 "foreman-diff exits 2 for a relative repo" -- \
  "$b/foreman-diff" --repo relative --base HEAD --head HEAD --out "$FOREMAN_ROOT/x.diff"
```

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: `test_diff.sh aborted before reporting counts` and the three `bin/foreman-diff` rows
plus the plumbing row from `test_bin.sh`. Nothing else red.

- [ ] **Step 3: Implement**

Create `scripts/diff-package.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Writes `git diff <base> <head>` to --out and then proves the file is the whole diff. The proof
# is structural, on purpose: git's own --numstat says how many paths changed and how many lines
# were added and removed, and the written file must agree; and a unified diff is built from a
# small closed set of line shapes, so any line outside that set is foreign. Nothing here knows
# or names the tool that abridged phase A's review packages -- it does not need to.

repo=""; base=""; head=""; out=""; verify_only=false
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; repo="$2"; shift 2 ;;
    --base) [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; base="$2"; shift 2 ;;
    --head) [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; head="$2"; shift 2 ;;
    --out)  [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; out="$2";  shift 2 ;;
    --verify-only) verify_only=true; shift ;;
    *) foreman_die "unknown argument: $1" 2 ;;
  esac
done
[ -n "$repo" ] || foreman_die "--repo is required" 2
[ -n "$base" ] || foreman_die "--base is required" 2
[ -n "$head" ] || foreman_die "--head is required" 2
[ -n "$out" ]  || foreman_die "--out is required" 2
foreman_require_abs "$repo" "--repo"
foreman_require_abs "$out" "--out"
[ -d "$repo" ] || foreman_die "repo not found: $repo" 2
# A leading '-' would be read by git as an option, not a revision.
case "$base" in -*) foreman_die "--base must not start with '-': $base" 2 ;; esac
case "$head" in -*) foreman_die "--head must not start with '-': $head" 2 ;; esac
git -C "$repo" rev-parse --verify --quiet "$base^{commit}" >/dev/null \
  || foreman_die "--base does not name a commit in $repo: $base" 2
git -C "$repo" rev-parse --verify --quiet "$head^{commit}" >/dev/null \
  || foreman_die "--head does not name a commit in $repo: $head" 2

if ! $verify_only; then
  out_dir="$(dirname "$out")"
  [ -d "$out_dir" ] || foreman_die "output directory not found: $out_dir" 2
  # Write beside the destination and rename into place: a caller must find either the previous
  # complete package or the new one, never a partial write (same reasoning as task-brief.sh).
  tmp_out="$(mktemp "$out_dir/.diff-package.XXXXXX")" \
    || foreman_die "cannot create a temp file in: $out_dir" 2
  trap 'rm -f "$tmp_out"' EXIT
  git -C "$repo" diff "$base" "$head" > "$tmp_out" || foreman_die "git diff failed" 2
  mv -f -- "$tmp_out" "$out" || foreman_die "failed to move the package into place: $out" 2
  trap - EXIT
fi
[ -f "$out" ] || foreman_die "no file to verify at: $out" 2

# Expected shape, from git's own accounting. numstat: one line per changed path,
# "<added>\t<deleted>\t<path>", with "-\t-" for a binary path.
numstat="$(git -C "$repo" diff --numstat "$base" "$head")"
want_files="$(printf '%s\n' "$numstat" | grep -c . || true)"
want_plus="$(printf '%s\n' "$numstat"  | awk -F'\t' '$1 != "-" {s += $1} END {print s + 0}')"
want_minus="$(printf '%s\n' "$numstat" | awk -F'\t' '$1 != "-" {s += $2} END {print s + 0}')"

# Observed shape, from the file. Added and removed lines are the "+"/"-" lines that are not the
# "+++ b/…" / "--- a/…" (or /dev/null) file headers. A content line that itself begins with
# "---" or "+++" arrives with a diff prefix in front ("+---") and is counted as content.
got_files="$(grep -c '^diff --git ' "$out" || true)"
got_plus="$(awk  '/^\+/ && !/^\+\+\+ (b\/|\/dev\/null)/ {n++} END {print n + 0}' "$out")"
got_minus="$(awk '/^-/  && !/^--- (a\/|\/dev\/null)/    {n++} END {print n + 0}' "$out")"

# Every line a `git diff` without --binary can produce starts with one of these. Anything else
# was put there by something that is not git.
allowed='^(diff |index |--- |\+\+\+ |@@ | |\+|-|\\ |old mode |new mode |deleted file mode |new file mode |similarity index |dissimilarity index |rename from |rename to |copy from |copy to |Binary files )'
foreign="$(grep -vcE "$allowed" "$out" || true)"

incomplete=""
[ "$got_files" = "$want_files" ] || incomplete="$incomplete files:$got_files/$want_files"
[ "$got_plus"  = "$want_plus"  ] || incomplete="$incomplete added:$got_plus/$want_plus"
[ "$got_minus" = "$want_minus" ] || incomplete="$incomplete removed:$got_minus/$want_minus"
[ "$foreign" = "0" ]             || incomplete="$incomplete foreign-lines:$foreign"

if [ -n "$incomplete" ]; then
  printf 'incomplete diff at %s:%s\n' "$out" "$incomplete" >&2
  exit 1
fi
printf '%s\n' "$out"
```

Create `bin/foreman-diff` with the same body as `bin/foreman-state`, execing
`"$root/scripts/diff-package.sh" "$@"` and with the comment's example path changed to
`scripts/diff-package.sh`. Then `chmod +x scripts/diff-package.sh bin/foreman-diff`.

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, roughly `+33` on the count before this task. Count your own.

- [ ] **Step 5: Mutation-check the new assertions**

Temporarily remove the `foreign=` line and its `incomplete` clause: `a diff carrying a line no
unified diff can contain exits 1` goes red and nothing else does. Restore. Temporarily make
`got_files` count `^index ` lines instead of `^diff --git `: `a diff missing a whole file` still
exits 1 through the `added:` count, but its `files:3/4` stderr assertion goes red. Restore.
Temporarily drop the `$1 != "-"` guard from both `want_` awk lines: `a binary change verifies`
goes red (awk reads `-` as 0 on one side and the header count still matches, so the failure
shows only if you also change the guard to count binary rows as 1 — do that variant too and
confirm the same assertion is the one that moves). Restore. Run the suite once more, green.

- [ ] **Step 6: Commit**

```bash
git add scripts/diff-package.sh bin/foreman-diff tests/test_diff.sh tests/test_bin.sh
git commit -m "scripts: foreman-diff writes a review package and proves it complete, structurally [JUDGE-1]"
```
