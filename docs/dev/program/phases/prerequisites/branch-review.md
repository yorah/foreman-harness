# Branch review — `feat/prerequisites`

- **Branch:** `feat/prerequisites`
- **Head:** `35690f2`
- **Merge base:** `origin/main` (`cc489e9`)
- **Worktree:** `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites`
- **Reviewer:** branch-level gate (first reader of the complete diff)
- **Status:** COMPLETE.
- **Gate:** 2 (whole-branch review). Seventh dispatch; the first six died on server-side 529s.

## Verdict

# GO

Nothing in this branch is broken, no numbered invariant is violated, the spec's phase A row and
§12.1 item 1 are delivered and I verified item 1 myself on this machine, and the suite grew
where the risk grew (610 → 660, exit 0, `delta 0`). The two **Important** findings below are
documentation-coherence defects, not code defects — but one of them has an imminent behavioural
consequence for the very next session this branch's own `STATE.md` tells the operator to launch,
so it should be fixed before that launch rather than after the merge.

## (a) `MANIFEST.tsv` and `evolve` — the trust boundary

**Verdict: clean, with two Minors.**

### The retired row is genuinely retired, in both directions

- `MANIFEST.tsv` no longer carries the `settings.local.json.tmpl` row (row count 16, header
  intact, tab-delimited — `tests/test_templates.sh:11` still checks the header byte-for-byte).
- `skills/foreman-init/templates/settings.local.json.tmpl` is a **genuine deletion**, not an
  emptying. Confirmed from the raw diff (`deleted file mode 100644`, `+++ /dev/null`) and from
  the working tree (`test -e` → absent; the templates directory holds exactly five files plus
  four subdirectories).
- The manifest is checked in *both* directions and both directions still hold: every template
  file must have exactly one row (`test_templates.sh:15-20`) and every row must point at a
  template that exists (`MISSING_TEMPLATE`, line 50). Removing the file without the row, or the
  row without the file, would have gone red. The phase also added the explicit reverse assertion
  at line 183 for the specific destination it retired.

### The `evolve` guarantee was **not** behaviourally verified, and the ledger is right about that

`bin/foreman-root` mentions `MANIFEST.tsv` only in a comment explaining why the plugin root is
the interface; nothing under `bin/` or `scripts/` parses it. The only mechanical consumer is
`tests/test_templates.sh`, which validates the manifest's *shape* (existence, four fields,
destination non-empty, mode in `{create,evolve}`, variable declaration in both directions,
on-demand `{{` rows in both directions, and a hardcoded destination→mode table). None of that
executes an evolve. So the "adds what is absent and touches nothing else" property is model
prose in `skills/foreman-init/SKILL.md`, exactly as the ledger states.

I tested that reasoning and it survives, for one reason the ledger does not name: there **is**
one behavioural witness, in `tests/test_dogfood.sh`'s last assertion — this repository's own
`.gitignore` still contains `/.superpowers/`, which is absent from `gitignore-additions.txt` and
can therefore only be present if the real `/foreman-init` run merged rather than replaced. That
is evidence for `.gitignore`'s evolve, not for `.claude/settings.json`'s, and it is
after-the-fact evidence from one historical run rather than a repeatable check. It is better
than nothing and less than a test.

**Is `evolve` still safe for `.claude/settings.json`?** Yes on the substance, with a Minor loss
of specificity the branch introduced:

- The risk profile did not get worse in kind. `.claude/settings.json` was already a `mode:
  evolve` row on `main`, already carried `enabledPlugins`, `worktree.baseRef`, `effortLevel` and
  `extraKnownMarketplaces` (the `fable-method` entry), and already had to merge into a target
  repository's existing file. The branch adds one sibling key under an object that was already
  there.
- Consent is preserved. A `github` marketplace source in a tracked file does not silently
  install anything: Claude Code prompts for trust on first start, and both `CLAUDE.md.tmpl` and
  this repository's `CLAUDE.md` now say so in the paragraph that replaced the local-path story.
  The old design's untracked file was per-contributor but *also* required each contributor to do
  manual work the clone could not tell them about — the change trades a private, undiscoverable
  step for a public, prompted one. That is the right direction for a trust boundary.

**Minor (a1) — the nested-merge instruction was deleted along with the file that motivated it.**
`skills/foreman-init/SKILL.md`'s `evolve` bullet previously spelled out key-level merge
semantics in one place only: "adding only the missing `extraKnownMarketplaces.foreman` key.
Never overwrite a contributor's other local settings". That sentence is gone and the surviving
guidance for `.claude/settings.json` is the generic "adding what is absent and touching nothing
else". The obligation it described did not go away — it *moved*, from an untracked
per-contributor file to a **tracked** one, where a whole-key overwrite would destroy a target
repository's other marketplace registrations for every contributor at once rather than for one.
The generic sentence probably suffices for a competent model, and nothing mechanical checked
either version, so this is a Minor and not a blocker; but the branch removed the only prose that
named the nested key path, at the moment that path became more consequential.

**Minor (a2) — `no template carries a machine-specific marketplace path` checks one variable
name.** `tests/test_templates.sh:396` is
`grep -rl 'FOREMAN_MARKETPLACE_PATH' "$t"`. That detects reintroduction of the retired
placeholder and nothing else: a template that hardcoded `/home/yorah/...`, or introduced
`{{MARKETPLACE_DIR}}`, satisfies the assertion while falsifying its label. See area (d).

### Vendor-name rule inside the manifest's blast radius

`settings.json.tmpl` (under `skills/`) contains `Sahir619/fable-method`, `fable@fable-method`
and two `@claude-plugins-official` entries. Ruling in area (i).

## (b) Spec delivery — §10 phase A row, §12.1 item 1

**Verdict: earned. §12.1 item 1 verified directly, on this machine, by me.**

### §12.1 item 1 — both halves

The spec's item 1 is an observation, not an intention: `bash tests/run.sh` green on a machine
whose global git config sets `commit.gpgsign=true` with no reachable signing agent, and on a
machine where `jq` on `PATH` is a tool-manager shim resolving through `$HOME`.

Both preconditions are **live on this machine**, and I confirmed them rather than taking them
from the ledger:

- `which jq` → `/home/yorah/.local/share/mise/shims/jq`, `readlink -f` → `/home/yorah/.local/bin/mise`.
  `jq` is a mise shim under `$HOME`. Any test that redirects `HOME` breaks it.
- the operator's global config carries `commit.gpgsign=true`, `tag.gpgsign=true`,
  `gpg.format=ssh`, `user.signingkey=key::ssh-ed25519 …`.

Under exactly those conditions, plain `bash tests/run.sh` from the worktree root prints
`14 files, 660 passed, 0 failed` and exits `0`. Reproduced by me at head `35690f2`. This is the
spec's item 1, observed.

The mechanism holds up on reading as well as on running:

- `tests/run.sh` writes a fresh global config to `mktemp`, exports `GIT_CONFIG_GLOBAL` at it and
  `GIT_CONFIG_NOSYSTEM=1`, and **unsets `GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT`** — which
  sit above the global file in git's precedence order and were the round-1 defect `[T2-M1]`.
  Between the replaced global file, the suppressed system file and the two neutralised env
  overrides, every documented path by which `commit.gpgsign` could reach git is closed.
- `scripts/lib.sh`'s `foreman_settings_chain` now takes the user tier from
  `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` and emits it only when absolute, so fixtures steer the
  user tier without touching `HOME`. `tests/test_resolve_gate.sh:358-362` enforces that no
  `tests/test_*.sh` redirects `HOME`, with the regex's exact reach spelled out in the comment
  above it.

The isolation is tested **in both directions** inside the suite, which is what makes it a test
and not a hope (`tests/test_bin.sh:110-203`): a purpose-built hostile config is first proved
hostile (a plain commit under it must fail, else the test says so and fails itself), then the
same commit is run inside a fixture test file through a nested `run.sh` and must succeed. The
same both-directions shape is repeated for `GIT_CONFIG_PARAMETERS`. `safe.directory=*` is pinned
and asserted, so replacing the operator's whole global file does not break a WSL or
containerised checkout.

**One limit on my own verification, stated plainly.** I could not re-run the suite under a
constructed hostile `GIT_CONFIG_GLOBAL` myself: this session's permission system refuses any
command that sets `GIT_CONFIG_GLOBAL` or runs git outside the worktree, and I did not work
around it. My evidence for the signing half is therefore (i) the operator's real global config
being mandatory-signing plus the plain green run, and (ii) reading the runner and the
both-directions test. I did not independently reproduce the merge-base `522 passed / 88 failed`
figure for the same reason; it is corroborated by the spec's own "the second [fails] 88" and by
the ledger's Step 1c record.

### §10's phase A row, item by item

| Row clause | Delivered | Evidence |
|---|---|---|
| `GIT_CONFIG_GLOBAL` pinned by the runner | yes | `tests/run.sh:20-24` |
| `commit.gpgsign=false` | **substance yes, letter no** | the runner sets no explicit `gpgsign=false`; it replaces the global file entirely and adds `GIT_CONFIG_NOSYSTEM=1`, so git's own default (do not sign) applies. The comment says exactly this. Stronger than the literal clause, and the observable in §12.1 item 1 is met. |
| user settings tier through `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` | yes | `scripts/lib.sh` `foreman_settings_chain`; the spec's parenthetical "the directory Claude Code itself honours" matches |
| no test redirects `HOME` | yes, with a disclosed exception | guard at `tests/test_resolve_gate.sh:361`; `chain_all`'s indented `HOME="$2"` in a subshell that runs no external command is deliberately out of scope and the comment says so |
| `[DEP-1]` dependency check at each skill's entry, stops cleanly | yes | see areas (e) and (f) |
| `[DIST-1]` marketplace source → `github`, `settings.local.json` retired | yes | see areas (a) and (c) |

### §10's two paragraphs after the table

- *"A changes the settings chain in `scripts/lib.sh` and removes a `MANIFEST.tsv` row … Both run
  at Opus with an Opus reviewer."* Honoured. Controller at Opus/high. Task 1 (`scripts/lib.sh`,
  a declared trust boundary) implementer and reviewer both Opus/high. Task 4 (`MANIFEST.tsv`,
  ditto) both Opus/high. Tasks 2 and 3 were implemented at Sonnet/medium, which is consistent
  with `POLICY.md`'s model table — task 2 touches only `tests/`, and task 3 touches skills and a
  template, for which the table mandates an **Opus reviewer regardless of implementer**. The
  ledger records task 3's reviewer as Opus/high on all four passes. No model rule was eroded.
- *"Phase sessions run the installed plugin, not the checkout. After each phase merges, the
  plugin is updated …"* Honoured and, more importantly, **not pre-empted**: the phase did not
  install, remove or re-register anything, and `STATE.md`'s marketplace ruling now records that
  the plugin this session ran is still the directory-sourced one and that the re-registration
  `DEFERRED.md` schedules is what closes the gap. That is the correct sequencing — `[DIST-1]`
  landing on the branch does not entitle the phase to re-register the marketplace before the
  merge.

### The baseline raise: safe on the branch, but note the zero headroom

Raising `baseline-count` to `660` on the phase branch rather than on `main` is the **safer** of
the two options and I would not change it. `main` still measures 610; a raise recorded on `main`
before the merge would make `main`'s own suite fail its own gate. Recorded on the branch, the
number and the assertions that justify it land in the same merge commit. `POLICY.md`'s baseline
paragraph states this explicitly.

Two observations rather than objections:

- **Zero headroom is real and is the point, but it has a consequence worth naming.** `delta 0`
  means any later commit on this branch that removes even one assertion fails gate 1. That is
  the intended ratchet. It also means the *rebase* step `POLICY.md`'s integration rule mandates
  ("rebase, re-run gate 1 in full on the rebased tree") is now the load-bearing check: if
  anything landed on `main` since `cc489e9` that removes an assertion, the rebased tree measures
  below 660 and gate 1 goes red at integration rather than here. `origin/main` is still at
  `cc489e9` (the merge base), so nothing has, today.
- **Minor (b1): `POLICY.md` attributes the 660 to `e8dc48e`, which is not the branch head.** Two
  commits followed it (`4feb245`, `a092edc`, and then `35690f2` which wrote the line itself).
  The claim is not false — I re-ran the suite at `35690f2` and got 660/0 — but the recorded SHA
  is not the tree a later reader will check out, and `tests/test_dogfood.sh` *does* read
  `POLICY.md`, so the file that records the count is inside the thing being counted. Recording
  the head, or noting that the three subsequent commits are ledger-only, would close it.

Nothing else in `POLICY.md` or `STATE.md` is now internally inconsistent. I checked the specific
couplings: `POLICY.md`'s gate table still has one row and `STATE.md`'s next-action probe now
names `660` rather than the stale `634`; the `STATE.md` phase row's status `gates` matches the
ledger's "gate 2 not reached"; the marketplace ruling's superseded-on-branch-not-on-`main`
wording matches what the branch actually contains; and no assertion in the suite constrains the
literal `610`, `660`, or this repository's real `STATE.md` — every relevant assertion runs
against fixtures (`FOREMAN_POLICY` in `tests/test_bin.sh`, `$tmp` repos in
`tests/test_phase_state.sh`), so these two edits could not have greened or reddened the suite by
touching what it measures. The ledger claims that check; I re-derived it.

**On the ownership question.** `POLICY.md`'s opening paragraph says a phase session never edits
it. The edits were made on the operator's explicit instruction, the operator is the program
manager, and the provenance is recorded in both `POLICY.md`'s baseline paragraph and the
ledger's Resumption section. A direct instruction from the file's owner outranks the file's
default. **Not reported as a violation.** The disclosure is what makes it reviewable, and it is
present in both places a later reader would look.

## (c) The install-story class — every surviving mention

**Verdict: clean. No surviving instruction sends anyone to a machine-specific marketplace path,
a local-directory source, or a `settings.local.json` step.**

I swept `bin/`, `scripts/`, `skills/`, `agents/`, `commands/`, `tests/`, `CLAUDE.md`,
`README.md`, `AGENTS.md`, `.claude/`, `.gitignore`, and every file under `docs/dev/program/`,
for six needles: `known_marketplaces`, `--scope local`, `settings.local.json`,
`FOREMAN_MARKETPLACE_PATH`, `marketplace add`, `plugins/cache`. Complete inventory:

### Machine-specific marketplace path — none introduced; one pre-existing, unrelated

- `FOREMAN_MARKETPLACE_PATH` is **gone** from every shipped surface. The only surviving
  occurrences are the two negative assertions (`tests/test_templates.sh:396`,
  `tests/test_init_skill.sh:64`) and historical `docs/dev/backlog.md` entries.
- `~/.claude/plugins/cache/` is **gone** from every shipped surface.
- `skills/foreman-init/SKILL.md:172` still carries
  `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/claude-md-management/skills/claude-md-improver/references/quality-criteria.md`.
  **Surviving, pre-existing, out of scope** — verified byte-identical against `origin/main`
  (line 193 there). It is a `$HOME`-relative path into *another* plugin's marketplace cache, used
  as the sanctioned fallback for `claude-md-management`'s rubric; it is not the `foreman`
  marketplace and `[DIST-1]` never covered it. Worth the program manager's eye later for two
  reasons: it is the same *shape* of machine-dependent path `[DIST-1]` retired, and the sentence
  around it is the literal phrase the `[DEP-1]` tripwire watches for ("read its rubric from").
  Not a finding against this branch.

### Local-directory source — none in any shipped surface

`"source": "directory"` appears nowhere outside `docs/` history. `settings.json.tmpl` and this
repository's `.claude/settings.json` both carry
`{"source":"github","repo":"yorah/foreman-harness"}`, byte-identical, in the same object shape
`fable-method` already used.

### `settings.local.json` — every surviving mention, and why each is correct

| Location | Verdict |
|---|---|
| `templates/gitignore-additions.txt:7` and this repository's `.gitignore` | **must stay.** Claude Code writes per-contributor permission grants there of its own accord. The comment's *rationale* changed (marketplace path → permission grants) and the new rationale is the true one. |
| `scripts/lib.sh:42` | **must stay.** First tier of the settings-precedence chain. |
| `templates/program/POLICY.md.tmpl:12` and `docs/dev/program/POLICY.md:12` | **must stay.** The effort-pin override caveat; asserted by `tests/test_templates.sh:457`. |
| `skills/foreman-init/references/audit-checklist.md:20` | **must stay.** An audit of an existing repository's `.claude/` assets; that file may exist in a target repo whether or not the harness put it there. |
| `tests/test_resolve_gate.sh` (many), `tests/test_program_skill.sh:81`, `tests/test_init_skill.sh:41` | fixtures for the chain tier. Correct. |
| `tests/test_templates.sh:183,394,416,433,457`, `tests/test_dogfood.sh:83,89` | the negative guards and the retirement check. Correct. |
| `docs/dev/program/STATE.md:47,64,70,74` | historical record: the superseded ruling, the merge probe, and the untouched-machine-state note. Correct. |
| `docs/dev/backlog.md` (10 lines) | closed items and their history. Correct. |

### `--scope local` — one surviving mention, correctly framed

`docs/dev/program/STATE.md:64` retains it inside the *Open rulings* entry recording how the
plugin was installed on 2026-09-02, and that bullet is now explicitly annotated **"Superseded on
the branch, not yet on `main`"**. That is the honest shape: the ruling describes a past act and
the annotation says what replaced it and when the gap closes (`DEFERRED.md`'s re-registration
entry). No instruction anywhere tells anyone to run it.

### Test-label coverage moved with the story

The three needles are now guarded **on both copies**, which is the `[T4-M3]` fix and the right
shape: `tests/test_templates.sh:412-417` on `CLAUDE.md.tmpl`, and `tests/test_dogfood.sh:85-90`
on this repository's own `CLAUDE.md`. Before that fix only one was guarded on this repository's
copy, so a reintroduced `--scope local` could land in the file contributors actually read and
leave the suite green.

`README.md:17` still says `/plugin marketplace add yorah/foreman-harness` — untouched by this
branch and already the correct GitHub-shorthand form, consistent with the new story.

### Recorded so nobody "fixes" it

`.gitignore` and `gitignore-additions.txt` have drifted apart in their opening comment
(`# Harness: regenerable review diff packages.` versus `…, and the per-contributor settings file
below.`). Both are true of their own file, and `tests/test_dogfood.sh` deliberately asserts
`/.superpowers/` survives in this repository's copy *because* evolve merged rather than replaced.
Divergence is expected here. Re-syncing the two files would destroy the only behavioural witness
this branch has for evolve.

## (d) Guards claiming more than they check

The phase produced this defect three times and fixed two; `[T4R1-M1]` was deferred. I swept
every assertion, label and comment the branch added or touched. Four residual instances, all
Minor, plus three pre-existing ones recorded as observations rather than charged to this branch.

**Minor (d1) — `[T4R1-M1]` is still open, and its comment still overclaims.**
`tests/test_templates.sh:419-427`. The comment says "Case-insensitive and optional-backtick **so
a reworded conflation is caught too**", above

```
grep -oiE '(the|this) repository is `?foreman-harness'
```

What that catches is two determiners, one exact verb phrase, one exact noun. It does not catch
"this repo is foreman-harness", "the repository, `foreman-harness`, …", or any rewording that
separates the subject from the name. The comment's claim is broader than the regex by a wide
margin. This is deferred `[T4R1-M1]` verbatim, unfixed here, and owed to the backlog.

**Minor (d2) — `no template carries a machine-specific marketplace path`.**
`tests/test_templates.sh:396-397` greps the templates tree for the single literal
`FOREMAN_MARKETPLACE_PATH`. A template that hardcoded `/home/yorah/checkouts/foreman`, or that
introduced `{{MARKETPLACE_DIR}}`, satisfies the assertion and falsifies its label. The label
should say what it checks: that the retired placeholder has not been reintroduced. (Also (a2).)

**Minor (d3) — a needle whose label asserts the opposite polarity of what the needle proves.**
`tests/test_templates.sh:410-411`:

```
assert_contains "$claude_md_tmplf" "claude plugin list" \
  "CLAUDE.md template names claude plugin list as the tell that the plugin is installed"
```

I checked this needle against `origin/main`'s `CLAUDE.md.tmpl`: `claude plugin list` occurs
**twice** there, in a paragraph whose entire purpose is to say `claude plugin list` is **not**
the tell. The assertion therefore passes identically against the pre-fix file, and against any
future revert to the old story, while its label claims the polarity the fix introduced.
Substring matching is polarity-blind — the exact lesson `[T3-M4]` established one task earlier,
here applied to a positive needle instead of a negative one. The same holds, less sharply, for
`assert_contains … "claude plugin install foreman@foreman"` at line 406 (present once on `main`).
Neither is a false claim about today's file; both are **non-discriminating**, so they carry none
of the weight their labels imply. The assertions that do discriminate for this change are the
three `assert_not_contains` at 412-417 and `"asks whether to trust that marketplace"` at 408 —
the last of which I confirmed is absent from `main`'s template. (Also (h).)

**Minor (d4) — the `[DEP-1]` disclosure's range sentence is wrong for one of the two skills.**
See area (f). It is deferred `[T3-M14]`, and the inaccuracy now lives in `backlog.md`, which is
the durable copy a future editor will read.

### Pre-existing, recorded not charged

- `tests/test_templates.sh:180` — `"every manifest destination is covered with the right mode"`.
  The loop walks a hardcoded 16-row `TABLE` and checks each *expected* destination has exactly
  one row with the required mode. It does not check the reverse: a manifest row whose
  destination is absent from `TABLE` is uncovered and silent. The comment at line 182 admits
  exactly this and closes it only for the one row this phase removed. Label unchanged from
  `main`, so not the branch's doing — but the branch is what drew attention to the gap and left
  the general case open.
- `tests/test_dogfood.sh` — `"The one true \`mode: evolve\` row in this repository"` above the
  `/.superpowers/` assertion. `MANIFEST.tsv` has **three** evolve rows and all three
  destinations exist here (`CLAUDE.md`, `.claude/settings.json`, `.gitignore`). Already
  inaccurate on `main` (four rows then); the branch made it less wrong without making it right.
- `tests/test_resolve_gate.sh:361` — the `HOME`-redirect guard scans `tests/test_*.sh` only, so
  a redirect in `tests/lib_assert.sh` or `tests/run.sh` would escape a label reading "no test
  file redirects HOME". Neither does today, and the comment above it is unusually explicit about
  the shapes it deliberately does and does not match, which is the right way to hold a narrow
  guard. Recorded for completeness only.

## (e) The "what a phase does first" class

**Verdict: the class is *not* fully swept. One live instance remains, in this repository's own
kickoff — and it is the file this branch's own `STATE.md` tells the next session to read.**

### Important (e1) — `docs/dev/program/phases/prerequisites/kickoff.md` still names Step 1a first

The template was fixed (`[T3-M1]`, `[T3-M6]`) and guarded in both directions. The **rendered
instance in this repository was not**. Line 3 and the paragraph under it read:

```
## First — `foreman-phase` Step 1a, then Step 1b's `EnterWorktree`

Record `<main-checkout>` … and `<default>` (the default branch, `main`) before doing
anything else — they are needed at gate 6 …
```

Both of the exact claims `[T3-M1]` and `[T3-M6]` were raised about, in one file. Compare the
template, which the branch corrected to `## First — foreman-phase Step 0, then Step 1a, then
Step 1b's EnterWorktree` and `before entering the worktree`.

Why this is Important rather than Minor — the consequence is concrete and imminent, not
hypothetical:

1. `[T3-M1]`'s own reasoning, from the test comment the branch added: *"a phase session reads
   the kickoff at dispatch, before it has read the skill, so if the kickoff's header names a
   later step as first, a session that trusts the header skips the dependency check silently."*
2. `STATE.md`'s **Next action** — written in `35690f2`, the branch's last commit — instructs
   exactly that dispatch: "re-run `/foreman:phase docs/dev/program/phases/prerequisites/kickoff.md`
   at Opus, high. A resuming session skips Step 4 … and re-enters at gate 1, then gate 2."
3. Neither `STATE.md`'s Next action, nor the ledger's "To resume" paragraph, nor the kickoff
   mentions Step 0. All three route the resuming session straight into the gate chain.
4. The gate chain is where `[DEP-1]`'s two dependencies are consumed — `fable:fable-judge` at
   gate 3 and `superpowers:finishing-a-development-branch` at gate 7. That is precisely the
   "a stop costs a finished branch" scenario Step 0 was added to prevent, and the resumption is
   the first run of this branch that will reach it.

So the branch falsified this file (it was true before task 3), swept the class across
`skills/`, `templates/` and `tests/`, and left the one live instance — which its own final
commit then pointed a session at. `POLICY.md`'s Authorization section grants a phase the right to
write anything under its own `docs/dev/program/phases/<slug>/`, so no authorization was missing;
this is an incomplete sweep, of the same class the phase itself twice identified as its failure
mode ("patching instances one at a time lost to it twice before the class was swept").

Remedy: two lines in that kickoff, matched to the template. No test change needed, though see
the coverage gap below.

**Coverage gap this exposes.** No assertion anywhere checks a *rendered* kickoff. The derivation
guard at `tests/test_templates.sh:300-319` reads
`skills/foreman-init/templates/program/kickoff.md.tmpl` only, and `tests/test_dogfood.sh` —
which exists to keep this repository's own generated files honest, and which the branch extended
for `CLAUDE.md` — has no equivalent for `docs/dev/program/phases/*/kickoff.md`. That is why the
suite is green at 660 with the falsehood on disk. Backlog candidate: extend the dogfood file's
CLAUDE.md pattern to the kickoff instances.

### Minor (e2) — `foreman-phase/SKILL.md`'s own Step 0 heading claims a primacy the file contradicts

`skills/foreman-phase/SKILL.md:11-13`:

```
Announce: "Running phase `<slug>` from `<kickoff path>`."

## Step 0 — dependencies, before anything else
```

The announce instruction precedes the step whose heading says "before anything else". This is the
same shape as `[T3-M6]` — two competing claims of primacy in one file — one level up, in the file
that started the class. It is the mildest instance (an announcement is not an action with a cost,
and the intent is plainly "before any work"), which is why it is Minor and not Important. The
symmetrical wording used by `foreman-program/SKILL.md:10` (`## Step 0 — the gate, before anything
else`) has the same shape and is pre-existing.

### Where the class *is* swept, confirmed

| Surface | State |
|---|---|
| `skills/foreman-phase/SKILL.md` | `## Step 0` precedes `## Step 1`; asserted by line-number comparison in `tests/test_phase_skill.sh`, which fails loudly rather than vacuously if either heading is missing. |
| `skills/foreman-program/SKILL.md:179-180` | now says "The kickoff's own first *action* is `foreman-phase` Step 0's dependency check; its first *tool call* is `EnterWorktree(…)`". Both halves asserted, emphasis-stripped so a compliant reword does not redden (`[T3-M12]`). |
| `templates/program/kickoff.md.tmpl` | header and body both corrected; header checked by deriving the expected step from the skill rather than hardcoding it, with an explicit non-empty guard (`[T3-M8]`) and a documented "Step 1" collision caveat (`[T3-M7]`). |
| `templates/` label at `tests/test_templates.sh:267-275` | relabelled from "first step matches" to "carries the EnterWorktree call", with a comment explaining that a "first step" label would itself now be the false claim (`[T3-M5]`). |
| `skills/foreman-phase/references/gate-chain.md` | swept clean. Its only `Step 1a` mention (line 150) is about *where* the trust-boundary read happens, not about what runs first. |
| `commands/`, `agents/` | no primacy claims about a phase's first step at all. |

One further residual, deferred rather than fixed: `[T3-M15]` — `[T3-M12]` de-italicised the
positive needles only, so an *italicised* reintroduction of the wrong primacy claim still passes
green. Confirmed still true; owed to the backlog.

## (f) The `[DEP-1]` guard's disclosed limit

**Verdict: declaring detection closed was right, and it was earned rather than convenient. The
disclosure is accurate in substance, wrong in one detail (`[T3-M14]`, deferred), and it
under-sells the guard's residual value in a way that invites a future editor to delete it.**

### Was closing detection right, or convenient?

Right, and the evidence is unusually strong for a negative result. Three things distinguish this
from a tired stop:

1. **Both directions were proved empirically, not argued.** The reviewer pasted
   `references/gate-chain.md:64`'s own compliant sentence — "do not invoke `fable:fable-judge`
   **yourself**" — into Step 0 and reddened the suite, demonstrating the false-positive
   direction on real in-repo prose. I confirmed that sentence is still at that line and still
   ends in a period, which is what the colon anchor now exploits. The controller then injected
   four plainly-worded fallbacks ("continue without it and apply the equivalent steps",
   "degrade gracefully", "improvise a substitute", "best-effort attempt … instead of halting")
   and all four left the suite at 654/0, demonstrating the false-negative direction.
2. **The asymmetry argument is concrete, not aesthetic.** A false positive on compliant prose
   makes the cheapest route back to green *deleting the sentence that reinforces the ruling*.
   That is a real, specific failure mode, and it makes widening strictly worse than not
   widening. The three markers were consequently **narrowed** past round 2's two collisions
   rather than widened.
3. **The one mechanism that would work was identified, costed and rejected on the record, not
   overlooked.** `[T3-M13]`: a closed-world check over the guarded range — a snapshot pin of the
   normalised Step 0 / `### Dependencies` body, or a word-count budget — gives zero false
   negatives inside invariant 1, and reddens on *every* edit to that range including a compliant
   reword. Recorded in `backlog.md` as "a policy choice for a future round".

That third point is why I would not accept the word "impossible" at face value, and the branch's
own documents do not ask me to: what is impossible is **open-world content matching** for a
polarity-sensitive semantic property; what is possible and was declined is a **closed-world
pin**. The `backlog.md` text draws that distinction correctly. The ledger's ruling headline
("mechanical detection … is **declared closed as impossible**") is stronger than the ruling two
paragraphs below it that records the closed-world option. A reader of the headline alone comes
away with the wrong idea. That is a wording imprecision inside one file, not a false record.

I also verified each of the three markers corresponds to a phrasing that really occurred, rather
than an invented shape:

- `proceed by running` — the phrase both of round 1's defeating mutations used. Narrower than
  bare `proceed by`, which collided with a compliant resume instruction.
- `yourself:` — colon-anchored. Confirmed against `gate-chain.md:64`, which ends "…**yourself**."
  with a period, so the anchor drops the collision without losing the fallback shapes.
- `read its rubric from` — a literal from `skills/foreman-init/SKILL.md:167-175`, this program's
  one *sanctioned* fallback (for `claude-md-management`). I confirmed the sentence is still there
  and, because the guard flattens newlines before matching, a pasted copy of it into Step 0 would
  be caught even though the phrase is line-wrapped at its source. That marker is well chosen: it
  guards against a copy of the single fallback a session has seen written down.

### Is the disclosure accurate?

Three durable places carry it — `tests/test_phase_skill.sh`, `tests/test_program_skill.sh`, and
`docs/dev/backlog.md`. The substance is accurate: tripwire not detector, polarity-blindness named
as the reason, the review-not-gate enforcement stated, the closed-world alternative recorded.

**Minor (f1) — one detail is wrong, and it is wrong in the durable copy.** `backlog.md` says
"the guard's range is each skill's **Step 0 body** only". For `foreman-phase` that is right. For
`foreman-program` it is not: the test explicitly scopes the markers to the narrower
`### Dependencies` subsection ("Scoped to the `### Dependencies` subsection itself, not the wider
Step 0 extract"), which is the *correct* scoping and the narrower claim. So the backlog overstates
the program-side reach of the guard — the one direction a disclosure must never overstate. This
is deferred `[T3-M14]`, still open, and it is worse in `backlog.md` than it would be in a test
comment because `backlog.md` outlives the phase report and is what a future editor reads.

### Does it underclaim enough to invite deletion?

**Minor (f2) — yes, marginally.** Count the sentences: the disclosure states the limit at least
four times ("not a detector for the class", "a differently-worded fallback passes this check with
a green suite", "no content-matching assertion can close that gap", "the rule is enforced by
review, not by the gate") and states the residual value once, in a clause about one marker. An
editor who reads only the disclosure can reasonably conclude the six assertions buy nothing and
remove them. What is missing is one sentence saying what deletion would cost: these three
phrasings are not hypothetical — two were produced by real agents inside this very task, so the
guard is regression protection against drift that has already happened once.

Two things currently stand in for that sentence, and neither is by design: the zero-headroom
baseline (`delta 0`) would turn a six-assertion deletion into a red gate, and the assertion
labels themselves name the markers. Both are accidents rather than statements of intent. One
line in the test comment and one in `backlog.md` would fix it.

### One interpretation the branch made silently, which I endorse

The spec's phase A row says `[DEP-1]` is "a dependency check at **each skill's entry** that stops
cleanly when a **required** skill is absent". Two of the three skills got one: `foreman-phase`
and `foreman-program`. `skills/foreman-init/SKILL.md` did not, and that is correct rather than an
omission — its only cross-plugin dependency (`claude-md-management`'s rubric) is *not required*,
because a sanctioned fallback exists for it at Step 4. `backlog.md` reasons out the fifth
reference (`plans/plan-README.md.tmpl`'s `superpowers:subagent-driven-development` banner) the
same way and calls it "judged covered, not overlooked". Both judgements are sound; the
`foreman-init` one is the only one not written down anywhere, so it is worth a line in the
backlog beside the other.

## (g) Scope — anything no task asked for

**Verdict: nothing unauthorised. Three things sit outside a task's declared `Files` list, and
all three are accounted for.**

Checked every path in the diffstat against the four plan task files' `**Files:**` sections.

| Path | Task | In its Files list? |
|---|---|---|
| `scripts/lib.sh`, `tests/test_resolve_gate.sh` | 1 | yes |
| `tests/run.sh`, `tests/test_bin.sh` | 2 | yes |
| `skills/foreman-phase/SKILL.md`, `skills/foreman-program/SKILL.md`, `tests/test_phase_skill.sh`, `tests/test_program_skill.sh`, `docs/dev/backlog.md` | 3 | yes |
| `templates/settings.json.tmpl`, `templates/settings.local.json.tmpl` (deleted), `templates/MANIFEST.tsv`, `templates/gitignore-additions.txt`, `templates/CLAUDE.md.tmpl`, `skills/foreman-init/SKILL.md`, `CLAUDE.md`, `.claude/settings.json`, `tests/test_templates.sh`, `tests/test_init_skill.sh`, `tests/test_dogfood.sh`, `docs/dev/backlog.md` | 4 | yes |

### The three outside a Files list

1. **`skills/foreman-init/templates/program/kickoff.md.tmpl`** and further edits to
   **`tests/test_templates.sh`**, by task 3. Not in task 3's Files list (which named only the
   two session skills and their two test files). They arrived through fix rounds 1-3 as the
   `[T3-M1]`, `[T3-M5]`, `[T3-M6]` and `[T3-M11]` remedies — cross-file contradictions that
   task 3's own change *created*. Fixing what your change falsified elsewhere is inside a fix
   round's remit, not scope creep, and the ledger records each instance with its finding tag.
   **Authorised.**
2. **`.gitignore`** (this repository), by task 4. Explicitly declared as a deviation and judged
   in the ledger: the file carried the now-false marketplace-path rationale *verbatim*, and the
   dispatch's own "sweep the class, do not patch one instance" caution applies. **Authorised,
   and correctly reasoned** — leaving it would have been the (e1)-shaped mistake in a different
   file.
3. **`docs/dev/program/POLICY.md`** and **`docs/dev/program/STATE.md`**, by the phase session at
   `35690f2`. Outside every task and against `POLICY.md`'s own default. Made on the operator's
   explicit instruction, disclosed in `POLICY.md`'s baseline paragraph and in the ledger's
   Resumption ruling. **Authorised by the file's owner**; see area (b).

### In scope by the skill, not by a task

- `docs/dev/program/phases/prerequisites/*` — briefs, reports, reviews, ledger.
  `POLICY.md`'s Authorization section grants a phase "write anything under its own
  `docs/dev/program/phases/<slug>/`" without asking.
- `docs/dev/reports/2026-09-03-prerequisites.md` — directed by
  `skills/foreman-phase/SKILL.md:406` ("Write `docs/dev/reports/YYYY-MM-DD-<slug>.md`"). It is
  the only path outside the phase directory the skill tells a phase to write, and it is a new
  file, so nothing was overwritten.
- `docs/dev/program/phases/prerequisites/branch-review.diff` — untracked (`*.diff` is
  gitignored), so it is not in the branch at all. Confirmed: it does not appear in
  `git ls-files` for that directory.

### Nothing that looks like a stowaway

No new script, wrapper, agent, command, template or manifest row. No dependency added. No
permission entry added to `.claude/settings.json` beyond the marketplace object `[DIST-1]`
required. No change to `scripts/resolve-gate.sh`, `scripts/baseline-check.sh`,
`scripts/phase-state.sh`, `scripts/task-brief.sh`, any `bin/` wrapper, `agents/`, `commands/`, or
`.claude-plugin/`. For a branch of 7,952 diff lines this is a tight change:
607 insertions and 185 deletions outside `docs/`, across 21 files.

## (h) Tests weakened, deleted, or made vacuous to hold a count level

**Verdict: nothing was weakened to hold a count. Two non-discriminating needles were *added*
(one of them reported at (d3)); one assertion was legitimately lost to a file deletion and the
arithmetic for it lands exactly.**

### The count moves, reconciled

Baseline `610` at `cc489e9` → `660` at head. Assertion-bearing lines, HEAD versus `origin/main`,
in the six files the branch touched:

| File | `main` | HEAD | Δ | Risk it now covers |
|---|---|---|---|---|
| `tests/test_resolve_gate.sh` | 72 | 85 | +13 | the settings-precedence chain — the trust boundary task 1 changed |
| `tests/test_bin.sh` | 17 | 28 | +11 | the runner's git isolation, both directions, twice |
| `tests/test_phase_skill.sh` | 114 | 122 | +8 | `[DEP-1]` Step 0 in the phase skill |
| `tests/test_program_skill.sh` | 37 | 46 | +9 | `[DEP-1]` in the program skill, and the primacy claim |
| `tests/test_templates.sh` | 45 | 56 | +11 | the `MANIFEST.tsv` trust boundary, `[DIST-1]`, the kickoff ordering derivation |
| `tests/test_dogfood.sh` | 21 | 26 | +5 | this repository's own settings and `CLAUDE.md` |

(Static counts; several sit inside loops, so they under-report the runtime total. The direction
and the distribution are what matter.) **Coverage moved to where the risk moved** — the largest
increases are on the two declared trust boundaries (`scripts/lib.sh`'s chain, `MANIFEST.tsv`)
and on the runner isolation that the whole phase exists to deliver. There is no file where
behaviour was added and no assertion followed it, with two exceptions both already reported: the
rendered kickoff instance (e1) and `evolve`'s executed behaviour (a).

### Deletions, each accounted for

- **`tests/test_templates.sh` −70 lines**: the four `settings.local.json.tmpl` assertions
  (placeholder present, renders to one object, source is `directory`, path substitutes) and the
  four old `CLAUDE.md.tmpl` install-story assertions. Every one of them asserted a fact the
  branch deliberately retired; keeping any would have been a red gate. They were **replaced**,
  not dropped: four new `[DIST-1]` assertions plus three `assert_not_contains` guards plus the
  deletion check. Net +11 on the file.
- **One assertion lost to the file deletion itself.** `tests/test_templates.sh:15-20` emits one
  assertion per file under `templates/`, so deleting `settings.local.json.tmpl` silently removes
  one. The ledger caught this and reconciled it arithmetically (654 + 4 − 1 = 657, then +3 for
  the fix round = 660), and I re-derived the 660 by running the suite. This is exactly the kind
  of silent count change that a count-level review misses and an arithmetic one catches.
- **`tests/test_init_skill.sh` −8**: two assertions removed (`records **user-scope**
  registrations only`, and `known_marketplaces.json`), three added. Both removed assertions
  asserted the retired lookup. Correct.
- **`tests/test_resolve_gate.sh` −6**: the `unset HOME` fixture block, relabelled and widened to
  `unset HOME CLAUDE_CONFIG_DIR`. Same assertion count, truer labels.

### Vacuity: checked read-only against `origin/main`, needle by needle

The reliable test for a self-satisfied needle is whether it was already true of the *pre-fix*
file. I ran that check for every positive needle the branch added:

| Needle | Present on `main`? | Verdict |
|---|---|---|
| `asks whether to trust that marketplace` | 0 | discriminating |
| `claude plugin install foreman@foreman` | 1 | **non-discriminating** — see (d3) |
| `claude plugin list` | 2 | **non-discriminating, and label-inverted** — see (d3) |
| `no template needs a machine-specific path` (`foreman-init/SKILL.md`) | 0 | discriminating |
| `^## Step 0 ` in `foreman-phase/SKILL.md` | 0 | discriminating |
| `^### Dependencies` in `foreman-program/SKILL.md` | 0 | discriminating |
| `do not substitute your own procedure` (both skills) | 0 | discriminating |
| `github` / `yorah/foreman-harness` on `settings.json.tmpl` and `.claude/settings.json` | absent | discriminating |
| `MANIFEST.tsv` reverse row (expect 0) | row present on `main` | discriminating |
| `before entering the worktree` (kickoff template) | absent | discriminating |

So of the branch's new positive needles, exactly two are non-discriminating, both in the same
block, and **both are surplus** — the block's discriminating work is done by its four other
assertions. Nothing was swapped in to hold a number level.

### The two known vacuity findings, re-checked

- **`[T3-M8]`** — the `case *""*` glob that matched everything when `$first_step` came out
  empty. Fixed properly, not papered over: `tests/test_templates.sh:303-319` now makes an empty
  derivation an explicit `fail`, and the `else` branch emits **two** `fail`s so the assertion
  count does not silently drop when the derivation fails. That second detail is the part that
  matters and it is present.
- **the brief's self-satisfied `trust` needle** (task 4) — the ledger records it was lengthened
  "to its longest unique form". Confirmed in the tree: the assertion is now
  `"asks whether to trust that marketplace"`, which I verified is absent from `main`'s template.
  Genuinely fixed.

### The relabelling round — the one place reach was genuinely reduced at a flat count

Task 3's round 3 (`e50992b`) left the count flat at 654. I read the commit rather than trusting
the label, and it is **not** pure relabelling: two negative-assertion needles were **narrowed**.

- `yourself` → `yourself:` (colon-anchored)
- `proceed by` → `proceed by running`

Narrowing a negative needle reduces its reach while leaving the assertion count untouched, which
is precisely the shape this review area exists to catch. Here it is justified, and the
justification is on the record and checkable:

- Both narrowings removed **demonstrated** false positives on this repository's own compliant
  prose — `references/gate-chain.md:64` ("do not invoke `fable:fable-judge` **yourself**.") and a
  compliant resume instruction ("proceed by starting a fresh phase session"). I confirmed line 64
  still ends in a period, so the colon anchor does what the comment says.
- The commit message records that both narrowed markers still catch every fallback shape named
  across rounds 1-2, mutation-verified, and that mutation D (round 1's defeating fallback) still
  reddens on both skills.
- The same round *widened* the positive needles' tolerance by stripping markdown emphasis
  (`[T3-M12]`), so a compliant reword no longer reddens. That widening had a side effect the
  round-3 review caught and deferred as `[T3-M15]`: the negative assertion still matches the raw
  haystack, so an *italicised* reintroduction of the wrong primacy claim passes green. I
  confirmed this is still true — `assert_not_contains "$skillf" …` at
  `tests/test_program_skill.sh` runs against the un-stripped text.

Verdict on the round: a legitimate, disclosed trade of reach for precision, not a covert
weakening. But it is the one place in this branch where an assertion's reach shrank while the
number stayed level, and a reader of the count alone would not know. Recorded here so the
program manager does.

Outside `tests/`, the third file whose changes could have moved the count is
`docs/dev/program/POLICY.md` — `tests/test_dogfood.sh` reads its `baseline-count:` line and runs
two assertions off it. Raising 610 → 660 changes neither assertion's outcome (both are relative
to whatever the file records), which is why the edit could not green or red the suite. The ledger
claims exactly this; I re-derived it from the assertions rather than from the claim.

## (i) One verdict per numbered invariant

| # | Invariant | Verdict | Evidence |
|---|---|---|---|
| 1 | Zero runtime dependencies beyond `bash`, `git`, `jq` | **PASS** | No shipped script gained an external command. `scripts/lib.sh`'s change is pure shell (`local`, `case`, `printf`). I grepped the whole 7,952-line diff for `python`, `perl`, `node`, `npm`, `curl`, `wget`, `yq`, `rg`, `md5sum`, `realpath`, `column`: every hit is inside a review or report document describing what a *reviewer* ran, never inside `bin/`, `scripts/`, `skills/` or `tests/`. |
| 2 | `#!/usr/bin/env bash` + `set -euo pipefail` + `chmod +x`, with the three exemptions | **PASS** | Verified directly. `scripts/lib.sh` and `tests/lib_assert.sh` carry a shebang and **no `set` line at all**. `tests/run.sh` and every `tests/test_*.sh` carry `set -uo pipefail` on line 2 — including the three inline fixture test files heredoc'd inside `tests/test_bin.sh`, which are sourced by a nested `run.sh` and therefore correctly take the test-file form. Every changed file is mode `775`. |
| 3 | Exit codes are contract: `0` / `1` / `2` | **PASS**, and strengthened | This branch's one exit-code decision is the right one: a relative `CLAUDE_CONFIG_DIR` makes the gate answer `unknown` and exit **2**, not guess a verdict from an unresolvable path. Asserted at `tests/test_resolve_gate.sh:377-381`, including that no relative path leaks into the JSON at all. `tests/run.sh`'s baseline gate still honours the distinction — `1` fails the run, `2` prints a warning and does **not**. |
| 4 | All paths passed between tiers are absolute | **PASS**, and strengthened | `foreman_settings_chain` now emits the user tier **only when it resolves to an absolute directory** (`case "$user_dir" in /*)`), for either variable, and drops the tier rather than falling back — so a relative value can never reach `effort_source`. Three assertions cover it. Every path in the ledger, the reports and `STATE.md` is absolute or an explicit `<abs …>` placeholder. |
| 5 | No `TODO`/`TBD`/`FIXME` in any `.md` under `skills/`, `agents/`, `commands/` | **PASS** | `grep -rlE '\b(TODO\|TBD\|FIXME)\b' skills agents commands` → empty. Also enforced inside the suite at `tests/test_templates.sh:461` for the templates subtree. |
| 6 | Harness scripts invoked by bare wrapper name only | **PASS** | No new invocation of any kind. The nine surviving `scripts/…` and `$CLAUDE_PLUGIN_ROOT` strings under `skills/` are all *prose about* the rule (three of them are the prohibition itself), which is the sanctioned form the existing `templates_path_form` guard distinguishes. `[DEP-1]`'s Step 0 additions reference skills (`fable:fable-judge`), not scripts. |
| 7 | `bash tests/run.sh` green before every commit; never below baseline | **PASS** | Reproduced by me at head `35690f2`: `14 files, 660 passed, 0 failed`, exit `0`, plain, no environment prefix. `foreman-baseline --count 660` → `pass`, `baseline 660`, `delta 0`. Per-commit greenness I take from the ledger, which records a count at every task's Step 4 and never below the then-current floor (610 → 616 → 623 → 628 → 640 → 646 → 654 → 657 → 660). |
| 8 | Body prose in shipped markdown wraps at 100 columns | **PASS** for shipped markdown | Scanned every changed `.md`. The only >100-column lines in shipped files are YAML frontmatter `description:` scalars (exempt) and two pre-existing lines in `skills/foreman-init/SKILL.md` (line 24 at 120 columns, and line 172, a 140-column unwrappable URL inside a fenced block) — both byte-identical to `origin/main`. `templates/CLAUDE.md.tmpl` and `templates/program/kickoff.md.tmpl` are clean. See the Minor below on the ledger's own report of this. |

### Minor (i1) — the ledger mis-reports the one invariant-8 exception it discloses

The Resumption section says: *"Invariant 8 holds in both files; the one over-length line is the
`STATE.md` table row, which cannot wrap without breaking the table and which was already 145
columns before this phase touched it — **trimmed to 141** rather than left at the 253 the first
draft produced."*

Measured:

```
origin/main  STATE.md:19  →  145 columns
HEAD         STATE.md:19  →  146 columns
```

The row is **146**, not 141 — one column **longer** than the row it replaced, not four shorter.
The substance of the disclosure is fine (a markdown table row genuinely cannot wrap, and
`STATE.md` is a generated instance rather than shipped markdown, so invariant 8 is not violated
either way), and 146 is a vast improvement on the 253 the first draft produced. But the number
is wrong in the ledger, and the ledger's numbers are what gate 3's judge re-derives. Worth one
correction.

### The vendor-name rule, and the `Sahir619/fable-method` ruling

The rule: no organisation or vendor names in `skills/`, `agents/`, `commands/`, `scripts/`, sole
exception `yorah/foreman-harness` in the template and this repository's settings.

**Verdict on this branch: PASS.** The only vendor name it introduces is `yorah/foreman-harness`,
in exactly the two places the exception names — `skills/foreman-init/templates/settings.json.tmpl`
and `.claude/settings.json` — plus the matching prose in `templates/CLAUDE.md.tmpl` and this
repository's `CLAUDE.md`, which is the same exception's natural extent (the template's Setup
paragraph has to name the marketplace it declares). `tests/test_templates.sh:391` and
`tests/test_dogfood.sh:79` pin the literal, which is the right way to hold an exception.

**Ruling on `Sahir619/fable-method`: outside the exception as written, but not this branch's
defect.** It sits in `skills/foreman-init/templates/settings.json.tmpl` — inside `skills/` — and
it is a third-party organisation name that the exception does not cover. It is **pre-existing
and byte-identical to `origin/main`**, which I verified; the branch neither introduced nor moved
it. Two further pre-existing names sit beside it in the same object and the same `enabledPlugins`
block: `fable-method` and `claude-plugins-official`.

So the rule as written is already violated on `main`, and this branch inherits rather than causes
that. My ruling, for the program manager to adopt or reject: the exception should be **widened,
not enforced**. The rule's purpose is to keep a machine's or a company's identity out of files
that ship into someone else's repository; a marketplace `source` object is the one place where
naming the upstream is the *function* of the field, and `settings.json.tmpl` cannot declare a
resolvable marketplace without it. `[DIST-1]` has just made that argument decisive by putting
`yorah/foreman-harness` in the same object for the same reason. Rewriting the exception as "the
`extraKnownMarketplaces` entries in `settings.json.tmpl` and this repository's settings" covers
all four names, keeps the rule meaningful everywhere else, and stops a future reviewer from
re-litigating this. Backlog item, not a branch change.

## (x) Cross-file program-state coherence — a second Important

This is the finding no per-task review could have reached: it exists only because two commits
edited two of three coupled program files.

### Important (x1) — `DEFERRED.md`'s "Raise the baseline" entry is now stale, and carries the one surviving `634`

`docs/dev/program/DEFERRED.md`:

```
- [ ] **Raise the baseline.** Condition: the same merge. Action: set `baseline-count:` in
  `docs/dev/program/POLICY.md` to the count the merged `main` prints for `bash tests/run.sh`
  (the plan expects 634; trust the run, not the plan), with the merge SHA and the date, in the
  same commit as the `STATE.md` row update.
```

Three things are now wrong or misleading in that entry:

1. The baseline **has already been raised**, to 660, on this branch (`35690f2`) — the entry
   describes it as still to do.
2. `the plan expects 634` is the **stale figure the branch went out of its way to correct
   elsewhere**. `STATE.md` line 45 now reads "expected **660** (not 634; that figure predated the
   phase's actual assertion count…)". So the branch identified the stale number, corrected it in
   `STATE.md`, and left the only other instance of it in `DEFERRED.md` — the file the program
   manager is told to open when the condition comes due.
3. "in the same commit as the `STATE.md` row update" is no longer available: the `STATE.md` row
   update also already happened, in the same `35690f2`.

Nothing catastrophic follows — a program manager who opens `POLICY.md` sees 660 immediately and
reconciles. But this is exactly the class the phase spent three fix rounds learning to sweep:
one stale number in three coupled files, two of them corrected. `DEFERRED.md` is not in any
task's `Files` list and was outside the operator's instruction, which is *why* nobody caught it —
and why it needed a whole-branch reader.

The entry is not wholly obsolete: after the merge, the recorded provenance (`Green at e8dc48e`)
should become the merge SHA, and that is still worth doing. So the remedy is to rewrite the entry
as "re-attribute the already-raised 660 to the merge SHA", not to tick it.

Recommended: rewrite the entry as part of the merge, and drop the `634`.

### `DEFERRED.md`'s other two entries are correct

- **Re-register the plugin from the GitHub source.** Accurate in every detail I could check: the
  removal command, the reason (the directory registration written to `.claude/settings.local.json`
  on 2026-09-02), the trust prompt the tracked `.claude/settings.json` now triggers, the expected
  `Source: GitHub (yorah/foreman-harness)` output, and the PM restart per spec §10. This entry and
  `STATE.md`'s superseded-marketplace ruling agree with each other and with the branch.
- **Reviewer return-size ratio** (spec §12.11 / 2026-08-28 §15.4). Condition "phase A's ledger is
  complete" is now met, so this becomes answerable at the merge. Worth flagging to the program
  manager as *due*, since the transcript it needs lives with the human and will not survive
  indefinitely.

### The abridged-review-package finding is correctly routed, and I am the compensation

The ledger's phase-level finding — `foreman-phase` Step 4 item 4 produces a silently truncated
review package under a `git`-rewriting proxy hook, 250 lines withheld across ten packages — is
correctly *not* patched here (a phase session does not amend the skill it is running) and is
recorded in `STATE.md`'s carry-into-phase-B list with a concrete remedy. I confirmed the
compensating condition it relies on: `docs/dev/program/phases/prerequisites/branch-review.diff`
is the raw diff and is what I read. Checked rather than assumed: 7,952 lines, **44**
`diff --git` headers — exactly the 44 files `git diff --stat origin/main...HEAD` reports — and
the only four occurrences of `... (N lines truncated)` / `--- Changes ---` in the whole file are
`+`-prefixed *prose inside the committed ledger and reviews describing the marker*, not the
marker itself. Note the ledger records the file at 7,659 lines while
my dispatch says 7,952: the difference is the three commits made after `e8dc48e`, which the file
correctly includes (I verified the `POLICY.md` and `STATE.md` hunks from `35690f2` are present in
it). Not a discrepancy, and worth saying so explicitly so nobody re-opens it.

One residual worth the program manager's weight, from the ledger and not from me:
**`[T2-R1-M4]`** — the suite can commit into a repository outside itself when `GIT_DIR` is set in
the environment, and report a nearly-clean run while doing it (reproduced by task 2's reviewer:
five branches into a victim repository, 624 passed / 4 failed). `tests/run.sh` unsets
`GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT` but not `GIT_DIR`, `GIT_WORK_TREE`,
`GIT_INDEX_FILE` or `GIT_OBJECT_DIRECTORY`. It is pre-existing, was correctly outside task 2's
brief, and `STATE.md` already carries it into phase B. I am recording it here only to add that
the fix is one line beside the two unsets task 2 already added, in the file task 2 already
touched — so it is cheaper than its carry-forward status suggests.

## Minors carried forward to the backlog

**None of the four task reviews' open Minors has reached `docs/dev/backlog.md`.** I checked each
tag: `T1-M4`, `T1-M5`, `T2-R1-M1`, `T2-R1-M2`, `T2-R1-M3`, `T2-R1-M4`, `T3-M13`, `T3-M14`,
`T3-M15`, `T4R1-M1`, `T4R1-M2`, `T4R1-M3` — **zero occurrences**. This is *correct so far*: the
ledger says each is "deferred to `backlog.md` **at gate 4**", and gate 4 was never reached
because gate 2 (this review) blocked on 529s six times. They are committed on the branch in
`docs/dev/program/phases/prerequisites/state.md` and the ten `task-N-review*.md` files, so
nothing is lost.

They are, however, **owed before this worktree is removed** — a deferral that lives only in a
phase directory is a deferral the program manager will not read. Full list, with this review's
own additions:

### Carried from the task reviews (must land at gate 4)

- `[T1-M4]`, `[T1-M5]` — task 1's round-1 Minors.
- `[T2-R1-M1]` — the `GIT_CONFIG_COUNT` half of the runner's unset has no assertion; dropping it
  still leaves the suite green.
- `[T2-R1-M2]` — the new `GIT_CONFIG_PARAMETERS` assertion re-creates the opacity `[T2-M3]` was
  raised about.
- `[T2-R1-M3]` — the runner comment's phrase "file-based config resolution" sweeps in local and
  worktree scope, which the pin does not govern.
- `[T2-R1-M4]` — **the heaviest of these, and not a comment nit.** The suite can commit into a
  repository outside itself when `GIT_DIR` is set, reporting a nearly-clean run while doing it.
  Pre-existing, correctly outside task 2's brief, already carried into phase B by `STATE.md`. My
  addition: the fix is one line beside the two unsets `tests/run.sh` already has.
- `[T3-M13]` — the closed-world alternative (snapshot pin / word budget) recorded, not
  implemented. Already in `backlog.md` as prose but **without its tag**, so a tag search misses
  it; give it the tag.
- `[T3-M14]` — the backlog's `[DEP-1]` range sentence overstates the program-side range (Step 0
  body versus the narrower `### Dependencies` subsection). Still wrong, and wrong in the durable
  copy. See (f1).
- `[T3-M15]` — `[T3-M12]` de-italicised the positive needles only, so an *italicised*
  reintroduction of the wrong primacy claim still passes green. Confirmed still true.
- `[T4R1-M1]` — the `[T4-M1]` guard's comment and label overclaim their reach. Confirmed still
  true; see (d1).
- `[T4R1-M2]` — the dogfood `--scope local` needle matches the raw haystack, so a line-wrapped
  reintroduction escapes it.
- `[T4R1-M3]` — the `[T10-1]` note understates the duplication (two new lines beside three
  stale, not one beside two).

### Added by this review

- **`[BR-1]` (Important)** — this repository's own `docs/dev/program/phases/prerequisites/kickoff.md`
  still names Step 1a as the phase's first step and says its reads come "before doing anything
  else". Fix before the resumed phase session launches, not after the merge. See (e1).
- **`[BR-2]` (Important)** — `docs/dev/program/DEFERRED.md`'s "Raise the baseline" entry is stale
  and carries the only surviving `634`. Rewrite it at the merge as "re-attribute the
  already-raised 660 to the merge SHA". See (x1).
- **`[BR-3]`** — no assertion checks a *rendered* kickoff. Extend `tests/test_dogfood.sh`'s
  `CLAUDE.md` pattern to `docs/dev/program/phases/*/kickoff.md`. This is what let `[BR-1]` ship
  green. See (e1).
- **`[BR-4]`** — two positive needles added by `[DIST-1]` are non-discriminating, and one has a
  label asserting the opposite polarity of what its needle proves
  (`tests/test_templates.sh:406,410`). See (d3).
- **`[BR-5]`** — `"no template carries a machine-specific marketplace path"` checks one literal
  variable name. Relabel or widen. See (a2)/(d2).
- **`[BR-6]`** — `skills/foreman-init/SKILL.md`'s `evolve` bullet no longer names key-level merge
  semantics anywhere, at the moment the obligation moved from an untracked to a **tracked** file.
  Restore one sentence. See (a1).
- **`[BR-7]`** — the `[DEP-1]` disclosure states its limit four times and its residual value
  once. One sentence saying what deleting the guard would cost. See (f2).
- **`[BR-8]`** — the vendor-name rule's exception should be widened to cover
  `extraKnownMarketplaces` entries in `settings.json.tmpl` and this repository's settings, so
  the pre-existing `Sahir619/fable-method`, `fable-method` and `claude-plugins-official` names
  stop being technical violations a future reviewer re-litigates. See (i).
- **`[BR-9]`** — the ledger's invariant-8 self-report says the `STATE.md` row was "trimmed to
  141"; it is 146, one column longer than the 145 it replaced. Correct the number. See (i1).
- **`[BR-10]`** — `POLICY.md` attributes `baseline-count: 660` to `e8dc48e`, not to the branch
  head. Record the head, or note that the three later commits are ledger-only. See (b1).
- **`[BR-11]`** — `foreman-phase/SKILL.md`'s `## Step 0 — dependencies, before anything else`
  sits below an `Announce:` instruction; `foreman-program/SKILL.md:10` has the same shape. The
  mildest residue of the (e) class. See (e2).
- **`[BR-12]`** — pre-existing, recorded because this branch's work sits next to it:
  `tests/test_templates.sh:180`'s destination/mode check has no reverse direction (only the one
  row `[DIST-1]` removed is covered); `tests/test_dogfood.sh`'s "the one true `mode: evolve` row"
  comment is false (there are three);
  `skills/foreman-init/SKILL.md:172`'s `~/.claude/plugins/marketplaces/…` path is the same shape
  of machine-dependent path `[DIST-1]` retired, and the sentence around it is the literal phrase
  the `[DEP-1]` tripwire watches for.
- **`[BR-13]`** — `DEFERRED.md`'s reviewer-return-size-ratio entry (spec §12.11) is now
  **answerable**: its condition, "phase A's ledger is complete", is met. Flagged as *due*,
  because the transcript it needs lives with the human and will not survive indefinitely.

## What I could not verify, stated plainly

- **The signing half of §12.1 item 1 under a *constructed* hostile config.** This session's
  permission system refuses any command that sets `GIT_CONFIG_GLOBAL` or runs `git` outside the
  worktree, and I did not work around it. Substituted evidence: the operator's *real* global
  config mandates `commit.gpgsign=true` with an ssh signing key, and the plain suite is green
  under it; plus `tests/test_bin.sh:110-203`'s in-suite both-directions proof, which constructs
  its own genuinely-unsatisfiable config and fails loudly if that config turns out not to be
  hostile.
- **The merge-base `522 passed / 88 failed` figure.** Same reason. Corroborated by the spec's own
  "Today … the second [fails] 88" and by the ledger's Step 1c record.
- **Mutation checks.** I did not mutate any tracked file, so I re-derived vacuity read-only
  instead — by testing each new needle against `origin/main`'s version of its own haystack, which
  is the sharper test for the specific defect this phase kept hitting (a needle that would pass
  before the fix). Four task reviewers and the controller ran live mutation checks; the ledger
  records each.
- **`evolve` executed end to end**, and Claude Code actually resolving the `github` marketplace
  and presenting its trust prompt. Both need a live `/foreman-init` run this phase was forbidden
  to perform. Correctly recorded as *uncovered* in the ledger rather than as checked. See (a).

## Tree state

Clean at the start of this review and clean at the end. I modified no tracked file, ran no
state-changing `git` command, and created nothing inside the repository except this findings
file. All fixtures were created under the session scratchpad.
