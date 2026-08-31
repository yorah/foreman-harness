# Task 1: Plugin skeleton, manifests, and the test harness

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `.claude-plugin/plugin.json`
- Create: `tests/lib_assert.sh`
- Create: `tests/run.sh`
- Test: `tests/test_manifests.sh`

**Interfaces:**
- Produces, for every later task:
  - `tests/run.sh` — the repo's only gate command. Discovers and runs `tests/test_*.sh`.
  - `tests/lib_assert.sh` — sourced by every test file. Exposes `assert_eq <expected>
    <actual> <label>`, `assert_exit <expected-code> <label> -- <cmd...>`, `assert_contains
    <haystack> <needle> <label>`, `assert_not_contains <haystack> <needle> <label>`,
    `fail <message>`.
  - `$HARNESS_ROOT` — absolute repo root, exported by `run.sh` to every test file.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_manifests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/tests/lib_assert.sh"

# --- marketplace manifest -------------------------------------------------
mp="$HARNESS_ROOT/.claude-plugin/marketplace.json"
[ -f "$mp" ] || fail "missing $mp"
assert_eq "harness" "$(jq -r '.name' "$mp")" "marketplace name"
assert_eq "1" "$(jq -r '.plugins | length' "$mp")" "marketplace declares one plugin"
assert_eq "harness" "$(jq -r '.plugins[0].name' "$mp")" "plugin name in marketplace"
assert_eq "./" "$(jq -r '.plugins[0].source' "$mp")" "plugin source is this directory"

# --- plugin manifest ------------------------------------------------------
pj="$HARNESS_ROOT/.claude-plugin/plugin.json"
[ -f "$pj" ] || fail "missing $pj"
assert_eq "harness" "$(jq -r '.name' "$pj")" "plugin name"
[ "$(jq -r '.version' "$pj")" != "null" ] || fail "plugin.json has no version"
[ "$(jq -r '.description' "$pj")" != "null" ] || fail "plugin.json has no description"

# --- frontmatter ----------------------------------------------------------
# Prints the frontmatter block of a markdown file (between the first two --- lines).
frontmatter() { awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1{print}' "$1"; }

while IFS= read -r f; do
  fm="$(frontmatter "$f")"
  assert_contains "$fm" "name:" "$(basename "$(dirname "$f")")/SKILL.md has name:"
  assert_contains "$fm" "description:" "$(basename "$(dirname "$f")")/SKILL.md has description:"
done < <(find "$HARNESS_ROOT/skills" -name SKILL.md 2>/dev/null)

while IFS= read -r f; do
  fm="$(frontmatter "$f")"
  assert_contains "$fm" "name:" "$(basename "$f") has name:"
  assert_contains "$fm" "description:" "$(basename "$f") has description:"
  assert_contains "$fm" "tools:" "$(basename "$f") has tools:"
done < <(find "$HARNESS_ROOT/agents" -name '*.md' 2>/dev/null)

while IFS= read -r f; do
  assert_contains "$(frontmatter "$f")" "description:" "$(basename "$f") has description:"
done < <(find "$HARNESS_ROOT/commands" -name '*.md' 2>/dev/null)

# --- no placeholders in shipped markdown ----------------------------------
for d in skills agents commands; do
  [ -d "$HARNESS_ROOT/$d" ] || continue
  hits="$(grep -rlE '\b(TODO|TBD|FIXME)\b' "$HARNESS_ROOT/$d" || true)"
  assert_eq "" "$hits" "no TODO/TBD/FIXME under $d/"
done
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run.sh`
Expected: FAIL — `tests/run.sh: No such file or directory`. That is the correct first failure;
the runner does not exist yet.

- [ ] **Step 3: Write the assertion library**

Create `tests/lib_assert.sh`:

```bash
#!/usr/bin/env bash
# Sourced by every test file. Requires $HARNESS_ROOT and $HARNESS_RESULTS_FILE.
# Deliberately no `set -euo pipefail` here: this file is sourced into the
# test file's shell, and adding strict mode here would change the test
# file's own error-handling semantics. That exemption is intentional.

_ok()   { printf 'P\n' >> "$HARNESS_RESULTS_FILE"; }
_bad()  { printf 'F\n' >> "$HARNESS_RESULTS_FILE"; printf '  FAIL: %s\n' "$1" >&2; }

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
```

- [ ] **Step 4: Write the runner**

Create `tests/run.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HARNESS_ROOT

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

for t in "$HARNESS_ROOT"/tests/test_*.sh; do
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

  HARNESS_RESULTS_FILE="$results_file" bash -c '
    source "$1"
    code=$?
    wait || true
    printf "D\n" >> "$HARNESS_RESULTS_FILE"
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
[ "$total_fail" -eq 0 ]
```

**This code is the version that shipped, after three fix rounds.** The design it replaced —
having each test print a `__COUNTS__ <pass> <fail>` summary on stdout for the runner to parse —
was false-green three separate ways, and the history is worth keeping because each break was
found only by someone trying to break it:

1. A test printing a `__COUNTS__`-shaped line and then dying was scored as a full pass with
   fabricated counts. The runner trusted a summary the test itself computed.
2. Moving that summary to a temp file did not help: the path was exported into the same shell
   the test is sourced into, and `exit` inside a sourced file kills the wrapper before its
   trusted write, so planted counts survived.
3. Once counting moved to per-assertion `P`/`F` records, a *backgrounded* failing assertion was
   still dropped — its line landed after the runner had already read and removed the file.

The rule the final design follows: **nothing but the runner computes the score.** The test
records individual assertions; the runner counts them, appends its own `D` completion sentinel
after `source` returns, `wait`s for the test's background jobs first, and requires all three of
a zero exit status, at least one assertion, and the sentinel.

- [ ] **Step 5: Write the manifests**

Create `.claude-plugin/marketplace.json`:

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "harness",
  "description": "A three-tier development harness: a program manager that coordinates, phase sessions that execute, and task subagents that write the code.",
  "owner": {
    "name": "yorah"
  },
  "plugins": [
    {
      "name": "harness",
      "description": "Program-manager orchestration with spec-driven, subagent-executed phases and a gate chain that catches regressions by mechanism.",
      "source": "./",
      "category": "workflow"
    }
  ]
}
```

Create `.claude-plugin/plugin.json`:

```json
{
  "name": "harness",
  "description": "A three-tier development harness: a program manager that coordinates, phase sessions that execute, and task subagents that write the code. Distilled from three projects run this way.",
  "version": "0.1.0",
  "author": {
    "name": "yorah"
  },
  "license": "MIT"
}
```

- [ ] **Step 6: Make the scripts executable and run the suite**

```bash
chmod +x tests/run.sh tests/lib_assert.sh tests/test_manifests.sh
bash tests/run.sh
```

Expected: `1 files, 5 passed, 0 failed`, exit 0. Five assertions: four on the marketplace
manifest, one on the plugin name. The `[ -f ... ]` and `!= null` guards call `fail` only on
their error path, so they contribute nothing when they pass; the `skills/`, `agents/` and
`commands/` loops contribute nothing until those directories exist. Record the observed
number — it becomes the baseline for Task 2.

- [ ] **Step 7: Verify the runner catches a dying test**

```bash
printf '#!/usr/bin/env bash\nset -euo pipefail\nexit 3\n' > tests/test_zzz_canary.sh
bash tests/run.sh; echo "exit=$?"
rm tests/test_zzz_canary.sh
```

Expected: output contains `aborted before reporting counts` and a non-zero exit. Then confirm
`bash tests/run.sh` is green again after the removal.

- [ ] **Step 8: Commit**

```bash
git add .claude-plugin tests
git commit -m "feat: plugin manifests and a zero-dependency test harness"
```

**Report:** record the passing assertion count from Step 6 — it is the baseline for Task 2.
