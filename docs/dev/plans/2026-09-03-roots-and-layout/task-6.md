# Task 6: `foreman-init` bootstraps the work root; `[BR-6]`

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Modify: `skills/foreman-init/SKILL.md` — Step 3 (two paragraphs) and Step 5 (approval branch)
- Modify: `tests/test_init_skill.sh` — one needle changes, new assertions appended
- Modify: `docs/dev/backlog.md` — close `[BR-6]`

**Interfaces:**
- Consumes: the manifest rows and `foreman.json.tmpl` variables from task 5.
- Produces: the install procedure task 12 follows by hand against a scratch repository.

**Why this exists.** Spec §4.2: in single mode `foreman-init` initialises the work root as a
nested repository, adds it to the product repository's `.gitignore`, and commits to it. The
manifest now says *where* the work-root files go; this skill must say *how* they get there,
since a `.foreman/` destination is not reached by the product repository's `git add -A` — the
directory is ignored, which is the point. The one ruling this task applies rather than asks:
spec §4.2 has `foreman-init` ask one mode question, but until phase D only `single` can be
honoured, and a question with one valid answer is not a question. `mode: single` is written
without asking; D adds the question.

---

- [ ] **Step 1: Write the failing tests**

In `tests/test_init_skill.sh`, change

```bash
assert_contains "$sf" "no template needs a machine-specific path" \
  "Step 3 states why the marketplace source needs no lookup"
```

to

```bash
assert_contains "$sf" "no template that lands in the product repository needs a machine-specific path" \
  "Step 3 states why the marketplace source needs no lookup, scoped to the product repository"
assert_contains "$sf" "carries them by design" \
  "Step 3 says foreman.json carries machine-specific paths on purpose, hence the ignored work root"
```

and append:

```bash

# --- phase B: single-mode bootstrap of the work root (spec §4.2) --------------------------------
assert_contains "$sf" 'Rows whose destination starts with `.foreman/` are the work root' \
  "Step 3 recognises the work-root rows as a class"
assert_contains "$sf" "written without asking" \
  "Step 3 writes mode single without an interview question (multi mode is phase D)"
assert_contains "$sf" "check-ignore -q .foreman" \
  "Step 5 proves the work root is ignored before committing anything"
assert_contains "$sf" "git -C <abs repo root>/.foreman init" \
  "Step 5 initialises the work root as a repository of its own"
assert_contains "$sf" "git clean -fdx" \
  "Step 5 prints the warning the ruling requires: -x deletes the work root and its history"
assert_contains "$sf" "leave the work root untouched" \
  "an existing foreman.json makes the bootstrap an evolve, not a re-init"
# [BR-6] The key-level merge semantics for settings.json rest on prose alone (nothing consumes the
# manifest), so the prose must actually state them.
assert_contains "$sf" "key-level merge" \
  "the evolve bullet states key-level merge semantics for settings.json [BR-6]"
assert_contains "$sf" "merged entry by entry" \
  "the evolve bullet says the plugin and marketplace maps merge by entry, not by replacement [BR-6]"
```

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: the changed needle and all eight appended assertions red; nothing else.

- [ ] **Step 3: Implement**

In `skills/foreman-init/SKILL.md`, Step 3:

Replace the `mode: evolve` bullet with:

```
- `mode: evolve` — merge with what exists. For `CLAUDE.md` this means keeping the project's
  own content and voice and folding in the missing sections, not replacing the file. For
  `.gitignore` it means adding each entry that is absent, by entry, not by line. For
  `.claude/settings.json` it is a **key-level merge**: every key the existing file has keeps
  its value; keys the template has and the file lacks are added; `enabledPlugins`,
  `extraKnownMarketplaces` and `permissions.allow` are merged entry by entry, never replaced.
  A contributor's `effortLevel`, permissions and other plugins survive an install. If the result
  leaves `effortLevel` below `high`, say so in the Step 5 summary — the gate will refuse in that
  repository until it is raised, and that is the contract working.
```

After the paragraph that begins `**Not every row is an init-time row.**` and before
`For each remaining row:`, add:

```
**Rows whose destination starts with `.foreman/` are the work root** (spec §4.2). They are
init-time rows and are rendered into the scratch tree like any other, but they never reach the
product repository's index: `.foreman/` is added to its `.gitignore` by the
`gitignore-additions.txt` row, and Step 5 commits the work root to a nested repository of its
own. In this release every install is single mode: `foreman.json.tmpl` carries
`"mode": "single"` and the mode is **written without asking** — multi mode, and the question
that chooses it, arrive with the program layer. Its variables: `PROGRAM_NAME` is the repository
name unless the interview named a program; `WORK_ROOT` is `<abs repo root>/.foreman`;
`REPO_NAME` is the repository name; `REPO_PATH` is `<abs repo root>`; `DEFAULT_BRANCH` is the
audit's answer; `TODAY` is today's date.
```

Replace the sentence `Substitute every \`{{VARIABLE}}\` from the audit and the interview. The
\`foreman\` marketplace is a GitHub source declared in \`settings.json.tmpl\`, so no template needs
a machine-specific path and nothing is looked up outside the repository being initialised.` with:

```
Substitute every `{{VARIABLE}}` from the audit and the interview. The `foreman` marketplace is
a GitHub source declared in `settings.json.tmpl`, so no template that lands in the product
repository needs a machine-specific path. `foreman.json` carries them by design (spec §4.3) —
`REPO_PATH` and `WORK_ROOT` are this machine's — which is exactly why its destination is the
ignored work root and never the repository.
```

Step 5, replace the paragraph beginning `On approval: copy the scratch tree over the
repository` with:

````
On approval: copy the scratch tree over the repository. Then prove the work root is ignored
before touching either index — `git -C <abs repo root> check-ignore -q .foreman` must exit 0;
if it does not, the `.gitignore` merge lost the `/.foreman/` line, and the `git add -A` below
would stage the whole work root into the product repository. Fix that first.

Then the two commits, work root first:

```bash
git -C <abs repo root>/.foreman init -q
git -C <abs repo root>/.foreman add -A
git -C <abs repo root>/.foreman commit -qm "Initialise the harness work root"
```

If `<abs repo root>/.foreman/foreman.json` already existed before this run, **leave the work
root untouched** — do not re-init, do not overwrite — and say so in the summary; that is the
evolve case for the work root. Print, in either case:
`.foreman/ is a nested repository ignored by this one. git clean -fdx deletes it, history
included.`

Then the product repository: `git add -A` (which honours `.gitignore`) or name the paths; never
`git add -f`. Commit with a message naming the harness version — the `version` field of
`$(foreman-root)/.claude-plugin/plugin.json`, which is on the plugin side, not in the
repository being initialised.
````

Replace the final paragraph `Confirm before claiming success: …` with:

```
Confirm before claiming success: `git status --short` shows every generated file staged, no
path under `.foreman/` in the index, and nothing ignored by `.gitignore` in the index;
`git -C <abs repo root>/.foreman log --oneline` shows the one commit. Then print the first
launch block: `/foreman:program`.
```

The block above is fenced with four backticks only so that its inner ```` ```bash ```` fence
survives this document; in the skill file it is an ordinary three-backtick fence, exactly like
the gate block at the top of the skill.

- [ ] **Step 4: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `0 failed`, exit 0, `+9` on the count before this task. Check the 100-column wrap
of every paragraph you wrote: `awk 'length > 100' skills/foreman-init/SKILL.md` prints nothing.

- [ ] **Step 5: Mutation-check**

Temporarily delete the `check-ignore` sentence: its assertion goes red. Restore. Temporarily
change `key-level merge` to `merge`: the `[BR-6]` assertion goes red. Restore. Green.

- [ ] **Step 6: Close the backlog item and commit**

In `docs/dev/backlog.md`, change `- [ ] [BR-6]` to `- [x] [BR-6]` and append `**Closed
2026-09-03, phase B task 6:** the evolve bullet states key-level merge, entry-by-entry for the
three maps, and what happens to a below-high effortLevel.`

```bash
git add skills/foreman-init/SKILL.md tests/test_init_skill.sh docs/dev/backlog.md
git commit -m "init: single-mode bootstrap of the .foreman work root; evolve semantics restated [BR-6]"
```
