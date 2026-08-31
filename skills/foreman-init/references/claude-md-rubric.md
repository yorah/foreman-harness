# What a good CLAUDE.md does here

The quality pass grades against the standard rubric. These are the harness's additions to it,
and they win where the two disagree.

**A warning must carry its why.** "Use `npm run typecheck`, not `npx tsc`" is a rule to route
around. The same rule plus "the proxy reports a false 'No errors found' even when real type
errors exist" is one a reader will keep. Never accept a finding that strips a reason to save
lines.

**Invariants are numbered.** They are quoted verbatim into dispatches and answered one by one
by reviewers. Numbering is the interface, not decoration.

**Architecture is described by responsibility, not by directory listing.** "`store`: owns
SQLite — schema, migrations, all persistence. No business logic." tells a session where a
change belongs. A file tree does not.

**State what is deliberately absent, and why.** A missing feature that looks like an oversight
gets built by a helpful session. Naming it as a decision prevents that.

**Commands are copy-pasteable and real.** Every one must have been run.

**The worktree rule must be present.** `EnterWorktree` is available to a session only when the
user or the project instructions call for worktrees; if `CLAUDE.md` does not say so, phase
sessions cannot legitimately isolate themselves.

**Length is not the metric; relevance is.** The test is whether a session must read material
about work that is not its own.
