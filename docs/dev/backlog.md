# Backlog

Durable home for Minors and follow-ups a review deferred rather than fixing in-branch, and for
deviations from the spec that a ruling decided to keep rather than reconcile immediately.

Format: `- [ ] [source-tag] short description — why deferred, what it needs`

## Open

- [ ] [T8-I15] `.claude/settings.local.json` is an undeclared spec deviation. Task 8's template
  manifest (`skills/foreman-init/templates/MANIFEST.tsv`) splits generated-repository settings
  across two files: the tracked `.claude/settings.json` and a new, gitignored
  `.claude/settings.local.json` carrying `{{FOREMAN_MARKETPLACE_PATH}}`
  (`skills/foreman-init/templates/settings.local.json.tmpl`). Spec §6's generated-repository
  layout names exactly one settings file — "`.claude/settings.json  enabledPlugins,
  extraKnownMarketplaces, worktree.baseRef, gate permissions`" — and states **"Everything is
  tracked."** as a principle with its reasons; §12.3 repeats the single-file list. The second
  file departs from both.

  Kept by ruling (`[T8-M16]`, fix round 3, reaffirmed in the round-4 controller note on
  `[T8-I15]`): a settings file with a machine-specific absolute path
  (`{{FOREMAN_MARKETPLACE_PATH}}`, the generating contributor's own checkout path for the
  `foreman` plugin repo) cannot be tracked without breaking every second contributor who clones
  the generated repo — the path would be wrong on their machine. That constraint is not one
  spec §6 weighed when it wrote "everything is tracked."

  Reconciling this would need: spec §6's layout and §12.3 rewritten to list the second file and
  its exception to "everything is tracked," with the exception's reason recorded there rather
  than only in this backlog entry; and spec §12.0's effort-resolution chain order (currently
  `.claude/settings.json`, then `.claude/settings.local.json`, then `~/.claude/settings.json`,
  "most specific winning") reconciled with `scripts/lib.sh`'s `foreman_settings_chain`, which
  reads `.claude/settings.local.json` **first** — the reverse order (`[T8-M21]`, parked). That
  discrepancy was pre-existing but became load-bearing the moment `/foreman-init` started
  generating a `settings.local.json` for every repository, since it is what let a local file
  silently outrank the tracked `effortLevel` pin `docs/dev/program/POLICY.md.tmpl` promises all
  three tiers (`[T8-I16]`, fixed in fix round 4 by qualifying that promise rather than changing
  `resolve-gate.sh`'s read order).

- [ ] [T9-R7] Four templates are orphaned: nothing instantiates them. `MANIFEST.tsv`'s four
  `{{`-bearing destinations — `program/kickoff.md.tmpl`, `plans/plan-README.md.tmpl`,
  `plans/task-N.md.tmpl` and `specs/spec.md.tmpl` — are correctly skipped at init, because
  `PHASE_SLUG`, `PLAN_SLUG`, `TASK_NUMBER` and `TOPIC` have no value until their subject
  exists. But nothing downstream picks them up either: `grep` for `templates`, `MANIFEST`,
  `kickoff.md.tmpl`, `plan-README`, `task-N` and `spec.md.tmpl` across
  `skills/foreman-program/SKILL.md` and `skills/foreman-phase/SKILL.md` returns nothing —
  neither skill mentions the templates directory or the manifest at all. `foreman-program`
  writes kickoffs freehand and plans via `superpowers:writing-plans`; `foreman-phase` writes
  task briefs.

  Consequence: the `PHASE_SLUG` / `PHASE_NAME` / `CONTEXT` / `PLAN_PATH` / `SPEC_REF` /
  `RULINGS` / `MODEL` / `EFFORT` shape those templates specify is not guaranteed by anything.
  `tests/test_templates.sh` asserts `kickoff.md.tmpl`'s first step matches what
  `foreman-program` *promises* the PM, which is a prose-to-prose check, not a wiring one.

  Deferred because wiring them is a `foreman-program` / `foreman-phase` change (tasks 6 and 7),
  not a `foreman-init` one: `/foreman-init` is right to skip them. Fix round 1 of task 9
  removed the false claim that `/program` and `/phase` instantiate them
  (`skills/foreman-init/SKILL.md`, Step 3) rather than leaving the skill asserting wiring that
  does not exist. What it needs: either the two skills read the manifest for their on-demand
  rows, or the four templates are deleted and their required shape moved into the skills that
  actually write those documents.

- [ ] [§15.4] **Measure the reviewer return-size ratio during the next real phase.** Spec §15.4
  asks for the byte size of a reviewer's returned message against the review file it wrote. It
  cannot be measured outside a live phase, so it was not measured in task 10. When the next
  phase runs, record the ratio in `docs/dev/CONTEXT.md`. The claim being checked is that the
  verdicts-only return contract keeps the controller's context small; an unmeasured ratio means
  that contract is asserted, not demonstrated.

- [ ] [T10-1] **`mode: evolve` for `.gitignore` needs to say "merge by entry", not "by line".**
  Task 10's dogfood implemented the instruction literally — add every absent line — and produced
  a `.gitignore` carrying the template's comment block twice, because the comments are absent as
  *lines* even when the entry they describe is already present. The merged file was corrected by
  hand before it landed. `skills/foreman-init/SKILL.md` Step 3 should say what it means.

---

## Flushed from the v1 phase ledger — 2026-08-31

Every Minor parked across tasks 1–9 lived only in the phase ledger under `.superpowers/sdd/`,
which is **gitignored** and does not survive the worktree. The branch review graded that a
Critical (spec §9.6) and it was right: a deferral nobody can read is a deletion with extra steps.

### Plan hygiene

- [ ] **[T-PLAN] `task-2.md`–`task-6.md` embed reference code superseded by their own fix rounds.**
  The shipped files are authoritative; the plans were never refreshed. Concrete example:
  `task-2.md:193` still shows the model check as `*opus*|*fable*`, a substring match accepting
  `notopus` and `fabled` — the shipped `resolve-gate.sh` rejects both by whole-token matching.
  Anyone reading a plan file as a specification reads a defect that was fixed months earlier.
  Either refresh the code blocks or mark each as historical.

### Task 1 — runner and assertions

- [x] **[T1-M1] The manifest `version`/`description` checks accepted an empty string**, not just
  rejected `null` — so a `plugin.json` with `"version": ""` published green. **Fixed in-branch**
  (`tests/test_manifests.sh`), verified both directions: empty and missing both fail now.
  *Recorded wrong the first time.* This entry originally described the adjacent ledger line
  ("`lib_assert.sh` lacks `set -euo pipefail` — ruled, not a defect"), because the tag sits at
  the end of the bullet above it and an unanchored scrape picked up the wrong one. The real
  deferral — a live defect — was lost for exactly as long as the wrong summary stood.
- [ ] **[T1-M3] A backgrounded assertion that never returns hangs the runner rather than failing
  it.** `run.sh`'s `wait` is unbounded. Parked deliberately: a bounded `wait` trades a hang for a
  race, and no shipped test backgrounds anything.

### Task 2 — `lib.sh` and the gate

- [x] **[T2-M1] `tests/test_manifests.sh` was the only test file carrying `set -e`**, against
  the runner's own rationale. The whole-branch review found the same thing independently as
  `[M-4]`; fixed in-branch.
- [ ] **[T2-M2] `--repo` pointing at an existing non-directory** falls through to the user
  settings tier instead of exiting 2. No caller reaches it; the harness always supplies an
  absolute repo root.
- [ ] **[T2-M3] An `effortLevel` of `" high"` or `"High"` returns `unknown`** rather than
  normalising. Safe (`unknown` is exit 2, never a false pass) but unfriendly.

### Task 3 — `task-brief.sh`

- [ ] **[T3-M1] The heading guard rejects a CommonMark-valid indented ATX heading** (up to three
  leading spaces). No plan file uses one.
- [ ] **[T3-M2] The subshell-write justification in the task-3 report is unsubstantiated.** The
  code is correct; the stated reason for it was never verified. Recorded because a wrong
  rationale outlives the code it explains.

### Task 4 — baseline and phase state

- [ ] **[T4-M1] A baseline value beyond 64 bits produces noisy stderr** rather than a clean
  diagnostic. The verdict stays safely non-`pass`.
- [ ] **[T4-M2] `lib.sh`'s `foreman_repo_root()` has the supplied-empty-vs-omitted shape** that
  `resolve-gate.sh` and `phase-state.sh` both fixed explicitly. Latent: no caller passes empty.

### Task 5 — agent contracts

- [ ] **[T5-M1] Reviewer "read-only" is prompt-level, not tool-level.** Both reviewer agents are
  granted `Bash`, which can write. The contract says do not fix what you find; nothing enforces
  it. This is the one on this list with real teeth — see `[M-6]`, which is its mirror image.
- [ ] **[T5-M2] `tools_line()`'s anchor can be bypassed** by a frontmatter shape the generator
  never emits.
- [ ] **[T5-M3] A lowercase tool-name variant is uncaught.** Not a real grant: Claude Code tool
  names are proper-cased.
- [x] **[T5-M4] The branch reviewer's Return names no output-file convention**, only "the file
  path you were given". The ledger records this as **pre-existing and correct** — the phase
  controller supplies that path per phase — not as an open defect. My first entry inverted the
  ruling into a bug report.
- [ ] **[T5-P1] A plan amendment was verified in the working tree and never committed, and was
  lost.** Process failure, not code. It is why the standing rule exists: *a ruling that edits a
  tracked file is not made until it is committed.*

### Task 6 — phase skill

- [ ] **[T6-M2] The fix-loop exit branch at `foreman-phase/SKILL.md:247` has no assertion.**
  Deleting it leaves the suite green.

### Task 8 — templates

- [x] **[T8-M26] `task-8.md:10` said "16 template files"; the manifest lists 17.** Fixed
  in-branch. Missing from the first flush entirely.

### From the whole-branch review

- [x] **[M-1] The invariant-6 detector missed a path-form call on the wrappers themselves.**
  Fixed in-branch, then found still incomplete on re-review (`[M-B]`): the widened pattern
  required a leading slash, so a bare relative `bin/foreman-gate --model` still passed. Both
  forms are caught now, each proven by planting it.
- [x] **[M-2] Detector comments stated the pre-invariant-6 rule.** Fixed in-branch, then found
  half-done on re-review (`[M-D]`): the comments were corrected but the assertion labels and the
  `unqualified_script()` function name still used the old vocabulary. All renamed.
- [ ] **[M-5] Invariants 1, 2 (for `scripts/`) and 8 have no mechanical enforcement.** Partly
  closed: `tests/run.sh` now carries the baseline gate and `tests/test_bin.sh` tests it in all
  three directions (below → exit 1, above → exit 0, unreadable → warn, never gate). The rest of
  the runner is still unscored by anything.
- [ ] **[M-6] Both reviewer agents require a written findings file and are granted no `Write`
  tool.** They have been writing via `Bash`, which is why nobody noticed — and which is also
  `[T5-M1]`. Decide which way the contract goes; today it is incoherent in both directions.
- [x] **[M-7] `tests/test_agents.sh` and `tests/test_phase_skill.sh` were mode 644.** Fixed in
  round 1 — every test file is 755. Listed open here by mistake after it had already been closed.

### Still open from the fix-round-1 re-review

- [x] **[M-A] A dispatched-but-not-launched phase reports `unreadable`.** `[I-4]` has the program
  manager write the `STATE.md` row at dispatch, which is right, but there is now a window between
  the row appearing and the phase session creating its branch. Both triage tables route the
  resulting exit 2 to `unreadable — <stderr>`, when the truthful reading is `planned, not yet
  launched`. The window is real and bounded; the wrong word is the defect.
- [x] **[M-E] The `[T-PLAN]` banner is untested, and its cited example is off-file.** All five
  plan files cite `task-2.md`'s `*opus*|*fable*` glob; in `task-3.md` through `task-6.md` that
  example is about a different file than the one the reader is holding. Nothing asserts the
  banner is present, so it can be deleted silently.

### Still open from the fix-round-2 re-review

- [x] **[M-A] A dispatched-but-not-launched phase reports `unreadable`.** Carried from round 1:
  `[I-4]` has the program manager write the `STATE.md` row at dispatch, so there is a window
  between the row appearing and the phase creating its branch. Both triage tables route the
  resulting exit 2 to `unreadable — <stderr>`, when the truthful reading is `planned, not yet
  launched`. The window is real and bounded; the wrong word is the defect.
- [x] **[M-E] The `[T-PLAN]` banner is untested and cites an off-file example.** All five plan
  files cite `task-2.md`'s `*opus*|*fable*` glob, so in `task-3.md`–`task-6.md` the example is
  about a different file than the one being read. Nothing asserts the banner is present.

### Found after the v1 merge

- [ ] **[DIST-1] The plugin is distributed as a local directory, so a generated repository
  cannot be handed to a second person by pushing it.** `templates/settings.local.json.tmpl`
  registers the `foreman` marketplace with `"source": "directory"` and
  `{{FOREMAN_MARKETPLACE_PATH}}` — an absolute path into the generating contributor's own
  checkout. That file is gitignored by `gitignore-additions.txt`, correctly, because the path is
  wrong on every other machine. The consequence is that cloning a foreman-initialised repository
  gets the policy, the ledger, the docs and a tracked `.claude/settings.json` saying
  `"foreman@foreman": true` — enabling a plugin Claude Code has no way to locate. The generated
  `CLAUDE.md` `## Setup` section explains the two commands needed, but the first of them requires
  the contributor to already possess a checkout of the harness repo, obtained out of band.

  Fix: publish the harness repo and change the marketplace source from `directory` to `github`,
  the shape `settings.json.tmpl` already uses for `fable-method`. The `foreman` entry then moves
  into the **tracked** `settings.json`, and `settings.local.json.tmpl`,
  `{{FOREMAN_MARKETPLACE_PATH}}`, its `MANIFEST.tsv` row, the `known_marketplaces.json` lookup in
  `foreman-init` Step 3 and the `CLAUDE.md` Setup section all go away with it. Onboarding becomes
  clone plus the trust prompt.

  Not a config edit: it touches the manifest, two templates, `foreman-init` Step 3, the generated
  `CLAUDE.md`, and the tests asserting each. Note this also **resolves `[T8-I15]`** — the
  undeclared spec deviation exists only to carry a machine-specific path, and there is no path
  once the source is a repo rather than a directory. **No longer blocked**: the harness is
  published at `github.com/yorah/foreman-harness`, so the `github` source this needs now exists.
  `settings.json.tmpl` already uses that shape for `fable-method`; copy it for `foreman`.

- [x] **[DEP-1] `fable-method` and `superpowers` are hard dependencies with no missing-plugin
  path.** `foreman-program` SKILL.md sends the spec interview to `superpowers:brainstorming`
  (:130) and the plan to `superpowers:writing-plans` (:136); `gate-chain.md` dispatches
  `fable:fable-judge` as gate 3 (:64,:73) and `superpowers:finishing-a-development-branch` (:174);
  `plans/plan-README.md.tmpl` carries a REQUIRED SUB-SKILL banner naming
  `superpowers:subagent-driven-development`. `foreman-init` Step 4 shows the pattern that is
  missing here: for `claude-md-management` it says "If the plugin is not installed, read its
  rubric from the marketplace cache instead" and applies it by hand. Nothing comparable exists
  for the other two — verified by grep across `skills/`, `agents/` and `commands/`.

  In practice they resolve: `superpowers` and `claude-md-management` come from the official
  marketplace and `fable-method` from a GitHub source in `settings.json.tmpl`. But resolution is
  not degradation. A contributor who declines the trust prompt, or a `fable-method` repo that
  moves, leaves a phase session at gate 3 invoking a skill that is not there — and the failure
  surfaces mid-gate-chain rather than at setup.

  Fix: decide per reference whether it is required or preferred, then either state the fallback
  the way Step 4 does, or check for the skill at a point where a clean stop is still possible —
  the phase session's Step 0, next to the refusal gate — rather than discovering it at gate 3.

  Unrelated, but adjacent enough to confuse a reader of `resolve-gate.sh`: that script's
  `*-fable-*` match is about **Fable the model**, not the `fable-method` plugin. The gate passes
  `claude-fable-5` with `fable-method` not installed at all.

  Closed by phase A task 3: each session skill checks its dependencies at Step 0 and stops
  cleanly, naming the plugin; no fallbacks, by ruling (a fallback is a second copy of another
  plugin's procedure). The fifth reference named above, `plans/plan-README.md.tmpl`'s
  `superpowers:subagent-driven-development` banner, was not given a check of its own: it ships
  inside the same `superpowers@claude-plugins-official` plugin that Step 0 already checks via
  `superpowers:finishing-a-development-branch`, so the failure mode this item describes — a
  whole plugin absent — is caught regardless. Judged covered, not overlooked.

### Closed on `fix/triage-and-plan-banner`

- **[M-A]** — both triage tables (`skills/foreman-program/SKILL.md`, `commands/program-status.md`)
  now disambiguate an absent branch with the phase row's own `Status` column: `planned` prints
  `planned, not yet launched`, and any later status with no branch anywhere still prints
  `unreadable`, because a phase that reached `executing` must have had a branch. Four assertions
  in `tests/test_program_skill.sh`, both directions, mutation-verified.
- **[M-E]** — the banner's worked example is `task-2.md`'s model check, so `task-3.md`–`task-6.md`
  now mark it as coming from a sibling plan rather than implying it is about the file in hand, and
  `task-2.md` cites it as its own. `tests/test_plans.sh` asserts the banner, its authoritative
  clause and its `[T-PLAN]` pointer in all five files, so it can no longer be dropped silently.
  `[T-PLAN]` itself stays open: the code blocks are still unrefreshed, and the banner is what
  stands in for that.

### Found while dispatching phase A (2026-09-02)

- [ ] **[DIST-2] Every slash command in shipped prose is written bare (`/phase`, `/program`,
  `/program-status`, `/foreman-init`); the installed plugin exposes them namespaced as
  `/foreman:phase`, `/foreman:program`, `/foreman:program-status`, `/foreman:foreman-init`.**
  Found by launching, not by reading: `/phase <kickoff>` in a session inside this repository
  returned `Unknown command: /phase`, while the skill listing names `foreman:phase`. Same class as
  `$CLAUDE_PLUGIN_ROOT`: invisible from inside the repository, fatal on install. Touch points
  (bare mentions per file): `CLAUDE.md.tmpl` 8, this repository's `CLAUDE.md` 8,
  `foreman-program/SKILL.md` 7 (including the launch block it prints), `README.md` 6,
  `foreman-init/SKILL.md` 4, `foreman-phase/SKILL.md` 2, `gate-chain.md` 1, and one each in
  `kickoff.md.tmpl`, `STATE.md.tmpl`, `POLICY.md.tmpl`. Fix: namespace every mention and add an
  assertion that no bare form survives in `skills/`, `commands/`, templates, `README.md`. Skills
  and templates, so an Opus reviewer. Candidate for phase B, which already rewrites the same
  files for the layout change.
