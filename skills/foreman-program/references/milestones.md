# Milestones and handover

A **milestone** is any point where your accumulated context stops helping and starts costing:
a phase finishing, a section shipping, a pivot to a different part of the system. At one, your
context is full of detail about work that is now done, which makes every later turn more
expensive and no better.

**Say so unprompted.** The user cannot see your context filling; you can. Waiting to be asked
is how the previous orchestrator ran out by the tenth task of the second plan.

At a milestone:

1. Write everything unrecorded into `docs/dev/program/STATE.md`,
   `docs/dev/program/RULINGS.md`, `docs/dev/program/DEFERRED.md`, or a report. Anything living
   only in the conversation is about to be lost.
2. Move finished material out of `STATE.md`: completed phases to
   `docs/dev/program/HISTORY.md`, rulings that are no longer about the present to `RULINGS.md`.
   **`STATE.md` must stay short enough to read at the start of every session.**
3. Commit.
4. Hand the user a **startup prompt** for a fresh program-manager session, naming the files to
   read and the first action.
5. Tell them plainly that it is now safe to start clean.

Restarting then costs one file read.

## Context discipline between milestones

- Kickoffs are files you write, not messages you paste.
- Summaries come back as text — that is the only per-phase context cost you pay.
- Probe output is a few lines. Print what answers the question, not everything.
- If you pass roughly 70% of your context, write `STATE.md` fully and call the milestone,
  whether or not a phase just ended.
