#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

s="$FOREMAN_ROOT/skills/foreman-phase/SKILL.md"
g="$FOREMAN_ROOT/skills/foreman-phase/references/gate-chain.md"
c="$FOREMAN_ROOT/commands/phase.md"

for f in "$s" "$g" "$c"; do [ -f "$f" ] || fail "missing $f"; done

skill="$(cat "$s" 2>/dev/null || true)"
gate="$(cat "$g" 2>/dev/null || true)"

# assert_near <text> <marker> <window> <needle> <label>
# Finds the first line containing <marker> (a fixed string) and checks that <needle> occurs in
# the <window> lines STRICTLY AFTER it -- the marker line itself is excluded from the search.
# Round 3's review proved by deletion that including the marker line lets a sentence that
# merely *names* a token (e.g. "It returns `GO` or `NO-GO`") satisfy the assertion on its own,
# with the real branch beneath it never inspected. Excluding the marker line forces the needle
# to come from the branch's own text.
assert_near() {
  local text="$1" marker="$2" window="$3" needle="$4" label="$5"
  local line
  line="$(printf '%s\n' "$text" | grep -nF -- "$marker" | head -1 | cut -d: -f1)"
  if [ -z "$line" ]; then
    fail "$label: marker not found: $marker"
    return
  fi
  local start=$((line + 1))
  local seg
  seg="$(printf '%s\n' "$text" | sed -n "${start},$((line + window))p")"
  assert_contains "$seg" "$needle" "$label"
}

# --- baseline presence checks --------------------------------------------------------------
assert_contains "$skill" "EnterWorktree"        "step 1 enters a worktree"
assert_contains "$skill" "task-brief.sh"        "briefs come from the script"
assert_contains "$skill" "baseline-check.sh"    "baseline gate is wired"
assert_contains "$skill" "foreman-implementer"  "dispatches the implementer agent"
assert_contains "$skill" "foreman-task-reviewer" "dispatches the task reviewer"
assert_contains "$skill" "Ruling:"              "records rulings in the ledger format"
assert_contains "$skill" "state.md"             "writes the phase state file"
assert_contains "$skill" "trust boundary"       "the model table escalates at trust boundaries"
assert_contains "$skill" "Haiku"                "the model table covers the cheap tier"
assert_contains "$skill" "529"                  "the dead-subagent protocol is present"
assert_not_contains "$skill" "sabotage"         "the sabotage protocol is excluded by decision"

# Case-insensitive form of the same exclusion: the case-sensitive check above is satisfied by
# capitalizing the word, which defeats the intent of excluding the concept, not just the token.
skill_lc="$(printf '%s' "$skill" | tr '[:upper:]' '[:lower:]')"
assert_not_contains "$skill_lc" "sabotage" "the sabotage exclusion holds regardless of case"

assert_contains "$gate" "fable-judge"             "adversarial verification is in the chain"
assert_contains "$gate" "foreman-branch-reviewer" "whole-branch review is in the chain"
assert_contains "$gate" "backlog.md"              "backlog flush gate"
assert_contains "$gate" "CONTEXT.md"              "context distillation gate"
assert_contains "$gate" "rebase"                  "rebase before merge"
assert_contains "$gate" "re-run"                  "gates re-run on the rebased tree"

assert_contains "$(cat "$c" 2>/dev/null || true)" "foreman-phase" "command invokes the skill"

# --- ordering: the actual rebase command must precede the actual merge command -------------
# (matching the bare words "rebase"/"merge" anywhere in the file is satisfiable by prose that
# never states the commands in the right order -- round-1 review's I15. This matches the
# literal command lines instead.)
rebase_cmd_line="$(grep -nE '^git( -C [^ ]+)? rebase ' "$g" | tail -1 | cut -d: -f1)"
merge_cmd_line="$(grep -nE '^git( -C [^ ]+)? merge --ff-only ' "$g" | head -1 | cut -d: -f1)"
[ -n "$rebase_cmd_line" ] && [ -n "$merge_cmd_line" ] && [ "$rebase_cmd_line" -lt "$merge_cmd_line" ] \
  && _ok || fail "the git rebase command must precede the git merge --ff-only command"

# --- ordering: the PR-escalation rule must precede the merge commands it overrides ----------
# (round-3 I: the rule was stated after the commands, so a controller reading top to bottom
# would run the merge before learning it might not have been allowed to.)
pr_rule_line="$(grep -n 'If it did, escalate to a' "$g" | head -1 | cut -d: -f1)"
[ -n "$pr_rule_line" ] && [ -n "$merge_cmd_line" ] && [ "$pr_rule_line" -lt "$merge_cmd_line" ] \
  && _ok || fail "the PR-escalation rule must precede the git merge --ff-only command"

# --- exit-code branches: every documented exit code is handled where its script is invoked --
# Markers are the invocation's own unique argument list, not the bare script name (the bare
# name also appears earlier in descriptive prose -- e.g. Step 3 explains why task-brief.sh
# needs the phase directory before Step 4 ever calls it -- so a bare-name marker would find
# that prose first and never reach the actual invocation).
assert_near "$skill" "--plan <abs-plan-dir> --task N" 8 "Exit 0" \
  "task-brief.sh: exit 0 has a stated action"
assert_near "$skill" "--plan <abs-plan-dir> --task N" 8 "Exit 2" \
  "task-brief.sh: exit 2 has a stated action"

assert_near "$skill" "--policy <abs-policy> --count <count-you-observed>" 10 "Exit 0" \
  "baseline-check.sh (per task): exit 0 has a stated action"
assert_near "$skill" "--policy <abs-policy> --count <count-you-observed>" 10 "Exit 1" \
  "baseline-check.sh (per task): exit 1 has a stated action"
assert_near "$skill" "--policy <abs-policy> --count <count-you-observed>" 30 "Exit 2" \
  "baseline-check.sh (per task): exit 2 has a stated action"

assert_near "$skill" "--phase <slug> --branch <branch>" 6 "Exit 0" \
  "phase-state.sh: exit 0 has a stated action"
assert_near "$skill" "--phase <slug> --branch <branch>" 6 "Exit 2" \
  "phase-state.sh: exit 2 has a stated action"

assert_near "$gate" "--policy <abs-policy> --count <observed-branch-count>" 6 "Exit 0" \
  "baseline-check.sh (branch-level): exit 0 has a stated action"
assert_near "$gate" "--policy <abs-policy> --count <observed-branch-count>" 6 "Exit 1" \
  "baseline-check.sh (branch-level): exit 1 has a stated action"
assert_near "$gate" "--policy <abs-policy> --count <observed-branch-count>" 6 "Exit 2" \
  "baseline-check.sh (branch-level): exit 2 has a stated action"

# --- verdict and status tokens: bound to the branch's OWN action text, not a naming sentence -
# Round 3 finding: deleting SKILL.md's Spec/Quality bullets and gate-chain.md's GO/NO-GO
# bullets left the suite green, because the lead-in sentence just above each ("It returns
# `Spec: ...`", "It returns `GO` or `NO-GO`") already names every token the old assertions
# looked for. These now match only the bullet's own stated action.
assert_near "$skill" "It returns one of three statuses" 10 "\`blocked\`" \
  "implementer status blocked has a stated branch"
assert_near "$skill" "It returns one of three statuses" 10 "\`partial\`" \
  "implementer status partial has a stated branch"

assert_contains "$skill" "Spec ✅ and Quality Approved:** go to 6." \
  "task reviewer Approved branch has a stated action (go to 6)"
assert_contains "$skill" "down to a lone Minor:** enter the fix loop." \
  "task reviewer not-approved branch has a stated action (enter the fix loop)"

assert_contains "$gate" "\`GO\`:** proceed to gate 3." \
  "branch reviewer GO branch has a stated action (proceed to gate 3)"
assert_contains "$gate" "\`NO-GO\`:** findings get **one** fix dispatch" \
  "branch reviewer NO-GO branch has a stated action (one fix dispatch and re-review)"

assert_near "$gate" "Record the verdict itself in the ledger" 8 "\`REFUTED\`" \
  "fable-judge REFUTED has a stated branch"
assert_near "$gate" "Record the verdict itself in the ledger" 8 "VERIFIED WITH CAVEATS" \
  "fable-judge VERIFIED WITH CAVEATS has a stated branch"
assert_near "$gate" "Record the verdict itself in the ledger" 8 "\`VERIFIED\`" \
  "fable-judge plain VERIFIED has a stated branch"

# --- gate 3 dispatch contract: fable-judge runs in a subagent, not inline (round-2 I12 fix) --
assert_contains "$gate" "do not invoke \`fable:fable-judge\` yourself" \
  "gate 3 dispatches into a subagent rather than invoking fable-judge inline"
assert_contains "$gate" "Give it four things: the branch name, the merge base" \
  "gate-3 dispatch supplies the branch name and the merge base"
assert_contains "$gate" "the phase directory" \
  "gate-3 dispatch supplies the phase directory"
assert_contains "$gate" "its findings-file path — \`<abs-phase-dir>/branch-judge.md\`" \
  "gate-3 dispatch supplies an explicit findings-file path (its own, not gate 2's)"
assert_near "$gate" "return **only**:" 5 "verdict" \
  "gate-3 dispatch's return contract states the verdict"
assert_near "$gate" "return **only**:" 5 "caveat" \
  "gate-3 dispatch's return contract states the caveats"
assert_near "$gate" "return **only**:" 5 "findings file" \
  "gate-3 dispatch's return contract states the findings-file path"

# --- round-2 fix: state the action for an exit code, never infer a specific cause ----------
assert_contains "$skill" "infer which" \
  "task-level baseline-check.sh exit 2 states the action without inferring a specific cause"
assert_contains "$gate" "infer which" \
  "branch-level baseline-check.sh exit 2 states the action without inferring a specific cause"
assert_not_contains "$skill" "cannot recur mid-phase" \
  "the round-1 false inference (baseline recorded => must be the disagreeing-lines case) is gone"

# --- specific defects from the round-1 review -----------------------------------------------
assert_contains "$skill" "HEAD~1" \
  "the diff-range rule warns against the under-reporting HEAD~1 shortcut"
assert_contains "$skill" "\`<main-checkout>\`: its absolute path (\`git rev-parse --show-toplevel\`)." \
  "the main checkout is captured in Step 1a, for the merge that cannot run from the worktree"
assert_contains "$gate" "git -C <main-checkout> checkout <default>" \
  "the merge runs from the main checkout, not the worktree"
assert_not_contains "$skill" "origin/main" \
  "the worktree fallback no longer hardcodes a literal origin/main"
assert_contains "$gate" "This gate fails if" \
  "gate 5 states a falsifiable failure condition, not only exhortation"

# --- round-3: every placeholder is defined exactly once, before first use ------------------
assert_contains "$skill" "\`<abs-policy>\` = \`<worktree>/docs/dev/program/POLICY.md\`" \
  "abs-policy is defined concretely, as an absolute path under the worktree"
assert_contains "$skill" "\`<abs-plan-dir>\` means \`<worktree>/docs/dev/plans/<slug>/\`" \
  "abs-plan-dir is defined concretely, as an absolute path under the worktree"
assert_not_contains "$skill" "abs-worktree" \
  "the abs-worktree/worktree placeholder inconsistency is resolved to one name"

# --- the harness scripts are invoked by BARE WRAPPER NAME, never by any path ---------------
# Found by installing the plugin and running it (task 10): $CLAUDE_PLUGIN_ROOT is NOT exported
# into the Bash tool's environment, so a call site written as "$CLAUDE_PLUGIN_ROOT/scripts/x.sh"
# expands to "/scripts/x.sh" and fails. Claude Code does put <plugin-root>/bin on PATH, so the
# wrappers there are callable by name. Each needle carries the flag that follows it, so a bare
# prose mention of a wrapper cannot satisfy an assertion about a call site.
assert_contains "$skill" "foreman-brief --plan" \
  "task-brief is invoked by bare wrapper name"
assert_contains "$skill" "foreman-baseline" \
  "baseline-check (per task) is invoked by bare wrapper name"
assert_contains "$skill" "foreman-state" \
  "phase-state is invoked by bare wrapper name"
assert_contains "$gate" "foreman-baseline" \
  "baseline-check (branch level) is invoked by bare wrapper name"

# The anti-pattern must not come back. NO path form is a valid call site any more -- neither a
# bare relative `scripts/x.sh` nor a `$CLAUDE_PLUGIN_ROOT`-prefixed one -- so the detector looks
# for a script path followed by a flag. Both files deliberately NAME the anti-pattern in prose to
# warn against it, and a prose mention carries no arguments, so it is correctly not a hit.
path_call_site() {
  sed -E ':a; /\\$/{N; s/\\\n//; ba}' "$1" 2>/dev/null \
    | grep -oE '[^ `"]*(scripts/[a-z-]+\.sh|bin/harness-[a-z]+)"? +--' || true
}
assert_eq "" "$(path_call_site "$s")" \
  "no path-form script call site survives in the phase skill"
assert_eq "" "$(path_call_site "$g")" \
  "no path-form script call site survives in the gate chain"

# --- round-4: <base> is captured once, positively stated, never recaptured -----------------
assert_contains "$skill" "captured exactly once per task, right here, before this first dispatch" \
  "the base-capture-once invariant is stated positively, not just implied by prohibition"

# --- round-4: the exit-1 reject loop is context-aware -- initial pass vs. inside a fix round -
# (round-3's single branch re-entered at item 2 unconditionally, which both re-captured <base>
# -- silently truncating the diff -- and, when it fired inside a fix round, threw away that
# round's fixer and its context to restart the whole task from a fresh implementer.)
assert_contains "$skill" "On the initial pass (from item 2):" \
  "exit-1 has a distinct branch for the initial pass"
assert_near "$skill" "On the initial pass (from item 2):" 4 "never a re-captured \`<base>\`" \
  "the initial-pass exit-1 branch does not re-capture base"
assert_contains "$skill" "Inside a fix-loop round (item 5):" \
  "exit-1 has a distinct branch for inside a fix round"
assert_contains "$skill" "Inside a fix-loop round (item 5):** return to that round's own fixer" \
  "the fix-round exit-1 branch returns to that round's fixer, not a fresh task implementer"

# --- round-4: the "three rejections" / "third attempt" off-by-one is resolved ---------------
assert_contains "$skill" "A fourth still-below-baseline result is the" \
  "the initial-pass reject cap states its trip condition unambiguously (a fourth failure)"
assert_near "$skill" "Inside a fix-loop round (item 5):" 6 \
  "trips the fix loop's breaker early, this" \
  "the fix-round reject cap states its trip condition unambiguously (a fourth failure)"

# --- round-4 self-review: a retry inside a fix round redoes the round, not just the fixer ---
# (found on the required end-to-end walkthrough, not in the coordinator's list: without this,
# a controller retrying the fixer after a within-round baseline rejection has no stated
# instruction to regenerate the diff and re-run the gate again before the reviewer sees it.)
assert_contains "$skill" "Redo this same round from its top (fixer dispatch," \
  "a within-round baseline retry redoes the whole round, not just the fixer dispatch"
assert_contains "$skill" "not advance item 5's outer round counter" \
  "a within-round baseline retry does not consume one of the outer five rounds"
assert_not_contains "$skill" "third attempt is still below baseline" \
  "the round-3 off-by-one phrasing (three rejections vs. a third attempt) is gone"

# --- round-3: the fix loop's fixer has its own blocked/partial branches, not item 2's -------
assert_near "$skill" "scoped to being mid-fix rather than" 10 "never \"retry from 1\"" \
  "the fix loop's blocked branch does not restart the task from brief generation"
assert_near "$skill" "scoped to being mid-fix rather than" 15 "\`partial\`" \
  "the fix loop's fixer has its own partial branch"

# --- round-4: item 2's blocked-escalate path halts, and now commits before it does ----------
assert_contains "$skill" "a halt that is not committed is invisible to the PM" \
  "item 2's blocked-escalate halt commits the ledger before waiting"

# --- round-4: Step 3's status gloss widened to cover every place blocked is actually set ----
assert_contains "$skill" "a plan defect with no path forward (item 1), an unresolvable invariant" \
  "Step 3's status gloss covers every stop-condition that sets blocked, not only the breaker"

# --- round-4: the gate chain states its own commit points, not just SKILL.md's general rule -
assert_contains "$gate" "Commit the ledger now — gate 6 rebases and merges what is on the" \
  "gate 1 states its own commit point"
assert_contains "$gate" "Commit the ledger now, whichever verdict it was." \
  "gate 3 states its own commit point"
assert_contains "$gate" "Commit \`docs/dev/backlog.md\` and the ledger now" \
  "gate 4 states its own commit point"
assert_contains "$gate" "Commit \`docs/dev/CONTEXT.md\` and the ledger now" \
  "gate 5 states its own commit point"
assert_contains "$gate" "Everything above must already be committed — gates 1, 3, 4 and 5" \
  "gate 6 has a safety-net reminder that everything upstream must be committed"

# --- round-3: every stop path commits the ledger before stopping ---------------------------
assert_near "$skill" "For every other reason it might" 10 "set \`status\` to \`blocked\`, commit" \
  "task-brief.sh's stop path (item 1) commits before stopping"
assert_contains "$skill" "unverified\`, commit" \
  "the baseline-check.sh unverified stop path commits before stopping"
assert_near "$skill" "A Critical or Important survives unresolved" 3 "commit \`<abs-phase-dir>\` exactly as" \
  "the fix-loop breaker's blocked stop path commits before stopping"
assert_contains "$skill" "ledger section, set \`status\` to \`blocked\`, commit \`<abs-phase-dir>\` (a" \
  "the dead-subagent destructive-operation stop path commits before waiting"

# --- round-3: every declared status/verdict value is assigned somewhere in Step 4 -----------
assert_contains "$skill" "with one entry per task the plan's README names" \
  "status: pending is assigned when the ledger is opened"
assert_near "$skill" "For each task, in the plan's order" 3 "in-progress" \
  "status: in-progress is assigned when a task starts"
assert_contains "$skill" "set \`status\` to \`passed\`" \
  "status: passed is assigned on the ordinary close"
assert_contains "$skill" "set \`verdict\` to \`adjudicated\`" \
  "verdict: adjudicated is assigned when the breaker trips"

# --- round-3: the gate-3 "deferred minor" note no longer implies a backlog.md entry ---------
assert_not_contains "$gate" "recorded as a deferred minor" \
  "the gate-3 parenthetical no longer claims a backlog-tracked deferral it never makes"
assert_contains "$gate" "does not belong in \`backlog.md\`" \
  "the gate-3 parenthetical is explicit that it is a design note, not a gate-4 Minor"

# --- round-5: halt-state truthfulness -- every halt assigns a status before it commits ------
# (round 4 widened Step 3's gloss to claim item 2 sets `blocked`, but item 2's own text never
# assigned it -- so a committed halt's ledger still read `status: in-progress`. Found to have
# two siblings: item 1's brief-generation stop, and the dead-subagent recovery's halt branch.)
assert_near "$skill" "For every other reason it might" 10 "set \`status\` to \`blocked\`, commit" \
  "item 1's brief-generation stop assigns status: blocked before it commits"
assert_contains "$skill" "ledger the ruling, set \`status\` to" \
  "item 2's escalate halt assigns status: blocked before it commits"
assert_contains "$skill" "ledger section, set \`status\` to \`blocked\`, commit \`<abs-phase-dir>\` (a" \
  "the dead-subagent halt branch assigns status: blocked before it commits"

# --- round-5: the general rule, stated once, so it cannot be reintroduced site by site ------
assert_contains "$skill" "no path may commit" \
  "the no-halt-commits-as-in-progress rule is stated once, generally"
assert_contains "$skill" "a halt while \`status\` still reads \`in-progress\`" \
  "the general rule names the specific failure mode (a committed halt reading in-progress)"

# --- round-5: Step 3's gloss now names every blocked-setting site, including the two siblings
assert_contains "$skill" "a dead subagent's destructive-operation stop-condition (Failure protocols)" \
  "Step 3's gloss now names the dead-subagent recovery as a blocked-setting site"

# --- round-5: gate 2 is no longer the one gate in the chain without a commit point ----------
assert_contains "$gate" "commit the ledger now — the" \
  "gate 2's NO-GO stop now has a stated commit point"

# --- round-5: dead-subagent recovery routes through item 3's baseline gate, all 3 exit codes -
assert_contains "$skill" "item 3's baseline gate yourself against the worktree, exactly as item 3 specifies" \
  "dead-subagent recovery runs item 3's baseline gate, not just the raw gate commands"
assert_contains "$skill" "On Exit 1 or Exit 2, or if the tree looks like an incoherent partial edit" \
  "dead-subagent recovery's halt branch covers exit 1 and exit 2, not just a binary red/green"

# --- round-5: two small consistency fixes ---------------------------------------------------
assert_not_contains "$skill" "ways to a halt" \
  "the gloss no longer calls deferred a halt when item 5 says it explicitly is not a stop"
assert_contains "$skill" "is not a stop, the task proceeds with its deferrals recorded" \
  "deferred is still explicitly stated as not a stop (unchanged, confirms the fix targeted the gloss)"
assert_contains "$skill" "recapture \`<head>\`, re-diff" \
  "the fix-round redo list qualifies recapture as <head>, not the never-recaptured <base>"

# --- round-5 self-review: the fix-round cap-trip sets status before it commits, not after ---
# (found on the required walkthrough: unlike every sibling halt, this one's prose listed
# "commit ... exactly as item 6 would" before "set status to blocked" -- backwards from what
# the general rule just above requires, and inconsistent with the initial-pass cap-trip and
# item 5's own breaker, both of which already set status first.)
assert_contains "$skill" "case does: set \`status\` to \`blocked\`" \
  "the fix-round cap-trip sets status to blocked before committing, not after"

# --- [I-4] the phase takes its branch from the kickoff instead of discovering it -----------
assert_contains "$skill" 'is **given to you by the kickoff**, not' \
  "the phase treats its branch name as an input"
assert_contains "$skill" 'If the kickoff names no branch, ask before proceeding' \
  "a phase with no agreed branch stops rather than inventing one"
# Needle is matched against the file as one line: written as a raw two-line string it would
# contain a literal backslash-n, never match, and pass unconditionally -- which is what the
# first version of this assertion did.
assert_not_contains "$(tr '\n' ' ' < "$s" | tr -s ' ')" 'the exact branch name that was created' \
  "the discover-and-report-back wording is gone"

# --- [DEP-1] the skills this one hands work to are checked at entry, not discovered at gate 3 -
# gate-chain.md dispatches fable:fable-judge (gate 3) and superpowers:finishing-a-development-
# branch (gate 7). Without a check up front, a session whose operator declined a plugin's trust
# prompt discovers the gap with a finished branch in hand. The check must name each skill it
# depends on, must sit before Step 1, and must tell the session to stop rather than improvise.
step0_line="$(grep -n '^## Step 0 ' "$s" | head -1 | cut -d: -f1)"
step1_line="$(grep -n '^## Step 1 ' "$s" | head -1 | cut -d: -f1)"
if [ -n "$step0_line" ] && [ -n "$step1_line" ] && [ "$step0_line" -lt "$step1_line" ]; then _ok
else fail "foreman-phase has a '## Step 0' heading before '## Step 1' (got step0=$step0_line step1=$step1_line)"; fi
step0_body="$(awk -v a="$step0_line" -v b="$step1_line" 'NR>a && NR<b' "$s" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$step0_body" 'fable:fable-judge' \
  "Step 0 names fable:fable-judge as a dependency"
assert_contains "$step0_body" 'superpowers:finishing-a-development-branch' \
  "Step 0 names superpowers:finishing-a-development-branch as a dependency"
assert_contains "$step0_body" 'fable@fable-method' \
  "Step 0 names the plugin fable-judge comes from, so the operator knows what to install"
assert_contains "$step0_body" 'superpowers@claude-plugins-official' \
  "Step 0 names the plugin the superpowers skills come from"
# [T3-M3] matched against a lowercased copy, not the raw mixed-case text: the raw form pinned a
# sentence-initial capital "Do", so an editor who capitalises that sentence -- ordinary English,
# and exactly what the brief's own Step 3 text did -- broke a green suite over typography with
# no change in meaning. Lowercasing both sides tests the claim, not its capitalisation.
step0_body_lc="$(printf '%s' "$step0_body" | tr '[:upper:]' '[:lower:]')"
assert_contains "$step0_body_lc" 'do not substitute your own procedure' \
  "Step 0 forbids improvising a missing skill's procedure (case-insensitive)"
# [T3-M4] round 2's review closed detection coverage as a target: substring matching is
# polarity-blind, so it cannot tell a fallback from a prohibition of that fallback or from a
# compliant stop -- the same vocabulary marks all three. Proved in-repo, not hypothetically:
# `references/gate-chain.md:64`'s own compliant sentence, "do not invoke `fable:fable-judge`
# **yourself**", collided with round 2's bare 'yourself' marker ([T3-M9]), and a compliant
# resume instruction ("...proceed by starting a fresh phase session") collided with 'proceed
# by'. Widening the marker list trades one more false negative for one more false positive,
# and a false positive is the worse failure: the cheapest way back to green is deleting the
# ruling-reinforcing sentence that tripped it. So this list is not widened again, and is now
# narrowed past round 2's two collisions rather than left to catch more shapes:
# "proceed by running" -- the exact phrase both of round 1's defeating mutations used to
# describe carrying out the missing skill's job in the session's own voice; narrower than bare
# "proceed by" so a compliant resume instruction ("proceed by starting a fresh session") no
# longer collides.
# "yourself:" -- colon-anchored, not bare "yourself": every fallback shape seen across three
# rounds phrases the self-substitution as "... yourself: <steps>", while this repository's own
# compliant prohibition at `gate-chain.md:64` ends the sentence with a period ("yourself."), so
# the colon anchor stops matching it without losing the shapes it was added for.
# "read its rubric from" -- the literal phrase foreman-init's own *sanctioned* fallback for
# `claude-md-management` uses; catches a literal copy of the one fallback this program allows
# into a skill the ruling says must not have one.
#
# What this is, stated plainly so the claim below does not outrun it: a tripwire against the
# specific phrasings named across rounds 1-2, not a detector for the class. A fallback worded
# around these three phrases passes this check with a green suite -- no content-matching
# assertion can close that gap, so the rule is enforced by review, not by the gate. The range
# is this file's Step 0 body only: a degraded path written at a dispatch site the skill merely
# points to (for instance `references/gate-chain.md`'s gate-3 section) is entirely outside it.
for marker in 'proceed by running' 'yourself:' 'read its rubric from'; do
  assert_not_contains "$step0_body_lc" "$marker" \
    "Step 0 does not carry a known self-substitution phrasing (marker: '$marker')"
done
