# Harness — design spec

**Status:** approved 2026-08-28. Written before implementation; the plan argues from this document.

A Claude Code plugin that installs a three-tier development harness into a repository:
a program-manager session that coordinates, phase sessions that execute, and task
subagents that write the code. It is distilled from how three projects — `couchseerr`,
`dockbrr` and `tradedashbrr` — were actually run, with the failures each of them
learned the hard way turned into mechanisms rather than prose.

---

## 1. Purpose

Three projects converged on the same shape without ever sharing a file:

- **`couchseerr`** — spec/plan discipline, per-plan scratch workspaces, and the single
  best context-saving invention of the three: *reviewers write findings to a file and
  return only verdicts.*
- **`dockbrr`** — numbered safety invariants checked on every change, model tiering per
  task, a tracked backlog that outlives gitignored scratch, and absolute paths in every
  dispatch.
- **`tradedashbrr`** — the program-manager tier the other two lack: an orchestrator that
  coordinates and does not write code, short-by-design state, standing rulings corrected
  in place, deferred checks, self-announced milestones, and verification by behavioural
  probe rather than code review.

Each rediscovered the others' lessons at its own cost. This plugin makes the union of
them installable, so the fourth project starts where the third finished.

**Goal:** a repository where non-trivial work runs as a pipeline — spec → plan → phase →
tasks → gates → merge — coordinated by a session whose context stays flat, executed by
sessions that start clean, at the cheapest model that can do each job, with regressions
caught by mechanism rather than by attention.

## 2. Non-goals

- Not a CI system. Gates run in sessions; CI, where it exists, is one more gate command.
- Not a replacement for `superpowers` or `fable`. It wires them; it does not reimplement
  them.
- Not a general project scaffolder. It installs a way of working into a repository that
  already exists, or is about to.
- Not automatic. A human starts every phase session. That is deliberate: it is the point
  at which a human sees the model, the effort and the task before tokens are spent.

## 3. Deliverable

A git repository at `/home/yorah/projects/harness`, which is simultaneously a Claude Code
plugin and its own single-plugin marketplace.

```
harness/
  .claude-plugin/
    marketplace.json           # marketplace "harness", one plugin, source "./"
    plugin.json                # plugin "harness"
  README.md
  CLAUDE.md                    # this repo's own project truth (dogfooding)
  AGENTS.md                    # 3-line pointer at CLAUDE.md
  docs/dev/                    # dogfoods the layout in §6
    specs/ plans/ reports/ reference/ program/
    README.md CONTEXT.md backlog.md
  skills/
    harness-init/              # the creator: gate → audit → interview → generate
      SKILL.md
      references/
        audit-checklist.md
        interview.md
        claude-md-rubric.md
        generation.md
      templates/               # everything written into a target repo
    harness-program/           # the program-manager role
      SKILL.md
      references/
        probes.md
        milestones.md
    harness-phase/             # the phase-controller role
      SKILL.md
      references/
        dispatch-contracts.md
        gate-chain.md
  agents/
    harness-implementer.md
    harness-task-reviewer.md
    harness-branch-reviewer.md
    harness-probe.md
  commands/
    harness-init.md            # /harness-init      run the creator on this repo
    program.md                 # /program           become the program manager
    phase.md                   # /phase <kickoff>   become a phase controller
    program-status.md          # /program-status    cheap read of index + phase states
```

Installed with:

```sh
/plugin marketplace add /home/yorah/projects/harness
/plugin install harness@harness
```

## 4. Architecture: logic in the plugin, policy in the repo

`tradedashbrr`'s `ORCHESTRATOR.md` is 291 lines of repo-local prose describing how the
orchestrator behaves. Across six projects that is six copies to maintain, and they will
diverge — the same repo already carries a `HANDOFF.md` pointing at `docs/sessions/`, a
directory that was renamed to `docs/orchestrator/` and never updated. A cold session
reads that file first.

So the split is:

| | Lives in | Why |
|---|---|---|
| **Logic** — how the PM behaves, dispatch contracts, gate chain, return formats | the plugin's skills and agent definitions | one fix propagates to every repo on `/plugin update`; nothing to drift |
| **Policy** — gate commands, trust boundaries, model table, push policy, doc home | `docs/dev/program/POLICY.md` in the repo | genuinely per-repo; must be readable by a human and reviewable in a PR |
| **State** — what is happening now | `docs/dev/program/` in the repo | per-repo by definition |
| **Record** — specs, plans, reports, context, backlog | `docs/dev/` in the repo | the design record belongs with the code |

A generated file that merely restates plugin logic is a drift source. The generator emits
policy and state; it does not emit copies of the role skills.

### 4.1 `POLICY.md` — the repo's answers

Written by `harness-init` from the audit and the interview. Read by all three tiers.
Machine-shaped enough to be quoted verbatim into a dispatch, prose enough to review.

```markdown
# Program policy

## Gate commands
Run in this order; all must be green before a phase may merge.
| # | Command | Runs | Expected |
|---|---------|------|----------|
| 1 | `mise run check` | go vet + go test + vitest | exit 0 |
| 2 | `cd web && npm run typecheck` | TS 7 compiler by explicit path | exit 0 |

## Baseline
`819 backend + 225 frontend` green at `<sha>`, recorded 2026-08-28.
A task report whose count drops below baseline is rejected before a reviewer is spawned.

## Trust boundaries
Touching any of these escalates the task's model and its reviewer's model:
- authentication, session handling, password or token storage
- secret material, encryption keys
- anything that mutates state outside the process (Docker, the filesystem, a remote)
- anything that serves bytes to a browser

## Invariants
Numbered. Injected verbatim into every implementer and reviewer dispatch.
1. ...

## Integration
- Base ref for phase branches: `origin/main` (`worktree.baseRef: fresh`)
- On phase completion: rebase, re-run gates, merge, push
- Escalate to a pull request when: the phase touched a trust boundary
- Force-push: never

## Model table
(§10, with any per-repo override and its reason)

## Ownership
Who else works in this repository, and which surfaces they own.
```

## 5. Three tiers

| Tier | Runs as | Reads at start | Writes | Never |
|---|---|---|---|---|
| **Program manager** | its own session, `/program` | `CLAUDE.md`, `program/STATE.md`, `POLICY.md` | STATE, RULINGS, DEFERRED, HISTORY, specs, plans, kickoffs | writes or edits code |
| **Phase controller** | a separate session, `/phase <kickoff>` | its kickoff, the plan `README.md`, `POLICY.md` | phase `state.md`, briefs, reports, code, commits | re-plans the program |
| **Task subagent** | Agent tool, inside the phase session | exactly one brief file | code, `task-N-report.md` | reads the plan, or the conversation |

### 5.1 The program manager

Adapted from `tradedashbrr`'s orchestrator charter, with the prohibitions the user
selected and only those.

**Binding:**

- **Never writes or edits code.** It edits program docs, specs, plans and kickoffs.
- **Announces its own milestones unprompted.** A milestone is any point where its
  accumulated context stops helping and starts costing — a phase finishing, a pivot to a
  different part of the system. The human cannot see the context filling; the PM can. At
  one it writes everything unrecorded into `STATE.md` / `RULINGS.md`, moves finished
  material to `HISTORY.md`, commits, and hands over a startup prompt for a fresh PM
  session.
- **Does not narrate.** Findings, rulings, the next command. Nothing else.
- **Does not re-explain the design in a kickoff.** It links the spec section and states
  only what the phase session cannot infer.

**Permitted, by explicit decision:**

- **May read source files, diffs and reports.** `tradedashbrr` forbade this to protect
  context; the trade is that a PM which cannot look must dispatch a session to answer
  every question. Permitted here, with the discipline that a behavioural probe is
  preferred where one exists, and a probe that disagrees with a report wins.
- **May spawn subagents for brainstorming and analysis** — never for implementation.
  Implementation goes to a phase session.

**Not adopted:** the sabotage protocol (§9.5).

### 5.2 The phase controller

A session started by the human in the repository root, which enters its own worktree and
then runs `superpowers:subagent-driven-development` against one plan. It is the SDD
controller of `couchseerr` and `dockbrr`, with the gate chain of §9 wrapped around it.

It rules rather than stalls: conflicts, ambiguities and plan defects are decided and
recorded as `Ruling: <decision> — <why> — <cost if wrong>`. It stops only for the four
superpowers stop-conditions — an irreversible or destructive operation, a
security-sensitive action, a side effect outside its worktree that norms say you ask
about first, or a plan so broken that every path forward is a guess.

### 5.3 Task subagents

Defined in the plugin under `agents/`, so their contracts live in their own system
prompts rather than in documentation a subagent may or may not read. This is the single
biggest change from the source repos, where "reviewers return only verdicts" and "always
use absolute paths" were prose conventions that were sometimes honoured.

## 6. Generated repository layout

```
CLAUDE.md                       tracked — project truth, numbered invariants, workflow pointer
AGENTS.md                       three lines pointing at CLAUDE.md
docs/dev/
  README.md                     who reads what; one audience per directory
  CONTEXT.md                    standing facts that outlive any one plan
  backlog.md                    deferred minors, tracked
  specs/YYYY-MM-DD-<topic>.md   what and why
  plans/<slug>/README.md        shared constraints + task summary table
  plans/<slug>/task-N.md        one task per file
  reports/YYYY-MM-DD-<phase>.md tracked audit trail — one file per *session*
  reference/                    measurements and calibration findings
  program/
    POLICY.md                   §4.1
    STATE.md                    index only — one line per phase
    RULINGS.md                  standing decisions, corrected in place, never deleted
    DEFERRED.md                 checks needing elapsed time or a live event
    HISTORY.md                  completed phases
    phases/<phase>/
      kickoff.md                written by the PM on main
      state.md                  written by the phase session on its branch
      task-N-brief.md           extracted from the plan, one per task
      task-N-report.md          the implementer's full report
      task-N-review.md          the reviewer's full findings
      task-N-rereview-R.md      scoped re-review of fix round R
      review-<a>..<b>.diff      generated diff package — gitignored, regenerable
.claude/settings.json           enabledPlugins, extraKnownMarketplaces, worktree.baseRef, gate permissions
```

**Everything is tracked.** `couchseerr` and `dockbrr` kept ledgers and reports in
gitignored `.superpowers/` scratch. That is invisible to a second person and dies with a
worktree — `dockbrr` needed an explicit backlog-flush rule precisely because of it.
`tradedashbrr` already tracked its reports. Tracked wins.

**A plan is a directory.** `tradedashbrr`'s measured token audit (2026-08-22) found a
session being handed a 1,442-line plan to execute 170 lines of it, and documents running
four times the size of the code. `README.md` carries the constraints every task shares
plus the task summary table; `task-N.md` carries one task. A session opens one file.

**One audience per directory, and never read a whole directory.** A session working on a
parser does not load the deployment topology.

### 6.1 Naming

`specs/` and `plans/` use `YYYY-MM-DD-<topic>`. The date is when the document was
written, not when the work finishes. One spec may spawn several plans.

### 6.2 `CLAUDE.md`

Evolved from what the repo has, not replaced wholesale, unless the audit finds nothing
worth keeping. It carries, in this order: what the project is; commands; architecture by
layer; **numbered invariants**; the worktree rule (§8.1); a pointer to `docs/dev/README.md`
and `docs/dev/program/`. Warnings carry their *why* — `dockbrr`'s note that `npx tsc`
reports a false "No errors found" is worth more than a bare instruction, because a reader
who knows the reason will not route around it.

### 6.3 `AGENTS.md`

Three lines pointing at `CLAUDE.md`. Nothing to synchronise means nothing to drift. If
the interview says a tool in use requires real content there, the generator instead makes
`AGENTS.md` a symlink to `CLAUDE.md` and records the choice in `POLICY.md`.

## 7. State model and concurrency

The constraint that shapes this section: **more than one person works in the repository
at once, and more than one phase may be live.**

### 7.1 Single writer per file

| File | Writer | Lives on |
|---|---|---|
| `program/STATE.md` | the PM | `main` |
| `program/RULINGS.md`, `DEFERRED.md`, `HISTORY.md` | the PM | `main` |
| `program/POLICY.md` | the PM (edited via `/harness-init` re-run) | `main` |
| `program/phases/<phase>/kickoff.md` | the PM | `main` |
| `program/phases/<phase>/state.md` | that phase's session | that phase's branch |
| `program/phases/<phase>/task-N-*.md` | that phase's controller and its subagents | that phase's branch |
| `docs/dev/reports/*` | the session that did the work | its branch |
| `docs/dev/backlog.md` | the phase flushing its deferred minors | its branch |

No file has two writers. `backlog.md` is appended to by different phases at different
times; entries are one line each and tagged with their source phase, so concurrent
appends collide as text-level conflicts git usually resolves, and never as semantic ones.

### 7.2 `STATE.md` is an index

Kept short deliberately: it is read at the start of every PM session. History goes to
`HISTORY.md`, rules to `RULINGS.md`. Its core is one line per phase, so two live phases
touch disjoint lines:

```markdown
| Phase | Owner | Branch | Status | Next action |
|---|---|---|---|---|
| detail-window-p3 | yorah | feat/detail-window-p3 | executing (task 4/7) | none — running |
| registry-cache   | ana   | feat/registry-cache   | gates green, awaiting rebase | PM: rebase + re-run gates |
```

Below the table: the current program-level next action, open rulings not yet promoted,
and any deferred check coming due. Everything else moves out.

### 7.3 Phase state lives on the phase branch

The phase session writes `phases/<phase>/state.md`, its task briefs and its reports
inside its worktree, committed to its branch. There are no cross-worktree writes and the
main checkout is never dirtied by a running phase.

The PM reads live progress without leaving its own directory:

```sh
git show <branch>:docs/dev/program/phases/<phase>/state.md
```

On merge, the phase's state and reports arrive on `main` with the code that produced
them — the audit trail lands attached to its own diff. Any teammate can read a running
phase's ledger with one `git show` and no coordination.

### 7.4 Phase state contents

Prose ledger, in the `dockbrr` shape, plus a machine-readable head so a resumed or
restarted controller can locate itself in about two kilobytes instead of a full re-read:

```markdown
---
phase: detail-window-p3
plan: docs/dev/plans/2026-08-28-detail-window-p3/
branch: feat/detail-window-p3
baseline: 518 at 5237bea
tasks:
  - {n: 1, model: sonnet, effort: medium, status: complete, commits: "a1b2c3..d4e5f6", verdict: approved, minors: [T1-M1]}
  - {n: 2, model: opus,   effort: high,   status: fix-round-2, commits: "d4e5f6..", verdict: needs-fixes, minors: []}
---
```

Then the prose: resolved design forks, per-task narrative, rulings, deviations, and
numbered minors `[TN-MK]`.

### 7.5 Rulings are corrected, never deleted

From `tradedashbrr`: when a ruling stops being true it is corrected in place with its
reasoning intact. That repo's own record contains an orchestrator's wrong accusation —
that three sessions had certified a red suite green — and its retraction, because the
red was a fixture time bomb that detonated at 21:00Z and every one of those sessions had
run before it. Keeping the retraction is what stops the wrong belief being rediscovered.

## 8. The phase lifecycle

### 8.1 Launch

The PM writes `phases/<phase>/kickoff.md` on `main`, commits and pushes it, then prints
exactly:

```
cd /home/yorah/projects/<repo>
claude --model sonnet
```

paste: `/phase docs/dev/program/phases/<phase>/kickoff.md`

**Model** sonnet — the plan is decided, nothing left to judge. **Effort** medium.

The model and the effort are always stated with a one-clause reason. An unstated model
inherits the human's default, which is usually the most expensive one.

The kickoff's first step is `EnterWorktree(name: "<phase-slug>")`, which creates
`.claude/worktrees/<phase-slug>` and branches from `origin/<default-branch>` under
`worktree.baseRef: fresh` — the correct base when other people are pushing, and one that
removes the "branched off a stale local main" failure entirely. Fallback where the tool
is unavailable: `git worktree add .claude/worktrees/<slug> -b <branch> origin/main`, then
`EnterWorktree(path: ...)`.

`EnterWorktree` may only be used when the user or project instructions direct it, so the
generated `CLAUDE.md` states the worktree rule explicitly. It earns its place there.

### 8.2 Kickoff file contents

Self-contained. The session starts at zero and can read the repo, but must not have to
hunt. From `tradedashbrr`'s prompt template, extended for the harness:

```markdown
# <Phase name>

## First
EnterWorktree(name: "<slug>")   # branches from origin/<default>

## Context
Two or three sentences: what this is and why it matters. Name the consequence of
getting it wrong.

## Read first
- `docs/dev/plans/<slug>/README.md` — constraints and the task table
- `docs/dev/program/POLICY.md` — gates, invariants, trust boundaries
- `docs/dev/specs/<spec>.md` §N — the requirements this argues from

## Rulings that must not be relitigated
- ...

## Method
superpowers:subagent-driven-development against the plan. Gate chain per POLICY.

## Report back
Write `docs/dev/program/phases/<slug>/state.md` as you go; commit it.
End with a summary under 150 words: status, commit range, gate results,
open minors, what remains uncovered. The human pastes this to the PM,
so it must stand alone.
```

Excludes everything unrelated. A session building a parser does not need the deployment
topology.

### 8.3 Cite the smallest file, or a symbol — never a line range

A line range in a file under active edit goes stale within a day. Cite the file, or a
symbol name to grep for.

### 8.4 Never wait on elapsed time

A check that needs an hour does not hold a session open — that costs a whole context to
watch a clock and blocks the human's next task. The session reports what it did, names
the query and the condition under which it becomes answerable, and ends. The PM records
it in `DEFERRED.md` and runs it later.

Related, from the same repo's scar tissue: **never state a wall-clock time you have not
read.** Write the condition, not the time — "after the US session has run" survives being
read an hour later; "it is past 21:00" does not.

### 8.5 Reporting back

The phase session's closing summary is pasted to the PM by the human. That summary is the
only per-phase context cost the PM pays. The full record is on disk, on the branch.

## 9. The gate chain

The answer to "no regressions" is a chain of mechanisms, each cheap, each placed before
the expensive thing it protects.

### 9.1 Baseline check — before a reviewer exists

`POLICY.md` records `<N> green at <sha>`. A task report whose test count is below
baseline is rejected by the controller **before** a reviewer subagent is spawned. Cheap,
mechanical, and it catches the weakened-test failure mode at its cheapest moment.

### 9.2 Task review

Per `superpowers:subagent-driven-development`: spec compliance plus code quality, fix
loop of at most five rounds, rounds 1–3 resume the implementer, rounds 4–5 use a fresh
implementer on a more capable model. Findings to a file; verdicts returned. §11.

### 9.3 Whole-branch review

Opus or Fable, at high effort, always. Reviews the full branch diff against the plan, the
spec and the numbered invariants.

### 9.4 Adversarial verification

`fable:fable-judge` then treats the phase's "done" as a set of claims: it re-runs the
claimed verifications, diffs what actually changed against what was said to change, and
detects weakened tests and false completion claims. Verdict: VERIFIED / VERIFIED WITH
CAVEATS / REFUTED.

This is the piece none of the three repos had. A whole-branch reviewer grades a diff; the
judge checks whether the verification actually happened. They fail differently, which is
why both run.

### 9.5 Not adopted: the sabotage protocol

`tradedashbrr` requires every session to break its own change, watch the new test fail,
restore, and report both outputs — plus confirm the sabotage edit actually landed, since
a regex that did not match looks exactly like a passing suite. Excluded by decision. It
is recorded here because it is the strongest single anti-regression device in the three
repos, and because `fable-judge` covers part of the same ground; if false-green tests
ever get through, this is the first thing to add back.

### 9.6 Exit gates

Two lessons that were learned by losing things become blocking checks:

- **Backlog flush.** A phase may not finish while its state names a deferred minor that
  is absent from `docs/dev/backlog.md`. `dockbrr` needed this rule because its ledger was
  gitignored scratch; here the state is tracked, but the point stands — a deferred item
  nobody wrote down is a forgotten one.
- **Context distillation.** Before a phase's workspace is closed, anything learned that
  outlives the plan is written into `docs/dev/CONTEXT.md`. Git history records what
  changed; `CONTEXT.md` records what was learned.

### 9.7 Integration

```
rebase onto origin/<default>  →  re-run the full gate chain on the rebased tree  →  merge  →  push
```

The re-run is the load-bearing step. A branch that was green before a rebase proves
nothing about the tree after it: a clean textual merge routinely hides a semantic
conflict, and with several people pushing, that is the common case rather than the
exotic one.

Escalate to a pull request instead of a direct merge when the phase touched a declared
trust boundary, or whenever `POLICY.md` says so.

### 9.8 Probes beat summaries

The PM's leverage is a behavioural probe: a short command whose output is a few lines.
If a probe disagrees with a report, the probe wins. A probe is evidence about the moment
it ran — which is why `tradedashbrr`'s orchestrator, probing four minutes after a fixture
time bomb detonated, briefly concluded three sessions had lied.

## 10. Model and effort tiering

| Work | Model | Effort | Reason |
|---|---|---|---|
| Program manager | Opus or Fable | high or above | judgement and rulings, low volume |
| Phase controller | Sonnet | medium | dispatch and adjudication against a decided plan |
| Phase controller, trust boundary | Opus | high | blast radius |
| Transcription — the plan carries the literal code | Haiku | low | copying and running tests |
| Implementation | Sonnet | medium | default |
| Implementation, trust boundary | Opus | high | blast radius |
| Task review | Sonnet | medium | default |
| Task review, trust boundary or large diff | Opus | high | the review is the only gate before the branch review |
| Whole-branch review | Opus or Fable | high | always |
| `fable-judge` | Opus or Fable | high | adversarial verification is the last gate |

The model and effort **actually used** are recorded per task in the phase state. After a
few phases the table stops being an assumption and becomes evidence; `POLICY.md` carries
any per-repo override with its reason.

## 11. Dispatch contracts

Held in the plugin's `agents/*.md`, so they are the subagent's own system prompt rather
than documentation it might skip.

### 11.1 What an implementer receives

The brief file path, the absolute worktree path, and the numbered invariants verbatim.
Not the plan. Not the conversation.

**Absolute paths always.** A subagent that does not `cd` resolves a relative path against
the main checkout and reads a stale file — this cost `dockbrr` most of a phase.

**Per-phase namespacing.** Briefs live under the phase's own directory. `dockbrr`'s
brief-extraction script wrote to a shared default path, earlier phases' briefs collided
with later ones, and subagents read the wrong task. Regenerate every brief from the
current plan before dispatching, and verify the brief's heading matches the task.

### 11.2 What an implementer returns

Status, commit SHAs, a one-line test summary, and concerns. The full report goes to
`program/phases/<phase>/task-N-report.md`.

**Two levels of report, deliberately.** Task-level artifacts — brief, report, review —
live in the phase directory, because their audience is that phase's controller. A
`docs/dev/reports/YYYY-MM-DD-<phase>.md` is written once per *session*, and its audience
is whoever comes next; it is the file that survives a lost conversation. Everything
except the regenerable `.diff` packages is tracked.

### 11.3 What a reviewer receives

A pre-generated diff file path, the brief path, and the invariants. The diff is written
to a file first (`git diff a..b > review-a..b.diff`); a reviewer never regenerates it
from conversation state.

### 11.4 What a reviewer returns

This is `couchseerr`'s invention and the single largest saving in the design. A
reviewer's prose stays resident in the controller's context for the rest of the session
and is re-read every turn — across a nine-task plan it is the main thing that grows
controller context. So the reviewer writes its complete analysis, with evidence and
`file:line`, to a file, and **returns only**:

- spec compliance verdict (✅ / ❌) and quality verdict (Approved / Not approved)
- one line per finding: severity plus a short label, no reasoning
- the report file path
- any ⚠️ "cannot verify from the diff" items, as bare labels

The controller reads the file only for findings entering a fix loop.

### 11.5 Never paste history into a dispatch

A fresh subagent needs its brief path, the interfaces it touches, the global constraints,
and nothing else.

## 12. `harness-init` — the creator

`/harness-init` runs in the target repository. Six steps, in order.

### 12.0 Refusal gate

Runs before anything else.

- **Model** from the session's own identity. Must be Fable or Opus.
- **Effort** from `.claude/settings.json`, then `.claude/settings.local.json`, then
  `~/.claude/settings.json`, most specific winning. Must be `high` or above.

If either fails, refuse, and offer as the first option **stop and switch**. Proceeding
anyway is possible only on the user's explicit say-so, and is recorded in `STATE.md` as a
ruling.

A runtime `/model` override is not visible to the session, so even on a pass the gate
states what it read and from where. This is checked, not merely asserted — but it is not
airtight, and the skill says so rather than implying otherwise.

The same gate guards `/program`. `/phase` does not carry it: a phase session is
deliberately allowed to run on Sonnet.

### 12.1 Audit

Parallel read-only agents, one concern each. This is the step that decides how much the
interview has to ask.

- **Stack and build system** — languages, package managers, task runner, version pins.
- **Gate commands** — what CI runs, what a `Makefile` / `mise.toml` / `package.json`
  exposes, and which of them actually pass right now.
- **Existing `.claude/` assets** — settings, permissions, agents, skills, commands,
  hooks, worktrees.
- **Layer layout** — the architectural boundaries the code already has, and anything that
  enforces them (an architecture test, a lint rule, a CI check).
- **Spec / plan / test conventions** — what documents exist, how they are named, what a
  test file looks like, the current green test count.
- **Invariants already implied** — assertions the code or CI already enforces are
  candidate numbered invariants and should not be invented afresh.
- **Git** — remote, default branch, protection rules, who has been committing.
- **Existing `CLAUDE.md`** — its content and its voice, so the rewrite evolves rather
  than flattens.

The audit reports what it found **and names what it could not settle**. Only the latter
reaches the interview.

### 12.2 Interview

`AskUserQuestion`, covering only what the audit left open. Candidate topics:

gate commands and their order · the baseline test count · trust boundaries · the numbered
invariants · spec lifecycle (who writes, who approves, when a spec is amended) · pipeline
scope (what is big enough to be a phase) · commit, merge and push policy · PR escalation
rule · `AGENTS.md` policy · doc home if the audit found conflicting conventions · deploy
policy, batched or per-change · model table overrides · who else works in the repo and
what they own.

Recommended options lead, marked as such. The audit's finding is offered as the default
wherever it has one.

### 12.3 Generate

Into a scratch tree, never in place. Emits §6 from `templates/`, `POLICY.md` from the
interview, and a `.claude/settings.json` carrying `enabledPlugins`,
`extraKnownMarketplaces`, `worktree.baseRef: fresh`, and permission entries for the gate
commands so they do not prompt.

Declared plugin dependencies: `harness@harness`, `superpowers@claude-plugins-official`,
`fable@fable-method`, `claude-md-management@claude-plugins-official`.

### 12.4 Quality pass

`claude-md-improver` (from `claude-md-management`) is run **report-only** — it stops
before its write phase. The creator then arbitrates each finding on one line, accept or
reject with a reason, and folds accepted ones into the generated `CLAUDE.md`.

The rubric matters more than the tool: if the plugin is not installed, the creator reads
`references/quality-criteria.md` from the marketplace cache and applies it directly.
Either way the arbitration is the creator's, not the improver's.

### 12.5 Full diff, then the gate

The complete diff between the repository and the scratch tree is shown. **Nothing lands
until the user says yes.** A partial acceptance is fine: the user may reject individual
files and the creator re-emits.

## 13. Skill wiring

| Skill | Used by | When |
|---|---|---|
| `superpowers:brainstorming` | PM | whenever anything gets specified — a new phase, a new section, a feature no spec covers, a spec section that turns out vague once building starts. Not for a defect fix whose behaviour is known, an agreed display change, or a deploy |
| `superpowers:writing-plans` | PM | once the spec is settled |
| `superpowers:subagent-driven-development` | phase controller | executing a plan |
| `superpowers:test-driven-development` | implementers | always |
| `superpowers:verification-before-completion` | implementers, phase controller | before any completion claim |
| `superpowers:finishing-a-development-branch` | phase controller | after the gate chain passes |
| `fable:fable-method` | PM | its operating loop: classify, define done, gather evidence, decide, act, verify, report outcome-first |
| `fable:fable-judge` | phase controller | §9.4 |
| `claude-md-management:claude-md-improver` | `harness-init` | §12.4, report-only |

`writing-plans` offers to dispatch subagents at the end. The PM does not take that
offer — work goes to phase sessions.

**Why `fable-method` for the PM specifically.** Its Step 0 classification (question /
task / plan-first) is exactly the PM's triage. Its Step 3 authorization gate is the right
mechanism for the push and merge policy: before an irreversible or outward-facing action
the PM writes `AUTH: user said "<their exact words>"`, and if the conversation supplies
no such quote the action becomes a proposed next step instead. Documentation is not
authorization — a workflow doc saying a push "must follow" a change makes it documented,
never authorized. `POLICY.md` grants standing authorization for the actions the user
named; anything outside it needs the quote.

## 14. Failure protocols

Both exercised in `dockbrr`, both worked.

- **A subagent dies mid-task** (a 529, a session limit). The controller verifies the
  tests, commits the completed work itself, and dispatches the reviewer against the
  committed diff. If the agent is resumable, resuming it by message retains its context.
- **A reviewer says needs-fixes and the implementer cannot converge.** Rounds 1–3 resume
  the implementer; rounds 4–5 use a fresh implementer on a more capable model; at round 5
  the controller adjudicates each open finding, parks the non-load-bearing ones in the
  phase state with rulings, and continues.
- **A task is reordered** because a dependency demands it. Fine; note it in the state.
- **A brief contradicts the codebase.** The implementer may deviate, but the report must
  call the deviation out and the reviewer must judge it.
- **The PM's context fills.** It announces the milestone itself, writes everything down,
  commits, and hands over a startup prompt. Restarting then costs one file read.

## 15. Verification — how we know the harness works

The harness is itself subject to §9, so its own claims need observable checks:

1. `/harness-init` runs end-to-end on this repository (`harness` dogfoods its own layout)
   and produces a diff a human accepts.
2. The refusal gate refuses: run `/program` with `effortLevel` set to `medium` in a
   scratch settings file and confirm it stops and offers to switch.
3. The baseline check rejects: hand the controller a task report with a test count below
   baseline and confirm no reviewer is spawned.
4. A reviewer subagent returns verdicts only — measured as the byte size of the returned
   message against the size of the file it wrote.
5. A full phase runs on a real repository, end to end, and merges. `couchseerr`'s next
   phase is the intended first subject.
6. `fable-judge` catches a planted weakened test on a branch that otherwise passes every
   other gate.

Checks 2, 3, 4 and 6 are mechanical and belong in the plan as tasks. Checks 1 and 5 are
observations a human makes.

## 16. Deferred

- **Retrofitting `couchseerr`, `dockbrr` and `tradedashbrr`** is one `/harness-init` run
  per repository, after the plugin exists. Not part of building it.
- **The sabotage protocol** (§9.5) — excluded by decision, recorded for reinstatement if
  false-green tests get through.
- **Token accounting per phase** beyond recording model and effort. Worth doing once
  there are enough phases to compare.
- **A `/program-status` that reads every live phase's branch state** is in scope; a
  dashboard is not.
