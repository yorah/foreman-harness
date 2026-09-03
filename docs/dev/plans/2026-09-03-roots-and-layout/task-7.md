# Task 7: `foreman-state` on `--work-root`; the `git show` path retired

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Modify: `scripts/phase-state.sh` — rewritten; the `--head` frontmatter logic is the one part kept
- Modify: `tests/test_phase_state.sh` — rewritten
- Modify: `tests/test_bin.sh` — the `foreman-state` plumbing row
- Modify: `tests/test_dogfood.sh` — the `phase-state.sh` call near the end

**Interfaces:**
- Consumes: nothing from other tasks (task 1's `foreman_roots` is how a *caller* finds the work
  root; this script only receives it).
- Produces: `foreman-state --phase <slug> --work-root <abs> [--head]`. Reads
  `<work-root>/phases/<slug>/state.md` as a file. Exit `0` with the file (or, with `--head`, the
  frontmatter block, fences included) on stdout. Exit `2` with nothing on stdout and one reason on
  stderr, one of: `no ledger at <path>`, `work root is not a directory: <path>`, `no frontmatter
  …`, `unterminated frontmatter block …`, or an argument error. `--repo` and `--branch` are gone
  and exit `2` as unknown arguments. Tasks 8 and 9 write the call sites; the PM's triage keys on
  the literal `no ledger at`.

**Why this exists.** Spec §4.5 and §11: the PM and every phase share one work root on one
machine, so a ledger is a file. The `git show <branch>:<path>` read, its `STATE.md` branch
lookup and the two triage tables built around the fact that "no such file on branch" meant two
different things are retired — not kept as a fallback, because two read paths for one file is
drift waiting to happen. `STATE.md` keeps its `Branch` column for the probe; this script stops
reading `STATE.md` at all. **This is the one task that lowers the count** (43 assertions out,
about 27 in); tasks 1–6 exist in part to make that safe.

---

- [ ] **Step 1: Write the failing tests**

Replace `tests/test_phase_state.sh` wholesale:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

ps="$FOREMAN_ROOT/scripts/phase-state.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The work root is a plain directory here, deliberately not a git repository: spec §4.5 says a
# ledger is a file, and this read must need nothing else. (The real work root is a nested
# repository; that it is one is irrelevant to reading it.)
wr="$tmp/work"
mkdir -p "$wr/phases/alpha" "$wr/phases/noattr" "$wr/phases/midstart" "$wr/phases/unterm" \
         "$wr/phases/empty" "$wr/phases/adir/state.md"
cat > "$wr/phases/alpha/state.md" <<'MD'
---
phase: alpha
baseline: 100 at deadbee
---

Prose ledger. MARKER_BODY here.
MD
printf 'Just prose, no frontmatter at all.\n'          > "$wr/phases/noattr/state.md"
printf '\n---\nphase: midstart\n---\n\nBody.\n'         > "$wr/phases/midstart/state.md"
printf -- '---\nphase: unterm\nno closing marker\n'    > "$wr/phases/unterm/state.md"
: > "$wr/phases/empty/state.md"

run() { "$ps" --work-root "$wr" "$@" 2>/dev/null; }
err() { "$ps" --work-root "$wr" "$@" 2>&1 >/dev/null; }

assert_eq "" "$(git -C "$wr" rev-parse --git-dir 2>/dev/null || true)" \
  "fixture: the work root is not a git repository, so the read cannot be leaning on one"

# --- the read -------------------------------------------------------------------------------------
full="$(run --phase alpha)"
assert_contains "$full" "MARKER_BODY"  "reads the ledger as a file at <work-root>/phases/<slug>/state.md"
assert_contains "$full" "phase: alpha" "includes the frontmatter"
assert_contains "$(run --phase noattr)" "Just prose" \
  "a full read returns the file even when --head would refuse it"

head_out="$(run --phase alpha --head)"
assert_contains     "$head_out" "baseline: 100 at deadbee" "--head keeps the frontmatter"
assert_not_contains "$head_out" "MARKER_BODY"              "--head drops the prose body"
assert_eq "$(printf -- '---\nphase: alpha\nbaseline: 100 at deadbee\n---')" "$head_out" \
  "--head is exactly the frontmatter block, both fences included"

# Flag order is free.
assert_contains "$("$ps" --head --phase alpha --work-root "$wr" 2>/dev/null)" "phase: alpha" \
  "flags may come in any order"

# --- the three named exit-2 reasons spec §12.3 requires --------------------------------------------
assert_exit 2 "a phase with no ledger exits 2" -- "$ps" --work-root "$wr" --phase gamma
assert_contains "$(err --phase gamma)" "no ledger at $wr/phases/gamma/state.md" \
  "a missing ledger names the exact path it looked for"

assert_exit 2 "--head on a file with no frontmatter exits 2"          -- "$ps" --work-root "$wr" --phase noattr --head
assert_contains "$(err --phase noattr --head)" "no frontmatter" "a malformed head names the defect"
assert_exit 2 "--head on frontmatter not starting on line 1 exits 2"  -- "$ps" --work-root "$wr" --phase midstart --head
assert_exit 2 "--head on an unterminated frontmatter block exits 2"   -- "$ps" --work-root "$wr" --phase unterm --head
assert_contains "$(err --phase unterm --head)" "unterminated frontmatter" \
  "an unterminated head names the defect"
assert_exit 2 "--head on an empty ledger exits 2" -- "$ps" --work-root "$wr" --phase empty --head

assert_exit 2 "a missing work root exits 2" -- "$ps" --work-root "$tmp/nope" --phase alpha
assert_contains "$("$ps" --work-root "$tmp/nope" --phase alpha 2>&1 >/dev/null)" \
  "work root is not a directory" "an unreadable work root names itself"
assert_exit 2 "a ledger path that is a directory exits 2" -- "$ps" --work-root "$wr" --phase adir

# --- arguments ------------------------------------------------------------------------------------
assert_exit 2 "a relative work root exits 2"  -- "$ps" --work-root work --phase alpha
assert_exit 2 "an empty --work-root exits 2"  -- "$ps" --work-root "" --phase alpha
assert_exit 2 "missing --work-root exits 2"   -- "$ps" --phase alpha
assert_exit 2 "missing --phase exits 2"       -- "$ps" --work-root "$wr"
assert_exit 2 "a phase with a slash exits 2 rather than escaping phases/" \
  -- "$ps" --work-root "$wr" --phase "../alpha"
assert_exit 2 "--branch is retired and exits 2 as an unknown argument" \
  -- "$ps" --work-root "$wr" --phase alpha --branch feat/alpha
assert_exit 2 "--repo is retired and exits 2 as an unknown argument" \
  -- "$ps" --work-root "$wr" --phase alpha --repo "$wr"
assert_eq "" "$("$ps" --work-root "$wr" --phase gamma 2>/dev/null)" "exit 2 prints nothing on stdout"

# --- a read changes nothing ------------------------------------------------------------------------
before="$(find "$wr" -type f -exec sha256sum {} + | sort)"
run --phase alpha >/dev/null; run --phase alpha --head >/dev/null; run --phase gamma >/dev/null
assert_eq "$before" "$(find "$wr" -type f -exec sha256sum {} + | sort)" \
  "reading, and failing to read, changes nothing under the work root"

# --- the retired path stays retired (spec §11) -----------------------------------------------------
# A ledger that exists only as a commit on some branch, and not as a file in the work root, is
# not found. There is one read path, and it is the file.
repo="$tmp/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" commit -q --allow-empty -m base
git -C "$repo" checkout -qb feat/alpha
mkdir -p "$repo/phases/alpha"
printf -- '---\nphase: alpha\n---\n\nON_BRANCH_ONLY\n' > "$repo/phases/alpha/state.md"
git -C "$repo" add -A
git -C "$repo" commit -qm "ledger on a branch"
git -C "$repo" checkout -q main
assert_exit 2 "a ledger committed on a branch but absent as a file is not found (git show retired)" \
  -- "$ps" --work-root "$repo" --phase alpha
assert_not_contains "$("$ps" --work-root "$repo" --phase alpha 2>/dev/null)" "ON_BRANCH_ONLY" \
  "no branch content leaks through"
```

In `tests/test_bin.sh`, change

```bash
assert_exit 2 "foreman-state exits 2 for an unknown phase" -- \
  "$b/foreman-state" --repo "$FOREMAN_ROOT" --phase no-such-phase
```

to

```bash
assert_exit 2 "foreman-state exits 2 for an unknown phase" -- \
  "$b/foreman-state" --work-root "$FOREMAN_ROOT" --phase no-such-phase
```

In `tests/test_dogfood.sh`, change the last two lines

```bash
assert_exit 2 "an unknown phase is a clean exit-2, not a crash" -- \
  "$R/scripts/phase-state.sh" --repo "$R" --phase no-such-phase
```

to

```bash
assert_exit 2 "an unknown phase is a clean exit-2, not a crash" -- \
  "$R/scripts/phase-state.sh" --work-root "$R" --phase no-such-phase
```

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: most of `test_phase_state.sh` red (`--work-root` is an unknown argument today, so
every positive read fails and the exit-2 assertions pass for the wrong reason — which is why
the `no ledger at` and `work root is not a directory` stderr assertions are there: they go red
too). The two plumbing rows red. Nothing else.

- [ ] **Step 3: Implement**

Replace `scripts/phase-state.sh` wholesale:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Reads one phase's ledger, <work-root>/phases/<slug>/state.md, as a file. The PM and every phase
# share one work root on one machine (spec §4.5), so there is nothing to resolve and no branch to
# consult: the previous `git show <branch>:<path>` read, its STATE.md lookup and the triage that
# grew around "no such file on branch" meaning two things are retired, not kept as a fallback
# (spec §11) -- two read paths for one file is drift waiting to happen.

phase=""; work_root=""; head_only=false
while [ $# -gt 0 ]; do
  case "$1" in
    --phase)     [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; phase="$2"; shift 2 ;;
    --work-root) [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; work_root="$2"; shift 2 ;;
    --head)      head_only=true; shift ;;
    *) foreman_die "unknown argument: $1" 2 ;;
  esac
done

[ -n "$phase" ]     || foreman_die "--phase is required" 2
[ -n "$work_root" ] || foreman_die "--work-root is required" 2
foreman_require_abs "$work_root" "--work-root"
# The slug is one path segment. Anything else would read outside phases/.
case "$phase" in
  */*|.|..) foreman_die "--phase must be a single path segment, got: $phase" 2 ;;
esac
[ -d "$work_root" ] || foreman_die "work root is not a directory: $work_root" 2
[ -r "$work_root" ] || foreman_die "work root is not readable: $work_root" 2

path="$work_root/phases/$phase/state.md"
[ -e "$path" ] || foreman_die "no ledger at $path" 2
{ [ -f "$path" ] && [ -r "$path" ]; } || foreman_die "ledger is not a readable file: $path" 2
content="$(cat "$path")"

if $head_only; then
  # Validate the frontmatter block structurally before extracting it: a file that does not
  # open with '---' on line 1, or whose block never closes, must refuse rather than silently
  # fall back to dumping the whole file as if it were the (bounded) machine-readable head.
  # `exit` inside an awk pattern block still runs END before terminating, so each early-exit
  # branch below sets `done` to keep END from printing a second, contradictory verdict.
  fm_status="$(printf '%s\n' "$content" | awk '
    NR==1 && $0 != "---" { print "no-frontmatter"; done=1; exit }
    NR==1                { infm=1; next }
    infm && $0 == "---"  { print "ok"; done=1; exit }
    infm                 { next }
    END { if (!done) print (infm ? "unterminated" : "no-frontmatter") }
  ')"
  case "$fm_status" in
    ok) ;;
    no-frontmatter)
      foreman_die "no frontmatter (file must open with '---' on line 1) in $path" 2 ;;
    unterminated)
      foreman_die "unterminated frontmatter block (no closing '---') in $path" 2 ;;
    *) foreman_die "could not parse frontmatter in $path" 2 ;;
  esac
  printf '%s\n' "$content" | awk '
    NR==1 && $0=="---" { infm=1; print; next }
    infm && $0=="---"  { print; exit }
    infm               { print }
  '
else
  printf '%s\n' "$content"
fi
```

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, and a count about `16` below the count before this task — still
well above `660` if tasks 1–6 landed first. If the count is *below 660*, stop: the task order
was not followed, and the fix is to land the missing earlier task, not to skip the baseline.

- [ ] **Step 5: Mutation-check**

Temporarily change `no ledger at` to `missing ledger`: the stderr assertion goes red. Restore.
Temporarily remove the `*/*|.|..` guard: the `../alpha` assertion goes red (it will find
`$wr/phases/../alpha/state.md`, which does not exist — so first create `$wr/alpha/state.md` in
the fixture while mutating, confirm it is *read*, then restore both). Temporarily replace `cat
"$path"` with `git -C "$work_root" show "HEAD:phases/$phase/state.md"`: the retired-path
assertion goes red. Restore. Green.

- [ ] **Step 6: Commit**

```bash
git add scripts/phase-state.sh tests/test_phase_state.sh tests/test_bin.sh tests/test_dogfood.sh
git commit -m "scripts: foreman-state reads the ledger as a file at --work-root; git show path and STATE.md lookup retired"
```
