#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

phase=""; branch=""; repo=""; head_only=false; branch_given=false; repo_given=false
while [ $# -gt 0 ]; do
  case "$1" in
    --phase)  [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; phase="$2"; shift 2 ;;
    --branch) [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; branch="$2"; branch_given=true; shift 2 ;;
    --repo)   [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; repo="$2"; repo_given=true; shift 2 ;;
    --head)   head_only=true;  shift ;;
    *) foreman_die "unknown argument: $1" 2 ;;
  esac
done

[ -n "$phase" ] || foreman_die "--phase is required" 2
# `--repo ''` (explicitly supplied but empty) must not be indistinguishable from omitting the
# flag entirely -- omission legitimately falls back to the repo containing $PWD; an explicit
# empty value is a caller error (e.g. `--repo "$REPO"` with an unset $REPO) and must refuse
# rather than silently read whatever repository happens to contain the current directory.
if [ -n "$repo" ]; then
  foreman_require_abs "$repo" "--repo"
elif $repo_given; then
  foreman_die "--repo must not be empty" 2
else
  repo="$(foreman_repo_root "$PWD" || true)"
  [ -n "$repo" ] || foreman_die "not inside a git repository and --repo not given" 2
fi

state_index="$repo/docs/dev/program/STATE.md"

if ! $branch_given; then
  [ -f "$state_index" ] || foreman_die "no STATE.md at $state_index; pass --branch" 2

  # Resolve the phase's branch by header name, not column position -- a reordered STATE.md
  # table must still resolve correctly, and a table with no header row (or one missing a
  # required column, or naming a required column twice) must refuse rather than guess. Also
  # refuse silently on more than one row for the same phase: that makes the branch unknowable,
  # not "take the first."
  #
  # awk always exits 0 here and communicates outcome via a stdout sentinel, so bash's own
  # `set -e` never short-circuits before we can attach the right exit code and diagnostic.
  # `exit` inside an awk pattern block still runs END before terminating, so each early-exit
  # branch below sets `done` to keep END from printing a second, contradictory verdict.
  lookup="$(awk -F'|' -v p="$phase" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^[[:space:]]*\|/ {
      n++
      if (n == 1) {
        for (i = 2; i <= NF; i++) {
          h = trim($i)
          if (h == "Phase")  { if (pc != 0) pdup = 1; pc = i }
          if (h == "Branch") { if (bc != 0) bdup = 1; bc = i }
        }
        if (pdup || bdup)       { print "ERR:duplicate-header"; done=1; exit }
        if (pc == 0 || bc == 0) { print "ERR:missing-columns";  done=1; exit }
        next
      }
      # separator row (|---|---|...): every cell is dashes, optionally colon-flanked -- skip it
      sep = 1
      for (i = 2; i <= NF; i++) {
        c = trim($i)
        if (c !~ /^:?-+:?$/) { sep = 0; break }
      }
      if (sep) next
      name = trim($pc)
      if (name == p) {
        br = trim($bc)
        cnt++
        if (cnt == 1) { first = br } else { dups = dups (dups == "" ? "" : ";") br }
      }
    }
    END {
      if (done) { exit }
      if (n == 0)             { print "ERR:no-header"; exit }
      if (pdup || bdup)       { print "ERR:duplicate-header"; exit }
      if (pc == 0 || bc == 0) { print "ERR:missing-columns"; exit }
      if (cnt > 1)            { print "ERR:duplicate:" first ";" dups; exit }
      if (cnt == 1)           { print first; exit }
      print "ERR:not-found"
    }
  ' "$state_index")"

  case "$lookup" in
    ERR:no-header)
      foreman_die "no header row (a line starting with '|') in $state_index" 2 ;;
    ERR:duplicate-header)
      foreman_die "STATE.md header names 'Phase' or 'Branch' more than once: $state_index" 2 ;;
    ERR:missing-columns)
      foreman_die "STATE.md header is missing a 'Phase' or 'Branch' column: $state_index" 2 ;;
    ERR:duplicate:*)
      foreman_die "phase '$phase' has more than one row in $state_index (branches: ${lookup#ERR:duplicate:})" 2 ;;
    ERR:not-found)
      foreman_die "phase '$phase' has no row in $state_index" 2 ;;
    *) branch="$lookup" ;;
  esac
fi

# A resolved branch must be non-empty and must not begin with '-', regardless of source
# (--branch directly, or STATE.md's Branch column) -- this is the single point every path to
# `git show` below passes through. Empty is not merely "nothing given": `git show ":path"` still
# succeeds by reading from the *index* rather than any ref, a different and possibly-uncommitted
# data source silently wearing the same output shape as a real ledger. A leading '-' risks being
# parsed as a git option rather than a revision.
if [ -z "$branch" ]; then
  if $branch_given; then
    foreman_die "--branch must not be empty" 2
  else
    foreman_die "phase '$phase' resolved to an empty branch (malformed row in $state_index)" 2
  fi
fi
case "$branch" in
  -*) foreman_die "branch value must not start with '-': $branch" 2 ;;
esac

path="docs/dev/program/phases/$phase/state.md"
content="$(git -C "$repo" show "$branch:$path" 2>/dev/null)" \
  || foreman_die "no $path on branch '$branch'" 2

if $head_only; then
  # Validate the frontmatter block structurally before extracting it: a file that does not
  # open with '---' on line 1, or whose block never closes, must refuse rather than silently
  # fall back to dumping the whole file as if it were the (bounded) machine-readable head.
  # `exit` inside an awk pattern block still runs END before terminating, so each early-exit
  # branch below sets `done` to keep END from printing a second, contradictory verdict.
  fm_status="$(printf '%s\n' "$content" | awk '
    NR==1 && $0 != "---" { print "no-frontmatter"; done=1; exit }
    NR==1                { infm=1; next }
    infm && $0 == "---"  { print "ok"; done=1; exit }
    infm                 { next }
    END { if (!done) print (infm ? "unterminated" : "no-frontmatter") }
  ')"
  case "$fm_status" in
    ok) ;;
    no-frontmatter)
      foreman_die "no frontmatter (file must open with '---' on line 1) in $branch:$path" 2 ;;
    unterminated)
      foreman_die "unterminated frontmatter block (no closing '---') in $branch:$path" 2 ;;
    *) foreman_die "could not parse frontmatter in $branch:$path" 2 ;;
  esac
  printf '%s\n' "$content" | awk '
    NR==1 && $0=="---" { infm=1; print; next }
    infm && $0=="---"  { print; exit }
    infm               { print }
  '
else
  printf '%s\n' "$content"
fi
