#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

# [M-E] task-2.md through task-6.md embed reference code that their own fix rounds superseded:
# the code in those blocks is the plan as written before execution, and the shipped files differ.
# Each carries a banner saying so. Nothing asserted the banner was there, so it could be deleted
# -- or lost in a re-flow -- silently, leaving a reader to take a known-defective code block for
# a specification. `[T-PLAN]` in docs/dev/backlog.md tracks refreshing the blocks themselves;
# until that happens the banner is the only thing standing between a reader and the defect.
#
# Scoped to this phase's plan files by name rather than to every plan directory: the banner
# states a fact about THESE documents, and a future plan whose code was never superseded should
# not be required to carry a warning that would not be true of it.

p="$FOREMAN_ROOT/docs/dev/plans/2026-08-28-harness-v1"

# The banner is a blockquote, so the `> ` marker has to come off before the lines are joined --
# otherwise a phrase wrapped across two quoted lines flattens to "The files in the > repository",
# and the needle misses for a reason that has nothing to do with the banner being present.
# Verified: it missed exactly that way on task-3 through task-6 before the marker was stripped.
quoted() { sed 's/^> \?//' "$1" | tr '\n' ' ' | tr -s ' '; }

for n in 2 3 4 5 6; do
  f="$p/task-$n.md"
  [ -f "$f" ] || { fail "missing $f"; continue; }
  body="$(quoted "$f")"

  # The warning itself, and the sentence that carries its force. Anchored on the authoritative
  # clause rather than the bare heading: a banner reduced to its title still looks like a banner
  # while telling the reader nothing about which of the two sources to believe.
  assert_contains "$body" '**Historical reference code.**' \
    "task-$n.md carries the historical-code banner"
  assert_contains "$body" 'The files in the repository are authoritative' \
    "task-$n.md says which source wins"
  assert_contains "$body" 'Tracked as `[T-PLAN]`' \
    "task-$n.md points at the backlog entry that tracks the refresh"
done

# [M-E]'s second half: the banner's worked example is `task-2.md`'s model check, so in every
# OTHER file the example is about a document the reader is not holding. The banner said "this
# task's own fix rounds" and then cited a sibling, which reads as a claim about the file in hand.
# Each file must be honest about which it is.
assert_contains "$(quoted "$p/task-2.md")" 'the model check below' \
  "task-2.md cites its own superseded block, which is in this file"
for n in 3 4 5 6; do
  assert_contains "$(quoted "$p/task-$n.md")" 'from a sibling plan, not this file' \
    "task-$n.md marks the worked example as belonging to another file"
done
