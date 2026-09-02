# Task 1 review — user settings tier through CLAUDE_CONFIG_DIR

Reviewer: task-reviewer (opus). Reviewed artifact:
`docs/dev/program/phases/prerequisites/task-1-review.diff` (3 files, +64/-16), which matches
commit `611675a` exactly — a read-only `diff --stat` against the parent commit reproduces the same
three-file stat. The diff was read from the file, not regenerated.

**Verdict: Spec compliance PASS / Quality Approved.** Three Minor findings, no Critical, no
Important.

---

## 1. Spec compliance

| Brief requirement | Status | Evidence |
|---|---|---|
| `scripts/lib.sh`, `foreman_settings_chain` only | PASS | `scripts/lib.sh:22-42`; no other function in the file changed |
| Chain order: `<root>/.claude/settings.local.json`, `<root>/.claude/settings.json`, then user tier | PASS | `scripts/lib.sh:32-41` — repo tiers still printed first, from the same `printf`, unchanged |
| User tier = `$CLAUDE_CONFIG_DIR/settings.json` when set and non-empty | PASS | `lib.sh:35`, `${CLAUDE_CONFIG_DIR:-}` (the `:-` form, so empty is treated as unset) |
| else `$HOME/.claude/settings.json` when `HOME` set and non-empty | PASS | `lib.sh:36-38` |
| else no user tier at all | PASS | `lib.sh:39-41`, guarded `printf` |
| No caller signature change | PASS | `foreman_setting` (`lib.sh:128`) still calls `foreman_settings_chain "$root"`; `resolve-gate.sh` untouched |
| `effort_source` names whichever file answered | PASS | verified live, outside the suite (section 4) |
| Fixture setup replaced verbatim as dictated | PASS | `tests/test_resolve_gate.sh:9-15` matches the brief's block character-for-character |
| `write_user` left alone | PASS | `tests/test_resolve_gate.sh:17` unchanged |
| `unset HOME` block replaced verbatim | PASS | `tests/test_resolve_gate.sh:128-135` matches the brief |
| Six appended assertions, verbatim as dictated | PASS | `tests/test_resolve_gate.sh:288-322` matches the brief's block |
| `tests/test_templates.sh` third-tier phrase updated | PASS | `tests/test_templates.sh:312-317` |
| Nothing unrequired added | PASS | the commit is exactly the three authorised files |

**Is `tests/test_templates.sh` within what the brief authorises?** Yes. The brief's **Files**
section names it explicitly ("Modify: `tests/test_templates.sh` — one comment that names
`$HOME/.claude/settings.json`") and Step 3 dictates the substitution. The change is comment-only
(`tests/test_templates.sh:312-317`); the assertion beneath it (`settings.json.tmpl sets
effortLevel ...`) is byte-identical. Authorised and correctly scoped.

**Doc-drift sweep (the required-and-missing check).** I searched the whole tree for any other
place that describes the third tier as `$HOME/.claude/settings.json`, across `*.sh`, `*.md`,
`*.tmpl` and `*.json`. The only remaining occurrences are (a) the spec, which already says
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, (b) `tests/test_bin.sh:35`, a comment that says "not
`$HOME`" and is still true, and (c) the new comments themselves. `POLICY.md`,
`templates/program/POLICY.md.tmpl`, `skills/`, `agents/` and `commands/` describe the pin and
`effort_source` but never enumerate the user tier's directory, so nothing else needed updating.
No missing follow-on edit.

---

## 2. Invariants

**1 — zero deps beyond bash/git/jq: PASS.** The added code uses only `local`, `[`, `printf` and
parameter expansion. No new external command anywhere in the diff (the new test uses `grep` and
`sed`, both already used across the suite, and neither is shipped-script code).

**2 — shebang / `set` line / exec bit: PASS.** `scripts/lib.sh` still carries **no `set` line**
(correct for a sourced library — a `set` there would leak into `resolve-gate.sh`, and into the new
`chain_third` subshell that sources it). `tests/test_resolve_gate.sh:2` still carries
`set -uo pipefail`, no `-e`. Neither file's mode changed. Notably the new code is `set -u`-safe:
`${CLAUDE_CONFIG_DIR:-}` and `${HOME:-}` both use the default-expansion form, so a caller running
under `set -u` with either variable unset does not abort — which is the whole reason the old
comment existed and the reason the change is safe for `resolve-gate.sh`, which *is*
`set -euo pipefail`.

**3 — exit codes are contract: PASS.** Verified against the real gate, not just the tests: user
tier `medium` via `CLAUDE_CONFIG_DIR` gives `verdict refuse`, **exit 1**; user tier via the real
`$HOME` at `xhigh` gives `verdict pass`, **exit 0**; and the suite's `no settings anywhere is
unknown` / `unknown exits 2` pair is still green, so the "no" / "I don't know" distinction
survives. A `CLAUDE_CONFIG_DIR` pointing at a directory with no `settings.json` yields no tier at
all, hence `unknown` / exit 2 — the safe direction, never a lax `pass`.

**4 — all paths between tiers absolute: PASS with a bounded caveat.** Both repo tiers remain
absolute (`--repo` is still validated by `foreman_require_abs`). The user tier is now only as
absolute as `$CLAUDE_CONFIG_DIR`. With a relative `CLAUDE_CONFIG_DIR` I reproduced
`"effort_source": "relcfg/settings.json"` from a live gate call — a relative path inside the
gate's JSON contract. See finding **[T1-M2]**; Minor, because it needs a deliberately relative
env var, the harm direction is a *missing* tier (safe) unless a same-named directory exists
relative to the cwd, and the repo tiers still outrank it.

**5 — no TODO/TBD/FIXME under skills/agents/commands: PASS (untouched).** No `.md` under those
trees is in the diff; the `no TODO/TBD/FIXME in templates` assertion is still green.

**6 — harness scripts invoked by bare wrapper name: PASS.** The new test's
`source "$FOREMAN_ROOT/scripts/lib.sh"` (`test_resolve_gate.sh:304`) is not a wrapper invocation:
`lib.sh` is not one of the five named wrappers, it is a sourced library, and
`scripts/resolve-gate.sh:3` sources it by path itself. The established test-side pattern is
already `gate="$FOREMAN_ROOT/scripts/resolve-gate.sh"` (`test_resolve_gate.sh:5`, pre-existing).
Nothing in `skills/`, `agents/` or `commands/` changed, so no path-form call site was introduced
where the invariant applies.

**7 — suite green, not below baseline: PASS.** I ran `bash tests/run.sh` in the worktree myself:
**`14 files, 616 passed, 0 failed`, exit 0**, with `jq` resolving to
`/home/yorah/.local/share/mise/shims/jq`. 616 = 610 baseline + 6 appended (the rewritten `unset`
block is 2-for-2). The runner's baseline gate (`tests/run.sh:101-113`) passes since 616 is at or
above `baseline-count: 610`.

**8 — 100-column body prose in shipped markdown: N/A.** The diff touches no markdown. For
completeness, no *added* line in any of the three files exceeds 100 columns; a length scan flags
only pre-existing lines (`test_resolve_gate.sh:19`, `:285`, and many in `test_templates.sh`).

---

## 3. The precedence order itself

This is the part that fails silently, so I attacked it directly rather than trusting a green run.
I copied the worktree to a scratch directory under `/tmp` (excluding `.git`, and confirmed green
at 616/0 there) and mutated `scripts/lib.sh` **in the copy only**. No tracked file in the worktree
was modified; a read-only short status before and after shows only the two pre-existing untracked
brief/report files.

| Mutation (in the /tmp copy) | Result | Read |
|---|---|---|
| `local user_dir="${CLAUDE_CONFIG_DIR:-}"` becomes `local user_dir=""` (CLAUDE_CONFIG_DIR ignored) | **608/8** — red: `CLAUDE_CONFIG_DIR names the user tier when set, even with HOME set` and `the user tier that answered is the CLAUDE_CONFIG_DIR file`, plus the six fixture-dependent assertions | Reproduces the report's row exactly. Also proves the *fixture* is real: `write_user` only reaches the gate through `CLAUDE_CONFIG_DIR`, so every pre-existing user-tier assertion in this file genuinely exercises the new seam. |
| `user_dir="$HOME/.claude"` becomes `user_dir="$HOME/.nowhere"` | **614/2** — red: `without CLAUDE_CONFIG_DIR the user tier is HOME/.claude/settings.json` and `an empty CLAUDE_CONFIG_DIR falls back to HOME rather than yielding /settings.json` | Reproduces the report's row. |
| a column-0 `HOME` redirect appended to `tests/test_baseline_check.sh`, in the exact `export HOME=` shape | **615/1** — red: `no test file redirects HOME ...`, naming that file | Reproduces the report's row. |
| **My own:** the user-tier `printf` moved *before* the two repo-tier paths — the dangerous inversion, in which a lax user file would decide every verdict | **588/28** — red, including `project settings beat user settings`, `source names the project file`, `source names the local file`, every `... at local tier is unknown, not a fall-through pass` pair, `--repo omitted reads the project settings, not the user's`, and all three `chain_third` precedence assertions | The precedence order is **strongly** protected. This is the failure mode the task instruction warned about, and it cannot land silently. |
| **My own:** the repo-shared tier `"$1/.claude/settings.json"` deleted from the chain | **602/14** — red on 14 assertions, but **not** on `with neither variable the chain has no user tier and still prints the two repo tiers` | Basis for **[T1-M1]**: that assertion's second clause is not what it checks. The property is still covered elsewhere (14 other assertions), so this is a labelling defect, not a coverage hole. |
| **My own:** a two-line column-0 `HOME` redirect (bare assignment on one line, plain `export HOME` on the next) appended to `tests/test_baseline_check.sh` | **616/0 — stayed green** | Basis for **[T1-M3]**: the guard's regex is narrower than its prose claim. |

**Conclusion on the trust boundary.** The chain is still repo-local, then repo-shared, then user;
and the user tier resolves as `CLAUDE_CONFIG_DIR`, then `HOME/.claude`, then nothing. Both
orderings are mutation-proven, at the path-printer level and end-to-end through the gate's verdict
and its `effort_source` attribution. I found no ordering defect.

A second-order property worth stating explicitly, because it is the one behavioural change a
reader could mistake for a bug: when `CLAUDE_CONFIG_DIR` **is** set but
`$CLAUDE_CONFIG_DIR/settings.json` does not exist, the chain does **not** fall back to
`$HOME/.claude/settings.json`. That is exactly what the brief's "else" specifies, it matches what
Claude Code itself does with `CLAUDE_CONFIG_DIR`, and it errs toward `unknown` / exit 2 rather
than toward an unverified `pass`. Correct as written.

---

## 4. Correctness, verified against reality rather than against the tests

Live gate calls against a scratch fixture under `/tmp` (since removed) — the check the tests
deliberately cannot make:

- With `CLAUDE_CONFIG_DIR` pointing at a scratch dir holding `{"effortLevel":"medium"}`:
  `verdict refuse`, `effort medium`, `effort_source` = that scratch file, **exit 1**.
- With `CLAUDE_CONFIG_DIR` unset, same repo: `verdict pass`, `effort xhigh`, `effort_source` =
  `/home/yorah/.claude/settings.json`, **exit 0**.

Both precedence branches behave as specified against the real binary, the attribution names the
right file in each, and the exit-code contract holds. This reproduces the report's "reality check"
section exactly, including the operator's real `xhigh`.

I also checked the one environmental worry the diff creates for itself: `test_resolve_gate.sh:131`
now runs the gate — and therefore `jq` — with `HOME` *unset*, and the whole point of the task is
that a broken `HOME` breaks a shim-served `jq`. Empirically, `jq --version` with `HOME` unset
returns `jq-1.7`, exit 0 on this machine, and the plain suite run is green: the mise shim
tolerates an *unset* `HOME` even though it does not tolerate a *redirected* one. Recorded as a
cannot-verify item for other tool managers rather than as a finding.

No input I could construct produces a wrong verdict or a crash. Specifically checked and found
sound: `CLAUDE_CONFIG_DIR` empty (the `:-` form handles it, and it is asserted);
`CLAUDE_CONFIG_DIR` set to a non-existent directory (tier absent, `unknown`, exit 2); both
variables unset (`set -u`-safe, repo tiers still emitted, asserted end-to-end);
`CLAUDE_CONFIG_DIR` with a trailing slash (yields `dir//settings.json`, which POSIX resolves
identically); and `HOME=/` (yields `//.claude/settings.json`, also fine).

---

## 5. Test quality

**Every new assertion is mutation-checked, and I re-ran the implementer's three checks myself
rather than taking the report's word for them.** All three reproduce with the exact counts the
report records (608/8, 614/2, 615/1) and name the exact assertions it claims. That is an unusually
faithful report.

**Both directions.** The `no test file redirects HOME` guard has both: red when a column-0
`export HOME=` line exists (reproduced), green when none does (the current 616/0). The
`CLAUDE_CONFIG_DIR`-wins claim has both: the positive at gate level (`effort_source` names the
`CLAUDE_CONFIG_DIR` file) and the fallback at chain level (`chain_third -unset- /h`).

**No test was weakened or deleted.** The `unset HOME` block was *broadened* — it now unsets both
variables, so it is a strictly stronger statement of the same property, and it is still two
assertions. Every pre-existing assertion in `test_resolve_gate.sh` survived, and mutation A proves
they are all still live through the new seam rather than accidentally reading the operator's real
`~/.claude/settings.json`. The precedence assertions at `test_resolve_gate.sh:63-71` and the whole
fall-through battery are the strongest existing guards on this boundary, and are untouched.

**`chain_third` is a sound testing device.** `foreman_settings_chain` is a pure path printer, so
asserting on its stdout in a controlled subshell is the right level; it avoids pointing the gate
at a redirected `HOME`, which would reintroduce the shim failure on precisely the machines the
change exists to protect. The subshell is correct: sourcing `lib.sh` there is safe because
`lib.sh` carries no `set` line (invariant 2), and the non-exported `HOME="$2"` is sufficient
because `foreman_settings_chain` reads it as a shell variable in the same process.

### Findings

**[T1-M1] Minor — `with neither variable ... still prints the two repo tiers` does not check the
second half of its claim.**
`tests/test_resolve_gate.sh:314-315`. The assertion is
`assert_eq "" "$(chain_third -unset- -unset-)"`, and `chain_third` ends in `sed -n '3p'`. That
`sed` prints nothing for a 3-line output missing its third line, for a 2-line output, for a 1-line
output, and for no output at all — so the "still prints the two repo tiers" half is invisible to
it. *Failure scenario:* delete `"$1/.claude/settings.json"` from the chain and this assertion
stays green. Confirmed — mutation table row 5, where 14 other assertions do go red, so the suite
as a whole still catches it and only this label is unearned. The property is genuinely covered by
`test_resolve_gate.sh:128-135`, which resolves a project-tier effort with both variables unset.
The fix is a label change, or a second assertion on the chain's line count. Not blocking; the
brief dictated this assertion text verbatim, so the implementer complied.

**[T1-M2] Minor — a relative `CLAUDE_CONFIG_DIR` puts a relative path into the gate's JSON
contract.**
`scripts/lib.sh:35-41`. `user_dir` is used unvalidated, unlike `--repo`, which `resolve-gate.sh`
passes through `foreman_require_abs`. *Failure scenario, reproduced:* with `CLAUDE_CONFIG_DIR`
set to a relative directory name that exists in the cwd and holds
`{"effortLevel":"low"}`, a gate call with an absolute `--repo` emits
`"effort_source": "relcfg/settings.json"` and exit 1. A tier that quotes `effort_source` without
first changing to the same directory then names a file it cannot read — the shape invariant 4
exists to prevent. Bounded, because it requires an operator to set a relative
`CLAUDE_CONFIG_DIR`, because the verdict is still computed from a file that *was* read, and
because the repo tiers outrank it. The report declares this under "Not verified", so it is
disclosed rather than hidden. A `foreman_require_abs`-style guard, or ignoring a non-absolute
`CLAUDE_CONFIG_DIR`, would close it; that is beyond this brief.

**[T1-M3] Minor — the `no test file redirects HOME` guard is narrower than the claim above it.**
`tests/test_resolve_gate.sh:317-322`. The comment says "No test file in this suite may redirect
HOME at the top level"; the check is `grep -lE '^export HOME='`. *Failure scenario, reproduced:*
appending two column-0 lines to `tests/test_baseline_check.sh` — a bare `HOME` assignment, then a
plain `export HOME` — redirects `HOME` for that whole file and the suite stays **616/0**: the
guard never fires. Other shapes that also slip through: an indented `export HOME=`, a
`declare -x` form, and a per-command `HOME=x cmd` prefix. The guard *does* catch the one shape the
comment names ("the shape the old fixture had"), which is the realistic regression, and the brief
dictated this exact line — hence Minor rather than Important. A pattern allowing optional leading
whitespace and an optional `export` keyword would match the prose.

No Important or Critical test-quality defect. Every one of the six new assertions fails against
the mutation it names.

---

## 6. Declared deviations — judged

1. **The ruled gate prefix's `GIT_CONFIG_GLOBAL` half could not be executed; gate 1 was run with
   only the `PATH` half. Sound.** I hit the same sandbox refusal myself on two unrelated commands,
   so the constraint is real and not an excuse. The evidence that the omission is harmless is
   internal and checks out: the prefixed run at the base commit produced **610**, the exact count
   the kickoff records for the full prefix, and the plain baseline run was 522/88 with *all* 88 in
   `test_resolve_gate.sh` — i.e. no `test_phase_state.sh` signing failures, which is precisely
   what pinning the global git config was there to suppress. That half of the prefix was a no-op
   on this machine. The implementer did not relitigate the ruling, said plainly that it could not
   be executed as written, and reported the substitute. Correct handling.
2. **Extra wording in the `test_templates.sh` comment ("in the operator's home directory" becomes
   "in the operator's own user settings") plus a paragraph reflow. Sound.** The original phrase
   became factually wrong the moment the tier stopped being `$HOME`-rooted, so leaving it would
   have created the very drift I swept for in section 1. The reflow is forced: the substituted
   phrase is longer than what it replaced. Comment-only, one contiguous paragraph, no assertion
   touched — inside the brief's "one comment" authorisation, and disclosed rather than slipped in.
3. **The brief's Step 2 predicted a FAIL label (`CLAUDE_CONFIG_DIR beats HOME when both name a
   settings file`) that its own Step 1 never creates. Sound.** The brief is internally
   inconsistent; Step 1's dictated text is the authoritative half, and the equivalent assertion
   (`CLAUDE_CONFIG_DIR names the user tier when set, even with HOME set`) did fail in Step 2 and
   does go red under mutation A — I reproduced both. Following the code the brief specifies over
   the prose that paraphrases it is the right call, and flagging the inconsistency is exactly what
   a report is for.
4. **`POLICY.md`'s `baseline-count: 610` left alone. Sound and required.** `POLICY.md:7` says a
   phase session never edits it. 616 is at or above 610, so the runner's baseline gate passes —
   verified.

## 7. Declared "Not verified" items — judged

- **`asdf`-shim machines.** Fair. The mechanism the fix removes is the `HOME` dependency itself,
  so it is tool-manager-agnostic in principle; only the mise case is observable here. Accepted as
  a cannot-verify item, not a finding.
- **Relative / non-existent `CLAUDE_CONFIG_DIR`.** Honest, and correct that the brief did not ask
  for it. I promoted the relative case to **[T1-M2]** because I could reproduce a concrete
  relative path escaping into the gate's JSON contract, which touches invariant 4. The
  non-existent-directory case I checked, and it is safe (tier absent, `unknown`, exit 2).
- **The 12 `test_phase_state.sh` failures the environment note predicts were never reproduced.**
  Consistent with my own green plain run (0 failures anywhere). Honest to say so rather than to
  claim the note was wrong; it is an operator-config-dependent condition, and task 2's problem.

## 8. Cannot verify from this diff

- Behaviour where `jq` is served by an `asdf` (or other) shim rather than `mise` — in particular
  whether `tests/test_resolve_gate.sh:131`'s `unset HOME CLAUDE_CONFIG_DIR` block, which invokes
  the gate and hence `jq` with `HOME` unset, stays green there. It is green here, so this is a
  residual environmental unknown, not a defect.
- Whether Claude Code's own resolution of `CLAUDE_CONFIG_DIR` matches this chain for edge values
  (relative path, non-existent directory, trailing slash). The common case — `CLAUDE_CONFIG_DIR`
  names the directory holding `settings.json`, else `~/.claude` — is what the diff implements, and
  is what the spec's phase A row and section 12.1 require.

## 9. What I ran

- `bash tests/run.sh` in the worktree: `14 files, 616 passed, 0 failed`, exit 0, `jq` = mise shim.
- Live `scripts/resolve-gate.sh` calls with `CLAUDE_CONFIG_DIR` set, unset, and set to a relative
  directory, against scratch fixtures under `/tmp` (all removed afterwards).
- Six mutations, all in a copy of the worktree under the scratchpad (removed afterwards): the
  three the report claims, plus user-tier-first, repo-tier-deleted, and a two-line `HOME` redirect
  in a test file.
- A line-length scan over the three changed files; tree-wide searches for `HOME`,
  `CLAUDE_CONFIG_DIR`, `settings.json` and `scripts/lib.sh` references.
- Read-only git only: short status, one-line log, and a `--stat` diff against the parent commit.
  **No repository file was created, modified or deleted, and no state-changing git command was
  run.**
