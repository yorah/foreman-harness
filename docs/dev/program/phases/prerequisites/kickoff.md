# Prerequisites (phase A of the program layer merge)

## First — `foreman-phase` Step 0, then Step 1a, then Step 1b's `EnterWorktree`

**Step 0 is the dependency check, and it comes before everything below.** This kickoff was
written before phase A task 3 added that step, and said Step 1a came first; a resuming session
following the old wording would route straight past the `[DEP-1]` check that stops cleanly when a
required plugin is absent. Corrected on 2026-09-03 after the whole-branch review caught it
(`[BR-1]`) — the same "what a phase does first" class the phase fixed three times in shipped
files and missed here, in its own kickoff.

Then record `<main-checkout>` (the directory `/phase` was invoked from — `git rev-parse
--show-toplevel`, not a worktree) and `<default>` (the default branch, `main`) before doing
anything else in Step 1 — they are needed at gate 6 and are hard to reconstruct once inside a
worktree. Then:

`EnterWorktree(name: "prerequisites")` — branches from `origin/main`.

**Your branch is `feat/prerequisites`.** The program manager chose it and has already written
it into `STATE.md`, which is how a running phase's ledger is found. If the worktree tool creates
a branch under a different name, rename it to this one (`git -C <worktree> branch -m
feat/prerequisites`) rather than reporting a different name back — the name is an input here,
not an output.

## Context

Phase A of `docs/dev/specs/2026-09-02-program-layer-merge.md` §10. Four fixes that make the
suite green on any contributor's machine and the plugin installable from a fresh clone. Nothing
after this phase can be measured until it lands. The plan is four tasks; the first two are
test-environment isolation, the third a dependency check in the two session skills, the fourth
the distribution switch to a GitHub marketplace source.

**This phase touches two declared trust boundaries** (`scripts/lib.sh`'s settings chain in task
1, `MANIFEST.tsv` in task 4). You run at Opus, high effort; the plan's task table already
escalates the implementer and reviewer on those tasks.

**The plan directory is `<worktree>/docs/dev/plans/2026-09-02-prerequisites/`**, absolute. Use
that as `<abs-plan-dir>` wherever `foreman-phase` says `docs/dev/plans/<slug>/`; the plan is
dated, the phase slug is not.

## Read first

- `docs/dev/plans/2026-09-02-prerequisites/README.md` — constraints, the environment note, and
  the task table
- `docs/dev/program/POLICY.md` — gate commands, baseline, trust boundaries, invariants
- `docs/dev/specs/2026-09-02-program-layer-merge.md` §10 (the phase A row and the two
  paragraphs after the table) and §12.1 — the requirements this argues from

Read nothing else until a task requires it. **Do not read the plan's task bodies** — generate
briefs with `foreman-brief`.

## Rulings that must not be relitigated

- **Step 1c and task 1 run gate 1 with an environment prefix.** On this machine a plain
  `bash tests/run.sh` fails 88 assertions before task 1 lands (a redirected `HOME` breaks the
  mise shim that serves `jq`) and may fail 12 more when no signing agent is reachable. Neither
  is a property of the tree. Until task 2 has landed, run gate 1 as
  `env PATH="/usr/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null bash tests/run.sh`, record the count
  it prints as the baseline, and ledger this ruling. From task 2's Step 4 onward run it plain;
  the plain run going green is part of the evidence. Costs if wrong: a phase that stops at Step
  1c on a red tree it exists to fix.
- **`[DEP-1]` is a presence check that stops cleanly, not a fallback.** A fallback restates
  another plugin's procedure here, and two copies drift. Costs if wrong: a session that halts
  where it could have degraded.
- **`.claude/settings.local.json` stays in `gitignore-additions.txt`.** Claude Code writes
  per-contributor permission grants there. Only the rationale in the comment changes.
- **The marketplace source is `github`, repository `yorah/foreman-harness`.** Not a directory,
  not a path variable.
- **Task order is 1, 2, 3, 4 and is forced by the environment**, not by taste: 1 makes the
  gate command green here, 2 removes the last prefix. Do not reorder.
- **The phase does not install, remove or re-register a plugin, and does not touch this
  repository's `.claude/settings.local.json`.** Both are the program manager's, after the merge.
- **Gate 6 ends in a pull request, not a merge.** This phase touched trust boundaries and
  spec D5 lands work as branches and pull requests. After the rebase and the full gate-1
  re-run, push `feat/prerequisites` and open the PR with `gh pr create`, its body carrying the
  gate evidence (the run counts, the branch-review verdict, the judge verdict, the backlog and
  context commits). Then stop; the program manager merges after its probe. Opening that PR is
  authorised by `POLICY.md`'s integration rule as amended today.

## Method

`foreman-phase`. Subagent-driven execution against the plan, then the gate chain in
`references/gate-chain.md`.

## Report back

Write `docs/dev/program/phases/prerequisites/state.md` as you go and commit it — the program
manager reads it off your branch.

End with a summary under 150 words: status, commit range, gate results, the final test count,
the PR URL, open Minors, what remains uncovered. The human pastes it to the program manager, so
it must stand alone.

**Model** Opus (or Fable). **Effort** high.
