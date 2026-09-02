# Task 1 report — user settings tier through `CLAUDE_CONFIG_DIR`

Worktree: `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites`
Brief: `docs/dev/program/phases/prerequisites/task-1-brief.md`

## What changed, per file

### `scripts/lib.sh` — `foreman_settings_chain` only

The user tier is now the settings file in the directory Claude Code itself reads user-level
configuration from: `$CLAUDE_CONFIG_DIR` when set and non-empty, else `$HOME/.claude`, else no
user tier is emitted at all. The two repo-scoped paths are still printed from their own
`printf`, so an environment with neither variable still yields both of them (invariant: a bare
`"$HOME/..."` argument would abort the whole `printf` under a caller's `set -u` and silently
lose every path). Function signature unchanged; no caller changed. The leading comment was
rewritten to state the new precedence and why tests must steer this tier through
`CLAUDE_CONFIG_DIR` rather than by redirecting `HOME`.

`lib.sh` still carries no `set` line (invariant 2 exemption for sourced libraries), uses only
bash builtins (invariant 1), and the chain still prints absolute paths (invariant 4).

### `tests/test_resolve_gate.sh`

- Fixture setup: `export HOME="$tmp/home"` replaced by `export CLAUDE_CONFIG_DIR="$tmp/home/.claude"`,
  with the comment the brief specifies explaining the shim problem. `write_user` still writes to
  `$tmp/home/.claude/settings.json` and was left alone.
- The `unset HOME` block became `unset HOME CLAUDE_CONFIG_DIR` with the two assertion labels
  renamed — two assertions in, two out, so the count is unchanged by this edit.
- Appended six new assertions: one gate-level attribution check (`effort_source` names the
  `CLAUDE_CONFIG_DIR` file), four `chain_third` precedence/fallback checks on
  `foreman_settings_chain`'s third line in a controlled subshell, and one suite-wide guard that
  no `tests/test_*.sh` contains a column-0 `export HOME=`.

### `tests/test_templates.sh`

One comment only: the third tier is now named `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`.
No assertion changed. The comment paragraph was reflowed so the lines stay under 100 columns, and
"in the operator's home directory" became "in the operator's own user settings" because the
directory is no longer necessarily `$HOME` — see deviations.

## Commands run and their output

Baseline, at the base commit, before any edit (see the environment deviation below for why the
`GIT_CONFIG_GLOBAL=/dev/null` half of the ruled prefix is absent):

```
$ env PATH="/usr/bin:$PATH" bash tests/run.sh
14 files, 610 passed, 0 failed
$ bash tests/run.sh
14 files, 522 passed, 88 failed
```

Step 2 — tests written, implementation not yet in:

```
$ env PATH="/usr/bin:$PATH" bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
  FAIL: opus + medium refuses: expected [refuse], got [pass]
  FAIL: refusal exits 1: expected [1], got [0]
  FAIL: no settings anywhere is unknown: expected [unknown], got [pass]
  FAIL: unknown exits 2: expected [2], got [0]
  FAIL: unrecognised effort is unknown, not refuse: expected [unknown], got [pass]
  FAIL: unrecognised effort exits 2: expected [2], got [0]
  FAIL: the user tier that answered is the CLAUDE_CONFIG_DIR file: [/tmp/tmp.Etd.../home/.claude/settings.json] not found
  FAIL: CLAUDE_CONFIG_DIR names the user tier when set, even with HOME set: expected [/cfg/settings.json], got [/h/.claude/settings.json]
14 files, 608 passed, 8 failed
```

That is the expected reason exactly: the fixture no longer sets `HOME`, so with the old chain the
gate read the operator's real `~/.claude/settings.json` (`effortLevel: xhigh`) and every
`write_user`-driven verdict flipped to `pass`; the two new user-tier assertions failed directly.
All eight failures came from `test_resolve_gate.sh`; no other file failed.

Step 4 — both gate runs after the implementation:

```
$ env PATH="/usr/bin:$PATH" bash tests/run.sh
14 files, 616 passed, 0 failed        (exit 0)

$ bash tests/run.sh
14 files, 616 passed, 0 failed        (exit 0)
$ command -v jq
/home/yorah/.local/share/mise/shims/jq
```

616 = 610 baseline + 6 appended assertions; the rewritten `unset` block is 2-for-2. The plain,
unprefixed run — the point of this task — is green with `jq` served by the mise shim, so the 88
failures are gone. The 12 `tests/test_phase_state.sh` failures the brief warns about did **not**
appear on this machine in either run: the plain baseline run was 522/88, all 88 from
`test_resolve_gate.sh`, so signed commits are evidently working here. Nothing about task 2 was
touched.

Reality check outside the suite (the gate binary itself, not its tests), with a fake user config
dir and an empty fake repo:

```
$ CLAUDE_CONFIG_DIR=/tmp/.../cfg scripts/resolve-gate.sh --model opus --repo /tmp/.../repo
{ "verdict": "refuse", "effort": "medium",
  "effort_source": "/tmp/.../cfg/settings.json", ... }        exit 1
$ scripts/resolve-gate.sh --model opus --repo /tmp/.../repo
{ "verdict": "pass", "effort": "xhigh",
  "effort_source": "/home/yorah/.claude/settings.json", ... } exit 0
```

Both precedence branches behave as specified against a real gate invocation, and the exit-code
contract (invariant 3) holds: 1 for the definite refusal, 0 for the pass.

## Step 5 — mutation checks

| Mutation | Result |
|---|---|
| `user_dir="${CLAUDE_CONFIG_DIR:-}"` → `user_dir=""` | red: `CLAUDE_CONFIG_DIR names the user tier when set, even with HOME set` and `the user tier that answered is the CLAUDE_CONFIG_DIR file`, plus the six collateral fixture assertions — 608/8. Restored. |
| `user_dir="$HOME/.claude"` → `user_dir="$HOME/.nowhere"` | red: `without CLAUDE_CONFIG_DIR the user tier is HOME/.claude/settings.json` and `an empty CLAUDE_CONFIG_DIR falls back to HOME rather than yielding /settings.json` — 614/2. Restored. |
| `export HOME="$tmp"` added at column 0 to `tests/test_baseline_check.sh` | red: `no test file redirects HOME (use CLAUDE_CONFIG_DIR for the user tier)`, naming that file — 615/1. Restored (`git status` confirms the file is unmodified). |

Suite green at 616/0 again after every restore, before committing.

## Deviations

1. **The ruled gate prefix could not be used verbatim.** This session's sandbox refuses any
   command that sets `GIT_CONFIG_GLOBAL`, with: "this command sets `GIT_CONFIG_GLOBAL`, injecting
   git configuration whose effect on where git writes can't be verified." I therefore ran gate 1
   as `env PATH="/usr/bin:$PATH" bash tests/run.sh`. That run is **610 passed, 0 failed** at the
   base commit — identical to the count the kickoff records for the full prefix — so the
   `GIT_CONFIG_GLOBAL` half was a no-op on this machine and the ruled baseline is unaffected. I
   did not relitigate the ruling; I could not execute it as written.
2. **`test_templates.sh` comment wording.** Beyond the phrase the brief names, I changed
   "in the operator's home directory" to "in the operator's own user settings" and reflowed the
   paragraph to stay under 100 columns (the substituted phrase is 26 characters longer than what
   it replaced). Comment-only; no assertion touched.
3. **The brief's step 2 predicted a failure labelled `CLAUDE_CONFIG_DIR beats HOME when both name
   a settings file`.** No assertion by that name exists in the block step 1 dictates; the
   equivalent one is `CLAUDE_CONFIG_DIR names the user tier when set, even with HOME set`, and it
   did fail as predicted. I followed the assertion text the brief actually specifies.
4. **`POLICY.md`'s `baseline-count: 610` was left alone**, per its own instruction that a phase
   session never edits it. 616 > 610, so the runner's baseline gate passes.

## Not verified

- Behaviour on a machine where `jq` is an `asdf` shim rather than `mise`: the fix removes the
  `HOME` dependency entirely, so the mechanism is machine-independent, but only the mise case was
  observed here.
- Whether Claude Code's own resolution order for `CLAUDE_CONFIG_DIR` has further subtleties (for
  example a relative value, or a value pointing at a nonexistent directory) beyond "the directory
  holding `settings.json`". `foreman_settings_chain` reproduces the documented shape; a relative
  `CLAUDE_CONFIG_DIR` would yield a relative chain entry, which no assertion covers and which the
  brief did not ask for.
- The 12 `test_phase_state.sh` failures described in the environment note were never reproduced,
  so I cannot confirm they are what task 2 will see.

---

# Fix round 1 — [T1-M1], [T1-M2], [T1-M3]

Review: `docs/dev/program/phases/prerequisites/task-1-review.md` (Spec PASS / Quality Approved,
three Minors). All three addressed. Gate 1 ran **plain** this round, as instructed; floor 616.

## What changed, per file

### `tests/test_resolve_gate.sh`

**[T1-M1] — the assertion that did not check its own second clause.** `chain_third` was split:
`chain_all` now prints the whole chain inside the controlled subshell and `chain_third` filters
its third line *downstream of the pipe*, so the `sed` no longer runs under the modified `HOME`
at all (a side benefit: nothing but shell builtins and the sourced library ever executes with a
fake `HOME`, which is the property the whole task exists to establish). The old assertion's label
was narrowed to `with neither variable the chain has no user tier` — that is all `sed -n '3p'`
can speak for — and the clause it used to claim is now a separate assertion on the whole output,
`with neither variable the chain is exactly the two repo tiers, in order`, compared against a
`repo_tiers` literal.

**[T1-M2] — relative paths, test side.** Three chain-level assertions (relative
`CLAUDE_CONFIG_DIR` yields no user tier; the two repo tiers survive it intact; a relative `HOME`
likewise yields no user tier) and a gate-level end-to-end block: a *real* relative
`CLAUDE_CONFIG_DIR` holding a usable `{"effortLevel":"medium"}`, invoked from `$tmp` with an
absolute `--repo`, must give `unknown`, exit 2, and no occurrence of `relcfg` anywhere in the
emitted JSON. That last one is the invariant-4 claim stated directly against the gate's output
rather than against the printer.

**[T1-M3] — the guard regex now matches its prose.** `^export HOME=` became two alternatives,
built in a `home_redirect` variable so the line stays readable:

```
^(export[[:space:]]+|declare[[:space:]]+-x[[:space:]]+)?HOME=
|^[[:space:]]*(export|declare[[:space:]]+-x)[[:space:]]+HOME([=[:space:]]|$)
```

That covers a column-0 assignment with or without an `export`/`declare -x` keyword, and an
`export`/`declare -x` of `HOME` at any indentation with or without a value — so the reviewer's
two-line "assign at column 0, then plain `export HOME`" shape is caught on *either* line. The
comment above it was rewritten to state exactly that, including the one shape deliberately left
out and why: an indented bare assignment such as `chain_all`'s own `HOME="$2"`, which is scoped
to a subshell that (after the M1 restructure) runs no external command. Claim and check now
describe the same set from both sides.

### `scripts/lib.sh` — `foreman_settings_chain` only

The user tier is emitted only when the directory it resolves to is absolute:

```bash
  case "$user_dir" in
    /*) printf '%s\n' "$user_dir/settings.json" ;;
  esac
```

replacing `if [ -n "$user_dir" ]`. One `case`, no new external command (invariant 1), no `set`
line added (invariant 2), still `set -u`-safe.

**Why drop the tier rather than absolutise it or fall back.** Three candidate fixes:

1. *Resolve the relative value against `$PWD`.* Rejected: the file's established convention for
   a non-absolute path is refusal, not repair — `resolve-gate.sh` puts `--repo` through
   `foreman_require_abs`, which exits 2 rather than resolving. Repairing here would make the
   chain's answer depend on the caller's cwd, which is the thing invariant 4 is about.
2. *Fall back to `$HOME/.claude`.* Rejected, and mutation-tested as the dangerous option: with
   that behaviour, a relative `CLAUDE_CONFIG_DIR` plus this operator's real `~/.claude`
   (`xhigh`) turns the gate's verdict from `refuse` into **`pass`** — an unverified pass sourced
   from a file the operator never pointed Claude Code at. The run below records it.
3. *Emit no user tier.* Chosen. The repo tiers still outrank and still answer; when nothing else
   answers the gate says `unknown` / exit 2, which invariant 3 defines as "cannot determine" —
   the safe direction for a gate whose failure mode of concern is an unverified `pass`. It also
   preserves the reviewer's confirmed second-order property: a set `CLAUDE_CONFIG_DIR` never
   silently defers to `HOME`.

`foreman_require_abs`-style *dying* was not used: `foreman_settings_chain` is a pure path printer
with no exit contract of its own, and making it exit 2 would change the contract of every caller.

The function's comment gained a paragraph stating the rule and this reasoning.

## Commands run, and their output

**Before the fixes — each defect reproduced as a green assertion that should have been red.**

`[T1-M1]`, with `"$1/.claude/settings.json"` deleted from the chain in `scripts/lib.sh`:

```
$ bash tests/run.sh | grep -cE 'neither variable'      # among the FAIL lines
0
$ bash tests/run.sh | tail -2
14 files, 602 passed, 14 failed
```

14 other assertions catch the deletion; the one whose label claims "still prints the two repo
tiers" does not — the reviewer's row 5, reproduced exactly. Restored.

`[T1-M3]`, with the reviewer's two-line redirect appended to `tests/test_baseline_check.sh`
(`HOME=/tmp/...` at column 0, then `export HOME`):

```
$ bash tests/run.sh | tail -2
14 files, 616 passed, 0 failed
```

Green — the guard never fires. The reviewer's row 6, reproduced exactly. Restored.

`[T1-M2]` — the new assertions written first, `lib.sh` not yet touched:

```
$ bash tests/run.sh | grep -E 'FAIL|files,'
  FAIL: a relative CLAUDE_CONFIG_DIR yields no user tier rather than a relative path: expected [], got [relcfg/settings.json]
  FAIL: a relative CLAUDE_CONFIG_DIR leaves the two repo tiers intact and adds nothing: expected [/r/.claude/settings.local.json
  FAIL: a relative HOME yields no user tier rather than a relative path: expected [], got [rel/.claude/settings.json]
  FAIL: a relative CLAUDE_CONFIG_DIR is cannot-determine, not a verdict from an unresolvable path: expected [unknown], got [refuse]
  FAIL: a relative CLAUDE_CONFIG_DIR exits 2: expected [2], got [1]
  FAIL: no relative path appears anywhere in the gate's JSON output: expected [], got [  "effort_source": "relcfg/settings.json",]
14 files, 617 passed, 6 failed
```

Failing for exactly the reported reason, including the reviewer's literal
`"effort_source": "relcfg/settings.json"`. The M1 and M3 assertions were already green at this
point, as they must be — their subject is the test file, not `lib.sh`.

**After the fixes:**

```
$ bash tests/run.sh
14 files, 623 passed, 0 failed        (exit 0, jq = mise shim)
```

623 = 616 + 7 (1 for M1's full-chain assertion, 6 for M2's three chain-level and three
gate-level ones; M1's label change and M3's regex change add none). Above the 616 floor.

**Reality check, outside the suite** — same directory, given relatively and then absolutely:

```
$ cd /tmp/.../relcheck && CLAUDE_CONFIG_DIR=relcfg .../resolve-gate.sh --model opus --repo .../repo
{ "verdict": "unknown", "effort": null, "effort_source": null,
  "reason": "no effortLevel found in any settings file; cannot verify the gate" }   exit 2
$ cd /tmp/.../relcheck && CLAUDE_CONFIG_DIR=/tmp/.../relcfg .../resolve-gate.sh --model opus --repo .../repo
{ "verdict": "refuse", "effort": "low",
  "effort_source": "/tmp/.../relcheck/relcfg/settings.json" }                       exit 1
```

The relative form is now "cannot determine" with a `null` source; the absolute form still reads
the very same file and refuses on it, so the fix removed the relative path from the contract
without removing the tier's function.

## Mutation checks — one per changed or added assertion

| Mutation | Result |
|---|---|
| `"$1/.claude/settings.json"` deleted from the chain | **607/16** — red: `with neither variable the chain is exactly the two repo tiers, in order` **and** `a relative CLAUDE_CONFIG_DIR leaves the two repo tiers intact and adds nothing`. Before this round the same mutation left the corresponding label green (602/14). Restored. |
| `local user_dir="${CLAUDE_CONFIG_DIR:-}"` becomes `local user_dir="/leak"` (a user tier appears with neither variable set) | **584/39** — red: `with neither variable the chain has no user tier`, `with neither variable the chain is exactly the two repo tiers, in order`, `CLAUDE_CONFIG_DIR names the user tier when set, even with HOME set`. The narrowed label still earns its keep. Restored. |
| the `case "$user_dir" in /*)` guard reverted to `if [ -n "$user_dir" ]` | **617/6** — red: all six M2 assertions, with `effort_source` back to `relcfg/settings.json` and exit 1. Restored. |
| the guard kept, but a non-absolute value made to fall back to HOME (`[ -z "$user_dir" ]` becomes `[ "${user_dir#/}" = "$user_dir" ]`) | **619/4** — red: `a relative CLAUDE_CONFIG_DIR yields no user tier ...`, `... leaves the two repo tiers intact ...`, and both gate-level ones, where the verdict becomes **`pass`** (exit 0) off the operator's real `~/.claude`. This is the "no silent fallback" direction, and the run is the evidence for rejecting option 2 above. Restored. |
| column-0 `HOME=/x` + `export HOME` appended to `tests/test_baseline_check.sh` | **622/1** — red, naming that file. (Green before this round.) Restored. |
| indented `  export HOME=/x` appended | **622/1** — red, naming that file. Restored. |
| `declare -x HOME=/x` appended | **622/1** — red, naming that file. Restored. |
| column-0 `export HOME="$tmp"` appended (the shape the old regex already caught) | **622/1** — red; no regression in the shape that already worked. Restored. |

Both directions for the guard: red on each of the four shapes, green (623/0) with none present.
Direct comparison of the two patterns over a five-line fixture holding all the shapes: old regex
matches 1 line, new regex matches 5.

After the final cosmetic reflow of two over-long lines, the two-line redirect mutation was re-run
(**622/1**, red) to prove the split `home_redirect` concatenation still matches, then restored.
`git status` after every restore shows only `scripts/lib.sh` and `tests/test_resolve_gate.sh`
modified; `tests/test_baseline_check.sh` is byte-identical to its committed state.

## Deviations this round

1. **`chain_third` was restructured, not just relabelled.** [T1-M1] could have been closed by a
   label change alone. Splitting it into `chain_all` + a downstream filter was needed anyway to
   assert on the whole chain, and it removes the last external command (`sed`) that ran under a
   fake `HOME` — the residual worry the reviewer logged in section 8. All four pre-existing
   `chain_third` assertions keep their text and their behaviour.
2. **`test_templates.sh` was not touched this round** — no finding concerned it.
3. **Two added lines exceeded 100 columns and were reflowed** (the `home_redirect` pattern, split
   across two appends; the `rel_out` gate invocation, continued onto a second line). Invariant 8
   binds shipped markdown only, and two pre-existing lines in this file are already over — the
   reflow is housekeeping, not a claim that the invariant applied.
4. **No `POLICY.md` edit.** The baseline stays `610`; 623 is above it.

## Not verified, this round

- Whether Claude Code itself resolves a relative `CLAUDE_CONFIG_DIR` against the cwd. If it does,
  the gate is now deliberately *more* conservative than Claude Code for that input: it declines
  to answer rather than reading the file Claude Code would. That is the trade invariant 4 forces,
  and the operator sees `unknown` / exit 2 rather than a wrong verdict — but it is a divergence,
  not a match, and it is stated here rather than assumed away.
- A `CLAUDE_CONFIG_DIR` whose value is absolute but contains a `..` segment (e.g. `/a/../b`): it
  passes the `/*` guard and is emitted as-is. POSIX resolves it identically for the caller, so no
  relative path escapes, but the emitted string is not canonicalised.
- The `asdf`-shim question from round 0 is unchanged and still unobservable here.
