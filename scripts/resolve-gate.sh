#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

model=""; repo=""; repo_given=false
while [ $# -gt 0 ]; do
  case "$1" in
    --model) [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; model="$2"; shift 2 ;;
    --repo)  [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; repo="$2"; repo_given=true; shift 2 ;;
    *) foreman_die "unknown argument: $1" 2 ;;
  esac
done
[ -n "$model" ] || foreman_die "--model is required" 2

# `--repo ''` (explicitly supplied but empty) must not be indistinguishable from omitting the
# flag entirely -- omission legitimately falls back to the repo containing $PWD; an explicit
# empty value is a caller error and must refuse rather than silently read whatever repository
# happens to contain the current directory (which here would mean skipping the project's own
# settings.json and letting a laxer user-level file decide the verdict).
if [ -n "$repo" ]; then
  foreman_require_abs "$repo" "--repo"
elif $repo_given; then
  foreman_die "--repo must not be empty" 2
else
  repo="$(foreman_repo_root "$PWD" || true)"
  repo="${repo:-$PWD}"
fi

emit() {  # emit <verdict> <effort> <source> <reason>
  jq -n --arg v "$1" --arg m "$model" --arg e "$2" --arg s "$3" --arg r "$4" \
    '{verdict:$v, model:$m,
      effort:(if $e == "" then null else $e end),
      effort_source:(if $s == "" then null else $s end),
      reason:$r}'
}

# --- model tier -----------------------------------------------------------
# Whole-token match: split the lowercased id on '-' and require some token to equal exactly
# "opus" or "fable" — not a substring anywhere ("notopus"/"opusless"/"xfablex"/"fabled" must
# stay refused), but any real id shape that carries the token, vendor-qualified or dated or
# not ("claude-opus-5", "claude-3-opus-20240229", "us.anthropic.claude-opus-4-latest",
# "anthropic.claude-opus-4-1-20250805-v1:0" all pass; a bare whitelist of full ids would wrongly
# refuse the latter three, which are ordinary Bedrock/dated ids, not exotic ones).
#
# A leading dash, trailing dash, or "--" denotes a degenerate id with an empty segment
# ("opus-", "-opus", "--opus--") — reject those outright rather than let a dash-wrapped
# substring test ("-$model_lc-" contains "-opus-") accept them; only once the id is confirmed
# free of empty segments is that substring test equivalent to "some token equals opus/fable".
model_lc="$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')"
model_ok=false
case "$model_lc" in
  -*|*-|*--*) : ;;
  *)
    case "-$model_lc-" in
      *-opus-*|*-fable-*) model_ok=true ;;
    esac
    ;;
esac

# --- effort ---------------------------------------------------------------
effort=""; effort_src=""
set +e
pair="$(foreman_setting "$repo" '.effortLevel')"
setting_rc=$?
set -e

case "$setting_rc" in
  0)
    effort="${pair%%$'\t'*}"
    effort_src="${pair#*$'\t'}"
    ;;
  2)
    # A file defines effortLevel but its value is unusable (empty/null/non-string/tainted), or
    # the file isn't valid JSON at all. Presence ends the search: this is unknown, never a
    # silent fall-through to a laxer file's opinion.
    effort_src="${pair#*$'\t'}"
    emit unknown "" "$effort_src" \
      "effortLevel in '$effort_src' is empty, null, non-string, or the file is not valid JSON; cannot verify the gate"
    exit 2
    ;;
  *)
    emit unknown "" "" "no effortLevel found in any settings file; cannot verify the gate"
    exit 2
    ;;
esac

case "$effort" in
  low) rank=1 ;; medium) rank=2 ;; high) rank=3 ;; xhigh) rank=4 ;; max) rank=5 ;;
  *) emit unknown "$effort" "$effort_src" "unrecognised effortLevel '$effort'"; exit 2 ;;
esac

effort_ok=false
[ "$rank" -ge 3 ] && effort_ok=true

# --- verdict --------------------------------------------------------------
if $model_ok && $effort_ok; then
  emit pass "$effort" "$effort_src" \
    "model '$model' is Opus/Fable and effort '$effort' is at or above high"
  exit 0
fi

reasons=""
$model_ok  || reasons="model '$model' is not Opus or Fable"
$effort_ok || reasons="${reasons:+$reasons; }effort '$effort' is below high"
emit refuse "$effort" "$effort_src" "$reasons"
exit 1
