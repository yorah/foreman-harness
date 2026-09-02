# Prerequisites (phase A) Implementation Plan

**Plan directory:** `docs/dev/plans/2026-09-02-prerequisites/` — this file plus one `task-N.md`
per task.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the suite green on any contributor's machine and the plugin installable from a
fresh clone, so that every later phase of the program-layer merge is measured against a green
suite and a distributable plugin.

**Architecture:** Four independent fixes, each closing one gap the 2026-09-02 spec §10 names for
phase A. Two are test-environment isolation (the user settings tier read through
`CLAUDE_CONFIG_DIR`; git configuration pinned by the runner), one is a dependency check at the
entry of the two session skills, one is the distribution switch from a local-directory
marketplace to a GitHub one. No new script, no new command. The task order is forced by the
environment: task 1 is what makes the gate command green on the machine running this phase, so
every later task's own gate run can be plain.

**Tech Stack:** bash, git, jq. Markdown skills and templates. The bash test suite under `tests/`.

**Spec:** `docs/dev/specs/2026-09-02-program-layer-merge.md` §10 (phase A row), §12.1, and
the backlog items `[DEP-1]`, `[DIST-1]`, `[T8-I15]` in `docs/dev/backlog.md`. Read the spec's
phase A row first. Where the plan and the spec disagree, the spec wins.

---

## Global Constraints

Every task's requirements implicitly include this section. They are `POLICY.md`'s invariants,
restated so a task's implementer needs no second file.

- **Zero runtime dependencies beyond `bash`, `git` and `jq`** in any shipped script.
- **Every executable script is `#!/usr/bin/env bash` with `set -euo pipefail`, and `chmod +x`.**
  Sourced libraries (`tests/lib_assert.sh`, `scripts/lib.sh`) carry no `set` line at all.
  Every `tests/test_*.sh` and `tests/run.sh` carry `set -uo pipefail` (no `-e`).
- **Exit codes are contract:** `0` success, `1` a definite negative verdict, `2` cannot
  determine.
- **All paths passed between tiers are absolute.**
- **No `.md` under `skills/`, `agents/` or `commands/` contains `TODO`, `TBD` or `FIXME`.**
- **Harness scripts are invoked by bare wrapper name** (`foreman-gate`, `foreman-brief`,
  `foreman-baseline`, `foreman-state`, `foreman-root`), never by any path.
- **`bash tests/run.sh` is green before every commit**, and no change leaves the suite below
  the recorded baseline.
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
  The one GitHub repository name this plan introduces is `yorah/foreman-harness`, in a template
  and in this repository's own settings, which is where the plugin's source belongs.

## Baseline

`610` green at `a1a4a95`. No task may leave the suite below it.

**Environment note for whoever runs this.** On the machine this phase was planned on, a plain
`bash tests/run.sh` fails 88 assertions before task 1 lands: `tests/test_resolve_gate.sh`
redirects `HOME`, and `jq` on `PATH` is a mise shim that needs `HOME` to find its binary. It may
also fail 12 assertions in `tests/test_phase_state.sh` when no SSH signing agent is reachable,
because the operator's global git config mandates signed commits. Neither is a property of the
tree. Until task 2 has landed, run gate 1 as

```bash
env PATH="/usr/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null bash tests/run.sh
```

and record the count it prints. From task 2's own Step 4 onward, run it plain: the plain run
going green is the evidence that tasks 1 and 2 did their job.

## File structure

| File | Responsibility |
|---|---|
| `scripts/lib.sh` | `foreman_settings_chain` gains the `CLAUDE_CONFIG_DIR` user tier (task 1) |
| `tests/test_resolve_gate.sh` | controls the user tier through `CLAUDE_CONFIG_DIR`, never `HOME` (task 1) |
| `tests/run.sh` | pins `GIT_CONFIG_GLOBAL` for every git command the suite runs (task 2) |
| `tests/test_bin.sh` | proves the runner's git isolation in both directions (task 2) |
| `skills/foreman-phase/SKILL.md` | Step 0 dependency check (task 3) |
| `skills/foreman-program/SKILL.md` | dependency check inside Step 0 (task 3) |
| `tests/test_phase_skill.sh`, `tests/test_program_skill.sh` | assert the checks and their position (task 3) |
| `skills/foreman-init/templates/settings.json.tmpl` | declares the `foreman` marketplace as a GitHub source (task 4) |
| `skills/foreman-init/templates/settings.local.json.tmpl` | deleted (task 4) |
| `skills/foreman-init/templates/MANIFEST.tsv` | loses the `settings.local.json` row (task 4) |
| `skills/foreman-init/templates/gitignore-additions.txt` | keeps the ignore line, loses the marketplace-path rationale (task 4) |
| `skills/foreman-init/templates/CLAUDE.md.tmpl` | Setup section rewritten for a clone-and-trust install (task 4) |
| `skills/foreman-init/SKILL.md` | Step 3 and Step 5 lose every mention of a machine-specific marketplace path (task 4) |
| `CLAUDE.md`, `.claude/settings.json` | this repository's own copies of the two above (task 4) |
| `tests/test_templates.sh`, `tests/test_init_skill.sh`, `tests/test_dogfood.sh` | flipped to the new distribution shape (task 4) |
| `docs/dev/backlog.md` | `[DEP-1]`, `[DIST-1]`, `[T8-I15]` closed with what was done (tasks 3, 4) |

## Task order and why

Task 1 first, because it is the only change that makes the gate command green on the planning
machine without an environment prefix; every later task's Step 4 depends on it. Task 2 next,
for the same reason one tier down. Tasks 3 and 4 are independent of each other and of the
first two; 4 is last because it touches a trust boundary and its reviewer needs the rest of the
tree stable.

| # | Task | Deps | Model | Effort | Reviewer | Reviewer model |
|---|------|------|-------|--------|----------|----------------|
| 1 | User settings tier through `CLAUDE_CONFIG_DIR` | — | opus | high | task-reviewer | opus |
| 2 | Runner pins git configuration | — | sonnet | medium | task-reviewer | opus |
| 3 | `[DEP-1]` dependency check at skill entry | — | sonnet | medium | task-reviewer | opus |
| 4 | `[DIST-1]` GitHub marketplace source, `settings.local.json` retired | — | opus | high | task-reviewer | opus |

Task 1 changes `scripts/lib.sh`'s settings-precedence chain and task 4 changes `MANIFEST.tsv`;
both are declared trust boundaries in `POLICY.md`, hence Opus on both sides. Task 2 changes the
runner that scores every other test, and task 3 changes text a live session executes as
instructions; `POLICY.md`'s model table gives both an Opus reviewer.

Record the model actually used per task in the phase ledger.

## Notes for whoever executes this

- This repository has no application code. Tests are bash assertions over script behaviour and
  file content. TDD applies normally: write the assertion, watch it fail for the right reason,
  implement, watch it pass, mutation-check, commit.
- `tests/run.sh` sources each test file in a subshell and scores the run from per-assertion
  records. A test file must not `exit`; it must not use `set -e`.
- Task 4 deletes a template. `git rm` it; do not leave an empty file. The manifest is the
  specification of what `foreman-init` writes, so the row goes with the file in the same commit.
- Task 4 does **not** touch `.claude/settings.local.json` in this repository or anywhere else,
  and does not install, remove or re-register a plugin. Those are the program manager's, after
  the merge, under `POLICY.md`'s authorization rule.
- Gate 5 (context distillation) has at least two entries waiting: the shim-under-redirected-HOME
  lesson from task 1, and the git-config isolation from task 2. Both outlive this plan.
