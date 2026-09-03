#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

s="$FOREMAN_ROOT/skills/foreman-program/SKILL.md"
m="$FOREMAN_ROOT/skills/foreman-program/references/milestones.md"
c="$FOREMAN_ROOT/commands/program.md"
st="$FOREMAN_ROOT/commands/program-status.md"

for f in "$s" "$m" "$c" "$st"; do [ -f "$f" ] || fail "missing $f"; done

skill="$(cat "$s" 2>/dev/null || true)"

# Prose needles are matched against a whitespace-flattened copy of the file. A raw substring
# match forces the shipped text to wrap so that every needle lands inside one line, which is a
# test constraining the prose it tests rather than checking it ([T9F1-2]). Flattening lets the
# markdown wrap naturally at 100 columns and keeps the needle meaningful.
flow() { tr '\n' ' ' < "$1" | tr -s ' '; }
skillf="$(flow "$s")"

# The scripts ship with the plugin, so every call site must be qualified. Asserting the
# bare basename would pass on the exact bug this checks for: in *this* repository a
# relative `scripts/resolve-gate.sh` resolves, so the defect is invisible here and fatal
# everywhere else. Assert the bare wrapper name, then assert no path form survives.
assert_contains "$skill" 'foreman-gate --model' \
  "the refusal gate is invoked through the plugin root"
assert_contains "$skill" 'foreman-state --phase' \
  "the ledger read is invoked through the plugin root"

# Every path-form *call site*. A call site is the script or wrapper name followed by a flag;
# a bare prose mention of the script by name has no arguments and is not a defect.
# Verified against the three shipped foreman-phase files (no false positive) and
# against a planted bare call (one hit) -- including the same-line and the
# line-continuation forms (`script.sh \` + newline + `  --flag`), the latter being the one
# foreman-phase actually uses for its longer invocations (see task-brief.sh's dispatch).
path_call_site() {
  # Join a `\`-continued line with what follows before scanning, so a call site split
  # across a line continuation still matches the same-line pattern below.
  sed -E ':a; /\\$/{N; s/\\\n//; ba}' "$1" 2>/dev/null \
    | grep -oE '[^ `"]*(scripts/[a-z-]+\.sh|bin/harness-[a-z]+)"? +--' \
    || true
}
for f in "$s" "$st" "$c"; do
  assert_eq "" "$(path_call_site "$f")" "no path-form call site in $(basename "$f")"
done

assert_contains "$skill" "Do not write or edit code." "the PM does not write code"
assert_contains "$skill" "fable:fable-method"      "fable-method is wired in by full name"
# Anchor on the code-fence content, not the bare token: a stray prose mention of "an `AUTH:`
# line" elsewhere satisfies a bare "AUTH:" needle without the gate block it refers to existing
# at all -- verified by deleting "## The authorization gate" wholesale and getting a green
# suite until this was anchored to text that occurs only inside that block.
assert_contains "$skill" 'AUTH: user said'   "the authorization gate is present"
assert_contains "$skill" "superpowers:brainstorming" \
  "brainstorming is wired in by full name, not merely mentioned"
assert_contains "$skill" "superpowers:writing-plans" \
  "writing-plans is wired in by full name, not merely mentioned"
# [G4]: anchored on the section's own thesis sentence, not the bare "foreman-probe" token --
# [F2a]'s worktree-is-gone bullet mentions "foreman-probe" twice more in prose about git
# hygiene, which cross-satisfies the bare token even with the whole section this assertion is
# labelled for deleted (mutation-verified). "Your leverage is the behavioural probe" occurs
# only at the top of that section.
assert_contains "$skill" "Your leverage is the behavioural probe" "verification is by probe"
# "STATE.md" alone occurs many times across the file (it's the entry point, referenced
# throughout) and would still pass with the whole "read STATE.md first" section deleted --
# anchor on the heading unique to that specific claim instead.
assert_contains "$skill" "Then read exactly three things" "state index is the entry point"

# 1 and 2 mean different things everywhere in this system; the gate is the first place a
# session meets that, and a skill that collapses them refuses on an unreadable setting.
# Anchored on the Step-0 bullet lines themselves, not the bare "exit `1`"/"exit `2`" tokens:
# [F1]/[F7]'s own new prose in the verifying section and the exit-2 refinement re-uses both
# tokens, which cross-satisfies a bare-token needle even with Step 0's own bullets deleted
# (mutation-verified).
assert_contains "$skill" 'exit `1` — **refuse**' "the gate distinguishes a refusal"
assert_contains "$skill" 'exit `2` — it could not reach a verdict' \
  "the gate distinguishes an unreadable effort"

# [T9-R1] The two exit-2 causes report on *opposite streams*, so a skill that sends the session
# to one of them handles only half the cases. Verified against scripts/resolve-gate.sh, both
# directions: a repo whose .claude/settings.local.json is malformed gives rc=2 with the JSON on
# stdout and an EMPTY stderr (effort_source names the file); `--repo relative` gives rc=2 with
# an EMPTY stdout and the message on stderr. The previous wording here conditioned the
# ask-the-user branch on "the stderr says the effort itself could not be read", which stderr
# never says, so a literal reading never reached that branch at all.
assert_contains "$skillf" 'Read the JSON on stdout first' \
  "exit 2 sends the session to stdout, where the effort-unreadable JSON actually is"
assert_contains "$skillf" 'effort_source` names the settings file' \
  "exit 2 names the field that identifies the file it read"
assert_contains "$skillf" 'exit `2` **with empty stdout** is an argument error' \
  "the empty-stdout case is the argument error, and is the session's own to fix"

assert_contains "$skill" "claude --model"    "the launch block names the model"
assert_contains "$skill" "**Effort**"        "the launch block names the effort in its own field"
assert_contains "$skill" "not a guess"       "the model id may not be inferred"
# [F3]: "EnterWorktree" alone occurs twice once the probe section names the exact path
# EnterWorktree(name: "<slug>") created -- deleting the kickoff rule this needle is labelled
# for still leaves the suite green (mutation-verified). Anchor on the clause unique to the
# kickoff rule instead.
assert_contains "$skill" "worktree command; the phase session makes its own" \
  "the kickoff creates the worktree, not the human"
assert_not_contains "$skill" "git worktree add" \
  "the human is not handed a worktree command"

# [T3-M5] this file used to tell the PM "the kickoff's own first step is
# EnterWorktree(name: ...)" -- the same cross-file contradiction [T3-M1] found in the
# template, one file over: foreman-phase's actual first step, since [DEP-1], is Step 0's
# dependency check, not EnterWorktree. A PM that trusts this line writes a self-contained
# kickoff (SKILL.md:117-118,:160) whose first action is EnterWorktree and which never mentions
# Step 0 -- the [T3-M1] failure, reached through the PM instead of the template.
# [T3-M12] the positive needles below are matched with markdown emphasis (`*...*`) stripped
# from both the extract and the needle, not against the raw asterisks: the load-bearing content
# is the action/tool-call distinction, not the italics, so a compliant reword that drops the
# emphasis (e.g. "the kickoff's first action is...") must not redden this test.
skillf_noemph="$(printf '%s' "$skillf" | tr -d '*')"
assert_not_contains "$skillf" "kickoff's own first step is \`EnterWorktree" \
  "the PM is no longer told EnterWorktree is the kickoff's first step (unqualified)"
assert_contains "$skillf_noemph" \
  "kickoff's own first action is \`foreman-phase\` Step 0's dependency check" \
  "the PM is told Step 0's dependency check is the kickoff's first action"
assert_contains "$skillf_noemph" "its first tool call is \`EnterWorktree" \
  "the PM is told EnterWorktree is only the kickoff's first tool call, not its first action"

# [C2]: the probe section must name which tree to run in, not merely gesture at worktrees --
# the tree path itself is the load-bearing token; deleting the naming bullets restores the
# original defect with a green suite unless this is anchored.
assert_contains "$skill" ".claude/worktrees/" "the probe is told which tree to run in"

# [I3]: also a cross-file drift detector against scripts/resolve-gate.sh's own threshold
# (rank -ge 3, i.e. "high" and above) -- if the script's threshold ever moves without this
# prose moving with it, this needle is where the divergence surfaces.
assert_contains "$skill" 'at or above `high`' \
  "the gate's pass criterion is stated, not just its exit codes"

# [F1] (coordinator-requested 6th assertion): SKILL.md carries its own copy of the
# branch-existence guard (the "no ledger on branch" message means two different things until
# the branch is confirmed real), separate from program-status.md's copy that [C1] already
# guards via $status. Nothing asserted this one -- deleting SKILL.md's guard wholesale left the
# suite green (mutation-verified) -- which is exactly the [F1] failure mode (one observation,
# two verdicts) re-appearing silently if the two copies ever drift. Anchor on the mechanism,
# not the wording: the origin/-ref existence check is the one line only the guard contains.
# Matched against the flattened copy: this needle is a shell invocation long enough to wrap,
# and a raw match forces the shipped paragraph to break in a place that suits the test rather
# than the reader -- which it did, the first time this paragraph was re-flowed ([T9F1-2]).
assert_contains "$skillf" 'rev-parse --verify --quiet origin/<branch>' \
  "the skill's own not-started/unreadable guard checks the remote branch, not just the local one"

# [I4]: one loop over the contract foreman-phase actually writes (skills/foreman-phase/SKILL.md
# Step 3), not one needle in prose -- the PM needs a branch for every status a phase can report.
# A bare backtick-wrapped word is cross-satisfied by generic prose that only names the statuses
# ("if the summary reports `blocked`, `deferred`, or `unverified` status...") and survives
# deleting the actual branch instructions (mutation-verified) -- anchor on each status's own
# bold branch-header instead. `blocked` and `deferred` share one header in this document (the
# PM's job is identical for both), so they share a needle; `unverified` gets its own.
declare -A _phase_status_needle=(
  [blocked]='`blocked` or `deferred`:**'
  [deferred]='`blocked` or `deferred`:**'
  [unverified]='`unverified`:**'
)
for phase_status in blocked deferred unverified; do
  assert_contains "$skill" "${_phase_status_needle[$phase_status]}" \
    "the PM has a branch for a phase that reports $phase_status"
done

mile="$(cat "$m" 2>/dev/null || true)"
assert_contains "$mile" "unprompted"   "milestones are self-announced"
assert_contains "$mile" "HISTORY.md"   "finished material moves to history"
assert_contains "$mile" "startup prompt" "handover produces a startup prompt"

status="$(cat "$st" 2>/dev/null || true)"
# Anchored on the qualified call site with its flags, not the bare "phase-state.sh" token:
# [F1]'s own new prose in this file ("`phase-state.sh` reads the ledger with a single `git
# show`...") mentions the script by name too, which cross-satisfies a bare needle even with the
# actual invocation deleted (mutation-verified).
assert_contains "$status" 'foreman-state --phase <slug> --head' \
  "status command uses the script"
assert_contains "$status" "git fetch"      "status refreshes before trusting a local STATE.md"
# [C1]/[F1]/[G1]: exit 2 that is not a missing ledger must not be folded into "not started" --
# anchored on the "any other reason" bullet's own text, not the bare "unreadable -- " token:
# [F1]'s own branch-existence guard prose also emits "unreadable -- " (a different message, for
# a different case), which cross-satisfies the bare token even with this bullet deleted
# (mutation-verified). "it means the opposite" occurs only in this bullet.
assert_contains "$status" "it means the opposite" \
  "exit 2 that is not a missing ledger is not 'not started'"

# --- [I-4] the branch name is an input the PM chooses at dispatch, not a phase output ------
# Cross-task gap found by the whole-branch review: `foreman-state` resolves a running phase
# through STATE.md's Branch column, but the branch name was something only the phase discovered
# and only reported when it finished. Every mid-flight read exited 2 for exactly as long as it
# could have been useful. Reproduced before the fix:
#   foreman-state --phase <running> --repo <root> --head
#   -> phase '<running>' has no row in .../STATE.md   exit=2
assert_contains "$skill" 'branch name now: `feat/<slug>`' \
  "the PM names the branch itself rather than waiting to be told"
assert_contains "$skillf" '`STATE.md` row **in the same commit**' \
  "the STATE.md row is written at dispatch, not on return"
assert_contains "$skillf" 'Edit that row in place; do not append a second row' \
  "the return path edits the existing row rather than adding a second"

# --- [M-A] a dispatched-but-not-launched phase is `planned`, not `unreadable` ---------------
# [I-4] has the program manager write a phase's STATE.md row at dispatch, which opens a window
# between the row existing and the phase session creating its branch. Both triage tables used to
# route the resulting exit 2 to `unreadable — <stderr>`, which is the wrong word for the one
# state the dispatch sequence guarantees will occur every time a phase is launched. The STATE.md
# Status column is what tells the two apart, so both files must consult it rather than reporting
# a single verdict for the branch simply being absent.
statusf="$(flow "$st")"
assert_contains "$skillf" '`planned` means exactly that, so say `planned, not yet launched`' \
  "the skill reports a dispatched-but-not-launched phase as planned"
assert_contains "$statusf" '`planned` means exactly that, so print `planned, not yet launched`' \
  "the status command reports a dispatched-but-not-launched phase as planned"

# The other direction. Without this, both assertions above are satisfied by a file that reports
# `planned, not yet launched` for every absent branch -- including a phase that reached
# `executing` and lost its branch, which is a genuine anomaly and the case the original
# `unreadable` wording existed to catch.
for f in "$skillf" "$statusf"; do
  assert_contains "$f" 'must have had a branch' \
    "an absent branch on a phase past planned is still an anomaly, not planned"
done

# --- [DEP-1] the PM's own dependencies are checked in Step 0, next to the refusal gate --------
# foreman-program sends the interview to superpowers:brainstorming, the plan to
# superpowers:writing-plans, and its operating loop to fable:fable-method. The check sits inside
# Step 0 (before "## Then read exactly three things") so a missing plugin stops the session
# before it has read STATE.md and formed intentions it cannot carry out.
step0_line="$(grep -n '^## Step 0 ' "$s" | head -1 | cut -d: -f1)"
next_line="$(grep -n '^## Then read exactly three things' "$s" | head -1 | cut -d: -f1)"
if [ -n "$step0_line" ] && [ -n "$next_line" ] && [ "$step0_line" -lt "$next_line" ]; then _ok
else fail "foreman-program Step 0 precedes the three-file read (got step0=$step0_line next=$next_line)"; fi
step0_body="$(awk -v a="$step0_line" -v b="$next_line" 'NR>a && NR<b' "$s" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$step0_body" '### Dependencies' \
  "Step 0 carries a Dependencies subsection"
for dep in 'fable:fable-method' 'superpowers:brainstorming' 'superpowers:writing-plans'; do
  assert_contains "$step0_body" "$dep" "Step 0 names $dep as a dependency"
done
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
# assertion can close that gap, so the rule is enforced by review, not by the gate. Scoped to
# the `### Dependencies` subsection itself, not the wider Step 0 extract, so this cannot be
# satisfied by unrelated text in the refusal gate above it -- and, symmetrically, a degraded
# path written anywhere this skill dispatches to (outside `### Dependencies`) is entirely
# outside this guard's range.
deps_line="$(grep -n '^### Dependencies' "$s" | head -1 | cut -d: -f1)"
deps_body="$(awk -v a="$deps_line" -v b="$next_line" 'NR>a && NR<b' "$s" | tr '\n' ' ' | tr -s ' ')"
deps_body_lc="$(printf '%s' "$deps_body" | tr '[:upper:]' '[:lower:]')"
for marker in 'proceed by running' 'yourself:' 'read its rubric from'; do
  assert_not_contains "$deps_body_lc" "$marker" \
    "Dependencies subsection does not carry a known self-substitution phrasing (marker: '$marker')"
done
