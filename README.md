# foreman-harness

[![tests](https://github.com/yorah/foreman-harness/actions/workflows/tests.yml/badge.svg)](https://github.com/yorah/foreman-harness/actions/workflows/tests.yml)

A Claude Code plugin that installs a three-tier development harness into a repository:

- a **program manager** session that coordinates and does not write code,
- **phase sessions** that each enter their own worktree and execute one plan,
- **task subagents** that write the code, one brief at a time.

Distilled from three projects that were run this way and rediscovered each other's lessons at
their own cost. The design record is in `docs/dev/specs/`.

## Install

```
/plugin marketplace add yorah/foreman-harness
/plugin install foreman@foreman
```

The repository is `foreman-harness`; the marketplace and the plugin inside it are both named
`foreman`, which is why the second command reads `foreman@foreman` rather than repeating the
repository name.

## Use

```
/foreman-init      audit this repository and install the harness into it
/program           become the program manager
/phase <kickoff>   execute one phase
/program-status    one line per phase, read from each phase's own branch
```

`/foreman-init` audits before it asks, asks only what the audit could not settle, generates into
a scratch tree, and shows you the complete diff. Nothing is written to your repository until you
approve it.

## What it is for

The harness exists to stop three things that cost the source projects real time: a session
rewriting work it could not see, a reviewer that fixes what it finds instead of reporting it, and
a test suite that goes green without testing anything. So the parts that must not drift are shell
scripts with a test suite rather than model prose — the refusal gate, brief extraction, the
baseline check and the phase-state read — and the dispatch contracts live in each subagent's own
system prompt, where they cannot be skipped.

## Develop

`bash tests/run.sh` is the only gate command. It needs `bash`, `git` and `jq`, and nothing else.

## License

MIT — see `LICENSE`. The templates this plugin writes into your repository are covered by the
same terms, which is to say they carry no obligation: what `/foreman-init` generates is yours.
