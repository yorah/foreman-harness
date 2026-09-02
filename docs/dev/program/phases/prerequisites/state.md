---
phase: prerequisites
plan: docs/dev/plans/2026-09-02-prerequisites/
branch: feat/prerequisites
baseline: 610 at cc489e9a0f0be85829ba288cf089ba28037fdcbb
tasks:
  - {n: 1, model: opus, effort: high, status: pending, commits: "", verdict: "", minors: []}
  - {n: 2, model: sonnet, effort: medium, status: pending, commits: "", verdict: "", minors: []}
  - {n: 3, model: sonnet, effort: medium, status: pending, commits: "", verdict: "", minors: []}
  - {n: 4, model: opus, effort: high, status: pending, commits: "", verdict: "", minors: []}
---

# Phase `prerequisites` — ledger

Phase A of `docs/dev/specs/2026-09-02-program-layer-merge.md` §10. Controller at Opus, high
effort, as the kickoff directs: the phase touches two declared trust boundaries
(`scripts/lib.sh`'s settings chain in task 1, `MANIFEST.tsv` in task 4).

## Setup, as observed

- `<main-checkout>`: `/home/yorah/projects/foreman-harness`. `<default>`: `main`, from
  `git symbolic-ref refs/remotes/origin/HEAD`.
- `<worktree>`: `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites`,
  branched from `origin/main` at `cc489e9`. `EnterWorktree` created it on
  `worktree-prerequisites`; renamed to `feat/prerequisites`, the name the kickoff supplies and
  `STATE.md` already carries.
- Baseline, Step 1c, run against the fresh worktree with the prefix the kickoff mandates:
  **610 passed, 0 failed**, exit 0, at `cc489e9`. This equals `POLICY.md`'s recorded
  `baseline-count: 610`.

## Rulings

Ruling: gate 1 runs as `env PATH="/usr/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null bash tests/run.sh`
until task 2 has landed, and plain from task 2's Step 4 onward — carried from the kickoff, where
it is marked not to be relitigated. Verified rather than assumed before adopting it: the plain
run on this machine reports **522 passed, 88 failed**, the prefixed run **610 passed, 0 failed**,
both at `cc489e9`. The 88 are `tests/test_resolve_gate.sh` redirecting `HOME`, which breaks the
mise shim that serves `jq`; they are a property of this machine, not of the tree, and they are
what tasks 1 and 2 exist to remove. — Costs if wrong: the phase stops at Step 1c on a tree it
was convened to fix, and nothing in the program can be measured behind it.

Ruling: the plain run's own count is recorded at each task's Step 4 from task 2 onward, and the
plain run reaching 0 failed is treated as the phase's evidence for spec §12.1 item 1 — not the
prefixed run's count. — Because §12.1 item 1 is a claim about an unprefixed suite on a hostile
machine; a prefixed green proves only that the prefix works. — Costs if wrong: the phase
reports a fix it has not demonstrated.

Rulings carried from the kickoff, recorded here so a later reader needs one file:

- `[DEP-1]` is a presence check that stops cleanly, not a fallback — two copies of another
  plugin's procedure drift.
- `.claude/settings.local.json` stays in `gitignore-additions.txt`; only the comment's
  rationale changes.
- The marketplace source is `github`, repository `yorah/foreman-harness` — not a directory and
  not a path variable.
- Task order is 1, 2, 3, 4, forced by the environment; no reordering.
- The phase does not install, remove or re-register a plugin, and does not touch this
  repository's `.claude/settings.local.json`.
- Gate 6 ends in a pull request, not a merge (spec D5, `POLICY.md`'s integration rule).

## Tasks

Filled in as each task closes.
