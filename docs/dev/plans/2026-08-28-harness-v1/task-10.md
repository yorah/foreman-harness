# Task 10: Dogfood the harness on itself, and verify spec §15

The plugin installs itself into its own repository. This is both the last integration test and
spec §15's verification: a harness that cannot be installed by its own creator does not work,
and no unit test would have told us.

**Files:**
- Create: `README.md`
- Create (by generation): `CLAUDE.md`, `AGENTS.md`, `docs/dev/README.md`,
  `docs/dev/CONTEXT.md`, `docs/dev/backlog.md`, `docs/dev/program/{POLICY,STATE,RULINGS,DEFERRED,HISTORY}.md`,
  `.claude/settings.json`
- Modify: `.gitignore`
- Test: `tests/test_dogfood.sh`

**Interfaces:**
- Consumes: everything. This task is the first time the whole chain runs together.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_dogfood.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$HARNESS_ROOT/tests/lib_assert.sh"

R="$HARNESS_ROOT"

# --- the generated layout exists ------------------------------------------
for f in CLAUDE.md AGENTS.md README.md \
         docs/dev/README.md docs/dev/CONTEXT.md docs/dev/backlog.md \
         docs/dev/program/POLICY.md docs/dev/program/STATE.md \
         docs/dev/program/RULINGS.md docs/dev/program/DEFERRED.md \
         docs/dev/program/HISTORY.md .claude/settings.json; do
  [ -f "$R/$f" ] || fail "dogfood did not produce $f"
done

# --- nothing unsubstituted ------------------------------------------------
# Scoped to files /harness-init GENERATED, never to all of docs/dev/. Four authored documents
# under docs/dev/ carry `{{` legitimately and always will: `backlog.md` and three plan files
# document template variables, and you cannot document a variable without writing it. A sweep
# over the directory fails on correct content and would be "fixed" by mangling the prose.
# `backlog.md` is a `mode: create` destination that already exists, so this run does not emit
# it — it is authored here, not generated, and is excluded for that reason.
gen_files=""
for f in CLAUDE.md AGENTS.md docs/dev/README.md docs/dev/CONTEXT.md \
         docs/dev/program/POLICY.md docs/dev/program/STATE.md \
         docs/dev/program/RULINGS.md docs/dev/program/DEFERRED.md \
         docs/dev/program/HISTORY.md .claude/settings.json .claude/settings.local.json; do
  [ -f "$R/$f" ] && gen_files="$gen_files $R/$f"
done
# shellcheck disable=SC2086
leftover="$(grep -ln '{{' $gen_files 2>/dev/null || true)"
assert_eq "" "$leftover" "no unsubstituted {{VARIABLES}} in generated files"

# The check above is only meaningful if it can fail. An unsubstituted variable also survives in
# a PATH, which a content grep never sees ([T9-P4], the same defect one tier up).
leftover_path="$(find "$R/docs/dev/program" "$R/.claude" -name '*{{*' 2>/dev/null || true)"
assert_eq "" "$leftover_path" "no unsubstituted {{VARIABLES}} in generated path segments"

# --- POLICY is machine-readable and agrees with reality -------------------
policy="$R/docs/dev/program/POLICY.md"
baseline="$(grep -m1 -E '^[[:space:]]*baseline-count:' "$policy" | grep -oE '[0-9]+' | head -1)"
[ -n "$baseline" ] || fail "POLICY.md has no baseline-count"

# The recorded baseline must not exceed what the suite actually produces. Counting the
# current run from inside it would be circular, so compare against the assertion count
# reported by the previous full run, recorded in POLICY as the baseline.
"$R/scripts/baseline-check.sh" --policy "$policy" --count "$baseline" >/dev/null \
  && _ok || fail "baseline-check disagrees with the baseline POLICY records"

# --- settings declare the harness's own dependencies ----------------------
s="$R/.claude/settings.json"
for p in "harness@harness" "superpowers@claude-plugins-official" "fable@fable-method"; do
  assert_eq "true" "$(jq -r --arg k "$p" '.enabledPlugins[$k] // "false"' "$s")" \
    "settings enable $p"
done
assert_eq "fresh" "$(jq -r '.worktree.baseRef' "$s")" "worktree base ref is fresh"

# --- CLAUDE.md carries what the harness needs it to -----------------------
c="$(cat "$R/CLAUDE.md")"
assert_contains "$c" "worktree"          "CLAUDE.md states the worktree rule"
assert_contains "$c" "/program"          "CLAUDE.md names the program command"
assert_contains "$c" "docs/dev/README.md" "CLAUDE.md points at the doc layout"

# --- AGENTS.md is a pointer, not a copy -----------------------------------
a="$(cat "$R/AGENTS.md")"
assert_contains "$a" "CLAUDE.md" "AGENTS.md points at CLAUDE.md"
[ "$(wc -l < "$R/AGENTS.md")" -le 12 ] && _ok || fail "AGENTS.md should be a pointer, not a copy"

# --- STATE.md parses as the phase index -----------------------------------
assert_contains "$(cat "$R/docs/dev/program/STATE.md")" "| Phase | Owner | Branch |" \
  "STATE.md carries the parseable phase table header"
assert_exit 2 "an unknown phase is a clean exit-2, not a crash" -- \
  "$R/scripts/phase-state.sh" --repo "$R" --phase no-such-phase

# --- gitignore keeps the ledger tracked -----------------------------------
gi="$(cat "$R/.gitignore")"
assert_contains     "$gi" "*.diff"    "regenerable diffs are ignored"
assert_not_contains "$gi" "docs/dev"  "the design record is never gitignored"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run.sh`
Expected: FAIL — `dogfood did not produce CLAUDE.md`, and the rest. Every earlier suite must
still be green; confirm that before continuing.

- [ ] **Step 3: Write `README.md`**

**Do not hardcode an absolute path in the install snippet below.** `README.md` is the one file in
this repository written for someone who is not its author, and a path under someone else's home
directory is wrong for every reader of it. The same reasoning already governs
`settings.json.tmpl`, where the machine-specific marketplace path was moved out to the untracked
local settings (`[T8-M16]`).

The template is fenced with **four** backticks because it contains three-backtick blocks of its
own; copy the inside, not the outer fence.

````markdown
# harness

A Claude Code plugin that installs a three-tier development harness into a repository:

- a **program manager** session that coordinates and does not write code,
- **phase sessions** that each enter their own worktree and execute one plan,
- **task subagents** that write the code, one brief at a time.

Distilled from three projects that were run this way and rediscovered each other's lessons at
their own cost. The design record is in `docs/dev/specs/`.

## Install

```
/plugin marketplace add <path-to-your-checkout-of-this-repository>
/plugin install harness@harness
```

## Use

```
/harness-init      audit this repository and install the harness into it
/program           become the program manager
/phase <kickoff>   execute one phase
/program-status    one line per phase, read from each phase's own branch
```

## Develop

`bash tests/run.sh` is the only gate command. It needs `bash`, `git` and `jq`, and nothing else.
````

- [ ] **Step 4: Install the plugin and run the creator on this repository**

**Who runs this, decided at preflight.** Steps 1-3 and 5-8 are the controller's. **Step 4 is the
user's**, and it cannot be delegated: `/plugin marketplace add` and `/plugin install` are slash
commands no subagent can issue, and `/harness-init`'s interview reaches a real person through
`AskUserQuestion`. The plan's task table assigns this task a sonnet implementer, which presumes
something no subagent can do — **that row is wrong for this task and this is the declared
deviation**. Running it any other way would skip plugin resolution and `$CLAUDE_PLUGIN_ROOT` in a
real install, which is exactly the defect class this branch has found in every skill it shipped
and which is structurally invisible from inside this repository.


```bash
bash tests/run.sh            # record the passing count — it is the baseline
```

Then, in Claude Code:

```
/plugin marketplace add /home/yorah/projects/harness
/plugin install harness@harness
/harness-init
```

**Which manifest rows this exercises.** Verified against the repository at preflight, because
the plan's premise matters to what the dogfood proves: this repository has **no** `CLAUDE.md`,
`AGENTS.md`, `README.md`, and no `.claude/` directory at all. So almost every row runs as
`mode: create`. Exactly two behave differently, and they are the interesting ones:

- `.gitignore` — exists, so this is the one true `mode: evolve`: the additions must be folded in
  while `/.superpowers/`, which the additions file does not carry, survives untouched.
- `docs/dev/backlog.md` — exists, and is a `mode: create` row, so it must be **left alone** and
  reported as skipped in the Step 5 summary.

If the dogfood emits a `create` row over either of those, that is a defect in the skill, not in
this repository.

Work through it as the user would. Expected answers for this repository, so the audit and
interview agree:

- **Gate commands:** `bash tests/run.sh`, expected exit 0.
- **Baseline:** the count from the run above, at the current HEAD.
- **Trust boundaries:** `scripts/resolve-gate.sh` (it is the refusal gate — a defect there
  silently disables every other check).
- **Invariants:** the global constraints from this plan's `README.md`, numbered.
- **`AGENTS.md`:** three-line pointer.
- **Doc home:** `docs/dev/` — already in use.
- **Ownership:** single operator for now.

Accept the diff. Commit.

- [ ] **Step 5: Run the tests to verify they pass**

```bash
bash tests/run.sh
```
Expected: `0 failed`. If `test_dogfood.sh` fails on a generated file, **fix the template or the
skill, then regenerate** — do not hand-edit the generated file to make the test pass. That
would make the next installation produce the broken version.

- [ ] **Step 6: Verify spec §15's mechanical checks**

Record each result in `docs/dev/CONTEXT.md`.

**§15.2 — the gate refuses.**

```bash
G="$(mktemp -d)"; mkdir -p "$G/.claude" && git -C "$G" init -q
printf '%s\n' '{"effortLevel":"medium"}' > "$G/.claude/settings.json"
bash scripts/resolve-gate.sh --model claude-opus-5 --repo "$G"; echo "exit=$?"
rm -rf "$G"
```

No `cd`, so no `$OLDPWD` to restore and no way to leave the session in the scratch repository if
a step fails partway.
Expected: `"verdict": "refuse"`, reason names the effort, `exit=1`.

**§15.3 — the baseline check rejects.**

```bash
scripts/baseline-check.sh --policy "$PWD/docs/dev/program/POLICY.md" --count 0; echo "exit=$?"
```
Expected: `"verdict": "below"`, negative delta, `exit=1`.

**§15.4 — the reviewer return is small.** Measured live during the next real phase, not here:
compare the byte size of the reviewer's returned message against the review file it wrote.
Record the ratio in `CONTEXT.md` when it happens. Note it in `docs/dev/backlog.md` as owed.

**§15.6 — `fable-judge` catches a planted weakened test.**

```bash
git checkout -b tmp/judge-canary
# Weaken a real assertion: make it compare a value to itself.
sed -i 's/assert_eq "pass"  "$(run 819 | jq -r .verdict)" "equal to baseline passes"/assert_eq "x" "x" "equal to baseline passes"/' tests/test_baseline_check.sh
bash tests/run.sh    # still green — that is the point
git commit -aqm "test: weaken a baseline assertion (canary)"
```

Invoke `fable:fable-judge` on `tmp/judge-canary`. Expected: it identifies the weakened
assertion and returns `REFUTED` or `VERIFIED WITH CAVEATS` naming it. Then:

```bash
git checkout feat/harness-v1 && git branch -D tmp/judge-canary
```

**Not `main`.** This branch is `feat/harness-v1` and `main` may not exist as a local branch at
all; `git checkout main` would fail, or in the worse case succeed and leave the canary commit
as the only place the work exists. Return to the branch you were on, and confirm
`git status --short` is clean and `bash tests/run.sh` is back at the baseline before continuing.

If the judge misses it, that is a finding: record it in `CONTEXT.md` and add a note to
`backlog.md` that §9.5's sabotage protocol should be reconsidered. Do not silently pass.

- [ ] **Step 7: Write the standing context**

Into the generated `docs/dev/CONTEXT.md`, dated: the §15 results from Step 6, the measured
baseline, and anything this plan's execution learned that the code does not show. Then flush
any deferred Minor from the ledger to `docs/dev/backlog.md`.

Both are blocking gates in `references/gate-chain.md`. This task is where they are exercised
for the first time.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: dogfood the harness on its own repository

Generated CLAUDE.md, the docs/dev layout and the program state via
/harness-init, and verified spec §15's mechanical checks."
```

**Note for the branch reviewer:** this task is deliberately the only one that changes files it
did not write by hand. Check that every generated file traces to a template and a manifest row,
and that nothing was hand-edited to make a test pass — a hand-edit here ships a broken template
to every future installation.
