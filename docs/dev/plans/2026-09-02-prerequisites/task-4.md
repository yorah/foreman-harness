# Task 4: `[DIST-1]` GitHub marketplace source, `settings.local.json` retired

**Plan:** `docs/dev/plans/2026-09-02-prerequisites/README.md` — shared constraints and the task
table.

**Files:**
- Modify: `skills/foreman-init/templates/settings.json.tmpl`
- Delete: `skills/foreman-init/templates/settings.local.json.tmpl`
- Modify: `skills/foreman-init/templates/MANIFEST.tsv` — remove one row
- Modify: `skills/foreman-init/templates/gitignore-additions.txt` — the comment above the
  `.claude/settings.local.json` line
- Modify: `skills/foreman-init/templates/CLAUDE.md.tmpl` — the `## Setup` section
- Modify: `skills/foreman-init/SKILL.md` — Step 3 and Step 5
- Modify: `CLAUDE.md` (this repository's `## Setup`), `.claude/settings.json` (this repository)
- Modify: `tests/test_templates.sh`, `tests/test_init_skill.sh`, `tests/test_dogfood.sh`
- Modify: `docs/dev/backlog.md` — close `[DIST-1]` and `[T8-I15]`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a generated repository's tracked `.claude/settings.json` declares
  `extraKnownMarketplaces.foreman.source = {"source":"github","repo":"yorah/foreman-harness"}`
  next to the existing `fable-method` entry, and enables `foreman@foreman` as before. No
  template writes `.claude/settings.local.json` any more, and no template variable carries a
  machine-specific path. `MANIFEST.tsv` has 16 rows after the header (17 today).

**Ruling this task implements.** The `.claude/settings.local.json` line stays in
`gitignore-additions.txt`: Claude Code writes per-contributor permission grants to that file on
its own, and it must never be tracked. Only the *reason* in the comment changes, because the
marketplace path it used to cite no longer exists. This task does **not** touch this
repository's own `.claude/settings.local.json` (the program manager's, after the merge) and
does not install, remove or re-register any plugin.

**MANIFEST.tsv is a declared trust boundary.** It decides what is written into someone else's
repository. The only change is the removal of one row; every other byte, including the tab
separators and the header, stays identical. Verify with `git diff` before committing that the
diff is one deleted line.

---

- [ ] **Step 1: Write the failing tests**

In `tests/test_templates.sh`:

1. In the destination table inside the `dest_mode_errs` loop (the heredoc labelled `TABLE`),
   delete the line `.claude/settings.local.json evolve`. That loop only checks table entries
   against the manifest, never the reverse, so a stale manifest row would survive it silently.
   Add, after the loop's `assert_eq "" "$dest_mode_errs" ...` line:

   ```bash
   # [DIST-1] The reverse direction the loop above lacks, for the one row this phase removed.
   assert_eq "0" "$(awk -F'\t' 'NR>1 && $2==".claude/settings.local.json"{n++} END{print n+0}' "$mf")" \
     "MANIFEST.tsv has no settings.local.json row: the marketplace source is tracked, not local"
   ```

2. Replace the whole block that begins with the comment `# settings.local.json.tmpl carries
   foreman@foreman's local-directory marketplace source.` and ends with the assertion labelled
   `settings.local.json.tmpl's harness marketplace path is the substituted
   {{FOREMAN_MARKETPLACE_PATH}}` with:

   ```bash
   # [DIST-1] The foreman marketplace is a GitHub source in the TRACKED settings.json, the same
   # shape fable-method already uses. A directory source carried a machine-specific absolute
   # path, which forced a second, untracked settings file and meant a cloned repository enabled
   # a plugin Claude Code could not locate. Now a clone needs only the trust prompt.
   assert_eq "github" \
     "$(printf '%s' "$rendered_full" | jq -r '.extraKnownMarketplaces.foreman.source.source' 2>/dev/null)" \
     "settings.json.tmpl declares the foreman marketplace as a github source"
   assert_eq "yorah/foreman-harness" \
     "$(printf '%s' "$rendered_full" | jq -r '.extraKnownMarketplaces.foreman.source.repo' 2>/dev/null)" \
     "settings.json.tmpl's foreman marketplace names the published harness repository"
   if [ ! -e "$t/settings.local.json.tmpl" ]; then _ok
   else fail "settings.local.json.tmpl still exists; the local marketplace source is retired"; fi
   assert_eq "" "$(grep -rl 'FOREMAN_MARKETPLACE_PATH' "$t" 2>/dev/null || true)" \
     "no template carries a machine-specific marketplace path"
   ```

3. Replace the block from the comment `# settings.local.json.tmpl is gitignored (see below)`
   through the assertion labelled `CLAUDE.md template names the actual missing step (claude
   plugin install) that claude plugin list does react to` with:

   ```bash
   # The generated CLAUDE.md is the one file every session reads whether or not the plugin
   # loaded, so it is where a contributor learns how the plugin arrives: the tracked settings
   # declare a GitHub marketplace, Claude Code asks to trust it on first start, and if that was
   # declined `claude plugin install foreman@foreman` is the manual step. It must not send
   # anyone to a local checkout path or to known_marketplaces.json any more.
   claude_md_tmpl="$(cat "$t/CLAUDE.md.tmpl" 2>/dev/null || true)"
   claude_md_tmplf="$(printf '%s' "$claude_md_tmpl" | tr '\n' ' ' | tr -s ' ')"
   assert_contains "$claude_md_tmplf" "claude plugin install foreman@foreman" \
     "CLAUDE.md template names the manual install command"
   assert_contains "$claude_md_tmplf" "trust" \
     "CLAUDE.md template explains the trust prompt a fresh clone sees"
   assert_contains "$claude_md_tmplf" "claude plugin list" \
     "CLAUDE.md template names claude plugin list as the tell that the plugin is installed"
   assert_not_contains "$claude_md_tmplf" "known_marketplaces.json" \
     "CLAUDE.md template no longer sends contributors to known_marketplaces.json"
   assert_not_contains "$claude_md_tmplf" "--scope local" \
     "CLAUDE.md template no longer registers a local-directory marketplace"
   assert_not_contains "$claude_md_tmplf" "settings.local.json" \
     "CLAUDE.md template no longer describes a machine-specific settings file"
   ```

4. The assertion labelled `gitignore-additions.txt excludes the machine-specific
   settings.local.json` stays, relabelled `gitignore-additions.txt keeps the per-contributor
   settings.local.json untracked`.

In `tests/test_init_skill.sh`:

5. Replace the `[T9-R5]` block (comment plus the assertion labelled `the marketplace lookup
   does not claim to always resolve`) with:

   ```bash
   # [DIST-1] The marketplace is a GitHub source declared in settings.json.tmpl, so generation
   # has no machine-specific path to look up and Step 3 must not send the session to
   # known_marketplaces.json or ask the user for a checkout path.
   assert_not_contains "$s" "known_marketplaces.json" \
     "Step 3 no longer looks up a marketplace checkout path"
   assert_not_contains "$s" "FOREMAN_MARKETPLACE_PATH" \
     "Step 3 no longer substitutes a marketplace path variable"
   assert_contains "$sf" "no template needs a machine-specific path" \
     "Step 3 states why the marketplace source needs no lookup"
   ```

6. Delete the assertion labelled `FOREMAN_MARKETPLACE_PATH is sourced, not invented` (the
   `assert_contains "$s" "known_marketplaces.json"` near the end).

In `tests/test_dogfood.sh`:

7. In the `for f in CLAUDE.md AGENTS.md docs/dev/README.md ...` list inside the
   "nothing unsubstituted" section, remove `.claude/settings.local.json`.

8. In the "settings declare the harness's own dependencies" section, after the `worktree base
   ref is fresh` assertion, add:

   ```bash
   assert_eq "github" "$(jq -r '.extraKnownMarketplaces.foreman.source.source' "$s" 2>/dev/null)" \
     "this repository's own settings declare the foreman marketplace as a github source"
   assert_eq "yorah/foreman-harness" "$(jq -r '.extraKnownMarketplaces.foreman.source.repo' "$s" 2>/dev/null)" \
     "this repository's own settings name the published harness repository"
   assert_not_contains "$(cat "$R/CLAUDE.md" 2>/dev/null || true)" "known_marketplaces.json" \
     "this repository's CLAUDE.md no longer sends contributors to known_marketplaces.json"
   ```

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

```bash
bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected `FAIL` lines, and only these: the `dest_mode_errs` assertion (or the explicit
no-row assertion), `settings.json.tmpl declares the foreman marketplace as a github source`,
`... names the published harness repository`, `settings.local.json.tmpl still exists`, `no
template carries a machine-specific marketplace path`, the three `assert_not_contains` on the
CLAUDE.md template, `CLAUDE.md template explains the trust prompt`, the two Step 3
`assert_not_contains`, `Step 3 states why the marketplace source needs no lookup`, and the
three dogfood assertions.

- [ ] **Step 3: Implement the templates and manifest**

`skills/foreman-init/templates/settings.json.tmpl` — add the `foreman` entry so the block reads:

```json
  "extraKnownMarketplaces": {
    "foreman": {
      "source": {
        "source": "github",
        "repo": "yorah/foreman-harness"
      }
    },
    "fable-method": {
      "source": {
        "source": "github",
        "repo": "Sahir619/fable-method"
      }
    }
  },
```

Delete the template and its manifest row:

```bash
git rm -q skills/foreman-init/templates/settings.local.json.tmpl
sed -i '/^settings\.local\.json\.tmpl\t/d' skills/foreman-init/templates/MANIFEST.tsv
git diff --stat skills/foreman-init/templates/MANIFEST.tsv   # expect: 1 deletion, 0 insertions
```

`skills/foreman-init/templates/gitignore-additions.txt` — replace the two comment lines above
`.claude/settings.local.json` with:

```
# Per-contributor: Claude Code writes local permission grants here. Never shared, never tracked.
```

and change the first comment block's `and the machine-specific settings file below` to
`and the per-contributor settings file below`.

`skills/foreman-init/templates/CLAUDE.md.tmpl` — replace the entire `## Setup` section (from the
heading to the line before `## Commands`) with:

```markdown
## Setup

Workflow commands (`/foreman-init`, `/program`, `/phase`, `/program-status`) come from the
`foreman` plugin. The tracked `.claude/settings.json` both enables it and declares where it
comes from: a GitHub marketplace, `yorah/foreman-harness`. A fresh clone therefore needs no
path and no second settings file. On first start in this repository Claude Code asks whether to
trust that marketplace; answer yes and the plugin installs. If the prompt was declined or
dismissed, install by hand with `claude plugin install foreman@foreman`.

`claude plugin list` is the tell: it shows `foreman@foreman` as enabled once the plugin is
installed, and does not list it before. The repository is `foreman-harness`; the marketplace
and the plugin inside it are both named `foreman`, which is why the command reads
`foreman@foreman`.
```

The template ships no comments, so nothing else goes in.

- [ ] **Step 4: Implement the skill prose**

`skills/foreman-init/SKILL.md`, Step 3:

- In the `mode: evolve` bullet, delete the sentences from `.claude/settings.local.json` is a
  fourth evolve destination` through `and never commit this file.`, so the bullet ends at
  `it means adding what is absent and touching nothing else.`
- Replace the paragraph beginning `Substitute every `{{VARIABLE}}` from the audit and the
  interview — with one exception.` and everything through `The value written into
  `settings.local.json` must be the source checkout.` (four paragraphs and one code block)
  with:

  ```markdown
  Substitute every `{{VARIABLE}}` from the audit and the interview. The `foreman` marketplace
  is a GitHub source declared in `settings.json.tmpl`, so no template needs a machine-specific
  path and nothing is looked up outside the repository being initialised.
  ```

`skills/foreman-init/SKILL.md`, Step 5: replace `then `git add` **the tracked files only**.
`.claude/settings.local.json` is deliberately ignored — write it, and leave it untracked. Stage
with `git add -A` (which honours `.gitignore`) or by naming paths; never `git add -f`.` with
`then `git add` **the tracked files only**: stage with `git add -A` (which honours `.gitignore`)
or by naming paths; never `git add -f`.` And replace `Confirm before claiming success: `git
status --short` shows the local settings file as ignored or absent from the index, and every
other generated file staged.` with `Confirm before claiming success: `git status --short` shows
every generated file staged and nothing ignored by `.gitignore` in the index.`

This repository's own `CLAUDE.md`: replace its `## Setup` section with the same text as the
template's, verbatim. This repository's `.claude/settings.json`: add the same `foreman` entry
to `extraKnownMarketplaces`, before `fable-method`, with `jq` or by hand; keep every other key.

`docs/dev/backlog.md`: change `[DIST-1]` and `[T8-I15]` from `- [ ]` to `- [x]`, and append to
each: `Closed by phase A task 4: the foreman marketplace is a GitHub source in the tracked
settings.json; settings.local.json.tmpl, its manifest row and the known_marketplaces.json lookup
are gone.`

- [ ] **Step 5: Run the gate commands**

```bash
bash tests/run.sh 2>&1 | tail -3
awk 'length > 100 {print FILENAME":"NR": "length}' skills/foreman-init/SKILL.md \
  skills/foreman-init/templates/CLAUDE.md.tmpl CLAUDE.md
grep -rn '{{' skills/foreman-init/templates/ | grep -v -E '\{\{(PROJECT_NAME|ONE_LINER|COMMANDS|ARCHITECTURE|INVARIANTS|DEFAULT_BRANCH|GATE_PERMISSIONS|GATE_TABLE|BASELINE_COUNT|BASELINE_SHA|TODAY|TRUST_BOUNDARIES|PR_RULE|MODEL_OVERRIDES|OWNERSHIP|STANDING_AUTHORIZATION|PHASE_SCOPE|SPEC_LIFECYCLE|PHASE_SLUG|PHASE_NAME|CONTEXT|PLAN_PATH|SPEC_REF|RULINGS|MODEL|EFFORT|PLAN_SLUG|PLAN_NAME|GOAL|STACK|SPEC_PATH|GLOBAL_CONSTRAINTS|TASK_TABLE|TASK_NUMBER|TASK_NAME|FILES|INTERFACES|TOPIC|PURPOSE)\}\}'
```

Expected: `14 files, 634 passed, 0 failed`, exit 0. The arithmetic from 630 after task 3: the
manifest row assertion +1; the `settings.local.json.tmpl` block replaced four assertions with
four; the CLAUDE.md block replaced seven with six; `test_init_skill.sh` replaced one with three
and dropped one; `test_dogfood.sh` added three. Net +4. If your count differs, recount the
assertions you removed and added before touching anything else, and record the final number in
the ledger. The `awk` prints nothing but frontmatter lines. The `grep`
prints nothing: every surviving `{{` is a variable the manifest still declares.

Also confirm the manifest diff is exactly one line and the template is gone:

```bash
git diff --cached --stat -- skills/foreman-init/templates/MANIFEST.tsv
git ls-files skills/foreman-init/templates/settings.local.json.tmpl   # expect: no output
```

- [ ] **Step 6: Mutation-check**

Change the template's `"repo": "yorah/foreman-harness"` to another string: the `names the
published harness repository` assertion must go red. Restore. Re-add the deleted manifest row
temporarily: the manifest assertion must go red. Remove it again. Put `known_marketplaces.json`
back into `CLAUDE.md.tmpl` as a bare word: its `assert_not_contains` must go red. Remove it.
Run once more, green.

- [ ] **Step 7: Commit**

```bash
git add -A skills/foreman-init/templates skills/foreman-init/SKILL.md CLAUDE.md \
  .claude/settings.json tests/test_templates.sh tests/test_init_skill.sh tests/test_dogfood.sh \
  docs/dev/backlog.md
git status --short   # .claude/settings.local.json must NOT appear; it is ignored
git commit -m "init: foreman marketplace is a GitHub source in tracked settings; retire settings.local.json.tmpl [DIST-1]"
```
