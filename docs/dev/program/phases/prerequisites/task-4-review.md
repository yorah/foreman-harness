# Task 4 review — `[DIST-1]` GitHub marketplace source, `settings.local.json` retired

Reviewed artifact: `docs/dev/program/phases/prerequisites/task-4-review.diff` (commit `1f73631`,
base `c033155`). The diff file was read, never regenerated; its stat block matches
`git show --stat 1f73631` byte for byte, so the artifact is faithful to the commit.

**Spec compliance: PASS.   Quality: Approved.**
Three Minors, no Critical, no Important.

---

## 1. Spec compliance

Every file the brief named is changed, and nothing outside the brief except one comment-only
edit the implementer declared (`.gitignore`, deviation 4 — judged sound below).

| Brief requirement | State | Evidence |
|---|---|---|
| `settings.json.tmpl` gains the `foreman` github entry before `fable-method` | done | `skills/foreman-init/templates/settings.json.tmpl:8-13` |
| `settings.local.json.tmpl` deleted | done, `git rm` | the commit stat lists it as `10 --`; `git ls-files` returns nothing for it |
| `MANIFEST.tsv` — one row removed, nothing else | done | `git show 1f73631 -- .../MANIFEST.tsv` is `1 file changed, 1 deletion(-)`, a single `-` line; 16 rows after the header |
| Row removed in the same commit as the file | done | both in `1f73631` |
| `gitignore-additions.txt` — comment only, ignore line stays | done | file still ends `.claude/settings.local.json`; only the two rationale lines changed |
| `CLAUDE.md.tmpl` `## Setup` rewritten | done | template lines 5-17 |
| `SKILL.md` Steps 3 and 5 rewritten | done | evolve bullet, substitution paragraph, staging paragraph |
| This repository's `CLAUDE.md` and `.claude/settings.json` | done | `CLAUDE.md` Setup is verbatim the template's text (compared side by side); settings valid JSON, `jq -e .` passes, every other key intact |
| Three test files | done | see section 4 |
| `backlog.md` closes `[DIST-1]` and `[T8-I15]` | done | see section 6 |
| **Not** installing/removing/re-registering a plugin | honoured | no `claude plugin` invocation anywhere in the diff |
| **Not** touching this repository's `.claude/settings.local.json` | honoured | absent from the commit and from the working-tree status |

Nothing required is missing. Nothing unrequired is present beyond the declared `.gitignore`
deviation.

---

## 2. The trust boundary — `MANIFEST.tsv` and the `mode` column

**Verdict: correct. `evolve` is the right mode for `settings.json.tmpl`, and no fresh
`foreman-init` can clobber an existing `.claude/settings.json`.**

I checked the *consumer* of the `mode` column, not only the manifest. There is no script that
reads `MANIFEST.tsv`: a recursive search over `scripts/ bin/ skills/ agents/ commands/ tests/`
returns only `bin/foreman-root`'s comment, `skills/foreman-init/SKILL.md:84` (the `cat` that
shows the manifest to the session), and the two test files. The mode is therefore executed by
prose in `skills/foreman-init/SKILL.md` Step 3:

> - `mode: evolve` — merge with what exists. For `CLAUDE.md` this means keeping the project's own
>   content and voice and folding in the missing sections, not replacing the file. For
>   `.gitignore` and `.claude/settings.json` it means **adding what is absent and touching
>   nothing else.**

That sentence survives the diff intact — the deletion was confined to the five sentences that
described `.claude/settings.local.json` as "a fourth evolve destination". The surviving prose
still names `.claude/settings.json` explicitly and still says *add what is absent, touch nothing
else*. A repository that already has `.claude/settings.json` with its own `permissions`,
`extraKnownMarketplaces` or `effortLevel` therefore keeps them and gains the `foreman` key.

The mode is also asserted, in both directions:

- `tests/test_templates.sh:163` — the `TABLE` heredoc pins `.claude/settings.json evolve`, and
  the loop fails with `MODE:...` if the manifest demotes it to `create`.
- The new `awk` assertion at `tests/test_templates.sh:183` closes the reverse direction the loop
  lacked.

No clobber path exists. Not a Critical.

A second-order note, not a defect: this change moves the `foreman` marketplace declaration from a
file that "usually does not exist yet" into one that frequently *does* exist in a target
repository. The evolve rule covers it, but the merge is now load-bearing in a way it was not
before. `[T10-1]` (open backlog, "`mode: evolve` needs to say merge by entry, not by line") is the
entry that would harden this; see Minor `[T4-M2]`.

---

## 3. The deletion is asserted, and the assertions are not vacuous

Mutation-checked in this worktree. Every mutation was made to a tracked file, then restored from a
scratchpad copy; the working tree and index are clean at the end of the review and the suite is
back at `14 files, 657 passed, 0 failed`.

| Mutation | Result | Verdict |
|---|---|---|
| Re-append the retired manifest row | **3 failed**: `MANIFEST.tsv has no settings.local.json row…`, `manifest rows are well formed` (`MISSING_TEMPLATE`), `no template carries a machine-specific marketplace path` | the absence of the row is genuinely guarded |
| Recreate `settings.local.json.tmpl` (with `{}`) | **2 failed**: `settings.local.json.tmpl still exists; the local marketplace source is retired`, `exactly one manifest row for settings.local.json.tmpl` | the absence of the template is genuinely guarded |
| `asks whether to` to `prompts you about whether to` in `CLAUDE.md.tmpl` | **1 failed**: `CLAUDE.md template explains the trust prompt a fresh clone sees` | the replacement needle is a real needle |
| `yorah/foreman-harness` to `someone/else` in `settings.json.tmpl` | **1 failed**: `settings.json.tmpl's foreman marketplace names the published harness repository` | the new source is guarded |

Both directions are covered — presence of the new github source **and** absence of the retired row
and file. This is the class of coverage the controller asked for, and it holds.

The one assertion the diff removes on net from `test_templates.sh` (`CLAUDE.md template names
claude plugin marketplace list as the tell…`) tested a step that no longer exists. Removing it is
correct, not a weakening.

`tests/test_init_skill.sh` loses `[T9-R5]`'s `records **user-scope** registrations only`
assertion and the `FOREMAN_MARKETPLACE_PATH is sourced, not invented` assertion. Both guarded
prose that the diff deleted; both are replaced by `assert_not_contains` on the same tokens, which
is strictly stronger.

---

## 4. The cross-file sweep (the class task 3 failed)

I swept the whole repository for the stale-claim tokens — `known_marketplaces`,
`FOREMAN_MARKETPLACE_PATH`, `scope local`, `marketplace add`, `"source": "directory"` — and read
every hit. **No shipped file, comment or test label still describes a machine-specific
marketplace path, a local-directory source, or a `settings.local.json` marketplace step.** Full
accounting:

Correct after the change:

- `skills/foreman-init/templates/CLAUDE.md.tmpl` — rewritten.
- `skills/foreman-init/SKILL.md` — Steps 3 and 5 rewritten; zero hits on any token.
- `CLAUDE.md` (this repository) — rewritten, **verbatim** identical to the template's Setup
  section (compared line by line).
- `.gitignore` and `templates/gitignore-additions.txt` — both now carry the same one-line
  per-contributor rationale; neither mentions a path.
- `README.md:17` — already correct (`/plugin marketplace add yorah/foreman-harness`), and its
  `foreman@foreman` explanation matches the new CLAUDE.md prose. Not changed, correctly.
- Test labels and comments in all three test files — rewritten; no label still describes the
  retired mechanism.

Legitimately unchanged (all verified, none false):

- `docs/dev/program/POLICY.md:12` and `templates/program/POLICY.md.tmpl:12` — name
  `.claude/settings.local.json` as the untracked file that can override the tracked `effortLevel`
  pin. Still true: `scripts/lib.sh:42` reads it first in `foreman_settings_chain`, and
  `tests/test_templates.sh:447` asserts the template says so.
- `scripts/lib.sh`, `tests/test_resolve_gate.sh`, `tests/test_program_skill.sh`,
  `skills/foreman-init/references/audit-checklist.md:20` — effort resolution, or auditing an
  existing repository. Unrelated to distribution.
- `docs/dev/specs/2026-08-28-harness-plugin-design.md:96` and
  `docs/dev/plans/2026-08-28-harness-v1/*` — historical records.
- `docs/dev/backlog.md` — the `[DIST-1]` and `[T8-I15]` bodies describe the *defect*, which is
  what a closed backlog entry is supposed to preserve.
- `tests/test_manifests.sh:11` and `.claude-plugin/marketplace.json` — `plugins[0].source: "./"`
  is the plugin's position *inside* its own marketplace repo, which a `github` marketplace source
  resolves correctly. Not the same "directory" as the retired setting.

One count-style claim I checked for staleness and cleared: nothing in `skills/`, `agents/`,
`commands/`, `tests/`, `POLICY.md`, `README.md` or `CLAUDE.md` asserts a template or row count
that the deletion invalidates. `tests/test_templates.sh:147`'s "only ten of sixteen destinations"
is a narrative comment about a past state, not a live count, and is unaffected.

---

## 5. The three declared concerns

### 5a. 657, not 658 — arithmetic confirmed independently

**Sound.** I did not take the report's word for it. Mutation 2 (recreating
`settings.local.json.tmpl`) produced `656 passed, 2 failed` = **658 total assertions**, against
**657** with the file absent. That is exactly one assertion per file under `templates/`, emitted
by the "Every template file has a manifest row" loop (`tests/test_templates.sh:15-20`), so
deleting the template removes one iteration. 654 (base) + 4 (net hand-added) - 1 = 657. The
report's intermediate observation (658 total with the test edits alone, before the file was
deleted) is consistent with the same arithmetic.

The brief's own figures (630/634) were stale against the base commit; the report says so and the
controller had already flagged it. 657 is above the recorded baseline, and `bash tests/run.sh` is
green.

### 5b. The `trust` needle — the replacement is meaningful

**Sound, and the implementer was right to change it.** I verified the vacuity claim directly
against the previous revision of `skills/foreman-init/templates/CLAUDE.md.tmpl`: its only
occurrence of "trust" is line 56, the unrelated bullet "Structural changes to this setup — new
gates, new trust boundaries — run `/foreman-init` again".

So the brief's `assert_contains "$claude_md_tmplf" "trust"` was green against the **old**
template, satisfied by a bullet the task does not touch. The brief expected that assertion to
fail in Step 2; it would not have. Lengthening it to `asks whether to trust that marketplace` is
the right repair, and it is not itself vacuous: the phrase occurs exactly once, only in the new
Setup prose, spans a line break in the shipped file (which is why the flattened
`$claude_md_tmplf` is the correct haystack — the same `flow()` discipline
`tests/test_init_skill.sh` already documents in its own header comment), and my own paraphrase
mutation turned it red. Deviating from a brief-supplied needle to make it discriminate is exactly
what a test-first task should do.

### 5c. The `.gitignore` edit — deviation sound

**Sound.** This repository's `.gitignore` carried the *identical* two-line rationale as
`gitignore-additions.txt`, verbatim, and that rationale ("a local absolute path that differs per
contributor's checkout") became false the moment the path stopped existing. Leaving it would have
been precisely the task-3 failure mode the dispatch warned about: a claim corrected in one file
and left false in another. The edit is comment-only, the `.claude/settings.local.json` ignore
line is untouched, and no assertion constrains those comment lines. Declared in the report.

The other two undeclared-by-the-brief edits (deviations 3 and 5 — the stale "`.gitignore`'s own
additions must actually exclude the file above" comment, and "three rules" to "two rules" in
`tests/test_init_skill.sh:121`) are the same class and equally sound: both comments were made
false by a deletion the brief ordered, and leaving them would have misdescribed the assertions
beneath them.

---

## 6. Program-manager-owned files, and the backlog closures

**Leaving `docs/dev/program/STATE.md` alone was correct.** `skills/foreman-program/SKILL.md:209`
establishes that the program manager commits `STATE.md` updates on the default branch; a phase
session writes its own ledger at `docs/dev/program/phases/<slug>/state.md`. `POLICY.md:6-7` makes
the same ownership rule explicit for `POLICY.md` itself. STATE.md's stale count (634) and its
stale "the shape this repository's `CLAUDE.md` documents today" clause are the program manager's
to fix at merge; the report discloses both under "What I could not verify", which is the correct
handling — a phase does not silently leave a known-stale statement unreported.

**Nothing else in the diff crosses into program-manager territory.** The 13 changed files are
this repository's `.claude/settings.json`, `.gitignore`, `CLAUDE.md`, `docs/dev/backlog.md`
(explicitly in the brief's file list), five files under `skills/foreman-init/`, and three test
files. No `POLICY.md`, no `STATE.md`, no `DEFERRED.md`, no `RULINGS.md`, no `HISTORY.md`, no
spec. `DEFERRED.md` already carries the "Re-register the plugin from the GitHub source" entry
with the exact expected `Source: GitHub (yorah/foreman-harness)` output, so the mechanism this
task could not exercise is already scheduled where it belongs — correctly left untouched.

**The backlog closures record what was actually done.** `[DIST-1]`'s own "Fix" paragraph
enumerates the marketplace source, `settings.local.json.tmpl`, `{{FOREMAN_MARKETPLACE_PATH}}`,
its `MANIFEST.tsv` row, the `known_marketplaces.json` lookup in Step 3, and the `CLAUDE.md`
Setup section. I verified each is gone or changed. `[T8-I15]` closes for the reason it says: the
second settings file was the whole deviation, and spec section 6's "everything is tracked" now
holds without a spec rewrite — the entry's own "Reconciling this would need…" paragraph is moot
in the direction the spec wanted, which the closure note states. Both entries keep the defect
description (correct for a ledger) and both use the same in-place `- [x]` plus "Closed by phase A
task 4:" shape `[DEP-1]` already uses. Neither closure overclaims.

---

## 7. Invariants

| # | Verdict | Basis |
|---|---|---|
| 1 — zero deps beyond bash, git, jq | PASS | No shipped script changed. The new test assertions use `awk`, `grep`, `jq`, `tr` — all already in the suite; no new tool. |
| 2 — shebang, `set -euo pipefail`, `chmod +x` | PASS | No executable script added, removed or re-moded. All three edited `tests/test_*.sh` retain `set -uo pipefail` at line 2, which is what the invariant requires for test files. No mode bits in the commit. |
| 3 — exit codes are contract | PASS (untouched) | No script with an exit contract is in the diff. `tests/run.sh`'s baseline gate is unchanged and still honours 1 versus 2. |
| 4 — absolute paths between tiers | PASS | The one path-bearing change is a *deletion* (the `~/.claude/plugins/known_marketplaces.json` lookup). Nothing new is passed between tiers. |
| 5 — no `TODO`, `TBD`, `FIXME` under `skills/`, `agents/`, `commands/` | PASS | A recursive word-boundary search over those trees with `--include='*.md'` returns no output. |
| 6 — bare wrapper names only | PASS | `$(foreman-root)` usages in SKILL.md unchanged; the diff adds no script call of any form. `tests/test_init_skill.sh`'s `templates_path_form` detector is still green on both SKILL.md and `commands/foreman-init.md`. |
| 7 — suite green, not below baseline | PASS | `bash tests/run.sh` gives `14 files, 657 passed, 0 failed`, exit 0, reproduced by me twice (before and after all mutations). Above the recorded baseline. |
| 8 — 100-column body prose in shipped markdown | PASS for this diff | A `^.{101,}` scan finds nothing in `CLAUDE.md.tmpl` or `CLAUDE.md`. `SKILL.md` reports lines 3 (YAML frontmatter, exempt), 24 (120 cols) and 172 (a URL-shaped path inside a fenced block). Both non-frontmatter hits are **pre-existing**: the previous revision of the file has the identical lines at 24 and 193 (193 shifted to 172 because this task deleted 21 lines above it). The diff introduces no new long line. |

### The organisation and vendor-name constraint

A case-insensitive search for `yorah`, `betclic`, `sahir` and `foreman-harness` over `skills/`,
`agents/`, `commands/`, `scripts/` and `bin/` returns exactly four hits, all in
`skills/foreman-init/templates/`:

- `CLAUDE.md.tmpl:9` and `:15`, and `settings.json.tmpl:12` — `yorah/foreman-harness`. **Inside**
  the sole exception the plan grants.
- `settings.json.tmpl:18` — `Sahir619/fable-method`. **Outside the literal wording** of the
  exception ("the GitHub repository name `yorah/foreman-harness` in the template and this
  repository's own settings"), but **pre-existing** — not introduced, moved or touched by this
  diff — and functionally identical in kind: it is the machine-readable marketplace coordinate
  for `fable@fable-method`, a plugin `enabledPlugins` already declares, not an organisation name
  in prose. Without it a generated repository enables a marketplace it cannot resolve, which is
  the very defect `[DIST-1]` existed to fix. It falls inside the exception's spirit and outside
  its letter; not a finding against this task, but the constraint would read more accurately as
  "GitHub repository coordinates required to resolve a declared marketplace".

`scripts/`, `bin/`, `agents/` and `commands/` are clean.

---

## 8. Findings

### Minor `[T4-M1]` — "The repository is `foreman-harness`" is ambiguous in a *generated* repository

`skills/foreman-init/templates/CLAUDE.md.tmpl:15`:

> `claude plugin list` is the tell: it shows `foreman@foreman` as enabled once the plugin is
> installed, and does not list it before. **The repository is `foreman-harness`**; the
> marketplace and the plugin inside it are both named `foreman`…

Failure scenario: this text lands verbatim in a target repository whose own name is, say,
`acme-api`, immediately under a heading that describes *that* repository. A contributor reading
"The repository is `foreman-harness`" has to infer that "the repository" means the marketplace's
repository named two sentences earlier, not the one they are working in. `README.md`'s version of
the same sentence does not have this problem, because there the antecedent really is this
repository. "The plugin's repository is `foreman-harness`" (or "The marketplace lives in
`yorah/foreman-harness`") removes the ambiguity at no cost, and no assertion pins that clause.
Worth doing, not worth blocking.

### Minor `[T4-M2]` — the changed `gitignore-additions.txt` comment guarantees a duplicated block on re-init, via open `[T10-1]`

`skills/foreman-init/templates/gitignore-additions.txt:1` and `:6` both changed text. Open
backlog entry `[T10-1]` records that Step 3's `evolve` instruction is implemented literally as
"add every absent **line**", which already produced a doubled comment block during task 10's
dogfood.

Failure scenario: `/foreman-init` is re-run against a repository initialised before this commit.
Its `.gitignore` already has the old two-line "Machine-specific: a local absolute path…"
rationale and the `.claude/settings.local.json` entry. The new one-line rationale is absent *as a
line*, so a literal implementation appends it, leaving the file carrying both the old (now false)
rationale and the new one. Bounded and cosmetic, and the root cause is `[T10-1]`, not this task —
but this change turns a possibility into a certainty for every already-initialised repository,
which is worth recording against `[T10-1]` when it is picked up.

### Minor `[T4-M3]` — asymmetric absence coverage between the template and this repository's `CLAUDE.md`

`tests/test_templates.sh:412-417` guards the template with three `assert_not_contains`
(`known_marketplaces.json`, `--scope local`, `settings.local.json`). `tests/test_dogfood.sh:80`
guards this repository's `CLAUDE.md` with only one (`known_marketplaces.json`).

Failure scenario: a later edit reintroduces `claude plugin marketplace add … --scope local` or a
`settings.local.json` step into this repository's own `CLAUDE.md` — the file the dogfood test
exists to keep honest, and the one a contributor to *this* repository actually reads — and the
suite stays green. The gap is brief-prescribed (the brief specified exactly the one dogfood
`assert_not_contains`), so it is not an implementation defect; adding the other two needles to
the dogfood block would close it in two lines.

### Not findings, recorded for completeness

- **Pre-existing invariant-8 violation at `skills/foreman-init/SKILL.md:24`** (120 columns, body
  prose). Proved pre-existing against the previous revision. The task rewrote prose elsewhere in
  the same file and left this line alone, correctly — fixing unrelated lines widens a
  trust-boundary diff.
- **The `github` source means this repository's own sessions resolve `foreman@foreman` from the
  published GitHub HEAD, not from the working tree.** That is the ruled-on design (kickoff:
  "plugin update between phases"), and `DEFERRED.md`'s re-registration entry is the action that
  reconciles it after the merge. Not a defect of this task.

---

## 9. Cannot verify from the diff

- **That Claude Code actually resolves the `github` marketplace source and shows a trust prompt
  for it.** Nothing in this task may run `claude` (kickoff ruling), so the new Setup prose in
  three files describes a mechanism whose *shape* matches the working `fable-method` entry but
  which was not exercised. The report discloses this, and `DEFERRED.md` already schedules the
  check with the exact command and expected output. Disclosed, scheduled, correctly out of scope.
- **That `/foreman-init` end-to-end still produces a correct repository.** The suite tests the
  templates and the manifest, not a generation run; no generation was performed. In particular
  the `evolve` merge into a pre-existing `.claude/settings.json` is verified as *prose* and as a
  manifest mode, not as an executed merge.

---

## 10. Review hygiene

Four mutations were applied to tracked files and restored from copies held in the session
scratchpad — never by checkout, to avoid the restore hazard the report itself records. Final
state: the working-tree status shows only the pre-existing untracked phase files
(`task-4-brief.md`, `task-4-report.md`) plus this review; the index and working tree carry no
modification to any tracked file; `bash tests/run.sh` prints `14 files, 657 passed, 0 failed`.
No repository-state-changing command was run.
