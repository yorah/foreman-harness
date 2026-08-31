# Task 2: `scripts/lib.sh` and the refusal gate

Implements spec §12.0. This is the mechanism behind "refuse to run the harness if not on Fable
or Opus at effort ≥ high". It reads a real configured value rather than asking the model to
attest to one.

**Files:**
- Create: `scripts/lib.sh`
- Create: `scripts/resolve-gate.sh`
- Test: `tests/test_resolve_gate.sh`

**Interfaces:**
- Produces, for Tasks 7 and 9:
  - `scripts/lib.sh`, sourced (never executed), exposing:
    - `harness_die <message> [exit-code]` — message to stderr, exit (default 2)
    - `harness_repo_root [start-dir]` — absolute repo root, or empty and non-zero
    - `harness_settings_chain <repo-root>` — settings paths, most specific first
    - `harness_setting <repo-root> <jq-path>` — prints `value<TAB>source-path` for the first
      settings file defining it; returns 1 if none does
  - `scripts/resolve-gate.sh --model <name> [--repo <abs-path>]` — prints a JSON object with
    keys `verdict` (`pass` | `refuse` | `unknown`), `model`, `effort`, `effort_source`,
    `reason`. Exit `0` pass, `1` refuse, `2` cannot determine.


> **Historical reference code.** The code blocks below are the plan as written *before*
> execution. Several were superseded by this task's own fix rounds and are **not** what shipped
> — the model check below, for one, shows a substring match (`*opus*|*fable*`) that the shipped
> `resolve-gate.sh` replaced with whole-token matching because the substring form accepts
> `notopus` and `fabled`. **The files in the repository are authoritative; this document
> records intent, not current behaviour.** Tracked as `[T-PLAN]` in `docs/dev/backlog.md`.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_resolve_gate.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$HARNESS_ROOT/tests/lib_assert.sh"

gate="$HARNESS_ROOT/scripts/resolve-gate.sh"
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run.sh`
Expected: FAIL — every assertion fails because `scripts/resolve-gate.sh` does not exist. Confirm
the failures name `resolve-gate.sh` and not something else.

- [ ] **Step 3: Write `scripts/lib.sh`**

```bash
#!/usr/bin/env bash
# Shared helpers for harness scripts. Source this file; do not execute it.

harness_die() {
  printf '%s\n' "$1" >&2
  exit "${2:-2}"
}

# harness_require_abs <path> <label> — exit 2 unless the path is absolute.
harness_require_abs() {
  case "$1" in
    /*) : ;;
    *) harness_die "$2 must be an absolute path, got: $1" 2 ;;
  esac
}

# harness_repo_root [start-dir] — absolute toplevel, or empty + non-zero.
harness_repo_root() {
  git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null
}

# harness_settings_chain <repo-root> — settings paths, most specific first.
harness_settings_chain() {
  printf '%s\n' \
    "$1/.claude/settings.local.json" \
    "$1/.claude/settings.json" \
    "$HOME/.claude/settings.json"
}

# harness_setting <repo-root> <jq-path> — prints "value<TAB>source"; returns 1 if unset.
harness_setting() {
  local root="$1" key="$2" f v
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    v="$(jq -r "$key // empty" "$f" 2>/dev/null || true)"
    if [ -n "$v" ]; then
      printf '%s\t%s\n' "$v" "$f"
      return 0
    fi
  done < <(harness_settings_chain "$root")
  return 1
}
```

- [ ] **Step 4: Write `scripts/resolve-gate.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

model=""; repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model) [ $# -ge 2 ] || harness_die "$1 requires a value" 2; model="$2"; shift 2 ;;
    --repo)  [ $# -ge 2 ] || harness_die "$1 requires a value" 2; repo="$2"; shift 2 ;;
    *) harness_die "unknown argument: $1" 2 ;;
  esac
done
[ -n "$model" ] || harness_die "--model is required" 2

if [ -n "$repo" ]; then
  harness_require_abs "$repo" "--repo"
else
  repo="$(harness_repo_root "$PWD" || true)"
  repo="${repo:-$PWD}"
fi

emit() {  # emit <verdict> <effort> <source> <reason>
  jq -n --arg v "$1" --arg m "$model" --arg e "$2" --arg s "$3" --arg r "$4" \
    '{verdict:$v, model:$m,
      effort:(if $e == "" then null else $e end),
      effort_source:(if $s == "" then null else $s end),
      reason:$r}'
}

# --- model tier -----------------------------------------------------------
model_lc="$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')"
model_ok=false
case "$model_lc" in
  *opus*|*fable*) model_ok=true ;;
esac

# --- effort ---------------------------------------------------------------
effort=""; effort_src=""
if pair="$(harness_setting "$repo" '.effortLevel')"; then
  effort="${pair%%$'\t'*}"
  effort_src="${pair#*$'\t'}"
fi

if [ -z "$effort" ]; then
  emit unknown "" "" "no effortLevel found in any settings file; cannot verify the gate"
  exit 2
fi

case "$effort" in
  low) rank=1 ;; medium) rank=2 ;; high) rank=3 ;; xhigh) rank=4 ;; max) rank=5 ;;
  *) emit unknown "$effort" "$effort_src" "unrecognised effortLevel '$effort'"; exit 2 ;;
esac

effort_ok=false
[ "$rank" -ge 3 ] && effort_ok=true

# --- verdict --------------------------------------------------------------
if $model_ok && $effort_ok; then
  emit pass "$effort" "$effort_src" \
    "model '$model' is Opus/Fable and effort '$effort' is at or above high"
  exit 0
fi

reasons=""
$model_ok  || reasons="model '$model' is not Opus or Fable"
$effort_ok || reasons="${reasons:+$reasons; }effort '$effort' is below high"
emit refuse "$effort" "$effort_src" "$reasons"
exit 1
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
chmod +x scripts/lib.sh scripts/resolve-gate.sh tests/test_resolve_gate.sh
bash tests/run.sh
```

Expected: `0 failed`, exit 0.

- [ ] **Step 6: Confirm the gate reads this machine correctly**

```bash
scripts/resolve-gate.sh --model claude-opus-5 --repo "$PWD"; echo "exit=$?"
```

Expected: `verdict: "pass"`, `effort: "high"`, `effort_source` ending
`/home/yorah/.claude/settings.json`, exit 0. If the source is not that file, the precedence
chain is wrong — investigate before continuing.

- [ ] **Step 7: Commit**

```bash
git add scripts/lib.sh scripts/resolve-gate.sh tests/test_resolve_gate.sh
git commit -m "feat(gate): model and effort refusal gate with settings precedence"
```

**Note for the reviewer:** `unknown` must be distinct from `refuse`. A skill that cannot read
the effort must say so rather than assert a refusal it did not verify — that distinction is the
whole reason exit code 2 exists in the global constraints.
