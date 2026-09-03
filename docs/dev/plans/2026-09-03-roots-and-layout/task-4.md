# Task 4: `[DIST-2]` every slash command in shipped prose is namespaced `/foreman:…`

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Modify: every file under `skills/` and `commands/` (templates included), `README.md`,
  `CLAUDE.md` — mechanical sweep, then a hand review of the diff
- Create: `tests/test_namespaced_commands.sh`
- Modify: `tests/test_dogfood.sh` — one needle; any other test that asserted a bare form
- Modify: `docs/dev/backlog.md` — close `[DIST-2]`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the four commands are written `/foreman:phase`, `/foreman:program`,
  `/foreman:program-status`, `/foreman:foreman-init` everywhere a user or a session is told what
  to type. Tasks 5, 8 and 9 write new prose; they use these forms.

**Why this exists.** The installed plugin exposes its commands namespaced; `/phase <kickoff>`
in a session returned `Unknown command: /phase`. Every shipped mention is bare, so every launch
block the harness prints is wrong on install and right only in this repository. Same class as
`$CLAUDE_PLUGIN_ROOT`: invisible from inside, fatal outside.

---

- [ ] **Step 1: Write the failing test**

Create `tests/test_namespaced_commands.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

# [DIST-2] The installed plugin exposes its commands as /foreman:<name>. A bare /phase in shipped
# prose is a launch instruction that fails on every install and works only in this repository.
#
# The detector: a slash command is "/" + name, not preceded by a path or namespace character and
# not followed by a path or word character. `docs/dev/program/STATE.md` is not a hit (preceded by
# a letter); `/foreman:program` is not a hit (preceded by ":"); `/program-status` is not a hit for
# the `/program` alternative (followed by "-").
bare='(^|[^A-Za-z0-9_:./-])/(phase|program|program-status|foreman-init)([^A-Za-z0-9_/-]|$)'

# The detector is itself tested against planted shapes, so a rewrite that stops matching is
# visible rather than making every assertion below vacuously green.
planted="$(printf 'run /phase now\nsee docs/dev/program/STATE.md\nuse /foreman:program\n/program-status\n')"
assert_eq "2" "$(printf '%s\n' "$planted" | grep -cE "$bare")" \
  "the detector catches the two bare forms and ignores a path and a namespaced form"

for group in skills commands "README.md CLAUDE.md"; do
  # shellcheck disable=SC2086
  hits="$(cd "$FOREMAN_ROOT" && grep -rnE "$bare" $group 2>/dev/null || true)"
  assert_eq "" "$hits" "no bare slash command survives in $group"
done

# The other direction: the namespaced forms are present where a person is told what to type.
for f in README.md CLAUDE.md skills/foreman-init/templates/CLAUDE.md.tmpl \
         skills/foreman-program/SKILL.md skills/foreman-init/SKILL.md; do
  assert_contains "$(cat "$FOREMAN_ROOT/$f" 2>/dev/null || true)" "/foreman:" \
    "$f names at least one namespaced command"
done
```

- [ ] **Step 2: Run the test to verify it fails for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: the three `no bare slash command survives in …` assertions red, the detector
self-test and the `/foreman:` presence checks partly red (only `README.md` and `CLAUDE.md`
currently lack any namespaced form; `foreman-program/SKILL.md` may already say `/foreman:` in
its `[DEP-1]` prose — read the output rather than assuming).

- [ ] **Step 3: Implement — the sweep, then read the diff**

From the worktree root:

```bash
files="$(grep -rlE '(^|[^A-Za-z0-9_:./-])/(phase|program|program-status|foreman-init)([^A-Za-z0-9_/-]|$)' \
  skills commands README.md CLAUDE.md)"
for f in $files; do
  sed -E -i \
    -e 's#(^|[^A-Za-z0-9_:./-])/program-status([^A-Za-z0-9_/-]|$)#\1/foreman:program-status\2#g' \
    -e 's#(^|[^A-Za-z0-9_:./-])/foreman-init([^A-Za-z0-9_/-]|$)#\1/foreman:foreman-init\2#g' \
    -e 's#(^|[^A-Za-z0-9_:./-])/program([^A-Za-z0-9_/-]|$)#\1/foreman:program\2#g' \
    -e 's#(^|[^A-Za-z0-9_:./-])/phase([^A-Za-z0-9_/-]|$)#\1/foreman:phase\2#g' \
    "$f"
done
/usr/bin/git diff --stat
```

Order matters: `/program-status` before `/program`, and the leading class excludes `:` so a
form namespaced by an earlier expression is not namespaced twice. Expected touched files, from
the backlog's count: `CLAUDE.md`, `README.md`, `skills/foreman-init/templates/CLAUDE.md.tmpl`,
`skills/foreman-program/SKILL.md`, `skills/foreman-init/SKILL.md`,
`skills/foreman-phase/SKILL.md`, `skills/foreman-phase/references/gate-chain.md`,
`skills/foreman-init/templates/program/kickoff.md.tmpl`, `…/program/STATE.md.tmpl`,
`…/program/POLICY.md.tmpl`, and the `description:` lines of the three skills. If a file outside
that list changed, read its hunk before going on.

Now read the whole diff with `/usr/bin/git diff` (not `git diff`; see the README's note on
the abridging hook) and check every hunk by eye for these two cases the regex cannot judge:

- A `description:` frontmatter line is prose and takes the namespaced form; that is correct.
- `README.md`'s command table (lines beginning `/foreman-init      audit…`) is a list of what to
  type, so `/foreman:foreman-init` is right there too; re-align the column if the longer names
  break it.

Then run the suite and fix every needle that asserted the bare form. Known: in
`tests/test_dogfood.sh`, `assert_contains "$c" "/program"` becomes
`assert_contains "$c" "/foreman:program"`. Any other red needle is the same kind of fix — a
test that pinned the bare form — and gets the same treatment; do not weaken a test to pass.

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, `+9` on the count before this task.

- [ ] **Step 5: Mutation-check**

Temporarily add a line `Then run /phase again.` to the end of `commands/phase.md`: `no bare
slash command survives in commands` goes red. Restore. Temporarily replace `/foreman:program` with
`/program` in `CLAUDE.md`: the `README.md CLAUDE.md` group goes red and the dogfood needle too.
Restore. Run the suite once more, green.

- [ ] **Step 6: Close the backlog item and commit**

In `docs/dev/backlog.md`, change `- [ ] **[DIST-2]` to `- [x] **[DIST-2]` and append:
`**Closed 2026-09-03, phase B task 4:** every mention namespaced by a bounded sweep;
tests/test_namespaced_commands.sh asserts no bare form survives in skills/, commands/, README.md
or CLAUDE.md, and that the detector itself still discriminates.`

```bash
git add -A skills commands README.md CLAUDE.md tests/test_namespaced_commands.sh tests docs/dev/backlog.md
git commit -m "skills+templates: every slash command namespaced /foreman:*; no bare form survives [DIST-2]"
```
