# Task 4: `baseline-check.sh` and `phase-state.sh`

Two small scripts that carry spec §9.1 (the baseline gate that runs *before* a reviewer is
spawned) and spec §7.3 (the PM reads a running phase's ledger off its branch, without leaving
its own directory or dirtying the main checkout).

**Files:**
- Create: `scripts/baseline-check.sh`
- Create: `scripts/phase-state.sh`
- Test: `tests/test_baseline_check.sh`
- Test: `tests/test_phase_state.sh`

**Interfaces:**
- Consumes: `scripts/lib.sh` from Task 2.
- Produces, for Tasks 6 and 7:
  - `scripts/baseline-check.sh --policy <abs-POLICY.md> --count <N>` — JSON with
    `verdict` (`pass` | `below` | `unknown`), `baseline`, `count`, `delta`.
    Exit `0` at or above baseline, `1` below, `2` no parseable baseline.
  - `scripts/phase-state.sh --phase <slug> [--branch <b>] [--repo <abs>] [--head]` —
    prints the phase's `state.md` from its branch, or only its YAML frontmatter with `--head`.
    Exit `0` found, `2` branch unresolvable or file absent on that branch.
- `POLICY.md` must carry a machine-readable line under `## Baseline`:
  `baseline-count: <N>`. Task 8's `POLICY.md.tmpl` emits it; this script is its only reader.


> **Historical reference code.** The code blocks below are the plan as written *before*
> execution. Several were superseded by fix rounds during execution and are **not** what shipped.
> For one example — from a sibling plan, not this file — `task-2.md`'s model check shows a
> substring match (`*opus*|*fable*`) that the shipped `resolve-gate.sh` replaced with whole-token
> matching because the substring form accepts `notopus` and `fabled`. **The files in the
> repository are authoritative; this document records intent, not current behaviour.** Tracked
> as `[T-PLAN]` in `docs/dev/backlog.md`.

---

## Part A: `baseline-check.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_baseline_check.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$HARNESS_ROOT/tests/lib_assert.sh"

bc="$HARNESS_ROOT/scripts/baseline-check.sh"
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run.sh` — FAIL naming `baseline-check.sh`.

- [ ] **Step 3: Write `scripts/baseline-check.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

policy=""; count=""
while [ $# -gt 0 ]; do
  case "$1" in
    --policy) [ $# -ge 2 ] || harness_die "$1 requires a value" 2; policy="$2"; shift 2 ;;
    --count)  [ $# -ge 2 ] || harness_die "$1 requires a value" 2; count="$2"; shift 2 ;;
    *) harness_die "unknown argument: $1" 2 ;;
  esac
done

[ -n "$policy" ] || harness_die "--policy is required" 2
[ -n "$count" ]  || harness_die "--count is required" 2
case "$count" in ''|*[!0-9]*) harness_die "--count must be a number, got: $count" 2 ;; esac
harness_require_abs "$policy" "--policy"
[ -f "$policy" ] || harness_die "policy file not found: $policy" 2

emit() {  # emit <verdict> <baseline> <delta>
  jq -n --arg v "$1" --arg b "$2" --argjson c "$count" --arg d "$3" \
    '{verdict:$v,
      baseline:(if $b == "" then null else ($b|tonumber) end),
      count:$c,
      delta:(if $d == "" then null else ($d|tonumber) end)}'
}

baseline="$(grep -m1 -E '^[[:space:]]*baseline-count:[[:space:]]*[0-9]+' "$policy" \
            | grep -oE '[0-9]+' | head -1 || true)"

if [ -z "$baseline" ]; then
  emit unknown "" ""
  printf 'no "baseline-count: <N>" line in %s\n' "$policy" >&2
  exit 2
fi

delta=$((count - baseline))
if [ "$count" -ge "$baseline" ]; then
  emit pass "$baseline" "$delta"
  exit 0
fi
emit below "$baseline" "$delta"
printf 'test count %s is below baseline %s\n' "$count" "$baseline" >&2
exit 1
```

- [ ] **Step 4: Verify Part A passes**

```bash
chmod +x scripts/baseline-check.sh tests/test_baseline_check.sh
bash tests/run.sh
```
Expected: `0 failed`.

## Part B: `phase-state.sh`

- [ ] **Step 5: Write the failing test**

Create `tests/test_phase_state.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$HARNESS_ROOT/tests/lib_assert.sh"

ps="$HARNESS_ROOT/scripts/phase-state.sh"
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
```

- [ ] **Step 6: Run it to verify it fails**

Run: `bash tests/run.sh` — FAIL naming `phase-state.sh`.

- [ ] **Step 7: Write `scripts/phase-state.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

phase=""; branch=""; repo=""; head_only=false
while [ $# -gt 0 ]; do
  case "$1" in
    --phase)  [ $# -ge 2 ] || harness_die "$1 requires a value" 2; phase="$2"; shift 2 ;;
    --branch) [ $# -ge 2 ] || harness_die "$1 requires a value" 2; branch="$2"; shift 2 ;;
    --repo)   [ $# -ge 2 ] || harness_die "$1 requires a value" 2; repo="$2"; shift 2 ;;
    --head)   head_only=true;  shift ;;
    *) harness_die "unknown argument: $1" 2 ;;
  esac
done

[ -n "$phase" ] || harness_die "--phase is required" 2
if [ -n "$repo" ]; then
  harness_require_abs "$repo" "--repo"
else
  repo="$(harness_repo_root "$PWD" || true)"
  [ -n "$repo" ] || harness_die "not inside a git repository and --repo not given" 2
fi

state_index="$repo/docs/dev/program/STATE.md"

if [ -z "$branch" ]; then
  [ -f "$state_index" ] || harness_die "no STATE.md at $state_index; pass --branch" 2
  branch="$(awk -F'|' -v p="$phase" '
    /^[[:space:]]*\|/ {
      name=$2; br=$4
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", br)
      if (name == p) { print br; exit }
    }' "$state_index")"
  [ -n "$branch" ] || harness_die "phase '$phase' has no row in $state_index" 2
fi

path="docs/dev/program/phases/$phase/state.md"
content="$(git -C "$repo" show "$branch:$path" 2>/dev/null)" \
  || harness_die "no $path on branch '$branch'" 2

if $head_only; then
  printf '%s\n' "$content" | awk '
    NR==1 && $0=="---" { infm=1; print; next }
    infm && $0=="---"  { print; exit }
    infm               { print }
  '
else
  printf '%s\n' "$content"
fi
```

- [ ] **Step 8: Run the tests to verify they pass**

```bash
chmod +x scripts/phase-state.sh tests/test_phase_state.sh
bash tests/run.sh
```
Expected: `0 failed`, count above Task 3's baseline.

- [ ] **Step 9: Commit**

```bash
git add scripts/baseline-check.sh scripts/phase-state.sh \
        tests/test_baseline_check.sh tests/test_phase_state.sh
git commit -m "feat: baseline gate and cross-branch phase-state reader"
```

**Note for the reviewer:** the `status --porcelain` and `branch --show-current` assertions in
Part B are the point of the task, not decoration. A phase-state read that dirtied the main
checkout or switched its branch would break every other person working in the repository —
spec §7.3's whole reason for using `git show`.
