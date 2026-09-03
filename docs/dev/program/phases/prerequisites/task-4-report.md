# Task 4 report — `[DIST-1]` GitHub marketplace source, `settings.local.json` retired

**Commit:** `1f73631` — `init: foreman marketplace is a GitHub source in tracked settings; retire
settings.local.json.tmpl [DIST-1]`
**Base:** `c033155`
**Gate 1:** `bash tests/run.sh` → `14 files, 657 passed, 0 failed`, exit 0 (floor was 654).

## What changed, per file

### `skills/foreman-init/templates/settings.json.tmpl`
Added a `foreman` entry to `extraKnownMarketplaces`, before `fable-method`, in the same shape
`fable-method` already used: `{"source":{"source":"github","repo":"yorah/foreman-harness"}}`.
This is the whole of the distribution fix: the marketplace is now declared in the **tracked**
settings file, so a clone of a generated repository can resolve `foreman@foreman` without any
per-machine path.

### `skills/foreman-init/templates/settings.local.json.tmpl` — deleted
Removed with `git rm`. Its only content was the `directory`-source marketplace entry carrying
`{{FOREMAN_MARKETPLACE_PATH}}`, an absolute path into the generating contributor's own checkout.
With the source now `github` there is nothing machine-specific left to write, so the second
settings file has no reason to exist.

### `skills/foreman-init/templates/MANIFEST.tsv`
One line deleted: the `settings.local.json.tmpl` row. Verified byte-for-byte with
`git diff --cached -- ... | cat -A`: one `-` line, no other change, header and every tab
separator identical. 17 rows after the header before, 16 after. The deletion is in the same
commit as the file it declares.

### `skills/foreman-init/templates/gitignore-additions.txt`
The `.claude/settings.local.json` ignore line **stays** (per the kickoff ruling). Only the
rationale changed: the two-line "machine-specific absolute path" comment became one line —
`# Per-contributor: Claude Code writes local permission grants here. Never shared, never tracked.`
— and the header comment's "and the machine-specific settings file below" became "and the
per-contributor settings file below".

### `skills/foreman-init/templates/CLAUDE.md.tmpl`
`## Setup` replaced wholesale (heading to the line before `## Commands`) with the clone-and-trust
story: the tracked `.claude/settings.json` both enables the plugin and declares the GitHub
marketplace; a fresh clone needs no path and no second settings file; Claude Code asks whether to
trust the marketplace on first start; `claude plugin install foreman@foreman` is the manual
fallback; `claude plugin list` is the tell. 29 lines became 13. No comments added (templates ship
none).

### `skills/foreman-init/SKILL.md`
- Step 3, the `mode: evolve` bullet: dropped the five sentences describing
  `.claude/settings.local.json` as "a fourth evolve destination". The bullet now ends at
  "…adding what is absent and touching nothing else." Three evolve destinations remain
  (`CLAUDE.md`, `.gitignore`, `.claude/settings.json`), which is what the surviving prose says.
- Step 3, substitution: four paragraphs and one `jq … known_marketplaces.json` code block
  replaced by three lines — substitute every `{{VARIABLE}}` from the audit and the interview,
  and "no template needs a machine-specific path and nothing is looked up outside the repository
  being initialised."
- Step 5: the staging paragraph no longer tells the session to write an untracked settings file;
  the confirmation line is now "`git status --short` shows every generated file staged and
  nothing ignored by `.gitignore` in the index." Reflowed to 100 columns.

### `CLAUDE.md` (this repository)
`## Setup` replaced with the template's text verbatim.

### `.claude/settings.json` (this repository)
The same `foreman` entry added to `extraKnownMarketplaces`, before `fable-method`. Every other
key untouched; `jq -e .` confirms the file is valid JSON. **No plugin command of any kind was
run**, and this repository's own `.claude/settings.local.json` was not touched or staged (it is
gitignored and does not appear in `git status --short`).

### `.gitignore` (this repository) — not in the brief's file list
See "Deviations" below. Comment-only: the same stale rationale the template carried was also
sitting in this repository's own `.gitignore`, verbatim, and is now false. Replaced with the same
one-line per-contributor rationale. The ignore line itself is unchanged.

### `tests/test_templates.sh`
- Destination table (`dest_mode_errs` heredoc): `.claude/settings.local.json evolve` removed.
- Added the reverse-direction assertion the loop lacks: an `awk` count of manifest rows whose
  destination is `.claude/settings.local.json`, asserted `0`. The loop only checks
  table→manifest, so without this a resurrected manifest row would pass silently.
- The four `settings.local.json.tmpl` assertions replaced by four: the rendered
  `settings.json.tmpl`'s `extraKnownMarketplaces.foreman.source.source` is `github`; its `.repo`
  is `yorah/foreman-harness`; `settings.local.json.tmpl` does not exist; no file under
  `templates/` contains `FOREMAN_MARKETPLACE_PATH`.
- The seven CLAUDE.md-template assertions replaced by six, three of them
  `assert_not_contains` (`known_marketplaces.json`, `--scope local`, `settings.local.json`) —
  a deletion nothing asserts is a deletion that comes back.
- The gitignore assertion kept, relabelled "gitignore-additions.txt keeps the per-contributor
  settings.local.json untracked".

### `tests/test_init_skill.sh`
- The `[T9-R5]` block (one assertion that the lookup "does not claim to always resolve") replaced
  by three: Step 3 contains neither `known_marketplaces.json` nor `FOREMAN_MARKETPLACE_PATH`, and
  does state why no lookup is needed.
- The `FOREMAN_MARKETPLACE_PATH is sourced, not invented` assertion deleted, and the comment above
  the surviving pair corrected from "three rules" to "two rules".

### `tests/test_dogfood.sh`
- `.claude/settings.local.json` removed from the "nothing unsubstituted" file list.
- Three assertions added after `worktree base ref is fresh`: this repository's own settings
  declare the `github` source and the `yorah/foreman-harness` repo, and this repository's
  `CLAUDE.md` no longer contains `known_marketplaces.json`.

### `docs/dev/backlog.md`
`[T8-I15]` and `[DIST-1]` changed from `- [ ]` to `- [x]`, each with a "Closed by phase A task 4:"
paragraph in the same shape `[DEP-1]` uses. `[T8-I15]`'s reconciliation is now moot in the
direction the spec wanted: the second settings file is gone, so spec §6's "everything is tracked"
holds without a rewrite.

## The cross-file sweep

The install story is told in five places. All five now agree:

| File | State |
|---|---|
| `skills/foreman-init/templates/CLAUDE.md.tmpl` | rewritten |
| `skills/foreman-init/SKILL.md` | rewritten (Steps 3 and 5) |
| `CLAUDE.md` (this repository) | rewritten, verbatim the template's text |
| test labels and comments in all three test files | rewritten |
| `README.md` | **already correct** — documents `/plugin marketplace add yorah/foreman-harness` and the `foreman@foreman` naming. No change needed; verified by reading it, not assumed. |

Deliberately **not** changed, with reasons:

- `docs/dev/program/POLICY.md` and `templates/program/POLICY.md.tmpl` mention
  `.claude/settings.local.json` as the file that can override the tracked `effortLevel` pin.
  Still true: `foreman_settings_chain` in `scripts/lib.sh` reads it first, and the file still
  legitimately exists per-contributor for permission grants. A test asserts the template says so.
- `tests/test_resolve_gate.sh`, `scripts/lib.sh`,
  `skills/foreman-init/references/audit-checklist.md` all reference `settings.local.json` for
  effort resolution or for auditing an existing repository. Unrelated to marketplace
  distribution; still true.
- `docs/dev/specs/2026-08-28-harness-plugin-design.md` — the design record, deliberately
  historical.
- `docs/dev/program/STATE.md` and `docs/dev/program/DEFERRED.md` — see "What I could not verify".

## Commands run

```
bash tests/run.sh                          # baseline at c033155: 14 files, 654 passed, 0 failed
bash tests/run.sh (after test edits only)  # 14 files, 643 passed, 15 failed
bash tests/run.sh (final)                  # 14 files, 657 passed, 0 failed

awk 'length > 100' on SKILL.md, CLAUDE.md.tmpl, CLAUDE.md, backlog.md
  → SKILL.md:3 (370, YAML frontmatter, exempt), SKILL.md:24 (120), SKILL.md:172 (140)
    Both non-frontmatter hits are pre-existing: `git show HEAD:skills/foreman-init/SKILL.md`
    has the same two lines (at 24 and 193; 193 shifted to 172 because this task deleted
    21 lines above it). Line 24 is body prose I did not touch; line 172 is a path inside a
    fenced code block. Neither is a line this task wrote.

grep -rn '{{' skills/foreman-init/templates/ | grep -v <declared vars>       → no output
grep -rlE '\b(TODO|TBD|FIXME)\b' skills/ agents/ commands/ --include='*.md'  → no output (inv. 5)
grep -rl FOREMAN_MARKETPLACE_PATH skills/ agents/ commands/ scripts/ bin/ tests/
  → tests/test_init_skill.sh, tests/test_templates.sh only, as assertion needles.
    Zero occurrences in any shipped file.

git diff --cached --stat -- .../MANIFEST.tsv    → 1 file changed, 1 deletion(-)
git diff --cached -- .../MANIFEST.tsv | cat -A  → exactly one `-` line, tabs intact
git ls-files .../settings.local.json.tmpl       → no output
jq -e . .claude/settings.json                   → valid
git status --short before commit                → no .claude/settings.local.json (ignored)
```

### The 15 expected failures, before implementation

Exactly the brief's list, no others: the manifest no-row assertion; `github` source; published
repo name; `settings.local.json.tmpl still exists`; no machine-specific path; the three CLAUDE.md
`assert_not_contains`; the trust-prompt assertion; the two Step 3 `assert_not_contains`; `Step 3
states why the marketplace source needs no lookup`; the three dogfood assertions.

### Mutation checks — seven, each red on the assertion it names, then restored

1. `"repo": "yorah/foreman-harness"` → `"someone/else"` in `settings.json.tmpl` → **1 failed**,
   `settings.json.tmpl's foreman marketplace names the published harness repository`.
2. Retired manifest row appended back → **3 failed**: the new no-row assertion, `no template
   carries a machine-specific marketplace path`, and (correctly) `manifest rows are well formed`
   with `MISSING_TEMPLATE`.
3. `known_marketplaces.json` appended to `CLAUDE.md.tmpl` → **1 failed**, its
   `assert_not_contains`.
4. `settings.local.json.tmpl` recreated → **2 failed**: `still exists; the local marketplace
   source is retired`, and the per-file `exactly one manifest row for settings.local.json.tmpl`.
5. Repo name corrupted in this repository's own `.claude/settings.json` → **1 failed**, the
   dogfood `names the published harness repository`.
6. "Claude Code asks whether to" → "Claude Code prompts you about" in `CLAUDE.md.tmpl` → **1
   failed**, the trust-prompt assertion.
7. SKILL.md's "nothing is looked up outside the repository being initialised" → "…outside
   `~/.claude/plugins/known_marketplaces.json`" → **1 failed**, `Step 3 no longer looks up a
   marketplace checkout path`.

One process note worth recording, because it nearly cost a silent regression: mutation checks 1–3
were run with the working tree **unstaged**, and the `git checkout -- <file>` used to restore
mutation 3 reverted `CLAUDE.md.tmpl` to `HEAD` — silently undoing the Setup rewrite rather than
just the mutation. Caught by mutation 4's run, which showed four CLAUDE.md-template assertions red
that had no business being red. The Setup section was re-applied, then everything was staged
*before* the remaining mutations, so `git checkout --` restored from the index. All restores after
that point were verified with an empty `git diff --stat`, and the final run is green at 657.

## Deviations from the brief

1. **Final count is 657, not the brief's predicted 634 (i.e. 654 + 4 = 658).** The brief's
   arithmetic is right about the assertions added and removed by hand (net +4) but misses one
   automatic loss: `tests/test_templates.sh`'s "Every template file has a manifest row" loop emits
   **one assertion per file** under `templates/`, so deleting `settings.local.json.tmpl` removes
   an assertion. 654 + 4 − 1 = 657. Confirmed empirically: 658 total (643 P / 15 F) with the test
   edits alone, dropping to 657 the moment the template file was deleted. 657 is above the 654
   floor. The brief's absolute numbers (630/634) were also stale against the base commit, which
   the controller had already flagged.
2. **The brief's `trust` needle was self-satisfied and I lengthened it.** `assert_contains
   "$claude_md_tmplf" "trust"` passed against the **old** template, because the unrelated bullet
   "new gates, new trust boundaries" further down `CLAUDE.md.tmpl` contains the word. A needle
   that is green before the fix is not a test of the fix, and the brief expected this one to fail.
   Changed to `"asks whether to trust that marketplace"` — its longest unique form, the same
   discipline `tests/test_init_skill.sh`'s own header comment demands. Label unchanged.
   Mutation-checked (#6 above).
3. **Repaired a stale comment the brief left behind.** The surviving gitignore assertion was
   introduced by the comment "`.gitignore`'s own additions must actually exclude the file above" —
   after this task there is no such "file above", since the block it referred to is gone.
   Rewritten to state the rule on its own terms. Comment only; the assertion is the brief's.
4. **Also edited `.gitignore` (this repository), which is not in the brief's file list.** It
   carried the *same* two-line rationale as `gitignore-additions.txt`, verbatim, and that
   rationale is now false in this repository too. This is precisely the "sweep the class, do not
   patch one instance" caution the dispatch gave. Comment-only; the `.claude/settings.local.json`
   ignore line is untouched, and no test constrains those comment lines.
5. **`tests/test_init_skill.sh`: adjusted one comment the brief did not mention.** Deleting the
   `FOREMAN_MARKETPLACE_PATH is sourced, not invented` assertion left the comment "The three rules
   a plausible SKILL.md omits" above two assertions. Changed "three" to "two".

## What I could not verify

- **That Claude Code actually resolves the `github` marketplace source and prompts for trust.**
  Nothing in this task runs `claude`, by ruling, so the new Setup prose describes a mechanism
  whose *shape* I asserted (identical to the working `fable-method` entry, which this repository
  already resolves) but did not exercise. `docs/dev/program/DEFERRED.md` already schedules that
  check for the program manager after the merge, with the exact commands and the expected
  `Source: GitHub (yorah/foreman-harness)` output.
- **Whether `/foreman-init` end-to-end still produces a correct repository.** The suite tests the
  templates and the manifest, not a generation run. No generation was performed.
- **Two program-manager files now hold statements this task made stale.** I did not touch them —
  they are the program manager's ledger, and the brief scoped them out — but they should not be
  read as current:
  - `docs/dev/program/STATE.md`'s "Next action" expects `bash tests/run.sh` to print **634** on
    this worktree. It prints **657**. Same for the `DEFERRED.md` "Raise the baseline" entry, which
    does already say "trust the run, not the plan".
  - `docs/dev/program/STATE.md`'s open ruling about the 2026-09-02 local-directory install says
    the directory source is "the shape this repository's `CLAUDE.md` documents today … until phase
    A's `[DIST-1]` replaces it". `[DIST-1]` has now replaced it, so that clause has come due; the
    `DEFERRED.md` re-registration entry is the action it points at.
- **The 100-column state of `skills/foreman-init/SKILL.md` lines 24 and 172.** Both exceed 100 and
  both are pre-existing (proved against `HEAD`); neither is a line this task wrote, so I left
  them. Line 172 is inside a fenced code block.
