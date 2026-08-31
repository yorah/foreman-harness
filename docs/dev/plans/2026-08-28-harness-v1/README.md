# Harness v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `harness` Claude Code plugin — a three-tier development harness (program
manager → phase controller → task subagents) installable into any repository.

**Architecture:** Logic ships in the plugin (skills, agent definitions, shell scripts); policy
and state are generated into the target repository. Everything mechanizable is a tested shell
script rather than model prose — the gate resolution, brief extraction, baseline check and
phase-state read are all scripts with a test suite, so the parts that must not drift cannot.

**Tech Stack:** Markdown (skills, agents, commands, templates), POSIX-ish bash + `jq` for
scripts, plain-bash test harness with no external dependencies. Git 2.53, jq 1.8.1.

**Spec:** `docs/dev/specs/2026-08-28-harness-plugin-design.md` — read it first. The plan argues
from the spec; where they disagree the spec wins.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Zero runtime dependencies beyond `bash`, `git` and `jq`.** No bats, no shellcheck, no node,
  no python in any shipped script. Both are absent from the target environment.
- **Every *executable* script is `#!/usr/bin/env bash` with `set -euo pipefail`** and is
  `chmod +x`. **Sourced libraries are exempt from `set -euo pipefail`** and carry only the
  shebang: `set -e` in a sourced file leaks into the sourcing shell, and in `tests/run.sh`'s
  per-file subshell that would abort a test file at its first failing assertion — destroying
  the counting the runner exists to do. This exempts `tests/lib_assert.sh` and
  `scripts/lib.sh`.
- **Scripts print machine-readable output on stdout and diagnostics on stderr.** A script whose
  output is consumed by a skill emits JSON; a script consumed by a human emits lines.
- **Exit codes are contract:** `0` success, `1` a definite negative verdict (refuse / below
  baseline / mismatch), `2` cannot determine (missing file, unparseable input). A skill must be
  able to tell "no" from "I don't know".
- **All paths passed between tiers are absolute.** Scripts reject a relative path where an
  absolute one is required, with exit 2. This is spec §11.1: a subagent that does not `cd`
  resolves a relative path against the main checkout and reads a stale file.
- **No `.md` file in `skills/`, `agents/` or `commands/` may contain `TODO`, `TBD`, or
  `FIXME`.** Enforced by `tests/test_manifests.sh`.
- **Skill frontmatter** requires `name` and `description`. **Agent frontmatter** requires
  `name`, `description` and `tools`; `model` is optional. **Command frontmatter** requires
  `description`.
- **The plugin must be installable from a local path**: `/plugin marketplace add
  /home/yorah/projects/harness` then `/plugin install harness@harness`.
- **`tests/run.sh` must be green before every commit.** It is this repo's only gate command.
- **Line length in shipped markdown: wrap body prose at 100 columns.** Skills are read by
  models, but the files are reviewed by humans in a terminal. **YAML frontmatter scalar values
  are exempt** — a `description:` is one logical value that tooling parses, and folding it
  across lines risks loader-specific behaviour for no reader benefit.

## Baseline

`0` tests at `5ee020f` (the spec commit). Task 1 establishes the suite; from Task 2 onward the
baseline is whatever the previous task left green, and no task may reduce it.

## File structure

| File | Responsibility |
|---|---|
| `.claude-plugin/marketplace.json` | declares the marketplace `harness` with one plugin, source `./` |
| `.claude-plugin/plugin.json` | plugin manifest: name, description, version |
| `tests/run.sh` | test runner + assertion helpers; discovers `tests/test_*.sh` |
| `tests/lib_assert.sh` | `assert_eq`, `assert_exit`, `assert_contains`, `assert_not_contains`, `fail` |
| `tests/test_manifests.sh` | manifest schema, frontmatter, and no-placeholder checks |
| `scripts/lib.sh` | shared: repo root, settings-precedence chain, single-setting read |
| `scripts/resolve-gate.sh` | spec §12.0 — model + effort refusal gate |
| `scripts/task-brief.sh` | spec §11.1 — extract task N from a plan directory into a brief |
| `scripts/baseline-check.sh` | spec §9.1 — reported test count vs `POLICY.md` baseline |
| `scripts/phase-state.sh` | spec §7.3 — read a phase's state from its branch via `git show` |
| `agents/harness-implementer.md` | spec §11.1–11.2 — what an implementer receives and returns |
| `agents/harness-task-reviewer.md` | spec §11.3–11.4 — verdicts-only return contract |
| `agents/harness-branch-reviewer.md` | spec §9.3 — whole-branch review, Opus |
| `agents/harness-probe.md` | spec §9.8 — read-only behavioural probe, ≤10 lines out |
| `skills/harness-phase/SKILL.md` | spec §5.2, §8, §9 — the phase controller and gate chain |
| `skills/harness-program/SKILL.md` | spec §5.1, §7, §13 — the program manager |
| `skills/harness-init/SKILL.md` | spec §12 — audit, interview, generate, quality pass, diff |
| `skills/harness-init/templates/` | spec §6 — everything written into a target repo |
| `skills/harness-init/templates/MANIFEST.tsv` | template → destination path + required variables |
| `commands/*.md` | `/harness-init`, `/program`, `/phase`, `/program-status` |

## Task order and why

Scripts come before the skills that call them, so a skill is written against a tested
interface rather than an imagined one. Agent definitions (5) precede the phase skill (6) that
dispatches them. Templates (8) precede the creator (9) that emits them. Task 10 dogfoods the
whole thing on this repository, which is also spec §15's verification.

| # | Task | Deps | Model | Effort | Reviewer | Reviewer model |
|---|------|------|-------|--------|----------|----------------|
| 1 | Plugin skeleton, manifests, test harness | — | haiku | low | task-reviewer | sonnet |
| 2 | `lib.sh` + `resolve-gate.sh` | 1 | sonnet | medium | task-reviewer | sonnet |
| 3 | `task-brief.sh` | 1 | sonnet | medium | task-reviewer | sonnet |
| 4 | `baseline-check.sh` + `phase-state.sh` | 1 | sonnet | medium | task-reviewer | sonnet |
| 5 | Agent definitions | 1 | sonnet | medium | task-reviewer | sonnet |
| 6 | `harness-phase` skill + `/phase` | 3,4,5 | sonnet | medium | task-reviewer | opus |
| 7 | `harness-program` skill + `/program`, `/program-status` | 2,4 | sonnet | medium | task-reviewer | opus |
| 8 | Templates + `MANIFEST.tsv` + template tests | 1 | sonnet | medium | task-reviewer | sonnet |
| 9 | `harness-init` skill + `/harness-init` | 2,8 | opus | high | task-reviewer | opus |
| 10 | Dogfood + spec §15 verification tests | 6,7,9 | sonnet | medium | branch-reviewer | opus |

Record the model actually used per task in the phase state, per spec §10.

## Deliberate deviations from the spec's file list

Spec §3 sketches three reference files this plan does not create. Each was consolidated into
the file that actually needs it, and this is a decision, not an oversight — do not "fix" it:

- `skills/harness-phase/references/dispatch-contracts.md` → the contracts live in
  `agents/*.md` (Task 5), which is the whole point of §11: a contract in a subagent's own
  system prompt cannot be skipped, one in a reference file can.
- `skills/harness-program/references/probes.md` → probe discipline lives in
  `agents/harness-probe.md` and the `harness-program` skill body. It is six rules; a file of
  its own would only be another thing to drift.
- `skills/harness-init/references/generation.md` → generation is manifest-driven, so the
  manifest is the specification and Step 3 of the skill is the procedure.

## Notes for whoever executes this

- This repository has no application code. "Tests" here are bash assertions over script
  behaviour and file structure — they are real tests, and the TDD cycle applies normally:
  write the assertion, watch it fail for the right reason, implement, watch it pass.
- Task 10 deliberately runs the harness against its own repository. If that surfaces a defect
  in an earlier task, fix it in Task 10 and note the deviation — do not skip the dogfood.
- The spec's §9.5 (sabotage protocol) is **excluded by decision**. Do not add it.
