# Task 10: Mechanical §12.2 — the manifest renders a valid single-mode layout

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Create: `tests/test_single_mode_layout.sh`

**Interfaces:**
- Consumes: `MANIFEST.tsv` and every template from task 5; `scripts/roots.sh` from task 1.
- Produces: nothing other tasks call. A standing test that the manifest, rendered as
  `foreman-init` Step 3 renders it, produces a repository satisfying spec §12.2's four
  observations.

**Why this exists.** Spec §12.2 is a mechanical verification item: after a single-mode init,
`docs/dev/program/` is untracked, `.foreman` is ignored, `.foreman` is a repository, and from
inside it the toplevel is the nested repository. Nothing consumes the manifest mechanically
(`[JUDGE-2]`), so `foreman-init`'s prose is what produces the layout in reality — task 12 runs
that for real. This test pins the *inputs*: if a manifest destination drifts back to
`docs/dev/program/`, or the ignore line is lost, or `foreman.json.tmpl` stops rendering as JSON,
this goes red without anyone running an install.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_single_mode_layout.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

# Spec §12.2, mechanised against the manifest. This renders every init-time row the way
# foreman-init Step 3 does -- fixed values for every variable -- into a scratch repository, then
# makes the four observations §12.2 names, plus the ones that make them meaningful.
t="$FOREMAN_ROOT/skills/foreman-init/templates"
mf="$t/MANIFEST.tsv"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" commit -q --allow-empty -m "product repository"

render() {
  sed -e 's#{{PROJECT_NAME}}#demo#g' -e 's#{{PROGRAM_NAME}}#demo#g' -e 's#{{TODAY}}#2026-09-03#g' \
      -e "s#{{WORK_ROOT}}#$repo/.foreman#g" -e 's#{{REPO_NAME}}#demo#g' -e "s#{{REPO_PATH}}#$repo#g" \
      -e 's#{{DEFAULT_BRANCH}}#main#g' -e 's#{{GATE_PERMISSIONS}}#"Bash(bash tests/run.sh)"#g' \
      -e 's#{{[A-Z_]*}}#rendered#g' "$1"
}

# Init-time rows only: a destination containing "{{" is instantiated later (kickoff, plan, spec).
# .gitignore is the one evolve row whose template is appended, not substituted.
while IFS=$'\001' read -r tpl dest; do
  case "$dest" in *'{{'*) continue ;; esac
  mkdir -p "$repo/$(dirname "$dest")"
  if [ "$dest" = ".gitignore" ]; then cat "$t/$tpl" >> "$repo/.gitignore"
  else render "$t/$tpl" > "$repo/$dest"; fi
done < <(awk -F'\t' 'NR>1 {printf "%s\001%s\n", $1, $2}' "$mf")

# The bootstrap foreman-init Step 5 performs: the work root is a repository of its own.
git -C "$repo/.foreman" init -q
git -C "$repo/.foreman" add -A
git -C "$repo/.foreman" commit -qm "work root"
git -C "$repo" add -A
git -C "$repo" commit -qm "harness"

# --- spec §12.2, the four observations -----------------------------------------------------------
assert_eq "" "$(git -C "$repo" ls-files docs/dev/program)" \
  "12.2(1) no path under docs/dev/program/ is tracked"
assert_exit 0 "12.2(2) .foreman is ignored by the product repository" -- \
  git -C "$repo" check-ignore -q .foreman
assert_eq "true" "$(git -C "$repo/.foreman" rev-parse --is-inside-work-tree 2>/dev/null)" \
  "12.2(3) the work root is a git repository"
assert_eq "$(cd "$repo/.foreman" && pwd -P)" "$(cd "$repo/.foreman" && git rev-parse --show-toplevel)" \
  "12.2(4) from inside .foreman/ the toplevel is the nested repository, not the product one"

# --- what makes those four meaningful --------------------------------------------------------------
assert_eq "" "$(git -C "$repo" status --short)" \
  "the product repository is clean: the work root is neither tracked nor shown as untracked"
assert_eq "" "$(git -C "$repo" ls-files .foreman)" "nothing under .foreman/ is in the product index"
assert_eq "" "$(git -C "$repo/.foreman" status --short)" "the work root's own tree is clean after its commit"

# Durable files where §4.1 puts them; transient files in the work root.
for f in docs/dev/POLICY.md docs/dev/RULINGS.md docs/dev/HISTORY.md docs/dev/README.md \
         docs/dev/CONTEXT.md docs/dev/backlog.md CLAUDE.md AGENTS.md .claude/settings.json .gitignore; do
  if [ -f "$repo/$f" ]; then _ok; else fail "rendered layout lacks $f"; fi
done
for f in STATE.md DEFERRED.md foreman.json .gitignore; do
  if [ -f "$repo/.foreman/$f" ]; then _ok; else fail "rendered work root lacks $f"; fi
done
if [ -e "$repo/docs/dev/program" ]; then fail "docs/dev/program/ exists in the rendered layout"; else _ok; fi

# foreman.json renders as JSON and foreman_roots resolves the result.
assert_exit 0 "the rendered foreman.json is one JSON object" -- \
  jq -e 'type == "object"' "$repo/.foreman/foreman.json"
assert_eq "single" "$(jq -r '.mode' "$repo/.foreman/foreman.json")" "the rendered mode is single"
assert_eq "$(printf '%s\t%s\t%s' "$repo/docs/dev" "$repo/.foreman" "$repo/.foreman/foreman.json")" \
  "$("$FOREMAN_ROOT/scripts/roots.sh" "$repo" 2>/dev/null)" \
  "foreman_roots resolves the rendered layout to the roots the manifest implies"

# Nothing unsubstituted survives, in content or in a path.
assert_eq "" "$(grep -rl '{{' "$repo" --exclude-dir=.git 2>/dev/null || true)" \
  "no unsubstituted variable survives in any rendered file"
assert_eq "" "$(find "$repo" -name '*{{*' -not -path '*/.git/*' 2>/dev/null)" \
  "no unsubstituted variable survives in any rendered path"

# The settings file rendered as JSON too (GATE_PERMISSIONS sits inside an array).
assert_exit 0 "the rendered settings.json is valid JSON" -- jq -e . "$repo/.claude/settings.json"
```

- [ ] **Step 2: Run the test to verify it fails for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: if task 5 has landed, this file is **green on first run** — that is the case for a
verification test of an input that already changed. Prove it is not vacuous instead: temporarily
change `program/STATE.md.tmpl`'s destination in `MANIFEST.tsv` back to
`docs/dev/program/STATE.md`, run, and confirm `12.2(1)` and `rendered work root lacks STATE.md`
go red. Restore. If task 5 has *not* landed, most of the file is red and that is the expected
failure — stop and let task 5 land first.

- [ ] **Step 3: Implement**

Nothing to implement beyond the test file; the layout is task 5's. If the test found a defect
in task 5's output — a destination, a variable, a `.gitignore` line — fix it in the template or
manifest and say so in your report, naming the assertion that caught it.

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, `+26` on the count before this task.

- [ ] **Step 5: Mutation-check**

The Step 2 mutation is one. Also: temporarily remove `/.foreman/` from
`gitignore-additions.txt`: `12.2(2)` and `the product repository is clean` go red. Restore.
Temporarily break `foreman.json.tmpl`'s JSON (drop a comma): three assertions go red. Restore.
Green.

- [ ] **Step 6: Commit**

```bash
git add tests/test_single_mode_layout.sh
git commit -m "tests: the manifest renders a single-mode layout that satisfies spec 12.2"
```
