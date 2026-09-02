# Program layer merge: design spec

**Status:** approved in discussion 2026-09-02, written before implementation. The plans argue
from this document. Where this spec and the 2026-08-28 harness spec disagree, this one wins;
where it is silent, the older one stands.

## 1. Purpose

Two skills written by the same author describe the same program-manager role in different
words. `em-assistant` (a personal skill, outside git) runs programs across several repositories
and people: versioned cross-repo contracts, handoff prompts, tracker dispatch to coworkers, a
published status page. `foreman-program` runs a program inside one repository with tested
scripts, agent contracts in system prompts and a gate chain. Their PM tiers overlap on roughly
three quarters of their content: a kickoff is a handoff prompt, `STATE.md` is the MISSION
status table, a ruling is a decision-log entry, the launch block is the handoff card. Two
bodies of PM prose maintained separately will drift, which is the failure the 2026-08-28 spec
§4 names as foreman's reason to exist.

**Goal:** one program manager, `foreman-program`, that runs a personal single-repository
project with nothing extra loaded, and a multi-repository, multi-person program with external
integrations switched on per program. `em-assistant` retires once its programs can migrate.

Five decisions were taken in the discussion that produced this spec and are binding here:

| # | Decision |
|---|---|
| D1 | The PM writes a phase **brief**, not the plan. The phase writes its own plan through a disposable planner subagent, then passes a per-phase gate (`PLAN-GATE` or `AUTONOMOUS`) before executing. |
| D2 | State is split by **durability**, not by location. Only non-transient documents are committed to a product repository. Transient working state lives in a work root that is never part of product history. |
| D3 | Two interviews, at two levels: `foreman-init` for repository policy (audit first, ask only what the audit could not settle), and a program interview for program logistics (one shaping question, then one batch). |
| D4 | Integrations are **adapters** behind three named seams, enabled per program in its config, never loaded otherwise. Core vocabulary is generic; no vendor or organisation names in the skills. |
| D5 | The work lands as branches and pull requests on this repository. No fork. |

## 2. Non-goals

- Not organisation-specific. Nothing in `skills/`, `agents/`, `commands/` or `scripts/` names a
  company, a team or a vendor. Vendor-specific text lives only under
  `references/adapters/`.
- Not a change to the task tier. Implementer, task reviewer, branch reviewer, probe and the
  gate chain (2026-08-28 spec §9, §11) are untouched except where planning inside the phase
  requires a new step in front of them.
- Not parallel tasks within a phase. Parallelism stays at the phase level.
- Not a migration of `em-assistant`'s live programs. That is a follow-up once multi-repository
  mode exists (§10, phase F), not part of building it.
- Not a dashboard, not a CI system, not the sabotage protocol. Inherited exclusions stand.

## 3. Vocabulary

| Term | Meaning |
|---|---|
| **program** | one coordinated effort with one PM session, one `STATE.md`, one set of specs. |
| **phase** | one unit of dispatch: one kickoff, one session, one branch in one target repository. What `em-assistant` called a work package. |
| **brief** | the PM-written part of a kickoff: goal, acceptance criteria, scope fences, contract snapshot, interfaces, rulings, gate. |
| **plan** | the plan directory (`README.md` plus one `task-N.md` per task) the phase executes. Written by the planner, not the PM. |
| **target repository** | a repository a phase changes. A program has one (single mode) or several (multi mode). |
| **repo root** | a target repository's checkout. Holds that repository's durable per-repo files. |
| **program root** | where a program's durable per-program files live. |
| **work root** | where a program's transient working state lives. Never inside product history. |
| **adapter** | an implementation of the three integration seams (§7) for one external system. |
| **owner** | who executes a phase: `local` (the human running the PM) or `dispatched` (another person, reached through an adapter). |

## 4. State: the durability split (D2)

### 4.1 Classification

Every file the harness writes is one of three kinds. The classification is the contract; the
location follows from it.

| Kind | Files | Committed where |
|---|---|---|
| **Durable, per repository** | `POLICY.md`, `CONTEXT.md`, `backlog.md`, `reference/` | that repository, under `docs/dev/` |
| **Durable, per program** | `specs/`, `RULINGS.md`, `HISTORY.md`, `CONTRACTS.md` | the program root |
| **Transient** | `STATE.md`, `DEFERRED.md`, `phases/<slug>/` (kickoff, ledger, briefs, task reports, review findings, judge findings, `.diff` packages), `plans/<slug>/`, `reports/` (session reports) | the work root |

Rulings taken on the borderline items: `HISTORY.md` is durable because it is the distillate that
makes ledgers disposable. Plans are transient because they are superseded by the code they
produced and, as this repository's own backlog records under `[T-PLAN]`, mislead a later
reader. Kickoffs are transient; what a phase was asked to do survives as its `HISTORY.md`
entry. Session reports move from `docs/dev/reports/` to the work root for the same reason as
plans.

`docs/dev/program/` ceases to exist in a product repository. `POLICY.md` moves up to
`docs/dev/POLICY.md`; `RULINGS.md` and `HISTORY.md` move up to `docs/dev/` in single mode.

### 4.2 Two modes

`foreman-init` asks one question that fixes both roots:

| Mode | Program root | Work root |
|---|---|---|
| **single** (one target repository) | `<repo>/docs/dev/` | `<repo>/.foreman/`, ignored by the product repository, itself a nested local git repository |
| **multi** (several target repositories) | the state repository | the same state repository |

In single mode the work root is a git repository of its own so that working state is
versioned and recoverable without ever entering product history. `.foreman/` is added to the
product repository's `.gitignore`; the nested repository is initialised by `foreman-init` and
committed to by the PM and by every phase session. `.claude/worktrees/` stays where it is;
phase sessions reach the work root by the absolute path of the main checkout, which
`foreman-phase` Step 1a already records.

In multi mode the state repository is the PM session's working directory, exactly the shape
`em-assistant` used (a local bootstrap folder, or one shared orchestration repository holding
`programs/<slug>/`). Committing transient state there is fine: it is not a product repository.
Per-repo durable files still live in each target repository's `docs/dev/`.

### 4.3 The program config

A program is anchored by `foreman.json`: at the program root in multi mode, inside the work
root in single mode (it carries machine-specific paths and must never be committed to the
product repository). JSON, not YAML: invariant 1 allows `bash`, `git` and `jq` and nothing
else.

```json
{
  "program": "program-layer-merge",
  "mode": "single",
  "created": "2026-09-02",
  "work_root": "/abs/path/.foreman",
  "repos": [
    { "name": "foreman-harness", "path": "/abs/path", "default_branch": "main",
      "policy": "/abs/path/docs/dev/POLICY.md", "notes": "" }
  ],
  "defaults": { "executor_model": "sonnet", "executor_effort": "medium" },
  "adapters": { "tracker": null, "status": null }
}
```

`repos[].path` is machine-specific. In single mode the file lives inside the work root, which
is not shared, so that is acceptable. In multi mode the state repository may be shared, so the
PM resolves each repository's path through a per-machine override file, `foreman.local.json`,
ignored by the state repository, with the same `repos[]` shape and only `name` and `path`
filled. `foreman.json` carries `path: null` for any repository whose location differs per
machine.

### 4.4 Resolution

Only the PM and `foreman-init` ever resolve roots. A phase session never does: its kickoff
carries every path it needs as an absolute path, which is invariant 4 applied one level up.

`scripts/lib.sh` gains one function, `foreman_roots <start-dir>`, that prints
`program_root<TAB>work_root<TAB>config_path` and exits `2` when it cannot: it looks for
`foreman.json` at the start directory (multi mode), then at `<repo-root>/.foreman/foreman.json`
(single mode). Every skill and template that today hardcodes `docs/dev/program/` reads through
that function or through a path the kickoff supplied. The `program-status` command and
`foreman-state` take `--work-root`.

### 4.5 Reading a phase's ledger

The PM and every phase share one work root on one machine, so a ledger is a file. `foreman-state`
reads `<work_root>/phases/<slug>/state.md` directly. The `git show <branch>:<path>` read path,
its `STATE.md` branch lookup and the triage tables built around it are retired. `STATE.md`
keeps its `Branch` column because the PM still needs it to find the worktree to probe (§5 of
the 2026-08-28 spec, "Verifying a finished phase").

Two consequences are accepted with this ruling: a phase's ledger no longer travels with its
merge, and a running phase on another machine is not readable. The first is the point of the
durability split. The second is recovered in multi mode by pushing the state repository.

### 4.6 Single writer, one nested repository

The single-writer rule (2026-08-28 spec §7.1) stands. In single mode several sessions commit to
one nested repository: the PM to `STATE.md`, `DEFERRED.md` and kickoffs, each phase to its own
`phases/<slug>/`, `plans/<slug>/` and `reports/` files. Each session stages only its own paths
(`git -C <work_root> add <its paths>`) before committing. Two sessions committing at the same
instant can collide on the index lock; the loser retries once. That is the whole concurrency
story, and it is the same one `backlog.md` already lives with.

## 5. Planning inside the phase (D1)

### 5.1 The kickoff is a brief

The PM writes `phases/<slug>/kickoff.md` in the work root. It carries the sections below; the
kickoff lint (§8) rejects one that is missing any of them.

```markdown
# <Phase name>

## First
Record <main-checkout> and <default>; EnterWorktree(name: "<slug>"); branch feat/<slug>.

## Where
- Repository: <abs path>            (one per phase, always)
- Base: origin/<default>            (single mode) | <branch> @ <sha> (when the kickoff pins one)
- Work root: <abs path>             Program root: <abs path>     Policy: <abs path>

## Goal
Two or three sentences. Name the consequence of getting it wrong.

## Acceptance criteria
A checklist. Each item is something a reviewer can check.

## Scope fences
What this phase must not touch. Contract files are always fenced: consuming is not amending.

## Contract snapshot
Verbatim excerpts from CONTRACTS.md with their version, or "none". The snapshot stays
authoritative for this phase even if CONTRACTS.md moves on.

## Interfaces with sibling phases
What this phase produces that another consumes, and the reverse, or "none".

## Rulings that must not be relitigated

## Plan
to be written | <abs path of an existing plan directory>

## Gate
PLAN-GATE | AUTONOMOUS

## Report back
Ledger at <work_root>/phases/<slug>/state.md, committed as you go. Summary under 150 words.

**Controller model** <model>, **effort** <effort>. **Planner model** <model>, **effort** <effort>.
```

`Plan: <path>` is the escape hatch for a phase whose plan already exists, for instance a phase
resumed after a stop. The PM does not write plans; `foreman-program` loses that step and the
`writing-plans` reference goes with it.

### 5.2 The planner

A new agent, `agents/foreman-planner.md`. It receives the kickoff path, the absolute worktree
path, the policy path, the spec path the kickoff names, and the plan directory to write. It
investigates the repository, then writes the plan in the shape `foreman-brief` consumes:
`README.md` with the shared constraints, the baseline line and a task table carrying a model
and effort per task, plus one `task-N.md` per task whose first heading names its number. It
never modifies anything outside the plan directory. It returns only: the task count, one line
per task (number and title), and the plan directory's absolute path. The plan body never enters
the controller's context, which is what keeps the controller on Sonnet.

Default model Opus (or Fable) at high effort. The planner is the one place in a phase where the
whole design is held in one head; that is where the strongest model earns its cost, and its
context is discarded when it returns.

### 5.3 The controller's new first step

`foreman-phase` Step 2 becomes:

1. Read the kickoff. If `Plan:` names a directory, skip to the gate check.
2. Otherwise dispatch `foreman-planner`, then `git -C <work_root>` add and commit the plan
   directory. Set the ledger head's `plan:` line.
3. Read the plan's `README.md` task table only. Never a task body (unchanged rule).
4. **Gate.** `AUTONOMOUS`: continue to Step 3 as today. `PLAN-GATE`: print a summary under 150
   words naming the plan path and the task table, set the ledger `status` to
   `awaiting-plan-approval`, commit, and stop.
5. **Resume.** A phase re-launched with the same kickoff finds the plan present. It continues
   only if the kickoff carries a `## Plan approval` section written by the PM; otherwise it
   reports that approval is pending and stops again. If the section is `## Plan corrections`
   instead, the planner is re-dispatched with the corrections appended to its inputs and the
   cycle repeats.

The PM reviews a `PLAN-GATE` plan against the spec and the contract snapshot. It may read the
plan (it is program documentation, not code) or dispatch a read-only reviewer with a
verdict-only return. It records the decision as a ruling and appends the approval or the
corrections to the kickoff, which is a PM-owned file. The human says go; the PM writes it down.

### 5.4 Who gets which gate

`PLAN-GATE` for a phase that amends a contract, crosses a trust boundary, or whose acceptance
criteria the PM could not make checkable. `AUTONOMOUS` otherwise. The trust-boundary escalation
of models (2026-08-28 spec §10) is unchanged and independent of the gate.

## 6. Two interviews (D3)

### 6.1 Repository interview: `foreman-init`, as today

Audit first, ask only what the audit could not settle, recommended answer first, every answer
has a home on disk before it is asked. Two additions: the mode question (single or multi,
§4.2), and, in single mode, the bootstrap of `.foreman/` as a nested repository plus the
`.gitignore` entry. The generated layout follows §4.1: no `docs/dev/program/`, `POLICY.md` at
`docs/dev/POLICY.md`. `foreman-init` remains a per-repository step; in multi mode it runs once
per target repository and writes nothing program-level.

### 6.2 Program interview: `foreman-program`, when no program exists

When `/program` finds no `foreman.json`, it runs the program interview rather than refusing.
One shaping question first: single repository here, or several (and if several, where the
state repository is). Then one batch:

- title and slug;
- target repositories: paths only. Default branch, gate commands and existing policy are read
  from each repository, never asked; only the gotchas that cannot be read are asked (parked
  checkouts, deploy calendars, approval gates);
- hard constraints and timeline;
- default executor model and effort;
- adapters: which, if any. Adapter-specific fields (§7) are asked only for an adapter that was
  switched on, and only the ones the adapter's reference declares as required.

The audit-first rule from 6.1 applies here too. Then `foreman.json` is written, `STATE.md`,
`DEFERRED.md` and the durable per-program files are scaffolded at their roots, the first commit
is made, and the session proceeds to mission refinement: `superpowers:brainstorming` on the
program goal until the first spec holds goals, non-goals and checkable success criteria. No
phase is cut before that. This is `foreman-program`'s existing "refine, and grill" applied to
the whole program rather than to one phase.

## 7. Adapters (D4)

### 7.1 Three seams

Every external integration `em-assistant` had touches the program at exactly three points.
They are named in `foreman-program` and nowhere else in core:

| Seam | When | What it does |
|---|---|---|
| `item.create` | when a phase is cut | creates one tracker item for the phase and writes its id into the `STATE.md` row. For a `dispatched` phase the item body is the kickoff, made self-contained (§7.3). |
| `report.ingest` | at session start and on demand | finds reports posted through the adapter and **materialises each as a file** in `<work_root>/reports/` before the PM reads it. The PM never reconciles from a tracker comment. |
| `status.publish` | after a `STATE.md` change, after a contract bump, on a cadence, on demand | renders the status page from `STATE.md`, `HISTORY.md`, `RULINGS.md` and the specs. The page is a projection; if it drifts, the files win. |

A fourth, `item.comment`, is an adapter's own convenience for corrections to a dispatched phase
and for contract-bump notices; core calls it only through those two events.

### 7.2 Configuration and loading

```json
"adapters": {
  "tracker": { "kind": "atlassian-jira", "epic": "ABC-123", "project": "ABC" },
  "status":  { "kind": "atlassian-confluence", "space": "TEAM", "page_id": null,
               "cadence": "weekly" }
}
```

`null` means off. `foreman-program` reads `references/adapters/<kind>.md` only when the kind is
set, at the seam that needs it. A personal program with both adapters `null` never loads an
adapter reference and never sees the word "tracker".

The first adapter shipped is `references/adapters/atlassian.md`, covering both `atlassian-jira`
and `atlassian-confluence`, ported from `em-assistant`'s `jira-dispatch.md` and
`confluence-status.md` with the organisation vocabulary removed ("squad" becomes "team",
mandatory-field conventions become "whatever the project requires, ask once and record it in
`foreman.json`"). A second adapter is out of scope, but the seams are the guarantee that adding
one is a new reference file and nothing else.

### 7.3 Dispatched phases

`STATE.md` gains an `Owner` column value of `dispatched` next to the existing owner name. A
dispatched phase's kickoff must run from the tracker item alone: no work-root paths, no
program-root paths, the contract snapshot and the report template inlined, the repository given
as a clone URL and a base commit. The kickoff lint (§8) enforces that when `Owner` is
`dispatched`. The report comes back through `report.ingest` as a file, and reconciliation
proceeds exactly as for a local phase, which is why the lint and the materialisation rule
exist: the PM's loop never branches on where a phase ran.

### 7.4 Contracts and design phases

`CONTRACTS.md` is a durable per-program file (§4.1) with `em-assistant`'s amendment procedure:
bump the version with a dated history line, add a ruling, and flag every in-flight phase whose
kickoff embedded the old version (a correction in its kickoff for a local phase, `item.comment`
for a dispatched one). A kickoff embeds contract excerpts verbatim with their version, and that
snapshot stays authoritative for the phase.

A **design phase** changes no repository. Its deliverable is a proposal in its report (a
contract draft, an architecture option). The PM ratifies or rejects it at reconciliation and
only the PM writes `CONTRACTS.md`. The kickoff declares `Flavor: design`; the controller then
skips the worktree, the planner and the gate chain, dispatches one Opus analyst with the brief,
and writes the report. This is the mechanism that stops a PM drafting a contract for a
repository it has never read.

## 8. Mechanised checks

Two scripts, both in the exit-code contract of invariant 3:

- `foreman-kickoff-lint --kickoff <abs> [--contracts <abs>]`: every §5.1 section present; `Gate`
  is one of the two values; `Where` names an absolute repository path; a `dispatched` kickoff
  contains no work-root or program-root path; every contract excerpt's version exists in
  `CONTRACTS.md`, with a warning on stdout when it is not the current one. Exit `1` on any
  violation, `2` when the kickoff or contracts file cannot be read.
- `foreman-sweep --work-root <abs>`: lists phases whose ledger head reports a terminal status
  (`passed` on every task and gate chain complete, `blocked`, `deferred`, `unverified`, or
  `awaiting-plan-approval`) while their `STATE.md` row still says something earlier, plus every
  file in `reports/` newer than the `STATE.md` last-updated line. Exit `0` when nothing is
  pending, `1` when something is, `2` when the work root is unreadable. `foreman-program` runs it
  before anything else and `program-status` prints its output. The rule it enforces is
  `em-assistant`'s: never cut a phase while a report sits unprocessed.

The PM's read-only investigation subagents get the verdict-only return contract the reviewers
already have: full memo to `<work_root>/reports/investigation-<slug>.md`, a few lines back.

## 9. Model and effort

Additions to the 2026-08-28 spec §10 table. Everything else is unchanged.

| Work | Model | Effort | Reason |
|---|---|---|---|
| Planner | Opus or Fable | high | the one place a phase's whole design is held at once; context discarded on return |
| Plan review under `PLAN-GATE` | Opus or Fable | high | the last cheap moment to change a decision |
| Design-phase analyst | Opus or Fable | high | the deliverable is judgement |
| Program interview and mission refinement | the PM's own model | | it is the PM |

## 10. Phasing

One spec, several plans, in this order. Each is a phase of this repository's own program and
runs under the *current* harness, since the new one does not exist yet.

| Phase | Delivers | Why this position |
|---|---|---|
| A. prerequisites | test fixtures isolate the environment: git config (`GIT_CONFIG_GLOBAL` pinned by the runner, `commit.gpgsign=false`) so the suite is green under a mandatory-signing global config, and the user settings tier read through `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` (the directory Claude Code itself honours) so that no test redirects `HOME`, which breaks a `jq` served by a tool-manager shim; `[DEP-1]` a dependency check at each skill's entry that stops cleanly when a required skill is absent; `[DIST-1]` marketplace source switched to `github` and `settings.local.json` retired | everything after this is measured against a green suite and an installable plugin |
| B. roots and layout | `foreman_roots`, `foreman.json`, the §4.1 layout in templates and manifest, `.foreman/` bootstrap in `foreman-init`, `foreman-state` and `program-status` on `--work-root`, retirement of the `git show` path and its triage tables, `docs/dev/README.md` and `CLAUDE.md` updated | single mode is the smallest end-to-end change and every later phase writes into this layout |
| C. planning in the phase | `foreman-planner`, kickoff template as §5.1, `foreman-phase` Step 2 as §5.3, plan writing removed from `foreman-program`, `foreman-kickoff-lint` | changes the seam between the PM and the phase; needs B's paths |
| D. program layer | multi mode, `foreman.local.json`, the program interview and mission refinement, `CONTRACTS.md` and design phases, `foreman-sweep`, verdict-only investigation returns | everything `em-assistant` had that is not an integration |
| E. adapters | the three seams in `foreman-program`, `references/adapters/atlassian.md`, `dispatched` owner and its lint rule, `status.publish` triggers | last because it is optional and the seams need D's program layer to attach to |
| F. migration (deferred) | `em-assistant`'s live programs moved to multi mode; the skill folder retired | not part of this spec's plans; recorded so it is not forgotten |

Phases A and B both touch declared trust boundaries in `POLICY.md`: A changes the settings
chain in `scripts/lib.sh` and removes a `MANIFEST.tsv` row, B changes both files again. Both
run at Opus with an Opus reviewer.

Phase sessions run the **installed** plugin, not the checkout. After each phase merges, the
plugin is updated (`claude plugin update foreman@foreman`, or a reinstall) before the next
phase is launched, and the PM session is restarted so that it too runs the new skill. This
matters most after B, which moves this repository's own state files: a PM still running the
pre-B skill would look for `STATE.md` where it no longer is.

## 11. Rulings taken while writing

Every question that came up is ruled here so that no plan inherits an open one.

- **Config format is JSON.** YAML would need a parser outside `bash`, `git` and `jq`.
- **The `git show` ledger path is retired, not kept as a fallback.** Two read paths for one
  file is drift waiting to happen. Cross-machine visibility is multi mode's job.
- **Plan approval is recorded in the kickoff by the PM**, not in the ledger by the phase. The
  kickoff is the PM's file; the ledger is the phase's. A phase never writes its own approval.
- **`foreman-init` stays per repository; the program interview lives in `foreman-program`.**
  Repository policy and program logistics have different lifetimes and different owners.
- **Index-lock collisions in the nested repository are retried once**, then reported. No
  locking layer.
- **Session reports move to the work root.** A per-session audit trail is transient by the
  §4.1 test. What outlives the session goes to `CONTEXT.md`, as gate 5 already requires.
- **Design phases skip the gate chain.** There is no diff to gate. Their verification is the
  PM's ratification.

## 12. Verification

Observations, not intentions. Each is either mechanical (belongs in a plan as a task with a
test) or human (a check a person makes once).

1. **Mechanical.** `bash tests/run.sh` is green on a machine whose global git config sets
   `commit.gpgsign=true` with no signing agent available, and on a machine where `jq` on
   `PATH` is a tool-manager shim that resolves its binary through `$HOME`. Today the first
   fails 12 assertions and the second 88, all in the resolve-gate tests.
2. **Mechanical.** After a single-mode `foreman-init` on a scratch repository: `git status
   --short` shows no path under `docs/dev/program/`; `git check-ignore .foreman` succeeds;
   `git -C .foreman rev-parse --is-inside-work-tree` prints `true`; `git -C <scratch>
   rev-parse --is-inside-work-tree` from inside `.foreman/` resolves to the nested repository,
   not the product one.
3. **Mechanical.** `foreman-state --work-root <abs> --phase <slug> --head` returns the ledger
   head while the PM's checkout stays on its branch with a clean tree, and exits `2` with a
   named reason for a missing ledger, a malformed head, and an unreadable work root.
4. **Mechanical.** A kickoff with `Plan: to be written` produces a plan directory that
   `foreman-brief` accepts for every task the README names. The controller's transcript contains
   no `Read` of any `task-N.md`.
5. **Mechanical.** Under `PLAN-GATE` the ledger head reads `awaiting-plan-approval` and the
   phase exits; re-launching with the kickoff unchanged stops again; re-launching after a
   `## Plan approval` section is appended proceeds to Step 3.
6. **Mechanical.** `foreman-kickoff-lint` exits `1` on a kickoff missing `## Gate`, on `Base:
   the current branch`, and on a `dispatched` kickoff containing the work-root path; exits `0`
   on the template filled correctly; exits `2` on a missing file.
7. **Mechanical.** `foreman-sweep` exits `1` when a ledger says `passed` and the `STATE.md` row
   says `executing`, and `0` once the row is updated.
8. **Mechanical.** With both adapters `null`, a PM session's file reads include no path under
   `references/adapters/`. With `tracker` set, `item.create` is called exactly once per cut
   phase and the `STATE.md` row carries the returned id.
9. **Human.** A two-repository program in multi mode runs two phases, one per repository, from
   one state repository, and the PM reads both ledgers without leaving it.
10. **Human.** An `em-assistant` program's state folder, copied into a multi-mode state
    repository with a `foreman.json` written by hand, is picked up by `/program` with no other
    change. This is the readiness check for phase F.
11. **Carried over.** The reviewer return-size ratio (2026-08-28 spec §15.4) is measured during
    the first phase of this program and recorded in `CONTEXT.md`.
