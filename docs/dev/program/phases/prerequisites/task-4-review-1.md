# Task 4 re-review (fix round 1) — `[T4-M1]`, `[T4-M2]`, `[T4-M3]`

Reviewed artifact: `docs/dev/program/phases/prerequisites/task-4-review-1.diff` (cumulative,
base `c033155`, head `fd90e51`). The diff file was read, never regenerated.

**Artifact fidelity.** The file's stat block — 13 files, `139 insertions(+), 162 deletions(-)` —
matches `git diff --stat c033155..fd90e51` line for line, so the artifact is faithful to the
committed range. One limitation, recorded because it affects what a reviewer reading only the
artifact can see: the compaction truncates the tail of the `tests/test_templates.sh` hunk
(`... (9 lines truncated)`), and the 9 elided lines contain the body of the `[T4-M1]`
assertion — the single assertion this round exists to add. I read that assertion from the
committed file (`tests/test_templates.sh:419-427`) and cross-checked it against
`git show fd90e51 -- tests/test_templates.sh`, which is a read of the commit, not a
regeneration of the reviewed diff.

**Spec compliance: PASS.   Quality: Approved.**
Three Minors, no Critical, no Important.

---

## 0. The controller's claims, re-derived

The fix round was committed by the phase controller, not the implementer (API 529s, dead-subagent
protocol). The implementer's report covers only round 0. Each claim was tested, not accepted.

| Claim | Verdict | Evidence |
|---|---|---|
| gate 1 plain at 660 passed, 0 failed | **confirmed** | `bash tests/run.sh` → `14 files, 660 passed, 0 failed`, exit 0. Reproduced five times across this review (before, between and after every mutation). Plain invocation, no environment prefix, from the worktree root. |
| `foreman-baseline --count 660` → pass, baseline 610, delta +50 | **confirmed** | `bash bin/foreman-baseline --policy <abs>/docs/dev/program/POLICY.md --count 660` → `{"verdict":"pass","baseline":610,"count":660,"delta":50}`, exit 0. `POLICY.md:30` still reads `baseline-count: 610` — the phase did not edit it, correctly. |
| arithmetic is exactly +3 over the 657 floor (`test_templates.sh` +1; `test_dogfood.sh` one assertion replaced by three) | **confirmed** | `fd90e51` touches five files; only two are tests. `tests/test_templates.sh` gains one `assert_eq` (+1, line 425). `tests/test_dogfood.sh` replaces one `assert_not_contains` with three (+2, lines 84-90). Nothing else in the commit can emit an assertion — the other three files are `CLAUDE.md`, `CLAUDE.md.tmpl` and `docs/dev/backlog.md`, and no loop in the suite iterates over their content (the per-template-file loop at `test_templates.sh:14-20` is unaffected: no template was added or removed this round). 657 + 3 = 660. Cross-checked against the mutation runs: single-failure mutations printed `659 passed, 1 failed`, the two-failure mutation printed `658 passed, 2 failed` — total 660 every time, so nothing is being skipped or double-counted. |
| all four new assertions mutation-check red | **confirmed** — and I found a fifth case that stays green, see finding 1 | table below |
| the committed diff is a complete subset of the round's three findings, nothing half-applied | **confirmed** | `fd90e51` = `[T4-M1]` (template wording + this repository's `CLAUDE.md` + the new assertion), `[T4-M3]` (two extra dogfood needles), `[T4-M2]` (backlog note under `[T10-1]`). Nothing else. No program-manager-owned file, no baseline edit, no test weakened or deleted in this round. |

### Mutation table (all mutations to tracked files, restored from scratchpad copies)

| # | Mutation | Result | Reading |
|---|---|---|---|
| A | `CLAUDE.md.tmpl`: revert to the committed-form conflation "The repository is `foreman-harness`" | **1 failed** — `CLAUDE.md template never tells a generated repository that it is the harness repository: expected [], got [The repository is \`foreman-harness]` | the `[T4-M1]` regression is genuinely guarded |
| B | `CLAUDE.md.tmpl`: cased/backticked variant "This Repository Is `FOREMAN-HARNESS`" | **1 failed** — same assertion | case-insensitivity is real, not decorative |
| C | `CLAUDE.md.tmpl`: reworded conflation "This repository is named `foreman-harness`" | **660 passed, 0 failed** | **escape** — finding 1 |
| E | this repository's `CLAUDE.md` gains `marketplace add /path --scope local` and `.claude/settings.local.json` on one line | **2 failed** — `this repository's CLAUDE.md no longer registers a local-directory marketplace`, `... no longer describes a machine-specific settings file` | both new `[T4-M3]` needles are live |
| G | the same reintroduction, with `--scope` / `local` split across a line wrap | **660 passed, 0 failed** | **escape** — finding 2 |
| H | the identical line-wrapped reintroduction in `CLAUDE.md.tmpl` | **1 failed** — `CLAUDE.md template no longer registers a local-directory marketplace` | the template-side guard catches what the dogfood-side guard misses |

The third dogfood needle (`known_marketplaces.json`) is unchanged from round 0, where it was
mutation-proved; it is a space-free token, so the haystack difference in finding 2 cannot reach it.

**Review hygiene.** Six mutations, each restored by copying back a scratchpad snapshot (never by
`git checkout`). Final state verified: `md5sum` of `CLAUDE.md` and `CLAUDE.md.tmpl` back to their
committed values, `git status --short` showing only the pre-existing untracked phase files
(`task-4-brief.md`, `task-4-report.md`, `task-4-review.md`), suite green at 660. No
repository-state-changing git command was run.

---

## 1. Finding — Minor `[T4R1-M1]`: the `[T4-M1]` guard's comment and label claim more reach than the guard has

`tests/test_templates.sh:419-427`:

```
# Every mention of the harness repository in the template must be attributed (to the plugin, the
# marketplace, or the `yorah/` owner) rather than left as the bare subject "the repository".
# Case-insensitive and optional-backtick so a reworded conflation is caught too.
assert_eq "" \
  "$(printf '%s' "$claude_md_tmplf" | grep -oiE '(the|this) repository is `?foreman-harness' || true)" \
  "CLAUDE.md template never tells a generated repository that it is the harness repository"
```

**The wording fix itself is sound.** "The plugin's own repository is `foreman-harness`" is
unambiguous in a generated repository: the name is attributed to the plugin, not left as a
predicate of "the repository" the reader is standing in. Applied verbatim to this repository's
own `CLAUDE.md` as well — `CLAUDE.md:16-19` and
`skills/foreman-init/templates/CLAUDE.md.tmpl:14-17` are byte-identical for the whole Setup
section, compared side by side. `README.md:21`'s "The repository is `foreman-harness`" is
correctly left alone: there the antecedent really is this repository. No other
`(the|this) repository is` in the harness sense occurs under `skills/`, `agents/` or `commands/`.

**But the guard's stated reach does not match what it checks.** The comment asserts a universal
rule ("*every* mention ... must be attributed") and the label asserts an absolute outcome
("*never* tells a generated repository that it is the harness repository"), while the regex pins
exactly one phrasing: the subject word `the` or `this`, the copula `is`, an optional backtick,
any casing. The comment's third line states the reach outright and states it wrongly — "so a
*reworded* conflation is caught too". Rewording is precisely what escapes; what is caught is
re-casing and backtick variance, which is not rewording.

**Failure scenario (mutation C, run).** An editor trusting the comment writes "This repository is
named `foreman-harness`" — a claim as false in `acme-api` as the one this round removed, and
under a heading that describes `acme-api`. The suite stays green at 660 and the false sentence
ships into every repository `/foreman-init` generates. "`foreman-harness` is this repository"
escapes the same way. The owner of a generated repository has no way to know it came out wrong,
which is the whole reason `[T4-M1]` was raised.

No regex can cover every conflation, so the honest repair is to the claim rather than the guard:
say that it pins the one phrasing that regressed, in any casing, and that other rewordings are
unguarded. Graded Minor, consistent with this phase's two prior rulings of the same class
(`[T3-M14]`, `[T3-M15]`) — the guard does redden on the regression it was built for (mutations A
and B), so the protection is real; what is defective is the description of it.

---

## 2. Finding — Minor `[T4R1-M2]`: `[T4-M3]`'s dogfood needles use a weaker haystack than the template-side guards they claim to mirror

`tests/test_dogfood.sh:80-90`:

```
# [T4-M3] All three needles test_templates.sh guards on CLAUDE.md.tmpl, applied to this
# repository's own copy -- ...
own_claude_md="$(cat "$R/CLAUDE.md" 2>/dev/null || true)"
assert_not_contains "$own_claude_md" "known_marketplaces.json" ...
assert_not_contains "$own_claude_md" "--scope local" ...
assert_not_contains "$own_claude_md" "settings.local.json" ...
```

The template side matches against a flattened haystack — `tests/test_templates.sh:405`:
`claude_md_tmplf="$(printf '%s' "$claude_md_tmpl" | tr '\n' ' ' | tr -s ' ')"` — and the dogfood
side matches the raw file. `assert_not_contains` (`tests/lib_assert.sh:26-32`) is a literal,
whitespace-sensitive `case` glob, so for the one needle containing a space — `--scope local` —
the two sides are not the same test.

**Failure scenario (mutations G and H, run).** A reintroduced setup step whose prose wraps at 100
columns between `--scope` and `local` lands in this repository's own `CLAUDE.md`: the suite stays
green at 660. The identical text in `CLAUDE.md.tmpl` reddens. That wrap is realistic, not
contrived: the text this task deleted was a >100-column line containing exactly that command,
and invariant 8 requires body prose in both files to wrap at 100.

So the comment's claim — "*all three* needles ... applied to this repository's own copy" — holds
for two of them and is strictly weaker for the third, in the file the dogfood test exists to keep
honest and the one a contributor to *this* repository actually reads. One line fixes it: flatten
`own_claude_md` with the same `tr '\n' ' ' | tr -s ' '` the template side uses, which is also the
house rule `tests/test_init_skill.sh`'s own header comment documents for prose needles.

Bounded — the primary regression shape (a single-line `--scope local`) is caught — so Minor.

---

## 3. Finding — Minor `[T4R1-M3]`: the `[T10-1]` sharpening understates the duplication it records

`docs/dev/backlog.md:81-88`.

**Recording it rather than working around it was right.** `[T10-1]` is the root cause — Step 3's
`evolve` instruction implemented literally as "add every absent *line*" — and it is not a
template edit. A template carrying both the old and the new rationale to dodge that merge defect
would ship the false one on purpose, which is worse than a duplicated comment. The note says
exactly this and points the fix at `[T10-1]`. Sound.

**The certainty claim holds, with one caveat.** For a repository initialised before `1f73631`
whose `.gitignore` was not hand-corrected, the old rationale is present and the new line is
absent *as a line*, so a literal by-line merge appends it; `[T10-1]` records that this already
happened once, in task 10's own dogfood. The caveat is that `evolve` is executed by prose, not by
a script, so "certainly" is a strong reading of a non-deterministic step. Acceptable for a
backlog note whose purpose is to raise urgency; not a finding on its own.

**What is inaccurate is the extent.** Task 4 changed *three* comment lines in
`gitignore-additions.txt`, not two: the header line ("... and the machine-specific settings file
below." to "... and the per-contributor settings file below.", now line 1) plus the two-line
rationale, which became the single line 6. Both surviving new lines — the new header line *and*
the new rationale — are absent as lines from an already-initialised repository, so a by-line
merge appends **two** new lines beside **three** stale ones. The note describes only "the new
one-line rationale beside the old two-line one", and its phrase "rewrote both comment lines"
reads as though the rationale were the only thing touched. A durable record another session will
act on should state the full extent; as written, whoever picks up `[T10-1]` will look for one
duplicated line and find two.

---

## 4. Not findings, recorded

- **The absence needles forbid more than their labels say.**
  `assert_not_contains ... "settings.local.json"` on the template and on this repository's
  `CLAUDE.md` forbids *any* mention of that file, not only a machine-specific one. A future and
  entirely true sentence — "Claude Code writes local permission grants to
  `.claude/settings.local.json`", which is what `gitignore-additions.txt:6` now says — would
  redden the suite under a label claiming the opposite ("no longer describes a machine-specific
  settings file"). Brief-prescribed on the template side, carried to the dogfood side by this
  round. Worth knowing before someone reads that red as a real regression.
- **`tests/test_init_skill.sh:62-65` matches its two absence needles against `$s` (raw) while
  that file's own header rationale prescribes the flattened `$sf`.** Harmless here: both needles
  (`known_marketplaces.json`, `FOREMAN_MARKETPLACE_PATH`) are space-free and cannot be split by
  a wrap. Inconsistent, not defective.
- **The `.claude/settings.json` `evolve` merge is now load-bearing** (round 0's second-order
  note). `[T10-1]` is titled for `.gitignore` only and this round's note does not extend it to
  the JSON case, where a literal by-line merge would not be merely cosmetic. Round 0 graded this
  "not a defect" and it remains one only in prospect: `skills/foreman-init/SKILL.md:111-114`
  still says "For `.gitignore` and `.claude/settings.json` it means adding what is absent and
  touching nothing else", `MANIFEST.tsv` still carries `settings.json.tmpl ... evolve`, and both
  directions are asserted (`tests/test_templates.sh:165` forward, `:184` the new reverse). No
  clobber path exists. Still unrecorded anywhere, though.
- **The dogfood side has no counterpart to the template's three *positive* assertions** (manual
  install command, trust prompt, `claude plugin list` as the tell). Outside `[T4-M3]`, which was
  about the absence needles only.
- **The committed template now deviates from the brief's verbatim Step 3 block**
  (`task-4-brief.md:227` prescribes "The repository is `foreman-harness`"). That deviation is
  round-0 Minor `[T4-M1]` being honoured; it is correct, and is recorded here so a later reader
  does not mistake it for drift.
- **No implementer report exists for this round**, so the only on-disk record of it is
  `fd90e51`'s commit message, and the phase ledger
  (`docs/dev/program/phases/prerequisites/state.md`) still ends at task 3. Closing that is the
  controller's, per "document what you did, on disk". The round-0 report's `657` figures are
  stale as a description of the tree, correctly so — it is a round-0 artifact and does not claim
  to cover this round.

---

## 5. The stale-mechanism sweep — every instance

Swept the whole tree case-insensitively for `known_marketplaces`, `FOREMAN_MARKETPLACE_PATH`,
`scope local`, `marketplace add`, `"source": "directory"` and `machine-specific`, and read every
hit. **No shipped file, comment or test label still describes a machine-specific marketplace
path, a local-directory source, or a `settings.local.json` marketplace step.** Complete
accounting of what remains:

Stale, and deliberately outside this phase's ownership:

- `docs/dev/program/STATE.md:44-49` — the open ruling recording the 2026-09-02 install
  (`claude plugin marketplace add <checkout> --scope local`) and calling the directory source
  "the shape this repository's `CLAUDE.md` documents today". That clause is now false; the
  ruling's own text says it holds "until phase A's `[DIST-1]` replaces it", which has now
  happened. Program-manager-owned, disclosed in the round-0 report; `DEFERRED.md`'s
  re-registration entry is the action it points at.
- `docs/dev/program/STATE.md:36-38` — "Next action" expects `bash tests/run.sh` to print 634 on
  this worktree; it prints 660. Same file, same owner. `DEFERRED.md`'s "Raise the baseline"
  entry already says "trust the run, not the plan".

Correct as they stand:

- `README.md:17` — `/plugin marketplace add yorah/foreman-harness` is a GitHub coordinate, not a
  local path, and is the plugin's own install instruction. Unchanged, correctly.
- `docs/dev/program/DEFERRED.md:11-19` — names the 2026-09-02 directory registration as the
  thing to *remove*, and expects `Source: GitHub (yorah/foreman-harness)` afterwards: a
  historical fact plus the corrective action. Untouched, correctly.
- `docs/dev/program/POLICY.md:12` and `templates/program/POLICY.md.tmpl:12`,
  `scripts/lib.sh:42,64`, `skills/foreman-init/references/audit-checklist.md:20` — all about
  `.claude/settings.local.json` as an untracked effort/permissions override, still true and
  unrelated to distribution.
- `docs/dev/backlog.md`'s `[T8-I15]` and `[DIST-1]` bodies, `docs/dev/plans/**`,
  `docs/dev/specs/**`, `task-4-report.md` — defect descriptions and historical records, which is
  what a ledger is for.
- All labels and comments in the three edited test files — negative or past tense ("no longer
  ...", "A directory source *carried* a machine-specific absolute path"). Correct.

---

## 6. Program-manager-owned files, kickoff rulings, backlog closures

**Nothing crossed the `STATE.md` line.** `git diff --stat c033155..fd90e51` lists 13 files: this
repository's `.claude/settings.json`, `.gitignore`, `CLAUDE.md`, `docs/dev/backlog.md`, five
files under `skills/foreman-init/`, and three test files. No `STATE.md`, `POLICY.md`,
`DEFERRED.md`, `RULINGS.md`, `HISTORY.md`, no spec, plan or kickoff. Leaving `STATE.md` stale was
the ruling; it was honoured.

**Kickoff rulings, each checked:**

- *Source is `github` / `yorah/foreman-harness`.* Both this repository's `.claude/settings.json`
  and `settings.json.tmpl` carry `extraKnownMarketplaces.foreman.source =
  {"source":"github","repo":"yorah/foreman-harness"}`, placed before `fable-method`. `jq -e .`
  passes on the former, and `jq -S 'del(.extraKnownMarketplaces)'` is byte-identical to the same
  projection at `c033155`, so the `foreman` key is the *only* change to that file.
- *`.claude/settings.local.json` still ignored, only its rationale changed.* `.gitignore:9` still
  reads `.claude/settings.local.json`; only the comment above it (line 8) and the header line
  changed. Same for `gitignore-additions.txt`, whose `.claude/settings.local.json` line (7) is
  asserted at `tests/test_templates.sh:432-434`.
- *No plugin installed, removed or re-registered.* No `claude plugin` invocation anywhere in the
  diff, and the machine state agrees: `~/.claude/plugins/known_marketplaces.json`'s `foreman`
  entry is still `{"source":"directory","path":"/home/yorah/projects/foreman-harness"}` with
  `lastUpdated: 2026-09-02T16:15:37Z` — unchanged today.
- *This repository's own `.claude/settings.local.json` untouched.*
  `/home/yorah/projects/foreman-harness/.claude/settings.local.json` still carries the directory
  source, mtime `2026-09-02 18:15`, before today's work. It does not exist in the worktree at
  all, being untracked.

**MANIFEST.tsv, the trust boundary.** The cumulative diff of that file is
`1 file changed, 1 deletion(-)`: the single `settings.local.json.tmpl` row. Header and tab
separators untouched; 16 rows after the header, every row exactly 4 tab-separated fields;
`git ls-files skills/foreman-init/templates/` lists 16 template files plus the manifest, so files
and rows correspond exactly — and both directions are now guarded
(`tests/test_templates.sh:14-20` forward, `:184` the reverse this task added).
`settings.local.json.tmpl` is untracked and absent from the tree.

**Backlog closures record what was done.** `[DIST-1]` and `[T8-I15]` are both `- [x]` with the
same closure sentence, and every noun in it checks out: the marketplace is a GitHub source in the
tracked settings; `settings.local.json.tmpl`, its manifest row and the `known_marketplaces.json`
lookup in Step 3 are all gone (verified individually). Neither closure overclaims — in particular
`[T8-I15]`'s closure does not claim the parked `[T8-M21]` chain-order discrepancy was resolved,
and it was not. Both entries keep the defect description, correct for a ledger, and use the
in-place `- [x]` shape `[DEP-1]` already established.

---

## 7. Invariants

| # | Verdict | Basis |
|---|---|---|
| 1 — zero deps beyond bash, git, jq | **PASS** | No shipped script changed this round. The new assertions use `grep -oiE`, `jq`, `cat`, `tr`; `grep -oE` is pre-existing house style in this suite (`test_templates.sh:79,108,211,308`, `test_dogfood.sh:45`, `test_init_skill.sh:92,112`) and `-i` adds no tool. |
| 2 — shebang, `set -euo pipefail`, `chmod +x` | **PASS** | All three edited test files still open `#!/usr/bin/env bash` + `set -uo pipefail` on lines 1-2, which is what the invariant requires of `tests/test_*.sh`. No executable added, deleted or re-moded; the deleted file is a JSON template. |
| 3 — exit codes are contract | **PASS (untouched)** | No script with an exit contract is in the diff. `foreman-baseline` re-verified live: `0` at the count, `2` on a missing or relative `--policy`. |
| 4 — absolute paths between tiers | **PASS** | The only path-bearing change is a deletion (the `~/.claude/plugins/known_marketplaces.json` lookup). New assertions address files through `$R` / `$t` / `$FOREMAN_ROOT`, all absolute. |
| 5 — no `TODO`/`TBD`/`FIXME` under `skills/`, `agents/`, `commands/` | **PASS** | Word-boundary recursive search over `*.md` in those trees returns nothing. |
| 6 — bare wrapper names only | **PASS** | The diff adds no script invocation of any form; `$(foreman-root)` in `SKILL.md` is unchanged and bare. `tests/test_init_skill.sh`'s path-form detectors are green on both `SKILL.md` and `commands/foreman-init.md`. |
| 7 — green, not below baseline | **PASS** | `14 files, 660 passed, 0 failed`, exit 0, reproduced five times. `foreman-baseline --count 660` → pass, baseline 610, delta +50. |
| 8 — 100-column body prose in shipped markdown | **PASS for this diff** | Per-file scan (`FNR`, not `NR` — the brief's own gate command uses `NR` and therefore misreports line numbers across multiple files) of `CLAUDE.md`, `CLAUDE.md.tmpl`, `gitignore-additions.txt` and `docs/dev/backlog.md`: nothing over 100. `skills/foreman-init/SKILL.md` reports 3 (YAML frontmatter, exempt), 24 (120) and 172 (140). Both non-frontmatter hits are pre-existing: the same scan at `c033155` reports the identical 3 / 24 / 193, and 193 is today's 172 (21 lines were deleted above it). Line 172 is a marketplace-cache path inside a fenced block. No new long line. |

### The organisation-and-vendor-name rule

Case-insensitive search for `yorah`, `betclic`, `sahir`, `foreman-harness` over `skills/`,
`agents/`, `commands/`, `scripts/`, `bin/` returns exactly four hits, all under
`skills/foreman-init/templates/`:

- `CLAUDE.md.tmpl:9` (`yorah/foreman-harness`), `CLAUDE.md.tmpl:15` (`foreman-harness`,
  attributed to the plugin) and `settings.json.tmpl:12` (`yorah/foreman-harness`) — **inside**
  the exception the plan grants.
- `settings.json.tmpl:18` — `Sahir619/fable-method`. **Outside the letter** of the exception,
  which names only `yorah/foreman-harness`; **inside its spirit**, and **pre-existing** — the
  same line exists at `c033155`, and this diff neither introduces nor moves it. It is the
  machine-readable coordinate that lets a generated repository resolve the `fable@fable-method`
  marketplace `enabledPlugins` already declares; without it the repository enables a plugin
  Claude Code cannot locate — the exact defect `[DIST-1]` existed to remove. Not a finding
  against this task. The constraint would read more accurately as "GitHub repository coordinates
  required to resolve a declared marketplace".

`scripts/`, `bin/`, `agents/` and `commands/` are clean.

---

## 8. Cannot verify from the diff

- **That Claude Code resolves the `github` marketplace source and shows a trust prompt for it.**
  No `claude` invocation is permitted in this phase, so the Setup prose in three files describes
  a mechanism whose shape matches the working `fable-method` entry but which was not exercised.
  Disclosed in the report; `DEFERRED.md` schedules the check with the exact command and expected
  output. Correctly out of scope.
- **That `/foreman-init` end-to-end still produces a correct repository.** No generation run was
  performed. In particular the `evolve` merge into a pre-existing `.claude/settings.json` is
  verified as a manifest mode and as prose, not as an executed merge.

---

## 9. Verdicts

**Spec compliance: PASS.** The round addressed all three round-0 Minors and nothing else; the
brief's own requirements, satisfied in round 0, are re-verified intact above (settings template
entry, deleted template, one-row manifest diff, gitignore rationale, both `## Setup` sections,
`SKILL.md` Steps 3 and 5, this repository's settings, three test files, two backlog closures).

**Quality: Approved.** Three Minors, no Critical, no Important. Carry forward:

- `[T4R1-M1]` — the `[T4-M1]` guard's comment and label claim reach the regex does not have; a
  reworded conflation ships green (proved, mutation C).
- `[T4R1-M2]` — the dogfood `--scope local` needle uses a raw haystack where its template-side
  twin uses a flattened one; a line-wrapped reintroduction escapes (proved both directions,
  mutations G and H).
- `[T4R1-M3]` — the `[T10-1]` note understates the duplication: two new lines beside three
  stale, not one beside two.
