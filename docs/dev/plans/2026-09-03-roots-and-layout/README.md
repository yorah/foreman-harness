# Roots and layout (phase B) Implementation Plan

**Plan directory:** `docs/dev/plans/2026-09-03-roots-and-layout/` — this file plus one `task-N.md`
per task.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the harness the durability split of spec §4 in single mode — durable files under
`docs/dev/`, transient state in a gitignored, nested `.foreman/` repository — with every reader
and writer of program state moved onto those roots, and this repository itself migrated onto
the layout it now installs.

**Architecture:** Two new scripts with `bin/` wrappers (`foreman-roots`, `foreman-diff`), one
rewritten script (`foreman-state` reads a file at `--work-root` instead of `git show` on a
branch), a manifest whose destinations encode §4.1's three kinds of file, and the four session
skills re-pointed at roots the kickoff or `foreman-roots` supplies. Every hardcoded
`docs/dev/program/` in shipped prose goes. The additive tasks come first so the suite's count is
well above baseline when the retirement task removes the `git show` path's tests, and this
repository's own migration is last, because `tests/run.sh`'s baseline gate must move with
`POLICY.md` in the same commit.

**Tech Stack:** bash, git, jq. Markdown skills, commands and templates. The bash test suite
under `tests/`.

**Spec:** `docs/dev/specs/2026-09-02-program-layer-merge.md` §4.1–4.6 (the design), §10 row B
(what this phase delivers), §11 (rulings taken while writing), §12.2 and §12.3 (this phase's
verification items). Backlog items absorbed: `[DIST-2]`, `[JUDGE-1]`, `[JUDGE-2]`,
`[T2-R1-M1]`, `[T2-R1-M4]`, `[BR-6]`, `[BR-11]`, `[T-PLAN]` in `docs/dev/backlog.md`. Read §4
first. Where the plan and the spec disagree, the spec wins.

---

## Global Constraints

Every task's requirements implicitly include this section. They are `POLICY.md`'s invariants,
restated so a task's implementer needs no second file.

- **Zero runtime dependencies beyond `bash`, `git` and `jq`** in any shipped script.
- **Every executable script is `#!/usr/bin/env bash` with `set -euo pipefail`, and `chmod +x`.**
  Sourced libraries (`tests/lib_assert.sh`, `scripts/lib.sh`) carry no `set` line at all.
  Every `tests/test_*.sh` and `tests/run.sh` carry `set -uo pipefail` (no `-e`).
- **Exit codes are contract:** `0` success, `1` a definite negative verdict, `2` cannot
  determine. A caller must be able to tell "no" from "I don't know".
- **All paths passed between tiers are absolute.** This phase applies it one level up: a phase
  never resolves roots; its kickoff hands it every path absolute (spec §4.4).
- **No `.md` under `skills/`, `agents/` or `commands/` contains `TODO`, `TBD` or `FIXME`.**
- **Harness scripts are invoked by bare wrapper name** — `foreman-gate`, `foreman-brief`,
  `foreman-baseline`, `foreman-state`, `foreman-root`, and from this phase `foreman-roots` and
  `foreman-diff` — never by any path, relative or `$CLAUDE_PLUGIN_ROOT`-prefixed.
- **`bash tests/run.sh` is green before every commit**, and no change leaves the suite below
  the recorded baseline. The task order below is what keeps that true through task 7; do not
  reorder tasks 1–6 after 7.
- **Body prose in shipped markdown wraps at 100 columns.** YAML frontmatter scalar values are
  exempt.
- **Prose assertions test meaning, not line breaks.** Match needles against a
  whitespace-flattened copy of the file (`tr '\n' ' ' | tr -s ' '`) when the needle may wrap;
  the existing tests call this helper `flow`.
- **Every new assertion is mutation-checked before commit:** delete or corrupt the one thing it
  names and confirm it goes red, then restore. An assertion that stays green through the
  mutation is not written yet.
- **Test both directions.** A claim "when X is broken you see Y" is not proven until Y is also
  shown absent when X works.
- **No organisation or vendor names in `skills/`, `agents/`, `commands/`, `scripts/`** (spec §2).
  In particular, the proxy hook `[JUDGE-1]` is about is never named; `foreman-diff`'s
  completeness check is structural, not a search for one tool's marker.
- **JSON, never YAML, for anything a script reads** (spec §11): `jq` is the only parser.
- **A phase never edits `POLICY.md`, `STATE.md`, `DEFERRED.md`, `RULINGS.md` or `HISTORY.md`.**
  Task 11 *moves* three of them with `git mv`; it does not change their contents. If a task
  believes one of them is wrong, it says so in its report and continues.

## Baseline

`660` green at `f811034`. No task may leave the suite below it. `main`'s tip when this plan was
written was `f557fb8`, a docs-only commit on top of `f811034` with the same count.

**Expected trajectory**, so a deviation is visible when it happens. Approximate; count your own
assertions rather than trusting these, but if a task lands far from its row, stop and find out
why before committing.

| After task | Suite | Change |
|---|---|---|
| 1 | ~674 | `tests/test_roots.sh` new; four `test_bin.sh` rows |
| 2 | ~686 | `tests/test_diff.sh` new; three `test_bin.sh` rows |
| 3 | ~690 | four runner-isolation assertions |
| 4 | ~694 | the no-bare-command sweep, four file groups |
| 5 | ~700 | manifest rows, nested `.gitignore`, `foreman.json.tmpl` renders as JSON |
| 6 | ~706 | init bootstrap prose |
| 7 | ~689 | `test_phase_state.sh` rewritten: 43 out, ~26 in |
| 8 | ~692 | program-side triage prose |
| 9 | ~695 | phase-side nested-repository prose |
| 10 | ~701 | `tests/test_single_mode_layout.sh` new |
| 11 | ~696 | `tests/test_plans.sh` removed (−5), dogfood list re-pointed |
| 12 | ~696 | no assertions; a verification run |

## File structure

| File | Responsibility |
|---|---|
| `scripts/lib.sh` | gains `foreman_roots <abs-start-dir>` (task 1) |
| `scripts/roots.sh`, `bin/foreman-roots` | CLI over `foreman_roots` (task 1) |
| `scripts/diff-package.sh`, `bin/foreman-diff` | writes a review diff and proves it complete (task 2) |
| `tests/run.sh` | unsets `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE` (task 3); baseline gate reads `docs/dev/POLICY.md` (task 11) |
| `tests/test_bin.sh` | wrapper rows for the two new wrappers (tasks 1, 2); runner isolation both directions (task 3); `foreman-state` row on `--work-root` (task 7) |
| `skills/**`, `commands/*.md`, `README.md`, `CLAUDE.md`, templates | every slash command namespaced `/foreman:…` (task 4) |
| `tests/test_namespaced_commands.sh` | no bare slash command survives (task 4) |
| `skills/foreman-init/templates/MANIFEST.tsv` | §4.1 destinations; two new rows (task 5) |
| `skills/foreman-init/templates/program/foreman.json.tmpl`, `program/work-root.gitignore` | new (task 5) |
| `skills/foreman-init/templates/{CLAUDE.md,docs/README.md,program/kickoff.md,program/STATE.md,plans/*}.tmpl`, `gitignore-additions.txt` | re-pointed at the new roots (task 5) |
| `tests/test_templates.sh` | destination table, new rows, `.foreman` ignore line (task 5) |
| `skills/foreman-init/SKILL.md` | single-mode bootstrap of `.foreman/`; `[BR-6]` (task 6) |
| `tests/test_init_skill.sh` | bootstrap prose assertions (task 6) |
| `scripts/phase-state.sh` | rewritten on `--work-root`; `git show`, `--repo`, `--branch`, `STATE.md` lookup retired (task 7) |
| `tests/test_phase_state.sh` | rewritten for a file read (task 7) |
| `tests/test_dogfood.sh` | `foreman-state` call on `--work-root` (task 7); generated-layout list re-pointed (task 11) |
| `commands/program-status.md`, `commands/program.md`, `skills/foreman-program/SKILL.md`, `references/milestones.md` | roots via `foreman-roots`; single-mode dispatch with no push; triage tables retired (task 8) |
| `tests/test_program_skill.sh` | new triage needles (task 8) |
| `skills/foreman-phase/SKILL.md`, `references/gate-chain.md`, `commands/phase.md` | `<work-root>` from the kickoff; artefacts committed to the nested repository; `foreman-diff`; `[BR-11]` (task 9) |
| `tests/test_phase_skill.sh` | placeholder definitions, `foreman-state` and `foreman-diff` call sites (task 9) |
| `tests/test_single_mode_layout.sh` | renders the manifest into a scratch repository and asserts spec §12.2 (task 10) |
| `docs/dev/POLICY.md`, `RULINGS.md`, `HISTORY.md` | moved up from `docs/dev/program/` (task 11) |
| `.foreman/` at the main checkout | bootstrapped nested repository holding phase A's artefacts, old plans and reports (task 11, under the kickoff's `AUTH:` line) |
| `.gitignore`, `.github/workflows/tests.yml`, `CLAUDE.md`, `docs/dev/README.md`, `README.md`, `.claude-plugin/plugin.json` | this repository on the new layout; version `0.2.0` (task 11) |
| `tests/test_plans.sh` | deleted (task 11) |
| `docs/dev/backlog.md` | absorbed items closed with what was done (tasks 2, 3, 4, 6, 9, 11, 12) |

## What stays where it is — the carve-out

This phase runs under the **pre-B installed plugin**, whose skill writes this phase's own ledger
to `docs/dev/program/phases/roots-and-layout/state.md` and whose `foreman-state` reads it there
through `git show`. So task 11 leaves five things untouched, and the program manager moves them
after the merge:

- `docs/dev/program/STATE.md` and `docs/dev/program/DEFERRED.md` — the PM edits these on `main`
  while this phase runs; a phase-side removal would guarantee a modify/delete conflict at gate 6.
- `docs/dev/program/phases/roots-and-layout/` — this phase's own kickoff and ledger.
- `docs/dev/plans/2026-09-03-roots-and-layout/` — this plan, read by `foreman-brief` all phase.
- `docs/dev/reports/2026-09-03-roots-and-layout.md` — this phase's own report, written at Step 6.

Everything else transient leaves `docs/dev/` in task 11. `docs/dev/program/` therefore still
exists at merge time, holding exactly those files, and disappears in the PM's post-merge step.

## Task order and why

Tasks 1–6 are additive and independent of each other; they build the headroom task 7 spends.
Task 7 rewrites `foreman-state` and its tests. Tasks 8 and 9 re-point the skills at the roots
tasks 1 and 7 provide, so they follow both; 8 before 9 because 9's kickoff contract depends on
what 8's dispatch writes. Task 10 mechanises §12.2 against the manifest task 5 produced. Task 11
is last: it moves `POLICY.md`, and `tests/run.sh`'s baseline gate must follow in the same
commit, and it is the one task that writes outside the worktree. Task 12 runs after everything
is in place and observes rather than changes.

| # | Task | Deps | Model | Effort | Reviewer | Reviewer model |
|---|------|------|-------|--------|----------|----------------|
| 1 | `foreman_roots` and `foreman-roots` | — | opus | high | task-reviewer | opus |
| 2 | `foreman-diff` `[JUDGE-1]` | — | opus | high | task-reviewer | opus |
| 3 | Runner isolates `GIT_DIR` and `GIT_CONFIG_COUNT` `[T2-R1-M4]` `[T2-R1-M1]` | — | sonnet | medium | task-reviewer | opus |
| 4 | `[DIST-2]` every slash command namespaced | — | sonnet | medium | task-reviewer | opus |
| 5 | Manifest and templates on the §4.1 layout | — | opus | high | task-reviewer | opus |
| 6 | `foreman-init` bootstraps the work root; `[BR-6]` | 5 | sonnet | medium | task-reviewer | opus |
| 7 | `foreman-state` on `--work-root`; `git show` retired | 1 | opus | high | task-reviewer | opus |
| 8 | Program side on roots: `program-status`, `foreman-program`, milestones | 1, 7 | sonnet | medium | task-reviewer | opus |
| 9 | Phase side on roots: `foreman-phase`, gate chain, `foreman-diff`; `[BR-11]` | 2, 7, 8 | sonnet | medium | task-reviewer | opus |
| 10 | Mechanical §12.2: the manifest renders a valid single-mode layout | 5 | sonnet | medium | task-reviewer | opus |
| 11 | This repository migrates; version `0.2.0` | 1–10 | opus | high | task-reviewer | opus |
| 12 | Live §12.2 and `[JUDGE-2]` against a scratch repository | 11 | opus | high | task-reviewer | opus |

Tasks 1, 2 and 7 change `scripts/` and `bin/`; task 5 changes `MANIFEST.tsv`; task 11 changes
`tests/run.sh` and writes outside the worktree. All are declared trust boundaries or the runner
that scores every other test, hence Opus on both sides. Every other task changes text a live
session executes as instructions, which `POLICY.md`'s model table gives an Opus reviewer.

Record the model actually used per task in the phase ledger.

## Notes for whoever executes this

- This repository has no application code. Tests are bash assertions over script behaviour and
  file content. TDD applies normally: write the assertion, watch it fail for the right reason,
  implement, watch it pass, mutation-check, commit.
- `tests/run.sh` sources each test file in a subshell and scores the run from per-assertion
  records. A test file must not `exit`; it must not use `set -e`.
- **Read diffs with `/usr/bin/git`** until task 2 lands, and with `foreman-diff` after it. A
  command-rewriting hook on `git` abridges diff output on the machine this plan was written on;
  that is `[JUDGE-1]`, and it is why task 2 exists.
- Until task 11 lands, `<abs-policy>` is `<worktree>/docs/dev/program/POLICY.md`. **From task
  11's commit onward it is `<worktree>/docs/dev/POLICY.md`**, for gate 1's baseline read and for
  every later `foreman-baseline` call. The kickoff says the same; this is the one mid-phase path
  change, and it is deliberate.
- Task 11 writes to `<main-checkout>/.foreman/`, outside the worktree, under the kickoff's
  `AUTH:` line and nowhere else. No other task writes outside the worktree.
- Gate 5 (context distillation) has at least three entries waiting: the worktree-vs-common-dir
  resolution in `foreman_roots` (task 1), the structural completeness check that replaced a
  marker search (task 2), and the modify/delete conflict the carve-out exists to avoid (task 11).
