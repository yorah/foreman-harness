# Gate 3 — adversarial verification (fable:fable-judge)

- Branch: `feat/prerequisites`
- Merge base: `origin/main` (`cc489e9`)
- Worktree: `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites`
- Run started: (in progress)
- Judge skill: `fable:fable-judge` — CONFIRMED AVAILABLE, invoked.

Status: COMPLETE. Verdict at the end of this file.
as evidence is gathered.

## 1. Re-run verifications (judge's own execution, not the report's)

All commands below were run by the judge in the phase worktree, in the operator's real
environment (no environment doctoring).

### Gate 1 — plain suite

```
$ bash tests/run.sh
14 files, 660 passed, 0 failed
EXIT=0
```

**Claim "14 files, 660 passed, 0 failed, exit 0" — REPRODUCED exactly.**

### Gate 1 — baseline check

```
$ foreman-baseline --policy <abs>/docs/dev/program/POLICY.md --count 660
{ "verdict": "pass", "baseline": 660, "count": 660, "delta": 0 }
EXIT=0
```

**Claim "baseline 660, delta 0, pass" — REPRODUCED exactly.**

Note: the ledger's shorthand `foreman-baseline --count 660` is not a runnable command;
`--policy` is required and its absence exits 2 (`--policy is required`). Cosmetic
imprecision in the ledger's transcription, not a false claim — the underlying check passes.

### Spec §12.1 item 1 — the two hostile environment conditions

The judge did NOT need to synthesise these conditions: **they are live in the operator's
real environment**, and the green run above was already subject to both.

```
$ type jq
jq is /home/yorah/.local/share/mise/shims/jq        <- tool-manager shim under $HOME

$ git config --global --list
gpg.format=ssh
user.signingkey=key::ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...
commit.gpgsign=true
tag.gpgsign=true                                     <- signing mandated, no agent reachable
```

No `GIT_CONFIG_GLOBAL` / `GIT_CONFIG_NOSYSTEM` override was present in the judge's
environment before the run (only `GIT_CONFIG_KEY_0/1` credential entries, which
`tests/run.sh` explicitly unsets along with `GIT_CONFIG_COUNT`).

**Claim "green under a $HOME-resolving jq shim and under mandated unsatisfiable signing"
— REPRODUCED.**

### The merge base, same environment — the control

The judge extracted the tree at `cc489e9` (`git archive`) into a scratch directory and ran
its own `tests/run.sh` in the identical live environment:

```
$ bash <scratch>/base/tests/run.sh
14 files, 522 passed, 88 failed
EXIT=1
```

**Claim "at the merge base the plain suite was 522 passed / 88 failed" — REPRODUCED to the
digit.**

The failure output also confirms the *mechanism*, which no report had to be taken on faith for:

```
mise ERROR error parsing config file: /home/yorah/.config/mise/config.toml
mise ERROR Config files in /home/yorah/.config/mise/config.toml are not trusted.
Trust them with `mise trust`.
  FAIL: opus + high passes: expected [pass], got []
```

`jq` is a mise shim; mise refuses to run because the operator's config is untrusted; the
shim emits nothing on stdout; every assertion downstream of a `jq` call collapses to the
empty string. This is a real, reproducible, environment-dependent breakage — 88 assertions
of it — and the branch genuinely eliminates it. **The phase solved a real problem, not a
paper one.** 610 - 88 = 522 also reconciles the arithmetic: 610 total assertions existed at
the merge base, 88 of them failed.

### "Never below baseline at any point" — checked, not accepted

The judge extracted each task-completion commit and ran its own suite:

| commit | task | ledger claims | judge observed | vs baseline 610 |
|---|---|---|---|---|
| `0c6f90d` | 1 | 623 / 0 | **14 files, 623 passed, 0 failed** | +13 |
| `57f5323` | 2 | 628 / 0 | **14 files, 628 passed, 0 failed** | +18 |
| `e50992b` | 3 | 654 / 0 | **14 files, 654 passed, 0 failed** | +44 |
| `fd90e51` | 4 | 660 / 0 | **14 files, 660 passed, 0 failed** | +50 |

Every figure reproduces to the digit. The progression is monotonic and never dips below
610. **Claim "610 -> 660, +50 net, never below baseline" — REPRODUCED.**

This is unusually high fidelity: four independently-claimed intermediate counts, all exact.
It is strong evidence the ledger was written from real runs rather than reconstructed.

## 2. Fraud hunt

### Weakened checks — NONE FOUND

The branch deletes 70 lines from `tests/test_templates.sh`, 8 from `tests/test_init_skill.sh`,
1 from `tests/test_dogfood.sh`, 6 from `tests/test_resolve_gate.sh`. Every deletion was read.

All of them are consequences of `[DIST-1]`: the local-directory marketplace source was retired,
`settings.local.json.tmpl` was deleted, so assertions *about that file* had nothing left to
assert. Crucially, they were not merely dropped — each was **replaced by a negative assertion
that the retired mechanism cannot return**:

| deleted positive assertion | replacement |
|---|---|
| `settings.local.json.tmpl` renders / declares a directory source / carries the path placeholder | a check that fails if the template still exists |
| CLAUDE.md.tmpl contains `known_marketplaces.json`, `--scope local` | `assert_not_contains` on both |
| SKILL.md contains "records **user-scope** registrations only" | `assert_not_contains known_marketplaces.json`, `assert_not_contains FOREMAN_MARKETPLACE_PATH` |
| (new) | `MANIFEST.tsv` has no settings.local.json row; no template carries a machine-specific marketplace path |

This is a **strengthening**, not a weakening: a positive assertion about one file was traded for
negative assertions that the whole retired mechanism cannot come back anywhere. The independent
branch reviewer reached the same conclusion ("nothing was weakened to hold a count",
`branch-review.md`:597); the judge confirms it by reading the diff, not by citing them.

### The judge's own mutation check

The most load-bearing new test is the meta-guard in `tests/test_resolve_gate.sh` that forbids
any test file from redirecting `HOME` — the shape that caused all 88 merge-base failures. A
guard like this is worthless if decorative, so the judge mutated it rather than reading it:

```
$ echo 'export HOME=/tmp/fake' >> <scratch>/g2/tests/test_bin.sh
$ bash <scratch>/g2/tests/run.sh
  FAIL: no test file redirects HOME (use CLAUDE_CONFIG_DIR for the user tier):
        expected [], got [<scratch>/g2/tests/test_bin.sh]
14 files, 659 passed, 1 failed
```

**The guard fires.** The fix is protected against the exact regression that caused the problem.
It had itself been hardened in fix round 1 (`[T1-M3]`) after a reviewer found the original
`^export HOME=` pattern too narrow — the hardened pattern catches a bare column-0 assignment,
`declare -x`, and an indented `export`, while deliberately permitting the subshell-scoped
fixture assignment. That nuance is documented in-file and is correct.

### False completion — NONE FOUND, and two self-reported

Not one claim the judge could re-run failed. More tellingly, the ledger reports **against
itself** in two places, both verified:

- `[BR-9]`: the ledger had claimed a `STATE.md` row was "trimmed to 141"; it actually measured
  146 — *longer* than the 145 it replaced. The ledger now says the row is "genuinely 128".
  Judge measured: `STATE.md`:19 is **exactly 128** columns. The correction replaced the false
  claim rather than sitting beside it.
- `[BR-10]`: `POLICY.md` had attributed the baseline to `e8dc48e` as "the head", which it was
  not. Restated as provisional. Judge extracted `e8dc48e` and ran its suite: **660 passed, 0
  failed** — the SHA is genuinely green at the attributed count.

An agent that invents a number does not later go back and correct that number downward against
its own interest.

### Scope creep — none. Debris — none. Unauthorized action — none.

- `TODO` / `TBD` / `FIXME` under `skills/`, `agents/`, `commands/` -> no matches (invariant 5
  holds).
- Working tree clean apart from this findings file, untracked. No tracked file was modified by
  the judge; nothing was left behind.
- The `*.diff` review packages are gitignored and correctly untracked.
- Nothing was pushed, no PR opened, the default branch untouched — consistent with the ledger
  and with the standing rule that gate 6 ends in a pull request.
- The one outward-facing config change (`.claude/settings.json` gaining the `foreman` GitHub
  marketplace) is a tracked-file edit inside the declared task-4 scope, not an install or a
  re-registration. The ledger explicitly records that no plugin was installed, removed or
  re-registered, and a reviewer confirmed the main checkout was untouched.

## 3. The four suspect claims, adjudicated

### (1) Task 4's fix round committed by the controller — SUBSTANTIATED, OUTCOME VERIFIED, PROCESS UNVERIFIABLE

Every commit on the branch carries an identical author and committer identity. **Git metadata
cannot distinguish an implementer subagent from the controller**, so "who typed the commit" is
not verifiable from the repository by any means available to a judge. What *is* verifiable:

- `fd90e51`'s message discloses the substitution explicitly and unprompted, naming the
  dead-subagent protocol, the two 529s, and the fact that the controller ran the mutation
  checks the dead agent never reached.
- The judge independently reproduced that commit's claimed state: **660 passed, 0 failed**.
- The self-review concern is **substantially mitigated by a fact the dispatch did not mention**:
  a *separate* reviewer subsequently graded that very commit in `task-4-review-1.md` —
  "**PASS.** The round addressed all three round-0 Minors and nothing else" — and raised three
  new Minors of its own. The agent that committed it was therefore not the last agent to judge
  it.

The structural hazard is real and worth keeping as a standing concern, but on this instance it
did not materialise.

### (2) Every per-task review ran on an abridged diff — CONFIRMED REAL, REMEDIATION VERIFIED, ORIGINAL EXPOSURE UNRECOVERABLE

**The judge hit this hook personally.** A `git diff` issued during this very session came back
ending in:

```
  ... (20 lines truncated)
  +122 -70
[full diff: rtk git diff --no-compact]
```

The abridging proxy is real, is still active, and silently substitutes a summary for a diff.
This is not a historical excuse — it is a live, reproduced defect in the review pipeline.

Remediation verified:

- All ten per-task `.diff` packages now contain **zero** truncation markers.
- Completeness spot-check: `task-4-review.diff` carries exactly the **13** `diff --git` headers,
  in the same order and for the same files, as a freshly regenerated raw diff of the task-4
  range — it is whole.
- `branch-review.diff` is **7952 lines over 44 files**, with no truncation. Its four
  `truncated` hits are added lines *inside* review prose discussing the defect, not abridgement
  of itself.

What cannot be recovered: **what the ten reviewers actually saw at the time.** Regenerating the
artefacts afterward does not retroactively hand a finished reviewer the 250 missing lines. The
mitigation offered — that each reviewer mutation-checked against the live tree — is plausible
and is evidenced in the review documents, but it is not provable by re-execution.

The gap is materially narrowed by something checkable: **gate 2 reviewed the entire branch
against a raw, complete 7952-line diff** and returned `GO`. Anything the per-task reviewers may
have missed through abridgement was still placed in front of one reviewer in full.

### (3) POLICY.md / STATE.md edited by the phase session — TRUE, DISCLOSED, AUTHORISED; the zero-headroom risk is REAL

`POLICY.md`:7 does say, in the file's own voice: "**A phase session never edits it**: a phase
that believes this file is wrong says so in its summary and stops." The phase edited it anyway.

Adjudication: an explicit operator instruction outranks a document's self-imposed rule
(authority order: user statement beats spec, spec beats tests, tests beat code). The instruction
is invoked in-file — "Written by the phase session on the operator's explicit instruction, which
is the one thing this file's own opening paragraph otherwise forbids" — and again in the ledger.
**This is disclosed rule-breaking under a superior authority, not covert rule-breaking.** The
judge cannot see the operator's instruction itself; that it was given is taken on the ledger's
word, and the ledger's word has been accurate everywhere it could be tested.

The **zero headroom is a genuine operational risk, not a paperwork nit**: baseline 660, count
660, delta 0. Any future change that removes even one assertion now fails the gate before a
reviewer is spawned. The default branch still measures 610, so the raise is a claim about a
state that does not yet exist. `DEFERRED.md` correctly schedules re-attribution against a run on
the merged default branch, and correctly instructs trusting the run over the entry — while
flagging that a disagreement is itself a signal. This is handled about as well as it can be, but
it remains a live trip-wire the next phase inherits.

### (4) evolve mode's `.claude/settings.json` guarantee — UNVERIFIABLE, and the mechanism claim is TRUE (in fact stronger than stated)

Every reference to `MANIFEST.tsv` in shipped code:

- `bin/foreman-root`:4 — a **comment** naming it as an example of what a skill would `cat`.
- `skills/foreman-init/SKILL.md`:84 — a `cat` instruction, i.e. prose addressed to a model.
- `tests/*` — assertions about it.

No script parses the file. The `evolve` / `create` column is interpreted **only by a model
reading `foreman-init`'s prose**. The claim is therefore correct, and one detail is *more*
favourable than claimed: `bin/foreman-root` does not use the manifest path as a sentinel at all
— it resolves the plugin root via `readlink -f "${BASH_SOURCE[0]}"` and merely mentions the
manifest in a comment.

The consequence is the honest one the phase states: **the guarantee that `evolve` will not
clobber a contributor's `.claude/settings.json` has no mechanical enforcement and no test.** It
rests entirely on prose being followed. Verifying it would need a live `/foreman-init`, which
this phase was forbidden to run. **UNVERIFIABLE** — correctly labelled as such by the phase
rather than asserted as done.

## 4. Post-gate-2 commits — reviewed by the judge, because nothing else has

`branch-review.diff` covers 44 files; HEAD has 47. Gate 2 therefore never saw `e99c22a` or
`35690f2`. The judge reviewed that delta directly. It is **documentation only** — `DEFERRED.md`,
`POLICY.md`, `STATE.md`, `kickoff.md`, plus `branch-review.md` itself. No code, no tests, no
templates. Both Important fixes are present and correct:

- `[BR-1]`: `kickoff.md`'s heading now reads "**Step 0**, then Step 1a, then Step 1b's
  `EnterWorktree`", with the correction, its date and its reason stated in the file. The
  "before doing anything else" phrase is now scoped to "anything else **in Step 1**". Correct.
- `[BR-2]`: `DEFERRED.md`'s stale `634` is gone, rewritten as a re-attribution entry naming 660.
  The judge confirmed no `634` survives anywhere as a live instruction.

Gate 1 was re-run by the phase after these edits, and re-run again by the judge at HEAD: 660 / 0.

## 5. Verdict

# VERIFIED WITH CAVEATS

Every load-bearing claim that could be re-executed was re-executed by the judge and reproduced
**exactly** — not approximately: 660/0 at HEAD; baseline delta 0; 522/88 at the merge base;
623, 628, 654, 660 at the four task commits; 660 at `e8dc48e`; 128 columns at `STATE.md`:19. No
claim failed reproduction. No weakened test, no false completion, no scope creep, no debris and
no unauthorized action was found. The phase fixed a real, reproducible, 88-assertion environment
breakage and protected the fix with a guard the judge mutation-tested and watched fire.

The ledger's accuracy is the strongest signal here: it volunteers the controller substitution,
the abridged diffs, the `POLICY.md` rule-break and two of its own false numbers — all four of
which checked out under adversarial re-execution.

### Caveats

1. **The branch is not finished.** Gates 3–7 have not run. **Gate 4 is blocking**: the judge
   confirmed **zero** of the 12 task Minors and 11 carried branch-review findings have reached
   `docs/dev/backlog.md`. The ledger states this plainly; the framing of this branch as
   "finished" is the dispatch's, not the ledger's.
2. **Who committed `fd90e51` is unverifiable** — all commits share one git identity. Mitigated:
   a separate reviewer graded that commit PASS afterward, and its state reproduces at 660/0.
3. **What the ten per-task reviewers saw cannot be reconstructed.** The abridging hook is real
   and still live (the judge hit it). Packages on disk are now raw and complete, and gate 2 saw
   the whole branch raw. The "verdicts stand" argument is plausible, evidenced, and unprovable.
4. **`evolve` mode's `.claude/settings.json` guarantee is unenforced and untested** — nothing
   mechanically consumes `MANIFEST.tsv`; the guarantee is prose only. Needs a live
   `/foreman-init` to verify.
5. **Zero baseline headroom** (660/660/0) is a live trip-wire, and the default branch measures
   610 until the merge lands. Scheduled in `DEFERRED.md`, but inherited by the next phase.
6. **`POLICY.md` was edited by a phase session against its own stated rule.** Authorised by the
   operator and disclosed in two places; the authorisation itself is outside the judge's view.
7. Cosmetic: the ledger's shorthand `foreman-baseline --count 660` is not runnable as written —
   `--policy` is required, and its absence exits 2. The underlying check passes.

### Recommended action

Proceed to **gate 3**, then treat **gate 4 as the blocking item it is** — 23 findings to flush
to `docs/dev/backlog.md`. Do not merge before gate 4. Carry `[BR-3]` (no assertion checks a
*rendered* kickoff — the structural gap that let `[BR-1]` ship green) into phase B along with
the abridging-proxy fix, which is a skill change and not a phase task.

Judging changed nothing: the judge ran read-only and left the tree clean apart from this file.
