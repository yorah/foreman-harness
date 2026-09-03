#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

R="$FOREMAN_ROOT"

# --- the generated layout exists ------------------------------------------
for f in CLAUDE.md AGENTS.md README.md \
         docs/dev/README.md docs/dev/CONTEXT.md docs/dev/backlog.md \
         docs/dev/program/POLICY.md docs/dev/program/STATE.md \
         docs/dev/program/RULINGS.md docs/dev/program/DEFERRED.md \
         docs/dev/program/HISTORY.md .claude/settings.json; do
  [ -f "$R/$f" ] || fail "dogfood did not produce $f"
done

# --- nothing unsubstituted ------------------------------------------------
# Scoped to files /foreman-init GENERATED, never to all of docs/dev/. Four authored documents
# there carry `{{` legitimately and always will: `backlog.md` and three plan files document
# template variables, and you cannot document a variable without writing it. A sweep over the
# directory fails on correct content and would be "fixed" by mangling the prose.
# `backlog.md` is a `mode: create` destination that already existed before this run, so it is
# authored here rather than generated, and is excluded for that reason.
gen_files=""
for f in CLAUDE.md AGENTS.md docs/dev/README.md docs/dev/CONTEXT.md \
         docs/dev/program/POLICY.md docs/dev/program/STATE.md \
         docs/dev/program/RULINGS.md docs/dev/program/DEFERRED.md \
         docs/dev/program/HISTORY.md .claude/settings.json; do
  [ -f "$R/$f" ] && gen_files="$gen_files $R/$f"
done
# /dev/null is a sentinel operand: with no generated files yet, `$gen_files` is empty and a
# bare `grep -ln '{{'` reads STDIN and hangs forever. /dev/null never matches, so the check
# behaves identically once files exist and terminates when none do.
# shellcheck disable=SC2086
leftover="$(grep -ln '{{' /dev/null $gen_files 2>/dev/null || true)"
assert_eq "" "$leftover" "no unsubstituted {{VARIABLES}} in generated files"

# An unsubstituted variable survives in a PATH as readily as in a body, and a content grep
# never sees it -- the same defect one tier up that task 9's leak check had to be widened for.
leftover_path="$(find "$R/docs/dev/program" "$R/.claude" -name '*{{*' 2>/dev/null || true)"
assert_eq "" "$leftover_path" "no unsubstituted {{VARIABLES}} in generated path segments"

# --- POLICY is machine-readable and agrees with reality -------------------
policy="$R/docs/dev/program/POLICY.md"
baseline="$(grep -m1 -E '^[[:space:]]*baseline-count:' "$policy" 2>/dev/null \
  | grep -oE '[0-9]+' | head -1)"
[ -n "$baseline" ] || fail "POLICY.md has no baseline-count"

# What this can and cannot check, stated plainly because the first version of it was a
# tautology that shipped. It read `baseline` out of POLICY.md and fed that same number back as
# `--count`, so count always equalled baseline and the assertion passed for ANY value --
# verified after the fact: `baseline-count: 999999` left the suite at 556 passed, 0 failed.
#
# A test running INSIDE the suite cannot know the suite's own total; that comparison is a
# gate-chain step, where `foreman-baseline --count <reported>` takes the count from a real
# completed run. What is checkable here is that POLICY records a usable threshold, and that
# the threshold discriminates -- so it is checked in BOTH directions against fixed offsets,
# which a wrong baseline cannot satisfy by construction.
# `baseline` is extracted with `grep -oE '[0-9]+'`, so it is digits or empty by construction and
# a "not a number" arm could never fire -- it would be dead code wearing the shape of a check.
# What IS reachable, and is a real defect, is a baseline of zero: it parses, and it silently
# permits any regression at all.
if [ -n "$baseline" ] && [ "$baseline" -gt 0 ]; then _ok
else fail "POLICY.md baseline-count must be greater than zero, got [$baseline]"; fi
assert_exit 0 "baseline-check accepts a count at the recorded baseline" -- \
  "$R/bin/foreman-baseline" --policy "$policy" --count "$baseline"
assert_exit 1 "baseline-check rejects a count one below the recorded baseline" -- \
  "$R/bin/foreman-baseline" --policy "$policy" --count "$((baseline - 1))"

# --- settings declare the harness's own dependencies ----------------------
s="$R/.claude/settings.json"
for p in "foreman@foreman" "superpowers@claude-plugins-official" "fable@fable-method"; do
  assert_eq "true" "$(jq -r --arg k "$p" '.enabledPlugins[$k] // "false"' "$s" 2>/dev/null)" \
    "settings enable $p"
done
assert_eq "fresh" "$(jq -r '.worktree.baseRef' "$s" 2>/dev/null)" "worktree base ref is fresh"
assert_eq "github" "$(jq -r '.extraKnownMarketplaces.foreman.source.source' "$s" 2>/dev/null)" \
  "this repository's own settings declare the foreman marketplace as a github source"
assert_eq "yorah/foreman-harness" "$(jq -r '.extraKnownMarketplaces.foreman.source.repo' "$s" 2>/dev/null)" \
  "this repository's own settings name the published harness repository"
# [T4-M3] All three needles test_templates.sh guards on CLAUDE.md.tmpl, applied to this
# repository's own copy -- the file a contributor to THIS repository actually reads, and the one
# the dogfood test exists to keep honest. Guarding one here and three there let a reintroduced
# `--scope local` or settings.local.json step land in this file and leave the suite green.
own_claude_md="$(cat "$R/CLAUDE.md" 2>/dev/null || true)"
assert_not_contains "$own_claude_md" "known_marketplaces.json" \
  "this repository's CLAUDE.md no longer sends contributors to known_marketplaces.json"
assert_not_contains "$own_claude_md" "--scope local" \
  "this repository's CLAUDE.md no longer registers a local-directory marketplace"
assert_not_contains "$own_claude_md" "settings.local.json" \
  "this repository's CLAUDE.md no longer describes a machine-specific settings file"

# --- CLAUDE.md carries what the harness needs it to -----------------------
c="$(cat "$R/CLAUDE.md" 2>/dev/null || true)"
assert_contains "$c" "worktree"           "CLAUDE.md states the worktree rule"
assert_contains "$c" "/program"           "CLAUDE.md names the program command"
assert_contains "$c" "docs/dev/README.md" "CLAUDE.md points at the doc layout"

# --- AGENTS.md is a pointer, not a copy -----------------------------------
a="$(cat "$R/AGENTS.md" 2>/dev/null || true)"
assert_contains "$a" "CLAUDE.md" "AGENTS.md points at CLAUDE.md"
if [ -f "$R/AGENTS.md" ] && [ "$(wc -l < "$R/AGENTS.md")" -le 12 ]; then
  _ok
else
  fail "AGENTS.md should be a pointer, not a copy"
fi

# --- STATE.md parses as the phase index -----------------------------------
assert_contains "$(cat "$R/docs/dev/program/STATE.md" 2>/dev/null || true)" \
  "| Phase | Owner | Branch |" "STATE.md carries the parseable phase table header"
assert_exit 2 "an unknown phase is a clean exit-2, not a crash" -- \
  "$R/scripts/phase-state.sh" --repo "$R" --phase no-such-phase

# --- gitignore keeps the ledger tracked -----------------------------------
gi="$(cat "$R/.gitignore" 2>/dev/null || true)"
assert_contains     "$gi" "*.diff"    "regenerable diffs are ignored"
assert_not_contains "$gi" "docs/dev"  "the design record is never gitignored"

# The one true `mode: evolve` row in this repository: the additions must fold in without
# dropping what was already there. `/.superpowers/` is absent from gitignore-additions.txt,
# so it can only survive if evolve merged rather than replaced.
assert_contains "$gi" "/.superpowers/" "evolve kept the pre-existing gitignore entries"
