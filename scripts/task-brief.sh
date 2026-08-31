#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

plan=""; task=""; phase_dir=""; worktree=""; policy=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plan)      [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; plan="$2"; shift 2 ;;
    --task)      [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; task="$2"; shift 2 ;;
    --phase-dir) [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; phase_dir="$2"; shift 2 ;;
    --worktree)  [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; worktree="$2"; shift 2 ;;
    --policy)    [ $# -ge 2 ] || foreman_die "$1 requires a value" 2; policy="$2"; shift 2 ;;
    *) foreman_die "unknown argument: $1" 2 ;;
  esac
done

[ -n "$plan" ]      || foreman_die "--plan is required" 2
[ -n "$task" ]      || foreman_die "--task is required" 2
[ -n "$phase_dir" ] || foreman_die "--phase-dir is required" 2
[ -n "$worktree" ]  || foreman_die "--worktree is required" 2

case "$task" in
  ''|*[!0-9]*) foreman_die "--task must be a number, got: $task" 2 ;;
esac

foreman_require_abs "$plan" "--plan"
foreman_require_abs "$phase_dir" "--phase-dir"
foreman_require_abs "$worktree" "--worktree"
[ -n "$policy" ] && foreman_require_abs "$policy" "--policy"

readme="$plan/README.md"
src="$plan/task-$task.md"
[ -d "$plan" ]     || foreman_die "plan directory not found: $plan" 2
[ -f "$readme" ]   || foreman_die "plan has no README.md: $readme" 2
[ -f "$src" ]      || foreman_die "no such task file: $src" 2
[ -d "$phase_dir" ] || foreman_die "phase directory not found: $phase_dir" 2

# Heading guard: the first heading must name this task number. A brief whose heading
# disagrees with the file it came from is the stale-brief bug wearing a disguise.
heading="$(grep -m1 -E '^#+[[:space:]]' "$src" || true)"
[ -n "$heading" ] || foreman_die "task file has no heading: $src" 2
printf '%s' "$heading" | grep -qiE "^#+[[:space:]]+Task[[:space:]]+$task([^0-9]|$)" \
  || foreman_die "heading does not name Task $task: $heading" 2

dest="$phase_dir/task-$task-brief.md"

# Write-ability guard: prove the destination can be opened before we touch it. This gives a
# clean exit 2 and a diagnostic naming the path for the common, cheap-to-detect cases --
# without it, the eventual write would fail with whatever raw exit status the shell's own I/O
# error produces (observed: 1), not the `2` the exit-code contract requires for "cannot
# determine". It cannot cover everything, though: a full filesystem, a disk quota, a ulimit, or
# a signal can still fail *mid*-write, after this check has already passed. The write-then-move
# below is what closes that remaining gap.
if [ -d "$dest" ]; then
  foreman_die "destination is a directory, not a file: $dest" 2
elif [ -e "$dest" ]; then
  [ -w "$dest" ] || foreman_die "destination exists but is not writable: $dest" 2
else
  [ -w "$phase_dir" ] || foreman_die "phase directory is not writable: $phase_dir" 2
fi

# Write to a temp file beside $dest, then rename it into place -- never write $dest directly.
# `>` on $dest truncates at open() time and only then starts writing, so a failure partway
# through (full disk, quota, ulimit, signal) leaves a partial file exactly where a caller
# expects either the old good brief or the new one, never a corrupt mix of both. Writing
# somewhere harmless and moving it only once it's whole makes the operation atomic for every
# failure cause at once, rather than requiring this script to enumerate them.
#
# The temp file is created with `mktemp` *inside* $phase_dir, not under /tmp: `mv` is only an
# atomic rename when source and destination are on the same filesystem, and $phase_dir may well
# be a different one from /tmp.
tmp_dest="$(mktemp "$phase_dir/.task-$task-brief.XXXXXX")" \
  || foreman_die "cannot create a temp file in: $phase_dir" 2
trap 'rm -f "$tmp_dest"' EXIT

# The body is generated inside a `( ... )` subshell whose own output is redirected onto
# $tmp_dest, deliberately -- not by redirecting the group directly in *this* shell. A builtin
# like `printf` writing straight to a redirected fd performs the write() call in *this* shell
# process; if that write trips a ulimit (SIGXFSZ) or similar, the signal kills this process
# outright before an `if` wrapped around it ever gets a chance to see a nonzero exit, and the
# script would die with the raw signal status again -- the exact bug being fixed here. `( ... )`
# forks a child that does the writing instead, so a signal there kills only that child, and its
# ordinary nonzero exit status (128+signal, same as any external command dying the same way) is
# exactly what `if !` inspects. (An `A | B` pipe or `cat < <(process substitution)` also move
# the write into a child, but each adds a *second* concurrent child -- and empirically, with
# `ulimit -f 1` and stderr going to a real file, bash's own asynchronous notification about
# *that* child's signal death can itself overrun the same tiny limit while it's being printed,
# which can take the whole script down with it. A single plain subshell has no such second
# child and was reliable across dozens of repeated trials under the same fault injection.)
if ! (
  printf '# Brief: task %s\n\n' "$task"
  printf 'Generated from `%s`. Do not read the rest of the plan.\n\n' "$src"
  printf '| | |\n|---|---|\n'
  printf '| Worktree (absolute) | `%s` |\n' "$worktree"
  printf '| Plan constraints | `%s` |\n' "$readme"
  [ -n "$policy" ] && printf '| Policy and invariants | `%s` |\n' "$policy"
  printf '| Write your report to | `%s/task-%s-report.md` |\n' "$phase_dir" "$task"
  printf '\n'
  printf 'All paths above are absolute. Resolve every relative path in the task body\n'
  printf 'against the worktree, not against your working directory.\n\n'
  printf -- '---\n\n'
  cat "$src"
) > "$tmp_dest"; then
  foreman_die "failed to write brief (destination unchanged): $dest" 2
fi

mv -f -- "$tmp_dest" "$dest" || foreman_die "failed to move brief into place: $dest" 2

printf '%s\n' "$dest"
