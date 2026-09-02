# Standing rulings

Decisions that constrain future work. The program manager reads this when a decision touches
one of them; a session reads it when told to. **Not** read every session — `STATE.md` is.

Each entry states what was decided, why, and what it costs if wrong.

**When a ruling stops being true, correct it here rather than deleting it**, so the reasoning
survives and the wrong belief is not rediscovered.

## 2026-09-02 — taken while reviewing the program-layer-merge spec

- **Phases integrate by pull request** (spec D5). A phase pushes its branch and opens the PR
  with the gate evidence in its body; the program manager merges after its probe. Supersedes
  the "never, for now" line `POLICY.md` carried from v1 — because a second reader of the diff is
  the point of the harness once the harness edits itself — costs, if wrong, one extra click per
  phase.
- **`foreman-sweep` (spec §8, phase D) compares file modification times**, not the
  `Last updated` date in `STATE.md`, when deciding whether a report is unprocessed — because the
  date is day-granular and a report written the same day as the last `STATE.md` edit would be
  missed, and §4.5 guarantees one machine for both files — costs, if wrong, a false "pending"
  after a clock change, which the PM can see and dismiss.
- **Spec §12.4's "no `Read` of any `task-N.md` in the controller's transcript" is a human
  check**, not a mechanical one: nothing in `bash`, `git` and `jq` can observe a transcript.
  Phase C's plan records it under the human checks and does not pretend to test it.
- **Phase B's `foreman-init` prints a warning about `git clean -fdx`** when it bootstraps
  `.foreman/`: the work root is an ignored directory, and `-x` deletes ignored files. The
  nested repository's own history goes with it. Losing transient state is the accepted cost of
  the durability split; losing it silently is not.
- **`[DEP-1]` is resolved by a presence check that stops cleanly, not by fallbacks** — because a
  fallback is a second copy of another plugin's procedure, and two copies drift, which is §1's
  own argument for the merge — costs, if wrong, a session that halts where it could have
  degraded.
