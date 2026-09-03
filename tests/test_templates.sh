#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

t="$FOREMAN_ROOT/skills/foreman-init/templates"
mf="$t/MANIFEST.tsv"
[ -f "$mf" ] || fail "missing $mf"

# Header shape. Built with printf: a literal tab in this file is one keystroke away from
# being saved as spaces, and the resulting failure would look like a manifest defect.
assert_eq "$(printf 'template\tdestination\tvariables\tmode')" "$(head -1 "$mf")" \
  "manifest header"

# Every template file has a manifest row.
while IFS= read -r f; do
  rel="${f#"$t"/}"
  [ "$rel" = "MANIFEST.tsv" ] && continue
  assert_eq "1" "$(awk -F'\t' -v r="$rel" 'NR>1 && $1==r {n++} END{print n+0}' "$mf")" \
    "exactly one manifest row for $rel"
done < <(find "$t" -type f ! -name MANIFEST.tsv)

# Every manifest row points at a template that exists, has exactly four fields, a non-empty
# destination, a sane mode, and a well-formed `variables` cell -- either `-` or a comma list of
# UPPER_SNAKE names. A blank line is flagged rather than silently skipped: the field-count
# guard below only fires on rows awk actually emits fields for, and a genuinely empty line
# reads as tpl="" with nf=0, which `[ -n "$tpl" ] || continue` used to swallow before this rule
# existed, so a stray blank line in the manifest gave zero errors instead of a report.
#
# Field extraction must not go through bash's `read` (or `read -a`) with IFS set to a tab:
# tab is an IFS *whitespace* character, so bash collapses runs of it and strips leading/
# trailing occurrences no matter what IFS is set to -- an empty middle field silently vanishes
# and every field after it shifts left, rather than reading as empty. Verified: piping
# `a\t\tc\td` through `IFS=$'\t' read -r w x y z` yields w=a x=c y=d z=(empty), not x=(empty).
# awk's `-F'\t'` field splitter has no such special case and reports the true field count, so
# fields are extracted with awk and handed to the loop across a delimiter (\x01) that is not
# IFS whitespace, which bash's `read` does *not* collapse. This applies to every loop in this
# file that reads manifest rows -- not just this one -- so all three below share the same
# extraction, keyed by line number so a genuinely blank line is distinguishable from a row
# whose fields all happen to be empty.
errs="$(mktemp)"
while IFS=$'\x01' read -r lineno raw tpl dest vars mode nf; do
  if [ -z "$raw" ]; then
    printf 'BLANK_LINE line %s\n' "$lineno"
    continue
  fi
  if [ "$nf" != "4" ]; then
    printf 'BAD_FIELD_COUNT %s(%s fields)\n' "$tpl" "$nf"
    continue
  fi
  [ -f "$t/$tpl" ] || printf 'MISSING_TEMPLATE %s\n' "$tpl"
  [ -n "$dest" ] || printf 'NO_DEST %s\n' "$tpl"
  case "$mode" in create|evolve) : ;; *) printf 'BAD_MODE %s %s\n' "$tpl" "$mode" ;; esac
  case "$vars" in
    -) : ;;
    "") printf 'BAD_VARS %s(empty)\n' "$tpl" ;;
    *)
      vars_bad=false
      IFS=',' read -ra vlist <<<"$vars"
      for v in "${vlist[@]}"; do
        [[ "$v" =~ ^[A-Z][A-Z0-9_]*$ ]] || vars_bad=true
      done
      $vars_bad && printf 'BAD_VARS %s(%s)\n' "$tpl" "$vars"
      ;;
  esac
done < <(awk -F'\t' \
  'NR>1{printf "%d\x01%s\x01%s\x01%s\x01%s\x01%s\x01%d\n", NR, $0, $1, $2, $3, $4, NF}' \
  "$mf") > "$errs"
assert_eq "" "$(cat "$errs")" "manifest rows are well formed"
rm -f "$errs"

# Every {{VAR}} used in a template is declared in its row. Uses the same awk extraction as
# above -- an earlier version of this loop and its sibling below read the manifest with
# `IFS=$'\t' read`, which (per the note above) collapses an empty `variables` cell and shifts
# `mode` left into the `vars` variable, so a row with a genuinely empty `variables` field was
# checked against the literal string `create`/`evolve` instead of against nothing.
undeclared=""
while IFS=$'\x01' read -r tpl vars; do
  [ -n "$tpl" ] && [ -f "$t/$tpl" ] || continue
  used="$(grep -oE '\{\{[A-Z0-9_]+\}\}' "$t/$tpl" | tr -d '{}' | sort -u || true)"
  for u in $used; do
    case ",$vars," in
      *",$u,"*) : ;;
      *) undeclared="$undeclared $tpl:$u" ;;
    esac
  done
done < <(awk -F'\t' 'NR>1{printf "%s\x01%s\n", $1, $3}' "$mf")
assert_eq "" "$undeclared" "every used variable is declared"

# Every declared variable is actually used (no dead declarations). Same awk extraction as
# above, for the same reason.
unused=""
while IFS=$'\x01' read -r tpl vars; do
  [ -n "$tpl" ] && [ -f "$t/$tpl" ] || continue
  [ "$vars" = "-" ] && continue
  for d in $(printf '%s' "$vars" | tr ',' ' '); do
    grep -q "{{$d}}" "$t/$tpl" || unused="$unused $tpl:$d"
  done
done < <(awk -F'\t' 'NR>1{printf "%s\x01%s\n", $1, $3}' "$mf")
assert_eq "" "$unused" "every declared variable is used"

# Every {{VAR}} used in a row's destination (column 2) must also be declared in that row's
# variables cell (column 3). The two loops above only grep template *bodies* -- a path variable
# used solely in a destination (as all four on-demand rows' path variables are) is invisible to
# both, so a new row with an undeclared destination variable, or a typo in one, passed silently.
dest_undeclared=""
while IFS=$'\x01' read -r tpl dest vars; do
  [ -n "$tpl" ] || continue
  used="$(printf '%s' "$dest" | grep -oE '\{\{[A-Z0-9_]+\}\}' | tr -d '{}' | sort -u || true)"
  for u in $used; do
    case ",$vars," in
      *",$u,"*) : ;;
      *) dest_undeclared="$dest_undeclared $tpl:$u" ;;
    esac
  done
done < <(awk -F'\t' 'NR>1{printf "%s\x01%s\x01%s\n", $1, $2, $3}' "$mf")
assert_eq "" "$dest_undeclared" "every {{VAR}} in a row's destination is declared in that row's variables"

# Emitted-at rule (docs/dev/plans/2026-08-28-harness-v1/task-8.md's Interfaces section): a
# destination containing {{ is emitted on demand, by the tier that authors that document, not
# by /foreman-init at generation time. Checked in both directions -- each of the four
# documented on-demand templates must still carry a {{ in its destination (else it silently
# became an init-time row emitting into one hardcoded path for every repo), and no other row
# may have gained a {{ in its destination without being added to this documented set.
ondemand_errs=""
for tpl in program/kickoff.md.tmpl plans/plan-README.md.tmpl plans/task-N.md.tmpl specs/spec.md.tmpl; do
  d="$(awk -F'\t' -v tp="$tpl" 'NR>1 && $1==tp {print $2}' "$mf")"
  case "$d" in
    *'{{'*) : ;;
    *) ondemand_errs="$ondemand_errs NOT_ONDEMAND:$tpl" ;;
  esac
done
while IFS=$'\x01' read -r tpl dest; do
  [ -n "$tpl" ] || continue
  case "$dest" in
    *'{{'*)
      case "$tpl" in
        program/kickoff.md.tmpl|plans/plan-README.md.tmpl|plans/task-N.md.tmpl|specs/spec.md.tmpl) : ;;
        *) ondemand_errs="$ondemand_errs UNRECOGNISED_ONDEMAND:$tpl" ;;
      esac
      ;;
  esac
done < <(awk -F'\t' 'NR>1{printf "%s\x01%s\n", $1, $2}' "$mf")
assert_eq "" "$ondemand_errs" \
  "on-demand rows (destination containing {{) are exactly the four documented ones, in both directions"

# Every destination the manifest can emit, and the mode Task 9 must apply to it. Previously
# only ten of sixteen destinations were checked at all (missing .claude/settings.json,
# .gitignore, and the four path-variable destinations), and `mode` was only ever checked for
# being *a* valid literal -- never the one its own destination requires (an `evolve` row
# demoted to `create`, or vice versa, passed silently).
dest_mode_errs=""
while read -r dest mode; do
  [ -n "$dest" ] || continue
  got_n="$(awk -F'\t' -v d="$dest" 'NR>1 && $2==d {n++} END{print n+0}' "$mf")"
  if [ "$got_n" != "1" ]; then
    dest_mode_errs="$dest_mode_errs MISSING:$dest(rows=$got_n)"
    continue
  fi
  got_mode="$(awk -F'\t' -v d="$dest" 'NR>1 && $2==d {print $4}' "$mf")"
  [ "$got_mode" = "$mode" ] || \
    dest_mode_errs="$dest_mode_errs MODE:$dest=$got_mode(want $mode)"
done <<'TABLE'
CLAUDE.md evolve
AGENTS.md create
.claude/settings.json evolve
.gitignore evolve
docs/dev/README.md create
docs/dev/CONTEXT.md create
docs/dev/backlog.md create
docs/dev/program/POLICY.md create
docs/dev/program/STATE.md create
docs/dev/program/RULINGS.md create
docs/dev/program/DEFERRED.md create
docs/dev/program/HISTORY.md create
docs/dev/program/phases/{{PHASE_SLUG}}/kickoff.md create
docs/dev/plans/{{PLAN_SLUG}}/README.md create
docs/dev/plans/{{PLAN_SLUG}}/task-{{TASK_NUMBER}}.md create
docs/dev/specs/{{TODAY}}-{{TOPIC}}.md create
TABLE
assert_eq "" "$dest_mode_errs" "every manifest destination is covered with the right mode"

# [DIST-1] The reverse direction the loop above lacks, for the one row this phase removed.
assert_eq "0" "$(awk -F'\t' 'NR>1 && $2==".claude/settings.local.json"{n++} END{print n+0}' "$mf")" \
  "MANIFEST.tsv has no settings.local.json row: the marketplace source is tracked, not local"

# POLICY must carry the machine-readable baseline line baseline-check.sh reads -- anchored to
# the exact shape of the line itself (leading space, the literal placeholder, nothing trailing),
# not to the word "baseline-count:" appearing anywhere in the file. The ownership paragraph
# above also says "baseline-count:" in prose ("correcting a wrong `baseline-count:` is its
# job"), so a substring check on the whole file is satisfied by that sentence alone and never
# notices the machine-readable line being renamed or getting trailing prose appended -- both
# leave baseline-check.sh unable to find its line (rendered verdict: "unknown", exit 2).
policy_tmpl_file="$t/program/POLICY.md.tmpl"
assert_eq "1" \
  "$(grep -cE '^[[:space:]]*baseline-count:[[:space:]]*\{\{BASELINE_COUNT\}\}[[:space:]]*$' \
     "$policy_tmpl_file" 2>/dev/null || true)" \
  "POLICY template carries the exact baseline-count: line baseline-check.sh parses"

# No template may name a scripts/*.sh path at all (invariant 6): the wrappers are the
# interface, and $CLAUDE_PLUGIN_ROOT does not resolve in the Bash tool. These files
# are emitted into a target repository, where nothing under scripts/ exists -- the plugin ships
# it. Unlike the shipped skills, a template has no legitimate path-form prose mention either,
# so this check is stricter than the one in tests/test_program_skill.sh: any occurrence at all,
# with or without arguments, is a defect.
# Verified before shipping, against planted templates: the three qualified forms (inline
# backtick, quoted, and a `\`-continued call) produce no hit; a bare mention in prose and a
# bare invocation each produce exactly one, named by file.
templates_path_form=""
while IFS= read -r tf; do
  hit="$(sed -E ':a; /\\$/{N; s/\\\n//; ba}' "$tf" \
        | grep -oE '[^ `"]*(scripts/[a-z-]+\.sh|bin/harness-[a-z]+)' || true)"
  [ -n "$hit" ] && templates_path_form="$templates_path_form ${tf#"$t"/}:$(printf '%s' "$hit" | tr '\n' ',')"
done < <(find "$t" -type f ! -name MANIFEST.tsv)
assert_eq "" "$templates_path_form" "no template names a script or wrapper by path"

# The phase-table header must keep the two column names phase-state.sh resolves by name. This
# is the machine-readable contract itself, not the prose describing it: a header rename (e.g.
# "Phase" -> "Phase name") breaks phase-state.sh for every phase even though the surrounding
# prose about the table would still read as true.
state_tmpl="$(cat "$t/program/STATE.md.tmpl" 2>/dev/null || true)"
assert_contains "$state_tmpl" "| Phase | Owner | Branch | Status | Next action |" \
  "STATE.md template's phase table header names the columns phase-state.sh resolves by name"

# The phase-table status vocabulary must cover the outcomes a phase can actually halt on --
# foreman-program branches on all three, and a status column that cannot express them forces
# the PM to record a halted phase as running. Anchored to the "Statuses:" paragraph itself
# (word-wrapped over several physical lines, so the paragraph is captured, not just its first
# line), not the whole file: a bare `assert_contains` on the whole file is satisfied by the
# vocabulary appearing anywhere at all, including somewhere a PM filling in the Status column
# never reads.
statuses_para="$(awk '/^Statuses:/{p=1} p{print} p && /^$/{exit}' \
  "$t/program/STATE.md.tmpl" 2>/dev/null || true)"
assert_contains "$statuses_para" "Statuses:" "STATE.md template has a Statuses: paragraph"
for st in blocked deferred unverified; do
  assert_contains "$statuses_para" "\`$st\`" \
    "STATE.md template's Statuses: paragraph includes $st"
done

# POLICY.md is the program manager's to edit; foreman-program instructs exactly that when a
# baseline-count line is wrong. The template must not forbid what the skill requires.
assert_contains "$(cat "$t/program/POLICY.md.tmpl" 2>/dev/null || true)" \
  "The program manager owns this file" "POLICY template names its writer"

# [T9-R3] foreman-program reads POLICY.md for a standing grant before it pushes a phase kickoff
# ("POLICY.md's standing grant for launching phases covers it... If POLICY.md grants no such
# standing authorization, this push falls under the authorization gate"). The interview asks the
# user for exactly that grant, so the template must have somewhere to put the answer -- without
# the slot, a user who grants standing authorization gets a POLICY.md that does not record it
# and every subsequent kickoff push is gated behind an AUTH: line they already waived.
policy_tmpl="$(cat "$t/program/POLICY.md.tmpl" 2>/dev/null || true)"
assert_contains "$policy_tmpl" "{{STANDING_AUTHORIZATION}}" \
  "POLICY template has a slot for the standing authorization foreman-program reads"
assert_contains "$policy_tmpl" "including the routine push of a phase kickoff" \
  "the standing-authorization section names the push that consumes it"
assert_contains "$policy_tmpl" "{{PHASE_SCOPE}}" \
  "POLICY template has a home for the pipeline-scope answer"
assert_contains "$policy_tmpl" "{{SPEC_LIFECYCLE}}" \
  "POLICY template has a home for the spec-lifecycle answer"

# [T3-M11] CLAUDE.md.tmpl's worktree rule authorises the tool every phase session's first tool
# call uses (EnterWorktree, since [DEP-1] Step 0's dependency check precedes it). Without this
# rule, nothing in the generated repo says the tool may be used there.
assert_contains "$(cat "$t/CLAUDE.md.tmpl" 2>/dev/null || true)" \
  "**This repository works in git worktrees.**" \
  "CLAUDE.md template states the worktree rule foreman-program relies on"

# [T3-M5] kickoff.md.tmpl must literally carry EnterWorktree(name: "{{PHASE_SLUG}}") --
# foreman-program tells the PM this is the kickoff's first *tool call* (SKILL.md, just below)
# as a statement of fact it does not itself verify. This assertion only proves the call is
# present in the template, not that it is first -- since [T3-M1] the template's actual first
# step is Step 0, not EnterWorktree, so a label claiming "first step" would itself now be the
# false cross-file claim [T3-M1] and [T3-M5] were raised about. Worded to match what is checked.
assert_contains "$(cat "$t/program/kickoff.md.tmpl" 2>/dev/null || true)" \
  'EnterWorktree(name: "{{PHASE_SLUG}}")' \
  "kickoff template carries the EnterWorktree call foreman-program promises the PM"

# [T3-M1] the kickoff header's ordering claim must not contradict foreman-phase's own first
# step. foreman-phase/SKILL.md's own first "## Step N" heading is the ground truth -- a phase
# session reads the kickoff at dispatch, before it has read the skill, so if the kickoff's
# header names a later step as first, a session that trusts the header skips the dependency
# check silently. Deriving the expected step from the skill itself (rather than hard-coding
# "Step 0") means this goes red again if the skill's first step is ever renumbered and the
# template is not updated to match -- the cross-file drift POLICY.md's model table warns about.
# [T3-M7] two corrections from the round-2 review, found by mutation. First: this derivation
# only distinguishes a renumbered step from "Step 1a" for step numbers that are not a literal
# prefix of "1a" -- i.e. it works for "Step 0" (the number in the repository today) and would
# also work for "Step 2" or higher, but a renumbering to bare "Step 1" collides byte-for-byte
# with "Step 1a" and the ordering check cannot pass no matter what the template says. The
# byte-offset search below is anchored so "Step 1" cannot match *inside* "Step 1a" (the
# character after the digits must not be a digit or letter), which is the fix mutation B2
# asked for; it does not lift the "Step 1" collision itself, since "Step 1" genuinely has no
# byte offset in this template that precedes "Step 1a" once the boundary is enforced -- that
# case still fails, correctly, and loudly, rather than passing by prefix accident. Second: the
# comment above overstated this as "goes red again if renumbered" without that caveat; this
# comment is the correction.
# [T3-M8] the presence check below used to pass vacuously when $first_step came out empty (a
# `case *""* ` glob matches everything), and the ordering check followed it into a false green
# (byte offset 0 always precedes "Step 1a"'s later offset). Guarded explicitly: an empty
# derivation is now itself a failure, not a silent pass.
kickoff_tmpl="$(cat "$t/program/kickoff.md.tmpl" 2>/dev/null || true)"
first_step="$(grep -m1 -oE '^## Step [0-9]+' "$FOREMAN_ROOT/skills/foreman-phase/SKILL.md" \
  | sed 's/^## //')"
if [ -n "$first_step" ]; then _ok
else fail "foreman-phase/SKILL.md has a '## Step N' heading to derive the first step from"; fi
if [ -n "$first_step" ]; then
  assert_contains "$kickoff_tmpl" "$first_step" \
    "kickoff template names foreman-phase's actual first step ($first_step)"
  first_num="$(printf '%s' "$first_step" | grep -oE '[0-9]+')"
  first_pos="$(printf '%s' "$kickoff_tmpl" \
    | grep -boE "Step ${first_num}([^0-9A-Za-z]|\$)" | head -1 | cut -d: -f1)"
  step1a_pos="$(printf '%s' "$kickoff_tmpl" | grep -bo 'Step 1a' | head -1 | cut -d: -f1)"
  if [ -n "$first_pos" ] && [ -n "$step1a_pos" ] && [ "$first_pos" -lt "$step1a_pos" ]; then _ok
  else
    fail "kickoff template names $first_step before Step 1a (got first=$first_pos step1a=$step1a_pos)"
  fi
else
  fail "kickoff template names foreman-phase's actual first step (no first step to compare)"
  fail "kickoff template names the first step before Step 1a (no first step to compare)"
fi

# [T3-M6] the same file's body used to say "before doing anything else" about the two git reads
# in Step 1a, three lines under a header that now says Step 0 runs first -- two competing
# claims of primacy in one file, the miniature of what [T3-M1] found across two files. The
# reads are read-only and spend nothing, so "before entering the worktree" states the real
# constraint (they must happen before EnterWorktree, since gate 6 needs them and a worktree
# cannot supply them) without also claiming to precede Step 0.
kickoff_flat="$(tr '\n' ' ' < "$t/program/kickoff.md.tmpl" | tr -s ' ')"
assert_not_contains "$kickoff_flat" 'before doing anything else' \
  "kickoff template no longer claims Step 1a's reads precede everything, including Step 0"
assert_contains "$kickoff_flat" 'before entering the worktree' \
  "kickoff template states the real constraint: before EnterWorktree, not before Step 0"

# settings.json.tmpl must render to exactly one well-formed JSON object and carry the settings
# other scripts and Claude Code itself depend on. The raw template is not valid JSON on its own
# ({{GATE_PERMISSIONS}} sits where an array element belongs), so the variable is substituted
# before validating -- once with a fixture permission entry, once with nothing, since Task 9
# may render either shape depending on whether any gate command needs a permission entry.
settings_tmpl="$(cat "$t/settings.json.tmpl" 2>/dev/null || true)"
render_settings() {  # render_settings <gate-permissions-value>
  printf '%s\n' "$settings_tmpl" | sed "s#{{GATE_PERMISSIONS}}#$1#"
}
for gp_label_value in "fixture:\"Bash(bash tests/run.sh:*)\"" "empty:"; do
  gp_label="${gp_label_value%%:*}"
  gp_value="${gp_label_value#*:}"
  rendered="$(render_settings "$gp_value")"
  is_one_object="false"
  printf '%s' "$rendered" | jq -s -e 'length == 1 and (.[0] | type == "object")' \
    >/dev/null 2>&1 && is_one_object="true"
  assert_eq "true" "$is_one_object" \
    "settings.json.tmpl renders to exactly one JSON object (gate permissions: $gp_label)"
done

rendered_full="$(render_settings '"Bash(bash tests/run.sh:*)"')"
assert_eq "fresh" "$(printf '%s' "$rendered_full" | jq -r '.worktree.baseRef' 2>/dev/null)" \
  "settings.json.tmpl sets worktree.baseRef to fresh"
for p in foreman@foreman superpowers@claude-plugins-official fable@fable-method \
         claude-md-management@claude-plugins-official; do
  assert_eq "true" \
    "$(printf '%s' "$rendered_full" | jq -r --arg p "$p" '.enabledPlugins[$p] == true' 2>/dev/null)" \
    "settings.json.tmpl enables $p"
done

# extraKnownMarketplaces must declare every third-party marketplace enabledPlugins names, not
# just foreman@foreman -- claude-plugins-official is a built-in the CLI hardcodes and needs no
# entry, but fable-method is an ordinary github marketplace and a target repo that has never
# added it names a marketplace it cannot resolve (the same defect foreman@foreman would have
# had without its own entry). Verified against this machine's own ~/.claude/settings.json,
# which declares fable-method exactly this way.
assert_eq "github" \
  "$(printf '%s' "$rendered_full" | jq -r '.extraKnownMarketplaces["fable-method"].source.source' 2>/dev/null)" \
  "settings.json.tmpl declares the fable-method marketplace as a github source"
assert_eq "Sahir619/fable-method" \
  "$(printf '%s' "$rendered_full" | jq -r '.extraKnownMarketplaces["fable-method"].source.repo' 2>/dev/null)" \
  "settings.json.tmpl's fable-method marketplace names the right repo"

# effortLevel: resolve-gate.sh walks .claude/settings.local.json, then .claude/settings.json,
# then ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json, and presence at any tier ends the
# search. Without this key a generated repo's own settings.json defines nothing, so the search
# falls through to whatever effortLevel happens to be in the operator's own user settings -- the
# gate's verdict then depends on who is running the session, not on the repository.
assert_eq "high" "$(printf '%s' "$rendered_full" | jq -r '.effortLevel' 2>/dev/null)" \
  "settings.json.tmpl sets effortLevel so the repo answers resolve-gate.sh for itself"

# [DIST-1] The foreman marketplace is a GitHub source in the TRACKED settings.json, the same
# shape fable-method already uses. A directory source carried a machine-specific absolute
# path, which forced a second, untracked settings file and meant a cloned repository enabled
# a plugin Claude Code could not locate. Now a clone needs only the trust prompt.
assert_eq "github" \
  "$(printf '%s' "$rendered_full" | jq -r '.extraKnownMarketplaces.foreman.source.source' 2>/dev/null)" \
  "settings.json.tmpl declares the foreman marketplace as a github source"
assert_eq "yorah/foreman-harness" \
  "$(printf '%s' "$rendered_full" | jq -r '.extraKnownMarketplaces.foreman.source.repo' 2>/dev/null)" \
  "settings.json.tmpl's foreman marketplace names the published harness repository"
if [ ! -e "$t/settings.local.json.tmpl" ]; then _ok
else fail "settings.local.json.tmpl still exists; the local marketplace source is retired"; fi
assert_eq "" "$(grep -rl 'FOREMAN_MARKETPLACE_PATH' "$t" 2>/dev/null || true)" \
  "no template carries a machine-specific marketplace path"

# The generated CLAUDE.md is the one file every session reads whether or not the plugin
# loaded, so it is where a contributor learns how the plugin arrives: the tracked settings
# declare a GitHub marketplace, Claude Code asks to trust it on first start, and if that was
# declined `claude plugin install foreman@foreman` is the manual step. It must not send
# anyone to a local checkout path or to known_marketplaces.json any more.
claude_md_tmpl="$(cat "$t/CLAUDE.md.tmpl" 2>/dev/null || true)"
claude_md_tmplf="$(printf '%s' "$claude_md_tmpl" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$claude_md_tmplf" "claude plugin install foreman@foreman" \
  "CLAUDE.md template names the manual install command"
assert_contains "$claude_md_tmplf" "asks whether to trust that marketplace" \
  "CLAUDE.md template explains the trust prompt a fresh clone sees"
assert_contains "$claude_md_tmplf" "claude plugin list" \
  "CLAUDE.md template names claude plugin list as the tell that the plugin is installed"
assert_not_contains "$claude_md_tmplf" "known_marketplaces.json" \
  "CLAUDE.md template no longer sends contributors to known_marketplaces.json"
assert_not_contains "$claude_md_tmplf" "--scope local" \
  "CLAUDE.md template no longer registers a local-directory marketplace"
assert_not_contains "$claude_md_tmplf" "settings.local.json" \
  "CLAUDE.md template no longer describes a machine-specific settings file"

# .gitignore's own additions must keep .claude/settings.local.json out of the index. Claude Code
# writes per-contributor permission grants there on its own; a tracked copy is a line every
# contributor would fight over on every pull.
assert_contains "$(cat "$t/gitignore-additions.txt" 2>/dev/null || true)" \
  ".claude/settings.local.json" \
  "gitignore-additions.txt keeps the per-contributor settings.local.json untracked"

# gitignore-additions.txt's other purpose -- excluding regenerable review diff packages -- had
# no assertion; renaming or dropping *.diff left the suite green.
assert_contains "$(cat "$t/gitignore-additions.txt" 2>/dev/null || true)" \
  "*.diff" \
  "gitignore-additions.txt excludes the regenerable review diff packages"

# POLICY.md must say out loud that this repository pins effortLevel: high, and why -- JSON
# carries no comments, and all three tiers (program manager, phase controller, reviewer) read
# POLICY.md, not settings.json, looking for standing facts about the repository.
policy_prose="$(cat "$t/program/POLICY.md.tmpl" 2>/dev/null || true)"
assert_contains "$policy_prose" \
  'pins `effortLevel: "high"`' \
  "POLICY template states that this repository pins effortLevel: high"

# The pin is not the whole truth: foreman_settings_chain (scripts/lib.sh) reads
# .claude/settings.local.json -- untracked, one per contributor -- before the tracked
# .claude/settings.json this pin lives in, so a local file can override it. POLICY.md must not
# claim the tracked pin is the final answer for every session; it must instead point at the one
# thing that is always true -- resolve-gate.sh names the file it actually read.
assert_contains "$policy_prose" "effort_source" \
  "POLICY template names effort_source as what to check, since the tracked pin can be overridden locally"
assert_contains "$policy_prose" "settings.local.json" \
  "POLICY template names settings.local.json as the file that can override the tracked pin"

# No placeholders-of-the-wrong-kind in templates.
assert_eq "" "$(grep -rlE '\b(TODO|TBD|FIXME)\b' "$t" || true)" "no TODO/TBD/FIXME in templates"
