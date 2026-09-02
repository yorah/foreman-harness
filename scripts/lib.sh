#!/usr/bin/env bash
# Shared helpers for harness scripts. Source this file; do not execute it.

foreman_die() {
  printf '%s\n' "$1" >&2
  exit "${2:-2}"
}

# foreman_require_abs <path> <label> — exit 2 unless the path is absolute.
foreman_require_abs() {
  case "$1" in
    /*) : ;;
    *) foreman_die "$2 must be an absolute path, got: $1" 2 ;;
  esac
}

# foreman_repo_root [start-dir] — absolute toplevel, or empty + non-zero.
foreman_repo_root() {
  git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null
}

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

# foreman_setting <repo-root> <jq-path> — prints "value<TAB>source"; <jq-path> must be a simple
# top-level field reference (e.g. ".effortLevel") — the only shape any caller uses.
#
# Presence ends the search, at two levels — path and key — not usability at either level. The
# first path in the chain that has *something* at it stops the walk if that something is not a
# readable regular file holding exactly one well-formed JSON object (a directory, a broken
# symlink, an unreadable file, a zero-length or whitespace-only file, malformed JSON, trailing
# garbage after an otherwise-valid object, two concatenated objects, or a non-object top level
# all count as "something unusable is here"). The first existing, well-formed-object file that
# *defines* the key then likewise stops the walk, whether or not its value is usable. Falling
# through either kind of brokenness to a less-specific path's opinion is exactly how a corrupted,
# half-written, or truncated settings.local.json would silently get overridden by a laxer file —
# the wrong direction for a gate whose failure mode of concern is an unverified `pass`.
#
# Validity is judged from jq's *exit code*, never from its stdout: `jq -r 'type'` on a file with
# trailing garbage after a valid object prints "object" for the first value and only then hits
# the parse error on the rest, so a stdout-based check reads a malformed file as well-formed.
# `jq -s -e 'length == 1 and (.[0] | type == "object")'` (slurp mode) settles every case by exit
# status alone: a parse error exits non-zero; a zero-length or whitespace-only input slurps to
# an empty array (length 0) and exits non-zero; multiple top-level values (concatenated objects,
# or a valid object followed by trailing garbage that still parses on its own) slurp to more
# than one element and exit non-zero; a non-object single value fails the type test and exits
# non-zero via -e.
#
# The complete rule, in order, per path in the chain:
#   1. nothing exists at the path (no file, no dangling symlink)      -> continue to next tier
#   2. something exists but isn't a readable regular file             -> stop: unusable (return 2)
#      (a directory, a broken symlink, or a file with no read permission)
#   3. a readable regular file that isn't exactly one JSON object     -> stop: unusable (return 2)
#   4. valid single object, does not have the key                    -> continue to next tier
#   5. valid single object, has the key, value unusable               -> stop: unusable (return 2)
#      (unusable = empty string, null, not a string, or contains a tab/newline)
#   6. valid single object, has the key, value usable                 -> stop: return it (return 0)
#
# Return codes:
#   0 — a file defines the key with a usable value: a non-empty string containing no tab or
#       newline (either would corrupt the "value<TAB>source" contract this function returns).
#       stdout: "value<TAB>source-path".
#   1 — no file in the chain defines the key at all (every existing path was a well-formed
#       single-object file lacking the key, or no path in the chain has anything at it).
#       stdout: empty.
#   2 — the search stopped at a path that is itself unusable (not a readable regular file, or a
#       readable regular file that isn't exactly one well-formed JSON object), or that defines
#       the key with an unusable value. stdout: "<TAB>source-path", so the caller can still
#       attribute the failure to a path.
foreman_setting() {
  local root="$1" key="$2" field f present v vtype
  field="${key#.}"
  while IFS= read -r f; do
    # Nothing at all here — not even a dangling symlink — is the normal "not set at this tier"
    # case: keep looking. `-e` alone would misjudge a broken symlink as "nothing here" (it
    # follows the link and reports false when the target is missing), so a symlink is checked
    # for explicitly with `-L` before concluding the path is simply absent.
    if [ ! -e "$f" ] && [ ! -L "$f" ]; then
      continue
    fi

    # Something is here (a real path, a directory, or a symlink of some kind) but it must be a
    # readable regular file to go any further. `-f`/`-r` both follow symlinks to their target,
    # so a symlink to a valid file passes this and a broken symlink (whose target doesn't
    # exist) correctly fails `-f`.
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
      printf '\t%s\n' "$f"
      return 2
    fi

    if ! jq -s -e 'length == 1 and (.[0] | type == "object")' "$f" >/dev/null 2>&1; then
      printf '\t%s\n' "$f"
      return 2
    fi

    present="$(jq -r --arg k "$field" 'has($k)' "$f" 2>/dev/null || true)"
    [ "$present" = "true" ] || continue

    v="$(jq -r "$key" "$f" 2>/dev/null || true)"
    vtype="$(jq -r "$key | type" "$f" 2>/dev/null || true)"
    case "$v" in *$'\t'*|*$'\n'*) vtype="tainted" ;; esac

    if [ "$vtype" = "string" ] && [ -n "$v" ]; then
      printf '%s\t%s\n' "$v" "$f"
      return 0
    fi
    printf '\t%s\n' "$f"
    return 2
  done < <(foreman_settings_chain "$root")
  return 1
}
