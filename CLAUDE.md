# foreman-harness

A Claude Code plugin that installs a three-tier development harness into a
repository: a program manager that coordinates, phase sessions that execute one plan each in
their own worktree, and task subagents that write the code.

## Setup

Workflow commands (`/foreman-init`, `/program`, `/phase`, `/program-status`) come from the
`foreman` plugin. `.claude/settings.json` enables it but does not say where to find it on
disk — that lives in `.claude/settings.local.json`, gitignored because the path differs per
contributor's checkout. Cloning this repository does not create that file for you; generate
your own, once, with `claude plugin marketplace add <path-to-your-checkout-of-the-foreman-plugin-repo> --scope local`.

`<path-to-your-checkout-of-the-foreman-plugin-repo>` is a checkout of the `foreman` plugin
repository — a separate project from this one (the source of its `.claude-plugin/marketplace.json`),
distributed as a local directory rather than a registry package. If you already have it
registered on this machine for another project, its path is recorded in
`~/.claude/plugins/known_marketplaces.json` under the `foreman` entry's `source.path`.
Otherwise, get your own checkout from whoever maintains it for this project and use that path.
What this must **not** be is a path under `~/.claude/plugins/cache/`: that is wherever a given
installation was resolved from, version-pinned, and not something a second contributor can
pull from.

If you skip the step above, `claude plugin marketplace list` shows no `foreman` entry — that
absence is the tell. `claude plugin list` is **not** the tell: it prints `No plugins installed`
before this step and after it alike, because it reports what has been installed, not what
marketplaces are known. Registering the marketplace only makes the plugin resolvable;
`claude plugin install foreman@foreman` is the step that actually installs it, and only then
does `claude plugin list` show `foreman@foreman` as enabled, even though `.claude/settings.json`
already said so.

## Commands

```bash
bash tests/run.sh     # the only gate command. Needs bash, git and jq, and nothing else.
```

There is no build, no linter and no package manager. `tests/run.sh` discovers `tests/test_*.sh`,
sources each in its own subshell, and scores the run itself from per-assertion records — a test
never reports its own count.

## Architecture

Described by responsibility. A file tree tells you where things are; this tells you where a
change belongs.

- `scripts/` — everything mechanizable, as tested bash rather than model prose: the refusal
  gate, brief extraction, the baseline check, the phase-state read. If a rule must not drift,
  it belongs here, not in a skill.
- `bin/` — thin wrappers that let a skill invoke those scripts **by bare name**. Claude Code
  puts this directory on `PATH`; `$CLAUDE_PLUGIN_ROOT` is not exported into the Bash tool, so a
  path-form call site fails in every install while appearing to work in this one.
- `skills/` — the three tiers as prose a session executes: `foreman-program`, `foreman-phase`,
  `foreman-init`. Read as instructions, so reviewed as code.
- `agents/` — the dispatch contracts, in each subagent's own system prompt. A contract in a
  system prompt cannot be skipped; one in a reference file can.
- `skills/foreman-init/templates/` — everything written into a target repository, driven by
  `MANIFEST.tsv`. The manifest is the specification.
- `tests/` — bash assertions over script behaviour and file content. They are real tests and
  TDD applies normally.

## Invariants

Check every change and every review against these. They are also in
`docs/dev/program/POLICY.md`, which is the copy dispatches quote.

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

## How work is organised

Non-trivial work runs as a **program**: one program-manager session coordinates and does not
write code; each phase goes to a **separate session** the human starts, which enters its own
worktree and executes one plan through subagents.

**This repository works in git worktrees.** A phase session creates its own under
`.claude/worktrees/<phase>`, branched from `origin/main`.

- Program manager: `/program`. Phase: `/phase <kickoff>`. Status: `/program-status`.
- Structural changes to this setup — new gates, new trust boundaries — run `/foreman-init`
  again; it is not a phase task.
- Documentation layout and who reads what: `docs/dev/README.md`.
- Current state: `docs/dev/program/STATE.md`.

## Rules every session follows

- **Document what you did, on disk.** Chat scrollback is not storage.
- **Test-first.** Write the failing test, confirm it fails for the reason you expect, then
  implement. A test that would pass against the bug you are fixing is not a test of your fix.
- **Verify against reality, not against the tests**, where the two can differ.
- **Never wait on elapsed time.** Report what you did, name the check and its condition, end.
- **Report faithfully.** If a step was skipped, say so.
