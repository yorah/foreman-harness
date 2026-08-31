# The interview

Ask **only what the audit could not settle**. Use `AskUserQuestion`. Where the audit produced a
defensible answer, offer it first and mark it `(Recommended)`.

Batch related questions into one call; four questions per call is the maximum, and fewer is
better than padding.

## Topics, in rough priority order

**Gate commands and order.** Which commands must be green before a merge, in which order.
Confirm the audit's list; ask about anything it found but could not run.

**Baseline.** Confirm the measured test count and the SHA. If the suite is currently red, ask
whether to record the count anyway or fix first.

**Trust boundaries.** Which surfaces escalate a task's model and its reviewer's: typically
authentication, secrets and keys, anything mutating state outside the process, anything
serving bytes to a browser. Offer the audit's guesses; the user knows the ones that bite.

**Invariants.** Present the enforced ones the audit found, and ask what is missing. Ask
specifically for rules that have been broken before — those are the ones worth numbering.

**Spec lifecycle.** Who writes a spec, who approves it, and whether a phase may amend one
mid-flight or must come back to the program manager.

**Pipeline scope.** What is big enough to be a phase rather than a single change.

**Commit, merge and push policy.** What a phase may do without asking — this becomes the
standing authorization `POLICY.md` records, and the program manager reads it before pushing a
kickoff, so a vague answer here gates every phase dispatch behind a fresh approval. And what
escalates to a pull request rather than a direct merge.

**`AGENTS.md` policy.** A three-line pointer (default, nothing drifts), a symlink to
`CLAUDE.md`, or real separate content because a tool in use requires it.

**Model overrides.** Anything about this repository that makes the default table wrong.

**Ownership.** Who else works here and which surfaces they own — two phases must not claim the
same surface.

## Rules

- One topic per question. Multiple choice where the options are genuinely distinct.
- Never ask about something the audit answered.
- Push back on a vague answer to a question that determines a stored convention. "Whatever you
  think" is not an answer to a question about which surfaces are sensitive; say why it matters
  and ask again.
- **Every answer must land somewhere on disk, and you must know where before you ask.** Nine
  of these topics are written into `POLICY.md`: gate commands, baseline, trust boundaries,
  invariants, spec lifecycle, pipeline scope, the standing authorization and PR rule, model
  overrides, and ownership. The tenth, the `AGENTS.md` policy, lands instead as the file Step 3
  emits. Nothing else is asked. An answer that stays in the conversation is lost, and a
  question whose answer has no home is worse than one never asked — the user believes they
  decided something.
