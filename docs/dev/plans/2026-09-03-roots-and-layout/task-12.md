# Task 12: Live §12.2 and `[JUDGE-2]` — a real single-mode install into a scratch repository

**Plan:** `docs/dev/plans/2026-09-03-roots-and-layout/README.md` — shared constraints and the task
table.

**Files:**
- Modify: `docs/dev/backlog.md` — close `[JUDGE-2]` with what was observed
- Modify: `docs/dev/CONTEXT.md` — one entry, only if something was learned that outlives this plan
- No other shipped file changes. If following the skill exposes a defect in it, **stop and
  report it as a finding** — do not fix `foreman-init` here.

**Interfaces:**
- Consumes: `skills/foreman-init/SKILL.md` Steps 3 and 5 as task 6 left them; the manifest and
  templates from task 5; the wrappers under `<worktree>/bin/`.
- Produces: an observation record. Every command below and its exact output goes in your report.

**Why this exists.** Task 10 proves the manifest *can* render a valid layout. Nothing proves the
skill's prose *does* — `[JUDGE-2]`: nothing consumes the manifest mechanically, so the `evolve`
guarantee for a contributor's `.claude/settings.json` rests on prose alone and has never been
exercised. Phase A was forbidden to run an install. This task runs one, by hand, following the
worktree's skill text literally, into a scratch repository that already has a settings file with
keys the template does not know about. The scratch repository is the same one §12.2 is measured
on, so both are settled in one run.

The installed plugin is still the pre-B one, so `/foreman:foreman-init` cannot run the new skill.
You follow `<worktree>/skills/foreman-init/SKILL.md` yourself, with `PATH="<worktree>/bin:$PATH"`
so `foreman-root` and the other wrappers name the worktree's tree.

---

- [ ] **Step 1: Prepare the scratch repository with a pre-existing settings file**

```bash
scratch="$(mktemp -d)/target"
mkdir -p "$scratch/.claude"
git -C "$scratch" init -q
printf '# Target\n\nA scratch product repository.\n' > "$scratch/README.md"
cat > "$scratch/.claude/settings.json" <<'JSON'
{
  "effortLevel": "medium",
  "permissions": { "allow": ["Bash(ls)"] },
  "enabledPlugins": { "some-other@marketplace": true },
  "custom": { "keep": true }
}
JSON
git -C "$scratch" add -A
git -C "$scratch" commit -qm "pre-existing"
git -C "$scratch" rev-parse HEAD
```

Record the HEAD. Every key in that settings file must survive.

- [ ] **Step 2: Follow the skill's Step 3 — generate into a scratch tree**

Read `<worktree>/skills/foreman-init/SKILL.md` Step 3 in full, then do what it says, with these
fixed interview answers: `PROJECT_NAME=target`, `PROGRAM_NAME=target`, `DEFAULT_BRANCH=main`,
`AGENTS.md` policy pointer, every paragraph variable a one-line placeholder sentence,
`GATE_PERMISSIONS` = `"Bash(bash tests/run.sh)"`, `BASELINE_COUNT=1`, `BASELINE_SHA=` the HEAD
you recorded, `TODAY=2026-09-03`, `WORK_ROOT=$scratch/.foreman`, `REPO_NAME=target`,
`REPO_PATH=$scratch`. Read the manifest through
`cat "$(foreman-root)/skills/foreman-init/templates/MANIFEST.tsv"` with the worktree's `bin/`
first on `PATH`, and confirm `foreman-root` printed the worktree.

For the `evolve` rows apply the skill's stated semantics. For `.claude/settings.json` the skill
says key-level merge with three maps merged entry by entry; do it with `jq`, existing file wins
on scalar conflicts:

```bash
jq -s '
  .[0] as $tmpl | .[1] as $have |
  ($tmpl * $have)
  | .enabledPlugins = (($tmpl.enabledPlugins // {}) + ($have.enabledPlugins // {}))
  | .extraKnownMarketplaces = (($tmpl.extraKnownMarketplaces // {}) + ($have.extraKnownMarketplaces // {}))
  | .permissions.allow = ((($tmpl.permissions.allow // []) + ($have.permissions.allow // [])) | unique)
' <rendered-template> "$scratch/.claude/settings.json" > <scratch-tree>/.claude/settings.json
```

If the skill's prose does not tell you enough to write that command — if you had to *decide*
something the text left open — that is a finding: record exactly what was underspecified.

Run the skill's leak checks (`[ -d <scratch-tree> ] || …`, the `grep -rn '{{'`, the
`find -name '*{{*'`) and record their three lines of output.

- [ ] **Step 3: Follow the skill's Step 5 — the approval branch**

Treat approval as given. Do exactly what the Step 5 text says, in its order: copy the scratch
tree over `$scratch`; `check-ignore`; the work-root `init`/`add`/`commit`; the warning line; the
product `git add -A` and commit naming the plugin version from
`$(foreman-root)/.claude-plugin/plugin.json` (`0.2.0`); the closing `git status --short` and
`git -C … log --oneline` confirmations.

- [ ] **Step 4: Observe — spec §12.2 and `[JUDGE-2]`**

```bash
git -C "$scratch" status --short | grep -c 'docs/dev/program' || echo 0   # 12.2(1): 0
git -C "$scratch" check-ignore -q .foreman && echo ignored                # 12.2(2): ignored
git -C "$scratch/.foreman" rev-parse --is-inside-work-tree                # 12.2(3): true
( cd "$scratch/.foreman" && git rev-parse --show-toplevel )               # 12.2(4): $scratch/.foreman
git -C "$scratch" ls-files | sort                                         # no .foreman/, no docs/dev/program/
git -C "$scratch/.foreman" ls-files | sort                                # STATE.md DEFERRED.md foreman.json .gitignore
PATH="<worktree>/bin:$PATH" foreman-roots "$scratch"

# [JUDGE-2]: the pre-existing settings survived, and the template's additions arrived.
jq -r '.custom.keep'                                   "$scratch/.claude/settings.json"   # true
jq -r '.effortLevel'                                   "$scratch/.claude/settings.json"   # medium
jq -r '.permissions.allow | sort | join(",")'          "$scratch/.claude/settings.json"   # both entries
jq -r '.enabledPlugins | keys | sort | join(",")'      "$scratch/.claude/settings.json"   # theirs + the template's
jq -r '.extraKnownMarketplaces.foreman.source.repo'    "$scratch/.claude/settings.json"   # yorah/foreman-harness
jq -r '.worktree.baseRef'                              "$scratch/.claude/settings.json"   # fresh
PATH="<worktree>/bin:$PATH" foreman-gate --model claude-opus-5 --repo "$scratch"; echo "exit $?"   # 1: medium refuses, as the skill says it will
```

Every line's output goes in the report verbatim. The last one is the contract working, not a
defect: `evolve` did not raise the contributor's `effortLevel`, and the skill's Step 5 summary is
where it says so.

- [ ] **Step 5: Both directions**

Delete `$scratch/.gitignore`'s `/.foreman/` line and run `git -C "$scratch" status --short`:
`?? .foreman/` must appear. Restore the line; it must vanish. This proves 12.2(2) was the ignore
rule and not an accident of git's embedded-repository handling. Record both outputs.

- [ ] **Step 6: Record and commit**

In `docs/dev/backlog.md`, `- [ ] [JUDGE-2]` → `- [x] [JUDGE-2]` with a closing sentence naming
the date, this task, the scratch repository's pre-existing keys, and that each survived — or,
if one did not, leave it open and write what happened. If Step 2 produced a finding about
underspecified prose, add it to the backlog as a new `[B12-1]` item under this phase's heading;
do not fix the skill in this task.

If the run taught something durable — a jq shape for the merge, a git behaviour around ignored
nested repositories — one entry in `docs/dev/CONTEXT.md`, dated.

```bash
git add docs/dev/backlog.md docs/dev/CONTEXT.md
git commit -m "Live single-mode install verified against a scratch repository: spec 12.2 observed, evolve preserves pre-existing settings [JUDGE-2]"
```

The suite count does not change in this task. Run `bash tests/run.sh 2>&1 | tail -3` anyway,
green, before committing.
