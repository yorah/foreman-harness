# Brief: task 1

Generated from `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites/docs/dev/plans/2026-09-02-prerequisites/task-1.md`. Do not read the rest of the plan.

| | |
|---|---|
| Worktree (absolute) | `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites` |
| Plan constraints | `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites/docs/dev/plans/2026-09-02-prerequisites/README.md` |
| Policy and invariants | `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites/docs/dev/program/POLICY.md` |
| Write your report to | `/home/yorah/projects/foreman-harness/.claude/worktrees/prerequisites/docs/dev/program/phases/prerequisites/task-1-report.md` |

All paths above are absolute. Resolve every relative path in the task body
against the worktree, not against your working directory.

---

# Task 1: User settings tier through `CLAUDE_CONFIG_DIR`

**Plan:** `docs/dev/plans/2026-09-02-prerequisites/README.md` — shared constraints and the task
table. Read its "Environment note" before running any gate command.

**Files:**
- Modify: `scripts/lib.sh` — `foreman_settings_chain` only
- Modify: `tests/test_resolve_gate.sh` — the fixture setup near the top, the `unset HOME` block,
  and new assertions at the end
- Modify: `tests/test_templates.sh` — one comment that names `$HOME/.claude/settings.json`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `foreman_settings_chain <repo-root>` prints, most specific first,
  `<root>/.claude/settings.local.json`, `<root>/.claude/settings.json`, then the user tier:
  `$CLAUDE_CONFIG_DIR/settings.json` when `CLAUDE_CONFIG_DIR` is set and non-empty, else
  `$HOME/.claude/settings.json` when `HOME` is set and non-empty, else no user tier at all. No
  caller's signature changes. `resolve-gate.sh`'s `effort_source` names whichever file answered.

**Why this exists.** `CLAUDE_CONFIG_DIR` is the variable Claude Code itself honours for the
directory that holds `settings.json`. Today the gate reads `$HOME/.claude/settings.json`
unconditionally, so for anyone who sets `CLAUDE_CONFIG_DIR` the gate reads a file Claude Code is
not using. The same gap forced `tests/test_resolve_gate.sh` to redirect `HOME` to control the
user tier, and a redirected `HOME` breaks any `jq` served by a tool-manager shim (mise looks for
its installs under `HOME`), which is 88 failures on the planning machine. One seam fixes both.

---

- [ ] **Step 1: Write the failing tests**

In `tests/test_resolve_gate.sh`, replace the fixture setup

```bash
# A fake repo and a fake HOME, so the chain is fully controlled.
mkdir -p "$tmp/repo/.claude" "$tmp/home/.claude"
export HOME="$tmp/home"
```

with

```bash
# A fake repo and a fake user config dir, so the chain is fully controlled. The user tier is
# steered through CLAUDE_CONFIG_DIR, the variable Claude Code itself honours, and never by
# redirecting HOME: on a machine where `jq` is a tool-manager shim (mise, asdf), the shim
# resolves its binary through HOME, so a fake HOME turns every gate call into an empty result
# and 88 assertions here go red for a reason that has nothing to do with the gate.
mkdir -p "$tmp/repo/.claude" "$tmp/home/.claude"
export CLAUDE_CONFIG_DIR="$tmp/home/.claude"
```

`write_user` already writes to `$tmp/home/.claude/settings.json`; leave it.

Replace the `unset HOME` block

```bash
# --- fix round 1: unset HOME must not break the chain for repo-scoped tiers
clear_all; write_project high
(
  unset HOME
  assert_eq "pass" "$(run opus | jq -r .verdict)" \
    "HOME unset still resolves a valid project-tier effort"
  assert_eq "0" "$(code opus)" "HOME unset with a valid project effort still exits 0"
)
```

with

```bash
# --- fix round 1: no user tier at all must not break the chain for repo-scoped tiers
clear_all; write_project high
(
  unset HOME CLAUDE_CONFIG_DIR
  assert_eq "pass" "$(run opus | jq -r .verdict)" \
    "HOME and CLAUDE_CONFIG_DIR unset still resolves a valid project-tier effort"
  assert_eq "0" "$(code opus)" "no user tier with a valid project effort still exits 0"
)
```

Append at the end of the file:

```bash
# --- phase A task 1: the user tier is CLAUDE_CONFIG_DIR first, then $HOME/.claude -----------
# Gate level: the file that answered is the CLAUDE_CONFIG_DIR one, attributed through
# effort_source, so a chain that silently read $HOME's file cannot pass by coincidence of values.
clear_all; write_user high
assert_contains "$(run opus | jq -r .effort_source)" "$tmp/home/.claude/settings.json" \
  "the user tier that answered is the CLAUDE_CONFIG_DIR file"

# Chain level: foreman_settings_chain is a pure path printer, so its precedence and fallback are
# asserted on its output directly, in a subshell with a controlled environment. This is
# deliberately NOT done by pointing the gate at a redirected HOME: that is the shim problem the
# top of this file describes, and it would make these assertions fail on exactly the machines
# they exist to protect.
chain_third() {  # chain_third <CLAUDE_CONFIG_DIR value or -unset-> <HOME value or -unset->
  (
    if [ "$1" = "-unset-" ]; then unset CLAUDE_CONFIG_DIR; else export CLAUDE_CONFIG_DIR="$1"; fi
    if [ "$2" = "-unset-" ]; then unset HOME; else HOME="$2"; fi
    source "$FOREMAN_ROOT/scripts/lib.sh"
    foreman_settings_chain /r | sed -n '3p'
  )
}
assert_eq "/cfg/settings.json" "$(chain_third /cfg /h)" \
  "CLAUDE_CONFIG_DIR names the user tier when set, even with HOME set"
assert_eq "/h/.claude/settings.json" "$(chain_third -unset- /h)" \
  "without CLAUDE_CONFIG_DIR the user tier is HOME/.claude/settings.json"
assert_eq "/h/.claude/settings.json" "$(chain_third '' /h)" \
  "an empty CLAUDE_CONFIG_DIR falls back to HOME rather than yielding /settings.json"
assert_eq "" "$(chain_third -unset- -unset-)" \
  "with neither variable the chain has no user tier and still prints the two repo tiers"

# No test file in this suite may redirect HOME at the top level, the shape the old fixture had.
# The reason is the shim problem described at the top of this file; the check is here so the
# next fixture that needs a controlled user tier is steered to CLAUDE_CONFIG_DIR by a red
# assertion rather than by a code review.
assert_eq "" "$(grep -lE '^export HOME=' "$FOREMAN_ROOT"/tests/test_*.sh 2>/dev/null || true)" \
  "no test file redirects HOME (use CLAUDE_CONFIG_DIR for the user tier)"
```

- [ ] **Step 2: Run the tests to verify they fail for the expected reason**

Run, from the worktree root:

```bash
env PATH="/usr/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null bash tests/run.sh 2>&1 | grep -E 'FAIL|files,'
```

Expected: the new assertions fail. Because `lib.sh` still reads `$HOME/.claude/settings.json`
and the fixture no longer sets `HOME`, the whole file's `write_user`-driven assertions read the
operator's real user settings, so expect many `FAIL` lines from this file, including
`CLAUDE_CONFIG_DIR beats HOME when both name a settings file`. Any `FAIL` from another file is
not expected; stop and read it.

- [ ] **Step 3: Implement the change in `scripts/lib.sh`**

Replace the `foreman_settings_chain` function and its comment:

```bash
# foreman_settings_chain <repo-root> — settings paths, most specific first.
# The user tier is the settings file in the directory Claude Code itself reads its user-level
# configuration from: $CLAUDE_CONFIG_DIR when that is set and non-empty, else $HOME/.claude. It
# is emitted only when one of the two is set, and from a separate printf than the repo-scoped
# paths, so an environment with neither never prevents the repo-scoped paths from being produced
# (a bare, unconditional "$HOME/..." argument would abort the whole printf under a caller's
# `set -u`, silently losing every path, not just the user one). Tests steer this tier through
# CLAUDE_CONFIG_DIR, never by redirecting HOME: a redirected HOME breaks a `jq` served by a
# tool-manager shim, which resolves its binary through HOME.
foreman_settings_chain() {
  printf '%s\n' \
    "$1/.claude/settings.local.json" \
    "$1/.claude/settings.json"
  local user_dir="${CLAUDE_CONFIG_DIR:-}"
  if [ -z "$user_dir" ] && [ -n "${HOME:-}" ]; then
    user_dir="$HOME/.claude"
  fi
  if [ -n "$user_dir" ]; then
    printf '%s\n' "$user_dir/settings.json"
  fi
}
```

In `tests/test_templates.sh`, the comment that begins `# effortLevel: resolve-gate.sh walks`
names `$HOME/.claude/settings.json` as the third tier. Change that phrase to
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`. It is a comment; no assertion changes.

- [ ] **Step 4: Run the gate commands**

```bash
env PATH="/usr/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null bash tests/run.sh 2>&1 | tail -3
```

Expected: `14 files, 616 passed, 0 failed` (610, plus 6 from the appended block; the rewritten
`unset` block replaces two assertions with two) and exit 0. If the count differs, count the
assertions you added rather than adjusting expectations.

Then the plain run, which is the point of this task on the planning machine:

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: the same count, `0 failed`, exit 0, with `jq` resolving to a mise shim. If this run
fails while the prefixed one passes, the file still depends on `HOME` somewhere; find it before
committing.

- [ ] **Step 5: Mutation-check the new assertions**

Temporarily change `user_dir="${CLAUDE_CONFIG_DIR:-}"` to `user_dir=""` in `lib.sh` and run the
suite: `CLAUDE_CONFIG_DIR names the user tier when set, even with HOME set` and `the user tier
that answered is the CLAUDE_CONFIG_DIR file` must both go red. Restore. Temporarily replace the
fallback `user_dir="$HOME/.claude"` with `user_dir="$HOME/.nowhere"`: `without CLAUDE_CONFIG_DIR
the user tier is HOME/.claude/settings.json` must go red. Restore. Temporarily add a line
`export HOME="$tmp"` at column 0 to any test file: the `no test file redirects HOME` assertion
must go red. Restore. Run the suite once more, green, before committing.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib.sh tests/test_resolve_gate.sh tests/test_templates.sh
git commit -m "lib: user settings tier follows CLAUDE_CONFIG_DIR; tests no longer redirect HOME"
```
