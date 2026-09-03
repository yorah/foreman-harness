#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

# The bin/ wrappers exist because $CLAUDE_PLUGIN_ROOT is NOT exported into the Bash tool's
# environment, which task 10's dogfood established by installing the plugin and running it: a
# call site written as "$CLAUDE_PLUGIN_ROOT/scripts/resolve-gate.sh" expands to
# "/scripts/resolve-gate.sh" and fails. Claude Code does put <plugin-root>/bin on PATH, so a
# wrapper there is callable by bare name with no variable and no path.
#
# This is the file that tests the mechanism itself. Every other test asserts that the SKILLS
# call the wrappers; only this one asserts the wrappers work.

b="$FOREMAN_ROOT/bin"

for w in foreman-gate foreman-brief foreman-baseline foreman-state foreman-root; do
  if [ -x "$b/$w" ]; then _ok; else fail "bin/$w is missing or not executable"; fi
done

# Invariant 2: every executable script carries the shebang and strict mode.
for w in foreman-gate foreman-brief foreman-baseline foreman-state foreman-root; do
  head1="$(head -1 "$b/$w" 2>/dev/null || true)"
  assert_eq '#!/usr/bin/env bash' "$head1" "bin/$w has the bash shebang"
  assert_contains "$(cat "$b/$w" 2>/dev/null || true)" 'set -euo pipefail' \
    "bin/$w sets strict mode"
done

# --- foreman-root prints the plugin root ----------------------------------
assert_eq "$FOREMAN_ROOT" "$("$b/foreman-root" 2>/dev/null || true)" \
  "foreman-root prints the plugin's absolute root"

# --- the wrappers reach their scripts and keep the exit-code contract ------
# 0 success, 1 a definite negative verdict, 2 cannot determine. A wrapper that swallowed or
# remapped its script's exit code would make every caller's branching wrong.
# A purpose-built repo, not this one and not $HOME: the settings precedence chain reads the
# repo's own .claude/settings.json before any user-level file, so this asserts the wrapper's
# plumbing rather than whatever effort the machine running the suite happens to be set to.
gate_repo="$(mktemp -d)"; mkdir -p "$gate_repo/.claude"; git -C "$gate_repo" init -q
printf '%s\n' '{"effortLevel":"high"}' > "$gate_repo/.claude/settings.json"
assert_exit 0 "foreman-gate passes a compliant model and effort" -- \
  "$b/foreman-gate" --model claude-opus-5 --repo "$gate_repo"
# Both directions: the same wrapper against the same repo must refuse once the effort drops,
# or exit 0 above would only prove the wrapper runs, not that its verdict reaches the caller.
printf '%s\n' '{"effortLevel":"medium"}' > "$gate_repo/.claude/settings.json"
assert_exit 1 "foreman-gate refuses below-high effort" -- \
  "$b/foreman-gate" --model claude-opus-5 --repo "$gate_repo"
rm -rf "$gate_repo"
assert_exit 2 "foreman-state exits 2 for an unknown phase" -- \
  "$b/foreman-state" --repo "$FOREMAN_ROOT" --phase no-such-phase
assert_exit 2 "foreman-baseline exits 2 for a missing policy" -- \
  "$b/foreman-baseline" --policy "$FOREMAN_ROOT/no-such-policy.md" --count 5
assert_exit 2 "foreman-brief exits 2 for a relative plan path" -- \
  "$b/foreman-brief" --plan relative/path --task 1 --phase-dir "$FOREMAN_ROOT" \
  --worktree "$FOREMAN_ROOT"

# --- the root is resolved from the wrapper, not from the caller ------------
# Both directions. `readlink -f` is what makes this true, and the failure it prevents is a
# wrapper invoked through a symlink on PATH resolving its root to the symlink's directory.
out_elsewhere="$(cd / && "$b/foreman-root" 2>/dev/null || true)"
assert_eq "$FOREMAN_ROOT" "$out_elsewhere" \
  "foreman-root is independent of the caller's working directory"

link_dir="$(mktemp -d)"
ln -s "$b/foreman-root" "$link_dir/foreman-root"
out_via_link="$(cd / && "$link_dir/foreman-root" 2>/dev/null || true)"
rm -rf "$link_dir"
assert_eq "$FOREMAN_ROOT" "$out_via_link" \
  "foreman-root resolves through a symlink to the real plugin root"

# --- the runner's baseline gate -------------------------------------------
# [M-5]/[I-3]: validating POLICY.md's baseline against the suite's real total cannot live inside
# a test file -- a test cannot know the suite's own total without re-running it -- so it lives in
# tests/run.sh. That makes it the one piece of the runner with logic of its own, and it needs a
# test.
#
# The runner is invoked against a ONE-FILE fixture directory via FOREMAN_TESTS_DIR, not against
# this suite. The first version of this test ran the real suite nested, which re-executed this
# file and spawned three more runs each time; the env-var guard that stopped that could itself be
# switched off from outside, silently dropping these three assertions while the run still
# reported green. A fixture directory removes the recursion instead of guarding against it.
rr="$FOREMAN_ROOT/tests/run.sh"
fix_dir="$(mktemp -d)"; mkdir -p "$fix_dir/tests"
cat > "$fix_dir/tests/test_fixture.sh" <<'FIXTURE'
#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"
assert_eq "a" "a" "fixture assertion 1"
assert_eq "b" "b" "fixture assertion 2"
FIXTURE
printf '%s\n' '# Program policy' '## Baseline' 'baseline-count: 999' > "$fix_dir/high.md"
printf '%s\n' '# Program policy' '## Baseline' 'baseline-count: 1'   > "$fix_dir/low.md"
printf '%s\n' 'no baseline recorded here'                            > "$fix_dir/none.md"
rt() { env FOREMAN_TESTS_DIR="$fix_dir/tests" FOREMAN_POLICY="$fix_dir/$1.md" "${@:2}" bash "$rr"; }

# The fixture run produces 2 passing assertions. Below the recorded baseline is a definite
# negative verdict: exit 1, even with zero failures.
assert_exit 1 "run.sh fails when the run is below POLICY's baseline" -- rt high
# Above it the gate is silent. Without this direction the one above would pass on a runner that
# simply always failed.
assert_exit 0 "run.sh passes when the run is above POLICY's baseline" -- rt low
# Cannot-determine is not a regression: an unreadable baseline warns, and must never gate.
assert_exit 0 "run.sh does not gate on a policy with no baseline" -- rt none
# [M-4] The documented escape hatch must actually work, or it is a comment, not a feature.
assert_exit 0 "FOREMAN_SKIP_BASELINE bypasses the gate" -- rt high env FOREMAN_SKIP_BASELINE=1
rm -rf "$fix_dir"

# --- the runner isolates git from the operator's configuration -----------------------------
# tests/test_phase_state.sh commits in scratch repositories. Under a global config that mandates
# signed commits with a key nobody can reach, every such commit fails and the suite goes red for
# a reason that is not in the tree. run.sh therefore pins GIT_CONFIG_GLOBAL for the whole run.
# Proven in both directions against the same hostile config: a commit run directly under it
# fails, and the same commit run through run.sh succeeds. Without the first direction, the
# second would pass on a config that was never hostile at all.
hostile_dir="$(mktemp -d)"
hostile_cfg="$hostile_dir/gitconfig"
printf '%s\n' '[user]' '	name = hostile' '	email = hostile@example.invalid' \
  '[gpg]' '	format = ssh' '[user]' '	signingkey = /nonexistent/foreman-hostile-signing-key' \
  '[commit]' '	gpgsign = true' > "$hostile_cfg"

# Direction 1: the hostile config really is hostile. A plain commit under it must fail.
hostile_repo="$hostile_dir/repo"
mkdir -p "$hostile_repo"
env GIT_CONFIG_GLOBAL="$hostile_cfg" GIT_CONFIG_NOSYSTEM=1 git -C "$hostile_repo" init -q
printf 'x\n' > "$hostile_repo/f"
env GIT_CONFIG_GLOBAL="$hostile_cfg" GIT_CONFIG_NOSYSTEM=1 git -C "$hostile_repo" add f
hostile_rc=0
env GIT_CONFIG_GLOBAL="$hostile_cfg" GIT_CONFIG_NOSYSTEM=1 \
  git -C "$hostile_repo" commit -qm "should fail" >/dev/null 2>&1 || hostile_rc=$?
if [ "$hostile_rc" -ne 0 ]; then _ok
else fail "the hostile git config did not make a plain commit fail (rc=0); the isolation test below proves nothing"; fi

# Direction 2: the same commit, inside a fixture test file run through run.sh, succeeds.
mkdir -p "$hostile_dir/tests"
cat > "$hostile_dir/tests/test_fixture.sh" <<'FIXTURE'
#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"
r="$(mktemp -d)"
git -C "$r" init -q
printf 'x\n' > "$r/f"
git -C "$r" add f
rc=0; git -C "$r" commit -qm "under the runner" >/dev/null 2>&1 || rc=$?
assert_eq "0" "$rc" "a commit inside a test succeeds regardless of the operator's git config"
assert_eq "main" "$(git -C "$r" symbolic-ref --short HEAD 2>/dev/null)" \
  "the runner pins init.defaultBranch=main for every scratch repository"
rm -rf "$r"
FIXTURE
printf '%s\n' 'no baseline recorded here' > "$hostile_dir/none.md"
# [T2-M3] The outer assert_exit only ever saw the nested runner's exit code -- assert_exit
# discards the child's stdout/stderr -- so a break in either of the fixture's two claims (commit
# succeeds; branch is main) produced the identical opaque message. Captured here instead, so a
# failure names which nested assertion broke, not just that something did.
d2_log="$(mktemp)"
env GIT_CONFIG_GLOBAL="$hostile_cfg" GIT_CONFIG_NOSYSTEM=1 \
    FOREMAN_TESTS_DIR="$hostile_dir/tests" FOREMAN_POLICY="$hostile_dir/none.md" \
    bash "$rr" >"$d2_log" 2>&1
d2_rc=$?
d2_detail="$(grep '  FAIL:' "$d2_log" | tr '\n' ';')"
rm -f "$d2_log"
assert_eq "0" "$d2_rc" \
  "run.sh isolates every test's git commands from a hostile global config${d2_detail:+ ($d2_detail)}"

# [T2-M1] GIT_CONFIG_PARAMETERS sits ABOVE the global config file in git's precedence order, so an
# inherited one (from a `git -c ...` wrapper, or a hook that re-exports it into a nested
# `bash tests/run.sh`) can reintroduce exactly the failure this task removes even though the
# pinned file itself is never touched. run.sh must neutralise the variable, not just the file.
hostile_params="'commit.gpgsign=true' 'gpg.format=ssh' 'user.signingkey=/nonexistent/foreman-hostile-signing-key'"

# Direction 1: the override alone, with no hostile GIT_CONFIG_GLOBAL at all, really is hostile to
# a plain commit -- otherwise direction 2 below would prove nothing.
params_repo="$(mktemp -d)"
git -C "$params_repo" init -q
printf 'x\n' > "$params_repo/f"
git -C "$params_repo" add f
params_rc=0
env GIT_CONFIG_PARAMETERS="$hostile_params" \
  git -C "$params_repo" commit -qm "should fail" >/dev/null 2>&1 || params_rc=$?
if [ "$params_rc" -ne 0 ]; then _ok
else fail "GIT_CONFIG_PARAMETERS did not make a plain commit fail (rc=0); the isolation test below proves nothing"; fi
rm -rf "$params_repo"

# Direction 2: the same override, inherited by run.sh, must not reach any test's git commands.
assert_exit 0 "run.sh neutralises an inherited GIT_CONFIG_PARAMETERS override" -- \
  env GIT_CONFIG_PARAMETERS="$hostile_params" \
      FOREMAN_TESTS_DIR="$hostile_dir/tests" FOREMAN_POLICY="$hostile_dir/none.md" \
      bash "$rr"

# [T2-M4] The pin replaces the operator's whole global config, which would otherwise silently
# drop a `safe.directory` entry a WSL or containerised checkout needs just to be usable at all --
# turning a working checkout into a failing one for exactly the contributor this task exists to
# help. run.sh must preserve one, not merely avoid mandating signing.
mkdir -p "$hostile_dir/tests_safe"
cat > "$hostile_dir/tests_safe/test_fixture.sh" <<'FIXTURE_SAFE'
#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"
assert_eq "*" "$(git config --global --get safe.directory 2>/dev/null)" \
  "the runner preserves a wildcard safe.directory for WSL/containerised checkouts"
FIXTURE_SAFE
assert_exit 0 "run.sh pins safe.directory=* for every test's git commands" -- \
  env FOREMAN_TESTS_DIR="$hostile_dir/tests_safe" FOREMAN_POLICY="$hostile_dir/none.md" bash "$rr"

rm -rf "$hostile_dir"
