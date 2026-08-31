#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

a="$FOREMAN_ROOT/agents"

for n in foreman-implementer foreman-task-reviewer foreman-branch-reviewer foreman-probe; do
  [ -f "$a/$n.md" ] || fail "missing agent definition: $n.md"
done

# The tools: frontmatter line is what actually grants write access, so the write-tool
# checks are anchored there rather than scanning the whole file for the words "Edit"/
# "Write" -- a whole-file scan bans ordinary English in the prose along with the tool.
tools_line() { grep -m1 '^tools:' "$1" 2>/dev/null || true; }

impl="$(cat "$a/foreman-implementer.md" 2>/dev/null || true)"
assert_contains "$impl" "task-N-report.md"  "implementer names its report file"
assert_contains "$impl" "absolute"          "implementer states the absolute-path rule"
assert_contains "$impl" "Never read the plan" "implementer is forbidden the plan"
assert_contains "$impl" "## Return"          "implementer has a Return section"

impl_tools="$(tools_line "$a/foreman-implementer.md")"
[ -n "$impl_tools" ] || fail "implementer has no tools: line"
assert_contains "$impl_tools" "Write" "implementer's tools: line grants Write"
assert_contains "$impl_tools" "Edit"  "implementer's tools: line grants Edit"

tr_="$(cat "$a/foreman-task-reviewer.md" 2>/dev/null || true)"
assert_contains "$tr_" "task-N-review.md"    "task reviewer names its findings file"
assert_contains "$tr_" "verdict"             "task reviewer speaks of verdicts"
assert_contains "$tr_" "No reasoning"        "task reviewer is told to omit reasoning"
assert_contains "$tr_" "cannot verify"       "task reviewer has the unverifiable category"

tr_tools="$(tools_line "$a/foreman-task-reviewer.md")"
[ -n "$tr_tools" ] || fail "task reviewer has no tools: line"
assert_not_contains "$tr_tools" "Edit"  "task reviewer's tools: line has no Edit"
assert_not_contains "$tr_tools" "Write" "task reviewer's tools: line has no Write"

br="$(cat "$a/foreman-branch-reviewer.md" 2>/dev/null || true)"
assert_contains "$br" "model: opus"          "branch reviewer pins opus"
assert_contains "$br" "invariant"            "branch reviewer checks the invariants"
assert_contains "$br" "## Return"            "branch reviewer has a Return section"
assert_contains "$br" "stated first"         "branch reviewer states its verdict first"
assert_contains "$br" "No reasoning"         "branch reviewer is told to omit reasoning"
assert_contains "$br" "review file"          "branch reviewer writes its findings to a file"

br_tools="$(tools_line "$a/foreman-branch-reviewer.md")"
[ -n "$br_tools" ] || fail "branch reviewer has no tools: line"
assert_not_contains "$br_tools" "Edit"  "branch reviewer's tools: line has no Edit"
assert_not_contains "$br_tools" "Write" "branch reviewer's tools: line has no Write"

pr="$(cat "$a/foreman-probe.md" 2>/dev/null || true)"
assert_contains "$pr" "10 lines"             "probe caps its output"

pr_tools="$(tools_line "$a/foreman-probe.md")"
[ -n "$pr_tools" ] || fail "probe has no tools: line"
assert_not_contains "$pr_tools" "Edit"  "probe's tools: line has no Edit"
assert_not_contains "$pr_tools" "Write" "probe's tools: line has no Write"

# Every agent must forbid inheriting conversation history.
for n in foreman-implementer foreman-task-reviewer foreman-branch-reviewer; do
  assert_contains "$(cat "$a/$n.md" 2>/dev/null || true)" "conversation" \
    "$n addresses conversation context"
done
