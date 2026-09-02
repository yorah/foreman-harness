# Task 1 re-review (fix round 1) — user settings tier through `CLAUDE_CONFIG_DIR`

Reviewer: task-reviewer (opus). Reviewed artifact: the pre-generated
`docs/dev/program/phases/prerequisites/task-1-review-1.diff` (3 files, +132/-16), read from the
file, never regenerated. A read-only `diff --stat 13dce8e 0c6f90d` reproduces the same
three-file stat, so the artifact is the cumulative diff from the task's original base
(`13dce8e`) through the fix-round commit (`0c6f90d`, "lib: drop a non-absolute user settings
tier; tighten the chain assertions and the HOME guard").

**Verdict: Spec compliance PASS / Quality Approved.** No Critical, no Important. All three
carried Minors — `[T1-M1]`, `[T1-M2]`, `[T1-M3]` — are **genuinely closed**, each confirmed by a
mutation I ran myself, not by reading the edit. Two new Minors are recorded below, both
non-blocking and both residues rather than regressions.

Working state: `bash tests/run.sh` in the worktree gives **`14 files, 623 passed, 0 failed`,
exit 0**, `jq` = `/home/yorah/.local/share/mise/shims/jq`. No repository file was created,
modified or deleted by this review; every mutation ran in an `rsync` copy of the worktree under
the scratchpad, since removed, and every fixture under `/tmp`, since removed. Only read-only git
(`log`, `status`, `ls-files`, `ls-tree`, `diff --stat`) was used.

---

## 1. Are the three Minors closed?

### `[T1-M1]` — "with neither variable ... still prints the two repo tiers" did not check its second clause. **CLOSED.**

`tests/test_resolve_gate.sh:304-313` splits the old helper: `chain_all` prints the whole chain
inside the controlled subshell, and `chain_third() { chain_all "$1" "$2" | sed -n '3p'; }`
filters downstream of the pipe. The over-claiming label is narrowed to
`with neither variable the chain has no user tier` (`:326-327`) — which is exactly what
`sed -n '3p'` can vouch for — and the dropped clause is asserted separately on the whole output
against a `repo_tiers` literal (`:313`, `:328-329`).

*Mutation I ran (scratch copy):* delete `"$1/.claude/settings.json"` from the chain in
`scripts/lib.sh`. Result **607 passed, 16 failed**, and the failure list now contains
`with neither variable the chain is exactly the two repo tiers, in order` and
`a relative CLAUDE_CONFIG_DIR leaves the two repo tiers intact and adds nothing`. Under the
pre-fix code the same mutation gave 602/14 with *no* assertion of that name red — the exact row 5
of the first review. The gap is closed, and closed by a check, not a relabel.

*Side benefit, verified:* the restructure removes the last external command (`sed`) that ran
inside the fake-`HOME` subshell. `chain_all`'s subshell now executes nothing but shell builtins
and the sourced library, which retires the residual worry logged in section 8 of the first
review for this helper (the `unset HOME CLAUDE_CONFIG_DIR` gate block at `:128-136` still invokes
the gate, and therefore `jq`, with `HOME` unset — see "cannot verify" below).

### `[T1-M2]` — a relative `CLAUDE_CONFIG_DIR` put a relative path into the gate's JSON contract. **CLOSED.**

`scripts/lib.sh:48-50` replaces `if [ -n "$user_dir" ]` with

```bash
  case "$user_dir" in
    /*) printf '%s\n' "$user_dir/settings.json" ;;
  esac
```

*Live reproduction of the old defect, and of the fix* (real `scripts/resolve-gate.sh`, fixtures
under `/tmp`, since removed). Same directory, given relatively then absolutely:

| Invocation | verdict | effort_source | exit |
|---|---|---|---|
| `cd $D && CLAUDE_CONFIG_DIR=relcfg gate --model claude-opus-5 --repo $D/repo` | `unknown` | `null` | **2** |
| `CLAUDE_CONFIG_DIR=$D/relcfg …` (same file) | `refuse` | `/tmp/…/relcfg/settings.json` | **1** |
| `CLAUDE_CONFIG_DIR=./relcfg …` | `unknown` | `null` | **2** |
| `CLAUDE_CONFIG_DIR='~/.claude'` (literal tilde, unexpanded) | `unknown` | `null` | **2** |
| `CLAUDE_CONFIG_DIR=$D/repo/../relcfg` (absolute, `..` segment) | `refuse` | `…/repo/../relcfg/settings.json` | 1 |
| `CLAUDE_CONFIG_DIR=$D/relcfg/` (trailing slash) | `refuse` | `…/relcfg//settings.json` | 1 |
| `CLAUDE_CONFIG_DIR=` (empty) + real `HOME` | `pass` | `/home/yorah/.claude/settings.json` | 0 |
| `env -u CLAUDE_CONFIG_DIR HOME=rel …` | `unknown` | `null` | **2** |

The first review's reproduced `"effort_source": "relcfg/settings.json"` no longer occurs; the
absolute form still reads the very same file and still refuses on it, so the tier's function was
not removed, only its non-absolute form. The `..` and trailing-slash forms stay absolute strings
that any caller resolves identically, so invariant 4 is satisfied for them; non-canonicalisation
is cosmetic and the report discloses it.

*Mutation I ran:* revert `case` to `if [ -n "$user_dir" ]`. Result **617/6**, red on exactly the
six new M2 assertions, including `expected [unknown], got [refuse]`, `expected [2], got [1]`, and
`got [  "effort_source": "relcfg/settings.json",]`. Reproduces the report's row and the reviewer's
original defect string verbatim.

*Mutation I ran, the opposite direction:* make the guard reject every value
(`/*)` → `/nosuchprefix*)`, i.e. the user tier is dropped even when absolute). Result: a very
large red block starting at `opus + high passes: expected [pass], got [unknown]`. An
over-conservative regression of this seam cannot land silently either — worth stating, because
"drop the tier" is precisely the mechanism that could have become too eager.

### `[T1-M3]` — the `no test file redirects HOME` guard was narrower than its prose. **CLOSED for the reproduced shape and three more; a narrower residue remains as `[T1-M4]`.**

`tests/test_resolve_gate.sh:358-362` builds the pattern in three appends:

```
^(export[[:space:]]+|declare[[:space:]]+-x[[:space:]]+)?HOME=
|^[[:space:]]*(export|declare[[:space:]]+-x)[[:space:]]+HOME([=[:space:]]|$)
```

*Direct comparison over a 16-shape fixture (`/tmp`, removed).* Old pattern `^export HOME=`
matched 1 line. New pattern matched 10: `export HOME=/x`, `HOME=/x`, `HOME="$tmp"`,
`  export HOME=/x`, tab-indented `export HOME=/x`, `declare -x HOME=/x`,
`  declare -x HOME=/x`, `export HOME`, `  export HOME`, `HOME=/x someprog --flag`.

*In-situ mutations I ran on the scratch copy, each appended to `tests/test_baseline_check.sh`:*

| Appended shape | Suite | Guard |
|---|---|---|
| column-0 `HOME=/tmp/fakehome` then `export HOME` (the reviewer's two-line shape, green before) | 622/1 | **red**, naming the file |
| `  export HOME=/tmp/fakehome` (indented) | 622/1 | **red**, naming the file |
| `  HOME=/tmp/fakehome jq --version >/dev/null` (indented command prefix) | 623/0 | green — see `[T1-M4]` |
| nothing appended (restored) | 623/0 | green |

Both directions are shown: red for each caught shape, green with none present. `chain_all`'s own
indented `HOME="$2"` (`:307`) is correctly *not* matched — it must not be, or the file would fail
its own guard — and the comment says so explicitly.

---

## 2. Spec compliance

| Brief requirement | Status | Evidence |
|---|---|---|
| `scripts/lib.sh`, `foreman_settings_chain` only | PASS | `scripts/lib.sh:22-51`; `foreman_die`, `foreman_require_abs`, `foreman_repo_root`, `foreman_setting` byte-identical |
| Chain order: local, shared, then user tier | PASS | `lib.sh:41-43` then `:44-50`; asserted end-to-end and at chain level |
| User tier = `$CLAUDE_CONFIG_DIR/settings.json` when set and non-empty | PASS (narrowed, see below) | `lib.sh:44` uses `${CLAUDE_CONFIG_DIR:-}` |
| else `$HOME/.claude/settings.json` when `HOME` set and non-empty | PASS (narrowed) | `lib.sh:45-47` |
| else no user tier at all | PASS | `lib.sh:48-50` |
| No caller signature change | PASS | `foreman_setting:137` still calls `foreman_settings_chain "$root"`; `resolve-gate.sh` untouched in both commits |
| `effort_source` names whichever file answered | PASS | live table in section 1 |
| `tests/test_resolve_gate.sh` fixture / `unset` block / appended assertions | PASS | `:9-15`, `:128-136`, `:288-381` |
| `tests/test_templates.sh` third-tier comment | PASS | `:310-317`, comment-only; the assertion beneath is byte-identical |
| Nothing unrequired added | PASS | both commits touch exactly the three authorised files |

**One narrowing of the brief's "Produces" line, and it is sound.** The brief's Interfaces section
says the user tier is `$CLAUDE_CONFIG_DIR/settings.json` *when set and non-empty*. After the fix
round it is that only when the value is also **absolute**. That is a deviation from the letter of
the brief, introduced to close `[T1-M2]`, which the first review itself raised against invariant
4 while noting a guard was "beyond this brief". Invariant 4 is POLICY and outranks a brief's
paraphrase; the narrowing is documented at length in `lib.sh:32-39` and argued in the report. I
rule it authorised. Worth noting only that the report's "Deviations this round" list does not
name it as a deviation from the Interfaces line — the reasoning is all present under `[T1-M2]`,
but the list has four entries and this is not one of them. Not a finding; a labelling nicety.

**Doc-drift sweep, repeated for the new behaviour.** I searched the tree for every mention of
`CLAUDE_CONFIG_DIR` and of the settings chain. The only consumers of `foreman_settings_chain` are
`foreman_setting` (same file) and, transitively, `resolve-gate.sh`. Nothing in `skills/`,
`agents/`, `commands/`, `POLICY.md` or the templates enumerates the user tier's directory or its
absoluteness rule, so the "relative value is dropped" behaviour needs no follow-on doc edit to
stay consistent. `tests/test_bin.sh:37-46` exercises the gate against a purpose-built repo whose
own `settings.json` answers, so it never reaches the user tier and is unaffected. The spec and
the plan describe `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` and remain accurate at that level of
detail.

---

## 3. The judged design decision: relative `CLAUDE_CONFIG_DIR` gives `unknown` / exit 2

**Ruling: right, and I would not have it resolve against the cwd.** Four reasons, in order of
weight.

1. **The gate genuinely cannot determine the answer, so exit 2 is the honest code, not merely a
   conservative one.** Resolving a relative `CLAUDE_CONFIG_DIR` against `$PWD` resolves it
   against *the gate call's* cwd. That is the cwd of a Bash tool invocation — a worktree, a
   subdirectory, wherever the session last changed to — not necessarily the directory Claude Code
   was launched from, which is what the variable would have been relative to for Claude Code
   itself. A resolved path would therefore be a **confident guess at a possibly different file**,
   emitted as an absolute `effort_source` that looks authoritative. Under invariant 3 that is
   precisely the case "I don't know" exists for. So this is not a gate refusing to answer where
   it could have; it is a gate declining to invent a cwd it has no claim to.
2. **Invariant 4 leaves no other emit-it option.** The chain's output reaches other tiers through
   the gate's JSON `effort_source`. A relative string there means a different file to every
   reader — the exact harm the invariant names. The two ways to comply are "make it absolute"
   (rejected by point 1) and "do not emit it".
3. **Dropping is monotonically safe; falling back is not.** The user tier is the **last** entry
   in the chain, so removing it can only turn an answer into *no* answer. It can never substitute
   a laxer file's opinion, because there is no tier after it. Option 2 in the report — falling
   back to `$HOME/.claude` — does exactly that, and the report's own mutation shows it turning a
   `refuse` into a **`pass`** off the operator's real `~/.claude` (`xhigh`). I re-derived the same
   asymmetry from the code and from the live table in section 1. Rejecting the fallback is
   correct.
4. **It matches the module's established convention.** `resolve-gate.sh:21` puts `--repo` through
   `foreman_require_abs`, which exits 2 rather than repairing a relative value. Repairing here
   while refusing there would make the module inconsistent about the same class of input.
   `foreman_settings_chain` correctly does *not* `foreman_die` — it is a pure printer with no exit
   contract of its own — so omitting the tier is the only shape available to it.

**Plainly, what a user with a relative `CLAUDE_CONFIG_DIR` now gets.** If their repo's own
`.claude/settings.json` declares `effortLevel` — the normal case, and the case `foreman-init`
guarantees for every generated repo (`tests/test_templates.sh:317`) — they notice nothing: the
repo tiers outrank the user tier and answer as before. Only if no repo tier declares it do they
get `verdict: unknown`, `effort_source: null`, exit 2. Per `skills/foreman-program/SKILL.md:44-52`
that is not a hard block: the session quotes the reason, asks the user for the effort directly,
and judges the answer against the pass criterion. So the cost is one question to a human in a
rare configuration; the avoided cost is a verdict attributed to a path the reader cannot resolve,
or computed from a file the operator never pointed Claude Code at. Right trade for a gate whose
failure mode of concern is an unverified `pass`.

The one honest caveat, which the report states itself under "Not verified": if Claude Code does
resolve a relative `CLAUDE_CONFIG_DIR` against its own cwd, the harness is now deliberately more
conservative than Claude Code for that input. That divergence is disclosed, is in the safe
direction, and is not recoverable by the gate without guessing a cwd. Accepted.

---

## 4. Invariants — one verdict each

**1 — zero deps beyond bash/git/jq: PASS.** The fix round adds one `case`, a shell builtin. No
new external command in `scripts/`; a scan of `lib.sh` for `awk|sed|grep|perl|python|realpath|
readlink|find` returns nothing. The test file adds `grep` and `sed` uses, both already present
across the suite and not shipped-script code.

**2 — shebang / `set` line / exec bit: PASS.** `scripts/lib.sh` still carries **no `set` line**
(a `^set ` scan returns 0 matches) — required, since `chain_all` sources it into a subshell and
`resolve-gate.sh` sources it under `set -euo pipefail`. `tests/test_resolve_gate.sh:2` is still
`set -uo pipefail`, no `-e`. Modes unchanged: the index records `100755` for all three files at
both the base and the fix-round commit. The new code stays `set -u`-safe
(`${CLAUDE_CONFIG_DIR:-}`, `${HOME:-}`), and `case "$user_dir" in` is safe with any value, since
the matched word is not pattern-expanded and is quoted.

**3 — exit codes are contract: PASS, and strengthened.** Verified live, not from the tests: a
relative `CLAUDE_CONFIG_DIR` yields `unknown` / exit **2** with a JSON body on stdout, which the
program skill distinguishes from the "exit 2 with empty stdout" argument-error case; an absolute
one holding `medium` yields `refuse` / exit **1**; an absolute one at `xhigh` yields `pass` /
exit **0**. "No" and "I don't know" stay distinguishable in code and in payload. The new branch
can only move a result toward 2, never toward 0 (section 3, point 3).

**4 — all paths between tiers absolute: PASS, and this is the invariant the round fixed.** The
caveat the first review logged is gone: no non-absolute string can leave `foreman_settings_chain`
now, asserted at chain level (three assertions, `:335-340`) and at gate level (`no relative path
appears anywhere in the gate's JSON output`, `:380-381`). Reproduced live.

**5 — no TODO/TBD/FIXME under skills/agents/commands: PASS (untouched).** No `.md` under those
trees is in the diff.

**6 — harness scripts invoked by bare wrapper name: PASS.** No new call site in `skills/`,
`agents/` or `commands/`. `chain_all`'s `source "$FOREMAN_ROOT/scripts/lib.sh"` is a test-side
source of a library that is not one of the five wrappers, and `resolve-gate.sh:3` sources it by
path itself; `"$gate"` is the file's pre-existing pattern from `:5`.

**7 — suite green, not below baseline: PASS.** I ran `bash tests/run.sh` myself in the worktree:
**623 passed, 0 failed**, exit 0, `jq` = mise shim. 623 = 616 + 7 new assertions (1 full-chain,
3 relative chain-level, 3 relative gate-level); the M1 relabel and the M3 regex widening add
none. `POLICY.md`'s `baseline-count: 610` is untouched and 623 clears it.

**8 — 100-column body prose in shipped markdown: N/A.** The diff touches no markdown. For
completeness, no *added* line in any of the three files exceeds 100 columns (checked over the
cumulative diff's `+` lines); the remaining long lines in these files are pre-existing.

---

## 5. Correctness — what input could produce a wrong result

I could not construct one. Checked, each against the real gate or the real chain:

- relative, dot-relative, and literal-tilde `CLAUDE_CONFIG_DIR`: tier dropped, `unknown`, exit 2,
  `effort_source: null`. Never a `pass`.
- relative `HOME` with no `CLAUDE_CONFIG_DIR`: same.
- empty `CLAUDE_CONFIG_DIR`: falls back to `HOME/.claude` (asserted, and live — `pass` from the
  operator's real file).
- both variables unset: two repo tiers only, `set -u`-safe, project effort still resolves
  (`:128-136`, plus mutation evidence that this block is live).
- absolute with `..` or a trailing slash: emitted as-is; both are absolute strings that resolve
  identically for any reader, so invariant 4 holds. Not canonicalised; disclosed by the report.
- a set-but-nonexistent `CLAUDE_CONFIG_DIR`: the path is in the chain but nothing is at it, so
  the walk continues and ends in `unknown` if nothing else answers. Safe direction.
- values containing glob metacharacters: `case` matches the *word* literally, and it is quoted.

The precedence order itself is unchanged from the first round and remains mutation-proven: I
re-ran the repo-shared-tier deletion (607/16, including two assertions that were silent before)
and the over-strict-guard mutation (large red block). Nothing about the fix round loosened the
ordering.

---

## 6. Test quality

**Every new assertion is mutation-checked, by me, not only by the report.** The four mutations I
ran independently (repo-shared tier deleted; `case` guard reverted; guard made to reject
everything; four `HOME`-redirect shapes appended in situ) reproduce the report's counts exactly
where they overlap — 607/16, 617/6, 622/1 — and name the assertions the report claims. The report
is again faithful; I found no claim in it I could not reproduce.

**The two previously unearned claims now earn themselves.** `with neither variable the chain is
exactly the two repo tiers, in order` fails against the mutation its label names (it did not
exist before, and its predecessor's label survived that mutation). `no test file redirects HOME`
fails against the two-line shape that defeated it, and against two further shapes.

**Both directions are shown for each new claim.** Relative gives no tier (red under the reverted
guard) *and* absolute gives a tier that answers (the pre-existing `write_user` battery, plus the
live absolute row). Guard red on the caught shapes *and* green at 623/0 with none present.

**No test was weakened or deleted.** The only narrowing is `[T1-M1]`'s label, compensated by a
strictly stronger assertion on the whole chain. All four pre-existing `chain_third` assertions
keep their text and their behaviour through the `chain_all` split.

**One vacuity note, not a finding.** `assert_eq "" "$(printf '%s' "$rel_out" | grep -F relcfg ||
true)"` (`:380-381`) would also be green if `$rel_out` were empty — a crashed gate. It cannot be
vacuous in practice, because the companion assertion two lines above requires `$rel_out` to parse
as JSON with `verdict == "unknown"`. Recorded so the pairing is not accidentally broken later.

**One machine-dependence note, not a finding.** The three *gate-level* relative assertions would
also stay green under a "fall back to `HOME`" mutation on a machine whose real
`~/.claude/settings.json` declares nothing. The three *chain-level* ones go red regardless, so
coverage of that mutation is machine-independent overall. (On this machine the fallback mutation
turns the verdict into `pass`, which is why the report saw all four go red.)

### Findings

**[T1-M4] Minor — the `HOME` guard still misses an indented per-command redirect, and its opening
sentence still claims that scope.**
`tests/test_resolve_gate.sh:342-362`. The comment opens "No test file in this suite may redirect
HOME **for a whole file or a whole command scope**", then enumerates what is matched and states
that the one deliberately unmatched shape is an indented bare assignment "scoped to a subshell
that runs no external command". That rationale covers `chain_all`'s `HOME="$2"` but not every
unmatched shape. *Failure scenario, reproduced:* append `  HOME=/tmp/fakehome jq --version
>/dev/null` (indented, a per-command prefix around a real external command — exactly the shim
problem the guard exists to prevent) to `tests/test_baseline_check.sh`; the suite stays **623/0**
and the guard never fires. Also unmatched, by pattern inspection over the 16-shape fixture:
`env HOME=/x cmd` at any indentation, `readonly HOME=/x`, `typeset -x HOME=/x`, and an indented
`HOME=/x; export HOME` on one line. Minor, not Important: the guard now catches every shape a
fixture is realistically written in (all four column-0 forms and every indented
`export`/`declare -x`), the reproduced defect from `[T1-M3]` is closed, and the comment does
enumerate its matches, so a reader is not misled about the mechanism — only the opening clause
over-reaches. Closing it fully means either widening the pattern to any line containing `HOME=`
not preceded by `#` (with a false-positive cost on heredoc fixtures) or bounding the prose; the
cheap fix is to drop "or a whole command scope" from the first sentence and name the excluded
shapes as excluded.

**[T1-M5] Minor — a dropped non-absolute user tier is invisible in the gate's `reason`.**
`scripts/lib.sh:48-50` with `scripts/resolve-gate.sh:80-83`. When the only tier that would have
answered is dropped for being relative, the gate emits `"reason": "no effortLevel found in any
settings file; cannot verify the gate"`. *Failure scenario, reproduced live:* an operator with
`CLAUDE_CONFIG_DIR=relcfg` and `relcfg/settings.json` containing `{"effortLevel":"medium"}` is
told no settings file declared an effort, while the file plainly does — and nothing in the JSON
mentions `CLAUDE_CONFIG_DIR` or absoluteness. Contrast `--repo`, whose non-absolute form dies
with `--repo must be an absolute path, got: …` on stderr (`lib.sh:10-15`): the same class of
input is loudly named in one place and silently ignored in the other. The verdict is not wrong —
`unknown`/2 is correct per section 3, and the program skill turns it into a question for the
human — so this is diagnosability, not correctness. It is also genuinely awkward to fix inside a
pure path printer with no error channel; a one-line note to stderr from `foreman_settings_chain`,
or a distinct `reason` when a non-absolute value was seen, are the shapes to consider. Beyond
this brief; recorded for the backlog.

No Important or Critical test-quality defect. Each of the seven assertions added this round fails
against the mutation it names.

---

## 7. Declared deviations this round — judged

1. **`chain_third` restructured rather than only relabelled. Sound.** The split was needed to
   assert on the whole chain at all (the compensating assertion for `[T1-M1]` cannot be written
   through a `sed -n '3p'` helper), and it has the independent benefit of removing the last
   external command from the fake-`HOME` subshell. All four pre-existing assertions keep their
   text; I verified their behaviour is unchanged by re-running the suite and the mutations that
   target them.
2. **`test_templates.sh` untouched this round. Sound.** No finding concerned it, and its comment
   remains accurate at the level of detail it states.
3. **Two over-long added lines reflowed. Sound.** Invariant 8 binds shipped markdown, so this was
   housekeeping and is declared as such rather than as compliance. The report also re-ran the
   two-line-redirect mutation *after* the reflow (622/1) to prove the split `home_redirect`
   concatenation still matches — the right check after cosmetically splitting a pattern, and I
   confirmed the concatenated pattern behaves as a single ERE.
4. **No `POLICY.md` edit; baseline stays 610. Sound and required** by `POLICY.md:7`. 623 clears
   it.

Round-0 deviations are unchanged and were judged sound in the first review; nothing this round
disturbs them.

## 8. Cannot verify from this diff

- **Behaviour where `jq` is served by an `asdf` (or other) shim rather than `mise`** — in
  particular whether the `unset HOME CLAUDE_CONFIG_DIR` block at
  `tests/test_resolve_gate.sh:128-136`, which still invokes the gate and hence `jq` with `HOME`
  unset, stays green there. Green here; a residual environmental unknown, not a defect. Narrower
  than last round, because the `chain_all` restructure removed the other fake-`HOME`
  external-command site.
- **Whether Claude Code itself resolves a relative `CLAUDE_CONFIG_DIR` against its launch cwd.**
  If it does, the harness is deliberately more conservative than Claude Code for that input.
  Section 3 explains why that is the right trade either way.

## 9. What I ran

- `bash tests/run.sh` in the worktree: `14 files, 623 passed, 0 failed`, exit 0.
- Four mutations in an `rsync` copy of the worktree under the scratchpad (removed afterwards):
  repo-shared tier deleted (607/16); `case` guard reverted to the old presence test (617/6);
  guard made to match nothing (large red block); four `HOME`-redirect shapes appended in turn to
  `tests/test_baseline_check.sh` (622/1, 622/1, 623/0 miss, 623/0 restored).
- Old-vs-new `home_redirect` comparison over a 16-shape fixture under the scratchpad: 1 match vs
  10 (removed afterwards).
- Eight live `scripts/resolve-gate.sh` invocations with `CLAUDE_CONFIG_DIR` relative,
  dot-relative, absolute, tilde-literal, `..`-containing, trailing-slash, empty, and with a
  relative `HOME` — fixtures under `/tmp`, removed afterwards.
- Tree-wide searches for `CLAUDE_CONFIG_DIR`, `foreman_settings_chain`, gate call sites in
  `tests/`, and the `unknown`/exit-2 contract in `skills/`.
- Read-only version-control inspection only (history, short status, index listing, tree listing,
  stat-only diff). **No repository file was created, modified or deleted, and no state-changing
  version-control command was run.**
