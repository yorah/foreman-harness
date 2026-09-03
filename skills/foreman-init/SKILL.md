---
name: foreman-init
description: Install the harness into a repository — audit its stack, docs and conventions, interview the user about what the audit cannot settle, generate CLAUDE.md, the docs/dev layout and the program state, run a CLAUDE.md quality pass, and show the complete diff before anything lands. Use when the user says /foreman-init or asks to set up the harness in a project.
---

# Install the harness into this repository

Six steps, in order. Nothing is written to the repository until Step 5 is approved.

## Step 0 — the gate

```bash
foreman-gate --model <your model id> --repo <abs repo root>
```

The harness's scripts are invoked by **bare name** — `foreman-gate`, `foreman-brief`,
`foreman-baseline`, `foreman-state` — and never by a path. Claude Code puts the plugin's `bin/`
directory on `PATH`, and those are thin wrappers that resolve the plugin root from their own
location. Do **not** write `$CLAUDE_PLUGIN_ROOT/scripts/...`: that variable is **not** exported
into the Bash tool's environment, so the call expands to `/scripts/...` and fails with "No such
file or directory". This was found by installing the plugin and running it, not by reading it —
the unqualified form also resolves in the repository where the harness was developed, so
nothing here could have caught it. For the two things that must be **read** rather than run,
`$(foreman-root)` prints the plugin's absolute root. A file this skill owns, such as `references/audit-checklist.md`, is
read relative to the skill and needs no prefix; that is a different thing.

`<your model id>` is the **exact model id** this session is running — not a family name and not
a guess. Source it from the session's own environment or from what the user states; if you
cannot establish it, that is an exit `2` situation, not a reason to pass something plausible.
The gate matches whole tokens, so a guess that happens to contain `opus` passes and certifies
nothing.

`<abs repo root>` is `git rev-parse --show-toplevel` — absolute, never typed from memory.

The gate passes only when the model is Opus or Fable **and** the effort is at or above `high`.

- exit `0` — state what it read (model, effort, and which settings file the effort came from),
  then continue.
- exit `1` — **refuse**. Offer, first: stop, switch model or effort, restart. Proceeding
  anyway requires the user's explicit say-so and is recorded in the generated `STATE.md` as a
  ruling with its cost.
- exit `2` — it could not reach a verdict, and the two causes report on **opposite streams**;
  do not infer which one it was from the exit code, and do not look for both in the same place.
  **Read the JSON on stdout**, not stderr: `reason` names the cause, and `effort_source` names
  the settings file it read `effortLevel` from — or is `null` when no settings file declared one
  at all. Quote both. That is the effort-unreadable case: ask the user for the effort directly,
  never guessing one, then judge their answer against the pass criterion above exactly as you
  would an exit `1` — if it fails, refuse; if it passes, continue, because the exit code told
  you the setting was unreadable, not that the gate refuses.
- exit `2` **with empty stdout** is the other case entirely: an argument error (a missing flag,
  an unknown argument, a non-absolute `--repo`), reported on stderr. That one is yours to fix
  and re-run; it is not a question for the user. Do not assert a refusal you did not verify.

Even on a pass, say what you read and from where. A runtime `/model` override is invisible to
this session, and implying otherwise would overstate the check.

## Step 1 — audit

Read `references/audit-checklist.md`. Dispatch its concerns as **parallel read-only agents**,
one per concern — they are independent and each is a fan-out over many files.

Then report, briefly: what the repository is, what it already has, and — the part that matters
— **what the audit could not settle**. Only that list reaches the interview.

If the repository already has a `docs/dev/`-shaped layout or an existing harness install, say
so: this becomes an evolve, not a create, and the manifest's `mode` column governs.

## Step 2 — interview

Read `references/interview.md`. Ask **only** what the audit left open, via `AskUserQuestion`.
Where the audit produced a defensible answer, offer it as the first option, marked
`(Recommended)`.

Never ask about something the audit could have answered. That is the whole point of running
the audit first.

## Step 3 — generate

Into a **scratch tree**, never in place. Use the scratch directory this session was given.

Read the manifest:

```bash
cat "$(foreman-root)/skills/foreman-init/templates/MANIFEST.tsv"
```

Four tab-separated columns — `template`, `destination`, `variables`, `mode` — with a header
row. `template` is relative to the directory the manifest sits in. Parse it with
`awk -F'\t'`, not with `read` under `IFS=$'\t'`: tab is IFS whitespace, so `read` collapses
runs of it and an empty middle field silently shifts every later field left.

**Not every row is an init-time row.** A row whose **destination** contains `{{` names a
document that is instantiated later, once its subject exists — the phase kickoff, a plan
directory, a task file, a spec. `PHASE_SLUG`, `PLAN_SLUG`, `TASK_NUMBER` and `TOPIC` are not
knowable at init, and emitting a directory literally named `{{PHASE_SLUG}}` is the failure this
rule exists to prevent. The carve-out is by **destination**, not by mode: those rows are
ordinary `create` rows and nothing in the `mode` column distinguishes them. Skip them here, and
say in the Step 5 summary that they are not init-time rows: they stay under
`$(foreman-root)/skills/foreman-init/templates/` — as `program/kickoff.md.tmpl`,
`plans/plan-README.md.tmpl`, `plans/task-N.md.tmpl` and `specs/spec.md.tmpl` — and a kickoff, a
plan, a task file and a spec get written when the program manager and the phase controller
reach them. Do not tell the user that `/program` or `/phase` instantiates these
template files — neither skill reads the templates directory today, so promising it would
describe wiring that does not exist.

For each remaining row:

- `mode: create` — emit only if the destination does not already exist in the repository. If
  it does, leave it and note it in the summary.
- `mode: evolve` — merge with what exists. For `CLAUDE.md` this means keeping the project's
  own content and voice and folding in the missing sections, not replacing the file. For
  `.gitignore` and `.claude/settings.json` it means adding what is absent and touching nothing
  else.

`AGENTS.md` is the one `create` row whose *content* the interview can change, so honour the
answer instead of emitting the template unconditionally:

- **pointer** (the default) — emit `AGENTS.md.tmpl` as it stands.
- **symlink** — `ln -s CLAUDE.md AGENTS.md`; no template file is emitted at all.
- **separate content** — write what the user described, not the pointer.

If the answer was not the default, name it in the Step 5 summary. A diff that shows the
three-line pointer to a user who asked for a symlink is the failure this branch exists to
prevent.

**`docs/dev/` is fixed, and is not an interview question.** Every `docs/dev/…` destination in
the manifest is a literal and the templates name that path in their own prose, so there is no
variable that could point the layout elsewhere. If the audit found a conflicting existing doc
convention, say so in the Step 5 summary and leave the existing tree where it is — but do not
ask the user to choose a home that generation cannot honour.

Substitute every `{{VARIABLE}}` from the audit and the interview. The `foreman` marketplace
is a GitHub source declared in `settings.json.tmpl`, so no template needs a machine-specific
path and nothing is looked up outside the repository being initialised.

**A `{{` surviving into the scratch tree is a defect** — and it can survive in a *path* as well
as in a file's contents, which is the harder half to see. Check both before continuing:

```bash
[ -d <scratch-tree> ] || { echo "NO SCRATCH TREE — nothing was checked"; exit 1; }
grep -rn '{{' <scratch-tree> && echo "UNSUBSTITUTED CONTENT" || echo "content clean"
find <scratch-tree> -name '*{{*' -print | grep . && echo "UNSUBSTITUTED PATH" || echo "paths clean"
```

The `[ -d ]` line is not decoration. `grep` and `find` both fail into the `||` branch on a path
that does not exist, so a mistyped or unwritten scratch path prints a confident `content clean`
/ `paths clean` without having looked at anything. Verified both ways: a dirty tree reports
`UNSUBSTITUTED CONTENT` and `UNSUBSTITUTED PATH`, and a *nonexistent* tree reported the same
double all-clear as a genuinely clean one until this guard was added.

Every `{{` in every template is a real variable — none is documentation of one — so a clean
scratch tree has zero hits on both checks. There is no legitimate exception to wave through.

Several answers are **paragraphs, not phrases** — `PHASE_SCOPE`, `SPEC_LIFECYCLE`,
`TRUST_BOUNDARIES`, `INVARIANTS`, `STANDING_AUTHORIZATION`. Where a template puts one on its own
line after a heading, leave it there; never splice a multi-sentence answer onto the end of a
bullet. Doing that produced a 147-column first line with every continuation at column 0 the
first time this ran. **Templates carry no comments to strip**, and none may be added: what is in
a template body is what lands in someone's repository.

`INVARIANTS` deserves care: prefer invariants the audit found **already enforced** by a test,
a lint rule or a CI check over anything invented in the interview. An invariant nothing
enforces is a wish.

## Step 4 — CLAUDE.md quality pass, report-only

Run `claude-md-improver` against the generated `CLAUDE.md`, stopping **before** its write
phase — it is report-only here. If the `claude-md-management` plugin is not installed, read
its rubric from the marketplace cache instead:

```
~/.claude/plugins/marketplaces/claude-plugins-official/plugins/claude-md-management/skills/claude-md-improver/references/quality-criteria.md
```

and apply it yourself. `references/claude-md-rubric.md` records what to weigh either way.

**You arbitrate.** Take each finding in turn and accept or reject it in **one line with a
reason**. Fold accepted findings into the generated file. Print the arbitration list.

Reject, by default, any finding that would strip a warning of its *why*: a reader who knows
the reason will not route around the rule, and a reader who does not, will.

## Step 5 — the diff, then the approval gate

Show the **full diff** between the repository and the scratch tree — every file, no elision.
Summarise in one line per file what it does and why. Name here the manifest rows Step 3 skipped
and why.

**Nothing lands until the user says yes.** They may accept some files and reject others; if
so, re-emit and show the diff again.

On approval: copy the scratch tree over the repository, then `git add` **the tracked files
only**: stage with `git add -A` (which honours `.gitignore`) or by naming paths; never
`git add -f`. Commit with a message naming the harness version — the `version` field of
`$(foreman-root)/.claude-plugin/plugin.json`, which is on the plugin side, not in the
repository being initialised.

Confirm before claiming success: `git status --short` shows every generated file staged and
nothing ignored by `.gitignore` in the index. Then print the first launch block: `/program`.
