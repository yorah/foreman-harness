# Task 1: `foreman_roots` and the `foreman-roots` wrapper

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Modify: `scripts/lib.sh` — append one function, `foreman_roots`; change nothing above it
- Create: `scripts/roots.sh` — the CLI over that function
- Create: `bin/foreman-roots` — the wrapper, same shape as `bin/foreman-state`
- Create: `tests/test_roots.sh`
- Modify: `tests/test_bin.sh` — the two `for w in …` wrapper lists, plus one plumbing assertion

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `foreman_roots <abs-start-dir>` (a `lib.sh` function) and `foreman-roots
  <abs-start-dir>` (its CLI). Both print exactly one line on stdout,
  `program_root<TAB>work_root<TAB>config_path`, all three absolute, and exit `0`; or print one
  reason on stderr, nothing on stdout, and exit `2`. Tasks 8 and 9 call the wrapper; task 10
  calls `scripts/roots.sh` directly.

**Why this exists.** Spec §4.4: only the program manager and `foreman-init` ever resolve roots,
through one function, so that every skill and template that today hardcodes `docs/dev/program/`
reads through it instead. The lookup is the spec's, plus one addition found by running this
repository's own program manager: it runs from a **linked worktree**, where
`git rev-parse --show-toplevel` names the worktree and `<toplevel>/.foreman/` does not exist.
`git rev-parse --git-common-dir` names the main checkout's `.git`, whose parent is where
`.foreman/` lives. Without that third step a PM started in a worktree is told the repository
is not initialised while the work root sits one directory over.

---

- [ ] **Step 1: Write the failing tests**

Create `tests/test_roots.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

fr="$FOREMAN_ROOT/scripts/roots.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- single mode: from the checkout root, a subdirectory, the work root itself, a worktree ----
repo="$tmp/repo"
mkdir -p "$repo/.foreman" "$repo/docs/dev" "$repo/sub"
git -C "$repo" init -q
printf '%s\n' '{"program":"p","mode":"single","created":"2026-09-03"}' > "$repo/.foreman/foreman.json"
git -C "$repo" commit -q --allow-empty -m init

expected="$(printf '%s\t%s\t%s' "$repo/docs/dev" "$repo/.foreman" "$repo/.foreman/foreman.json")"
assert_eq "$expected" "$("$fr" "$repo" 2>/dev/null)" \
  "single mode resolves from the checkout root"
assert_eq "$expected" "$("$fr" "$repo/sub" 2>/dev/null)" \
  "single mode resolves from a subdirectory of the checkout"
assert_eq "$expected" "$("$fr" "$repo/.foreman" 2>/dev/null)" \
  "single mode resolves when started inside the work root itself"

# A linked worktree has its own toplevel and no .foreman/ of its own; the work root is at the
# main checkout, which --git-common-dir names. This is how this repository's own PM runs.
git -C "$repo" worktree add -q "$tmp/wt" -b feat/x 2>/dev/null
assert_eq "$expected" "$("$fr" "$tmp/wt" 2>/dev/null)" \
  "single mode resolves from a linked worktree to the main checkout's work root"

# --- multi mode: a foreman.json at the start directory is the state repository -----------------
state="$tmp/state"
mkdir -p "$state"
printf '%s\n' '{"program":"p","mode":"multi"}' > "$state/foreman.json"
assert_eq "$(printf '%s\t%s\t%s' "$state" "$state" "$state/foreman.json")" \
  "$("$fr" "$state" 2>/dev/null)" \
  "multi mode: both roots are the directory holding foreman.json"

# Precedence: the start directory's own foreman.json wins over the enclosing checkout's
# .foreman/ -- a state repository that happens to live inside some git checkout must resolve to
# itself, not to that checkout's single-mode config.
mkdir -p "$repo/state2"
printf '%s\n' '{"mode":"multi"}' > "$repo/state2/foreman.json"
assert_eq "$(printf '%s\t%s\t%s' "$repo/state2" "$repo/state2" "$repo/state2/foreman.json")" \
  "$("$fr" "$repo/state2" 2>/dev/null)" \
  "a foreman.json at the start directory takes precedence over the checkout's .foreman/"

# --- exit 2: not initialised, bad arguments -----------------------------------------------------
bare="$tmp/bare"
mkdir -p "$bare"
git -C "$bare" init -q
assert_exit 2 "an initialised repository with no .foreman/ exits 2"      -- "$fr" "$bare"
assert_exit 2 "a directory outside any repository, no foreman.json, exits 2" -- "$fr" "$tmp"
assert_exit 2 "a relative start directory exits 2"                        -- "$fr" "repo"
assert_exit 2 "a missing start directory exits 2"                         -- "$fr" "$tmp/nope"
assert_exit 2 "no argument exits 2"                                       -- "$fr"
assert_exit 2 "two arguments exit 2"                                      -- "$fr" "$repo" "$repo"
assert_eq "" "$("$fr" "$bare" 2>/dev/null)" "exit 2 prints nothing on stdout"
assert_contains "$("$fr" "$bare" 2>&1 >/dev/null)" "no foreman.json" \
  "exit 2 names the reason on stderr"

# --- exit 2: a config that exists but cannot be trusted ---------------------------------------
bad="$tmp/bad"
mkdir -p "$bad/.foreman"
git -C "$bad" init -q
printf '{"mode":"single"' > "$bad/.foreman/foreman.json"
assert_exit 2 "malformed JSON exits 2" -- "$fr" "$bad"
printf '%s\n' '{"mode":"sideways"}' > "$bad/.foreman/foreman.json"
assert_exit 2 "an unknown mode exits 2" -- "$fr" "$bad"
assert_contains "$("$fr" "$bad" 2>&1 >/dev/null)" 'mode must be "single" or "multi"' \
  "an unknown mode is named as the reason"
printf '%s\n' '{"program":"p"}' > "$bad/.foreman/foreman.json"
assert_exit 2 "a missing mode exits 2" -- "$fr" "$bad"
printf '%s\n' '{"mode":"single"}' '{"mode":"single"}' > "$bad/.foreman/foreman.json"
assert_exit 2 "two concatenated objects exit 2" -- "$fr" "$bad"
printf '%s\n' '["single"]' > "$bad/.foreman/foreman.json"
assert_exit 2 "a non-object top level exits 2" -- "$fr" "$bad"

# --- the function itself, sourced, has the same contract as the CLI ---------------------------
lib_out="$(source "$FOREMAN_ROOT/scripts/lib.sh"; foreman_roots "$repo" 2>/dev/null)"
assert_eq "$expected" "$lib_out" "foreman_roots sourced from lib.sh prints the same line"
lib_rc=0
(source "$FOREMAN_ROOT/scripts/lib.sh"; foreman_roots "$bare" >/dev/null 2>&1) || lib_rc=$?
assert_eq "2" "$lib_rc" "foreman_roots sourced from lib.sh returns 2 when not initialised"
```

In `tests/test_bin.sh`, change both wrapper lists

```bash
for w in foreman-gate foreman-brief foreman-baseline foreman-state foreman-root; do
```

to

```bash
for w in foreman-gate foreman-brief foreman-baseline foreman-state foreman-root foreman-roots; do
```

(there are two such lines; change both), and after the line

```bash
assert_exit 2 "foreman-brief exits 2 for a relative plan path" -- \
  "$b/foreman-brief" --plan relative/path --task 1 --phase-dir "$FOREMAN_ROOT" \
  --worktree "$FOREMAN_ROOT"
```

add

```bash
assert_exit 2 "foreman-roots exits 2 for a relative start directory" -- \
  "$b/foreman-roots" relative/path
```

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: `test_roots.sh aborted before reporting counts` (or every assertion in it failing with
"No such file"), and `bin/foreman-roots is missing or not executable` plus its shebang and
strict-mode rows from `test_bin.sh`. No `FAIL` from any other file.

- [ ] **Step 3: Implement**

Append to `scripts/lib.sh`:

```bash

# foreman_roots <abs-start-dir> — prints "program_root<TAB>work_root<TAB>config_path", all three
# absolute, and returns 0; or prints one reason on stderr, nothing on stdout, and returns 2. Only
# the program manager and foreman-init call this. A phase session never resolves roots: its
# kickoff carries every path it needs, absolute (spec §4.4).
#
# Lookup order, first hit wins:
#   1. <start>/foreman.json                 multi mode: the start directory is the state repository
#   2. <toplevel>/.foreman/foreman.json     single mode, <toplevel> being the checkout <start> is in
#   3. <common>/.foreman/foreman.json       single mode from a linked worktree: --show-toplevel
#      names the worktree, which has no .foreman/ of its own; --git-common-dir names the main
#      checkout's .git, and its parent is where .foreman/ lives.
# The file must be exactly one JSON object with "mode" of "single" or "multi" — the same validity
# rule foreman_setting applies to settings files, for the same reason: a half-written config
# fails loudly instead of being read as far as it parses. single: the work root is the directory
# holding the file and the program root is <parent-of-work-root>/docs/dev. multi: both roots are
# the directory holding the file.
foreman_roots() {
  local start="${1:-}" cfg="" top common mode wr pr
  case "$start" in
    /*) : ;;
    *) printf 'start directory must be absolute, got: %s\n' "$start" >&2; return 2 ;;
  esac
  [ -d "$start" ] || { printf 'start directory does not exist: %s\n' "$start" >&2; return 2; }

  if [ -f "$start/foreman.json" ]; then
    cfg="$start/foreman.json"
  else
    top="$(git -C "$start" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$top" ] && [ -f "$top/.foreman/foreman.json" ]; then
      cfg="$top/.foreman/foreman.json"
    else
      common="$(git -C "$start" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
      common="${common%/.git}"
      if [ -n "$common" ] && [ -f "$common/.foreman/foreman.json" ]; then
        cfg="$common/.foreman/foreman.json"
      fi
    fi
  fi
  if [ -z "$cfg" ]; then
    printf 'no foreman.json at %s/foreman.json or at <checkout>/.foreman/foreman.json (start: %s)\n' \
      "$start" "$start" >&2
    return 2
  fi

  if ! jq -s -e 'length == 1 and (.[0] | type == "object")' "$cfg" >/dev/null 2>&1; then
    printf 'not a single JSON object: %s\n' "$cfg" >&2
    return 2
  fi
  mode="$(jq -r '.mode // ""' "$cfg" 2>/dev/null || true)"
  wr="$(dirname "$cfg")"
  case "$mode" in
    single) pr="$(dirname "$wr")/docs/dev" ;;
    multi)  pr="$wr" ;;
    *) printf 'mode must be "single" or "multi", got "%s": %s\n' "$mode" "$cfg" >&2; return 2 ;;
  esac
  printf '%s\t%s\t%s\n' "$pr" "$wr" "$cfg"
}
```

Create `scripts/roots.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# One positional argument, the absolute directory to resolve from. Everything else is in lib.sh:
# this file exists so a skill can reach foreman_roots by bare wrapper name.
[ $# -eq 1 ] || foreman_die "usage: foreman-roots <abs-start-dir>" 2
foreman_roots "$1"
```

Create `bin/foreman-roots`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Thin wrapper so a skill can invoke this by bare name. Claude Code puts <plugin-root>/bin on
# PATH, but does NOT export $CLAUDE_PLUGIN_ROOT into the Bash tool's environment: a call site
# written as "$CLAUDE_PLUGIN_ROOT/scripts/roots.sh" expands to "/scripts/roots.sh" and fails.
# readlink -f resolves this file through any symlink, so the root comes from where the wrapper
# actually is, not from the caller's directory or an unset variable.
root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
exec "$root/scripts/roots.sh" "$@"
```

Then `chmod +x scripts/roots.sh bin/foreman-roots`.

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, and a count of roughly `660 + 25`. Count the assertions you added
rather than adjusting expectations. If `single mode resolves from a linked worktree` is the one
red line, check `git --version`: `--path-format=absolute` needs git 2.31 or later, and the
machine's git is the fact to report, not something to paper over with a fallback.

- [ ] **Step 5: Mutation-check the new assertions**

Temporarily delete the `common=` block (the third lookup): the worktree assertion must go red,
the others stay green. Restore. Temporarily change `single) pr=…docs/dev` to `…docs/devx`: the
three single-mode assertions and the sourced-function assertion go red. Restore. Temporarily
swap the order of lookups 1 and 2: the precedence assertion goes red. Restore. Temporarily
remove the `jq -s -e` validity check: the malformed-JSON and concatenated-objects assertions go
red (the mode check still catches `["single"]`). Restore. Run the suite once more, green.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib.sh scripts/roots.sh bin/foreman-roots tests/test_roots.sh tests/test_bin.sh
git commit -m "lib: foreman_roots resolves program and work roots from foreman.json; foreman-roots wrapper"
```
