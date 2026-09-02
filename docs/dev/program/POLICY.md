# Program policy

The repository's answers. Read by the program manager, every phase controller, and every
reviewer.

**The program manager owns this file** and edits it directly — correcting a wrong
`baseline-count:` is its job, not a reason to re-run anything. **A phase session never edits it**:
a phase that believes this file is wrong says so in its summary and stops. Structural changes —
new gates, new trust boundaries — come from re-running `/foreman-init`.

This repository pins `effortLevel: "high"` in `.claude/settings.json` as the default every
session gets. That pin is not the last word: `.claude/settings.local.json` — untracked, one per
contributor's checkout — is read first and can set a lower value, overriding the tracked pin
for that contributor's sessions only. A harness repository running any session below high
effort is exactly what the refusal gate is meant to catch, so what the gate actually guarantees
is not a single repository-wide answer but that it never guesses: `resolve-gate.sh` always names
the exact file it read `effortLevel` from, as `effort_source` in its JSON output. When a verdict
looks wrong, check `effort_source`, not this pin — it names the file that decided it.

## Gate commands

Run in this order. All must be green before a phase may merge.

| # | Command | Expected | Notes |
|---|---|---|---|
| 1 | `bash tests/run.sh` | exit 0, `0 failed` | the only gate. Run from the repository root. |

## Baseline

baseline-count: 610

Green at `de22a66`, recorded 2026-08-31. A task report whose test count falls below
this is rejected before a reviewer is spawned. Raise it when a phase merges; never lower it
without a ruling that says why.

## Trust boundaries

Touching any of these escalates the task's model and its reviewer's model, per the model table.

- **`scripts/resolve-gate.sh` and `bin/foreman-gate`.** This is the refusal gate. A defect here
  does not fail loudly — it silently disables the check that guards every other check, and the
  result looks exactly like a pass.
- **`scripts/lib.sh`'s settings-precedence chain.** It decides which file's `effortLevel`
  answers, and therefore which verdict the gate reaches.
- **`skills/foreman-init/templates/MANIFEST.tsv`.** It decides what is written into someone
  else's repository and whether an existing file is preserved or overwritten.

## Invariants

Numbered, and injected verbatim into every implementer and reviewer dispatch. A reviewer
returns one verdict per invariant the diff could plausibly touch.

1. **Zero runtime dependencies beyond `bash`, `git` and `jq`** in any shipped script.
2. **Every executable script is `#!/usr/bin/env bash` with `set -euo pipefail`, and `chmod +x`.**
   Three kinds of file are exempt. Sourced libraries (`tests/lib_assert.sh`, `scripts/lib.sh`)
   carry **no `set` line at all**, because any strict-mode setting in a sourced file leaks into
   the shell that sourced it. Every `tests/test_*.sh` and `tests/run.sh` itself carry
   `set -uo pipefail`. `run.sh` sources each test file, so `-e` would abort at the first
   failing assertion and destroy the per-assertion counting the runner exists to do; `run.sh`
   is exempt for the same reason from the other side, since it must survive a test file that
   fails in order to score it.
3. **Exit codes are contract:** `0` success, `1` a definite negative verdict, `2` cannot
   determine. A caller must be able to tell "no" from "I don't know".
4. **All paths passed between tiers are absolute.** A subagent that does not `cd` resolves a
   relative path against the main checkout and reads a stale file.
5. **No `.md` under `skills/`, `agents/` or `commands/` contains `TODO`, `TBD` or `FIXME`.**
6. **Harness scripts are invoked by bare wrapper name** — `foreman-gate`, `foreman-brief`,
   `foreman-baseline`, `foreman-state`, `foreman-root` — and never by any path, relative or
   `$CLAUDE_PLUGIN_ROOT`-prefixed. The variable does not resolve in the Bash tool.
7. **`bash tests/run.sh` is green before every commit**, and no change leaves the suite below
   the recorded baseline.
8. **Body prose in shipped markdown wraps at 100 columns.** YAML frontmatter scalar values are
   exempt.

## Authorization

What a phase or the program manager may do without asking, every time, with no fresh approval.
Anything not granted here falls under the authorization gate and needs its own `AUTH:` line
before it happens — including the routine push of a phase kickoff to the default branch, which
the program manager performs on every dispatch.

A phase may, without asking: create and remove its own worktree; commit
and push its own phase branch; write anything under its own `docs/dev/program/phases/<slug>/`.

A phase may **not**, without an explicit `AUTH:` line: push to `main`; force-push anything;
delete a branch it does not own; install or remove a plugin; or write outside its worktree.

The program manager may push a kickoff to `main` as routine phase dispatch, under this grant.

## Scope and spec lifecycle

**What is big enough to be a phase rather than a single change.**

A phase is work that needs a plan with more than one task, or that touches a trust boundary.
Anything smaller is a single change on a branch and does not need the machinery — the harness is
overhead when the work is one commit.

**Who writes a spec, who approves it, and whether a phase may amend one mid-flight.**

The program manager writes and owns specs. A phase may **not** amend one mid-flight: a phase that
believes its spec is wrong says so in its summary and stops, and the program manager rules. Where
a plan and its spec disagree, the spec wins.

## Integration

- Phase branches base on `origin/main` (`worktree.baseRef: fresh`).
- On completion: rebase, **re-run gate 1 in full on the rebased tree**, merge, push.
- Escalate to a pull request instead of a direct merge: **always**, since 2026-09-02 (spec
  D5 of `docs/dev/specs/2026-09-02-program-layer-merge.md`, ruling in `RULINGS.md`). After the
  rebase and the full gate-1 re-run, a phase pushes its branch and opens the pull request with
  `gh pr create`, the gate evidence in its body, and stops. The program manager merges after its
  probe. Opening that pull request is granted here as part of routine phase integration; it is
  not a fresh outward-facing act needing its own `AUTH:` line. (Until this date the rule was
  "never, for now — single operator"; the harness now edits itself, so a second read of every
  diff is the point.)
- Force-push: never.

## Model table

Defaults are in the `foreman-phase` and `foreman-program` skills. Overrides for this
repository, each with its reason:

- **Any change under `scripts/` or `bin/`** escalates both the implementer and the reviewer to
  Opus: these are the trust boundaries above, and their defects are silent.
- **Any skill or template**, which a live session executes as instructions, takes an **Opus
  reviewer** regardless of who implemented it. Measured, not assumed: the one task on the v1
  branch scheduled with a Sonnet reviewer needed four fix rounds, and the defects were
  cross-file semantic contradictions invisible from inside the file being read.

## Ownership

Who else works here, and which surfaces they own. Two phases must not claim the same surface.

Single operator. No surface is claimed by anyone else, so no two phases can collide
yet. When that changes, list each contributor and the surfaces they own here first — two phases
must not claim the same surface.
