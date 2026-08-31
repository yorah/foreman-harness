# Audit checklist

One parallel read-only agent per concern. Each returns findings only — no recommendations, no
edits. The audit's most valuable output is the list of things it **could not settle**.

## 1. Stack and build system

Languages and versions, package manager, task runner (`Makefile`, `mise.toml`, `justfile`,
`package.json` scripts), version pins, and how dependencies are installed. Note anything the
project does that is unusual enough to trip a fresh session.

## 2. Gate commands

What CI runs (`.github/workflows/`, or equivalent). What the task runner exposes. **Which of
them actually pass right now** — run them. A gate command that is already red is a finding,
not a detail. Record the current green **test count**; it becomes the baseline.

## 3. Existing `.claude/` assets

`settings.json`, `settings.local.json`, permissions, agents, skills, commands, hooks, existing
worktrees. Note anything that would conflict with the harness, and any permission the gate
commands would otherwise prompt for.

## 4. Layer layout

The architectural boundaries the code already has, and — separately — **anything that enforces
them**: an architecture test, a lint rule, an import guard, a CI check. Enforced boundaries are
candidate invariants; unenforced ones are candidate conventions.

## 5. Spec, plan and test conventions

What documents exist and how they are named. Where tests live and what one looks like. Whether
the project already writes design docs, and in what voice.

If development docs already live somewhere other than `docs/dev/` — `doc/`, `documentation/`,
a wiki checked into the tree — report it as a **finding**, not as something to ask about.
`docs/dev/` is fixed: every such destination in the manifest is a literal, so there is no
answer the generator could act on. The finding's job is to make the collision visible in the
Step 5 summary.

## 6. Invariants already implied

Assertions the code or CI already makes about itself. Prefer these over anything invented:
an invariant with a test behind it is checkable, and one without is a wish. List each with
the file that enforces it.

## 7. Git

Remote, **default branch**, protection rules, whether the tree is clean, and who has been
committing recently — the last of these tells you whether this is a single-operator repository
or a shared one, which changes the integration policy.

## 8. Existing `CLAUDE.md` / `AGENTS.md`

Content, structure, and **voice**. The rewrite evolves this file; it must not flatten a
project's own way of saying things into template prose. Note any warning that carries a
*why* — those are the most valuable lines in the file and must survive.

## Reporting

Findings, then a separate list headed **"could not settle"**. Anything in the second list
becomes an interview question. Anything in the first does not.
