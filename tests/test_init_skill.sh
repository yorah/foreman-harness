#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

d="$FOREMAN_ROOT/skills/foreman-init"
c="$FOREMAN_ROOT/commands/foreman-init.md"

for f in SKILL.md references/audit-checklist.md references/interview.md \
         references/claude-md-rubric.md; do
  [ -f "$d/$f" ] || fail "missing $d/$f"
done
[ -f "$c" ] || fail "missing $c"

s="$(cat "$d/SKILL.md" 2>/dev/null || true)"
# Prose needles are matched against a whitespace-flattened copy of the file. A raw substring
# match forces the shipped text to wrap so that every needle lands inside one line, which is a
# test constraining the prose it tests rather than checking it ([T9F1-2]). Flattening lets the
# markdown wrap naturally at 100 columns and keeps the needle meaningful.
flow() { tr '\n' ' ' < "$1" | tr -s ' '; }
sf="$(flow "$d/SKILL.md")"
cmd="$(cat "$c" 2>/dev/null || true)"

# Every needle below is asserted in its *longest unique* form. A bare token ("destination",
# "full diff", "claude-md-improver") recurs elsewhere in the file, so deleting the paragraph
# the assertion is labelled for would leave the token behind and the assertion green -- which
# is exactly the self-satisfied assertion this suite exists to prevent. Each needle here was
# mutation-checked against the shipped file: delete or corrupt the one occurrence it names and
# the assertion goes red.
assert_contains "$s" 'foreman-gate --model' \
  "the refusal gate runs first, by bare wrapper name"
assert_contains "$s" '$(foreman-root)/skills/foreman-init/templates/MANIFEST.tsv' \
  "generation is manifest-driven, rooted via foreman-root"
assert_contains "$s" "never in place" "generation goes to a scratch tree first"
assert_contains "$s" "AskUserQuestion"  "the interview uses AskUserQuestion"
assert_contains "$s" 'Run `claude-md-improver` against' "the quality pass is wired"
assert_contains "$s" "it is report-only here" "the quality pass does not write"
assert_contains "$s" "full diff"        "the diff is shown before anything lands"
assert_contains "$s" "Nothing lands"    "the approval gate is explicit"

# [T9-R1] scripts/resolve-gate.sh reports its two exit-2 causes on OPPOSITE streams. Verified
# both directions against the script: a repo with a malformed .claude/settings.local.json gives
# rc=2, the JSON on stdout (effort_source naming that file) and an EMPTY stderr; `--repo
# relative` gives rc=2, an EMPTY stdout and the message on stderr. A skill that sends the
# session to stderr handles only the half it does not describe.
assert_contains "$sf" '**Read the JSON on stdout**, not stderr' \
  "exit 2 sends the session to stdout, where the effort-unreadable JSON actually is"
assert_contains "$sf" 'exit `2` **with empty stdout** is the other case' \
  "the empty-stdout case is the argument error, and is the session's own to fix"

# [T9-R2] The interview offers three AGENTS.md answers; without a branch here, Step 3 emits the
# pointer template whatever the user chose and the answer is silently discarded.
assert_contains "$s" "ln -s CLAUDE.md AGENTS.md" \
  "Step 3 honours the symlink answer the interview offers"
# [T9-R2] The other half of the same rule: docs/dev/ has no variable behind it, so it must not
# be asked about at all rather than asked and ignored.
assert_contains "$s" '**`docs/dev/` is fixed, and is not an interview question.**' \
  "Step 3 states the doc home is not negotiable"

# [DIST-1] The marketplace is a GitHub source declared in settings.json.tmpl, so generation
# has no machine-specific path to look up and Step 3 must not send the session to
# known_marketplaces.json or ask the user for a checkout path.
assert_not_contains "$s" "known_marketplaces.json" \
  "Step 3 no longer looks up a marketplace checkout path"
assert_not_contains "$s" "FOREMAN_MARKETPLACE_PATH" \
  "Step 3 no longer substitutes a marketplace path variable"
assert_contains "$sf" "no template needs a machine-specific path" \
  "Step 3 states why the marketplace source needs no lookup"

# [T9-R6] grep and find both fall into the `||` branch on a path that does not exist, so
# without this precondition a mistyped scratch path prints a confident double all-clear.
assert_contains "$s" "[ -d <scratch-tree> ] ||" \
  "the leak check refuses to report clean when it could not look"

# [T9-R7] Nothing in foreman-program or foreman-phase reads the templates directory, so the
# summary must not promise that /program and /phase instantiate these files.
assert_contains "$s" "neither skill reads the templates directory today" \
  "the carved-out rows are not credited to wiring that does not exist"

# [T9-R9] The version is on the plugin side, not in the repository being initialised.
assert_contains "$s" ".claude-plugin/plugin.json" \
  "Step 5 names where the harness version is read from"

# NO path form is a valid call site (invariant 6): not a bare relative `scripts/x.sh`, not a
# $CLAUDE_PLUGIN_ROOT-prefixed one, and not a path to the wrapper either. A call site is a
# script or wrapper name
# followed by a flag; a bare prose mention of a script has no arguments and is not a defect.
# The sed pass first joins `\`-continued lines, so a call site split across a continuation is
# scanned as one line rather than slipping past the same-line pattern.
# Verified against every shipped .md before this assertion was written: zero false positives.
path_call_site() {
  sed -E ':a; /\\$/{N; s/\\\n//; ba}' "$1" 2>/dev/null \
    | grep -oE '[^ `"]*(scripts/[a-z-]+\.sh|bin/harness-[a-z]+)"? +--' \
    || true
}
assert_eq "" "$(path_call_site "$d/SKILL.md")" \
  "no path-form script call site in SKILL.md"
assert_eq "" "$(path_call_site "$c")" \
  "no path-form script call site in commands/foreman-init.md"

# The templates ship with the plugin too, so every reference to a file under them is qualified
# for the same reason the scripts are: written as a bare path it resolves inside the repo being
# initialised, where no such directory exists -- and this repo is the one place that defect is
# invisible.
#
# [T9-R4] Anchored to a *file* path -- `templates/` plus at least one path character -- not to
# the bare directory, exactly as the scripts guard requires a following ` --`. Naming the
# directory in prose ("the plugin's `templates/` directory") is not a defect, and the previous
# form flagged it, which is why the shipped prose had been bent around the assertion. Uses the
# same `\`-continuation join as the scripts guard, and is applied to the command file too.
templates_path_form() {
  sed -E ':a; /\\$/{N; s/\\\n//; ba}' "$1" 2>/dev/null \
    | grep -oE '[^ `"]*skills/foreman-init/templates/[A-Za-z0-9._/-]+' \
    | grep -v 'foreman-root' || true
}
assert_eq "" "$(templates_path_form "$d/SKILL.md")" \
  "no unrooted templates path in SKILL.md"
assert_eq "" "$(templates_path_form "$c")" \
  "no unrooted templates path in commands/foreman-init.md"

# The two rules a plausible SKILL.md omits, each anchored to the sentence that states it.
assert_contains "$s" 'whose **destination** contains' \
  "the manifest carve-out is by destination, not by mode"
assert_contains "$s" "-name '*{{*'" \
  "the leak check covers path segments, not only file contents"

# Step order: gate, audit, interview, generate, quality, diff.
# Anchored to the *heading* of each step, not to the bare string "Step N": the body of one step
# legitimately refers to another by number ("say so in the Step 5 summary"), and matching that
# forward reference would order the steps by where they are mentioned rather than where they are.
order() { grep -n "$1" "$d/SKILL.md" | head -1 | cut -d: -f1; }
g="$(order 'foreman-gate')"; a="$(order '^## Step 1')"; i="$(order '^## Step 2')"
gen="$(order '^## Step 3')"; q="$(order '^## Step 4')"; df="$(order '^## Step 5')"
if [ -n "$g$a$i$gen$q$df" ] && [ "$g" -lt "$a" ] && [ "$a" -lt "$i" ] \
   && [ "$i" -lt "$gen" ] && [ "$gen" -lt "$q" ] && [ "$q" -lt "$df" ]; then
  _ok
else
  fail "SKILL.md steps must run gate < audit < interview < generate < quality < diff"
fi

au="$(cat "$d/references/audit-checklist.md" 2>/dev/null || true)"
# Each key is asserted through the one heading or sentence that owns the concern, so that
# deleting that section actually fails the assertion. The bare keyword recurs across sections
# and would survive the deletion.
assert_contains "$au" "## 1. Stack and build system"  "audit covers: build system"
assert_contains "$au" "A gate command that is already red" "audit covers: gate command"
assert_contains "$au" 'Existing `.claude/` assets'    "audit covers: .claude"
assert_contains "$au" "an invariant with a test behind it" "audit covers: invariant"
assert_contains "$au" "current green **test count**"  "audit covers: test count"
assert_contains "$au" "Remote, **default branch**"    "audit covers: default branch"
assert_contains "$au" 'a separate list headed **"could not settle"**' \
  "the audit reports its own gaps"
assert_contains "$au" "report it as a **finding**, not as something to ask about" \
  "a conflicting doc convention is a finding, not an interview question"

iv="$(cat "$d/references/interview.md" 2>/dev/null || true)"
assert_contains "$iv" "only what the audit"           "interview asks only unsettled things"
assert_contains "$iv" "**Trust boundaries.** Which surfaces escalate" \
  "interview covers: trust boundaries"
assert_contains "$iv" "merge and push policy"         "interview covers: push"
assert_contains "$iv" "**Baseline.** Confirm"         "interview covers: Baseline"
# [T9-R2] Removed, not reworded: every docs/dev/... destination in MANIFEST.tsv is a literal,
# so an answer here could not change what Step 3 emits. The audit reports a conflicting doc
# convention as a finding instead (asserted below).
assert_not_contains "$iv" "Doc home" \
  "the doc-home question is gone, because generation cannot honour a non-default answer"
assert_contains "$iv" '**`AGENTS.md` policy.**'       "interview covers: AGENTS.md"
assert_contains "$iv" "Every answer must land somewhere on disk" \
  "interview answers are written down, not left in the conversation"

ru="$(cat "$d/references/claude-md-rubric.md" 2>/dev/null || true)"
assert_contains "$ru" "A warning must carry its why" \
  "the rubric protects a warning's reason"
assert_contains "$ru" "Invariants are numbered" \
  "the rubric keeps invariant numbering, which dispatches quote"

assert_contains "$cmd" '`foreman-init` skill' "the command routes to the skill"
assert_contains "$cmd" "refusal gate first"   "the command orders the gate first"
