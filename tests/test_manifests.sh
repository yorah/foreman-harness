#!/usr/bin/env bash
set -uo pipefail
source "$FOREMAN_ROOT/tests/lib_assert.sh"

# --- marketplace manifest -------------------------------------------------
mp="$FOREMAN_ROOT/.claude-plugin/marketplace.json"
[ -f "$mp" ] || fail "missing $mp"
assert_eq "foreman" "$(jq -r '.name' "$mp")" "marketplace name"
assert_eq "1" "$(jq -r '.plugins | length' "$mp")" "marketplace declares one plugin"
assert_eq "foreman" "$(jq -r '.plugins[0].name' "$mp")" "plugin name in marketplace"
assert_eq "./" "$(jq -r '.plugins[0].source' "$mp")" "plugin source is this directory"

# --- plugin manifest ------------------------------------------------------
pj="$FOREMAN_ROOT/.claude-plugin/plugin.json"
[ -f "$pj" ] || fail "missing $pj"
assert_eq "foreman" "$(jq -r '.name' "$pj")" "plugin name"
# [T1-M1]: `!= "null"` rejects a missing key and accepts an empty string, which is the same
# defect one step along -- a plugin.json with "version": "" published cleanly. Checked for
# non-empty, not merely non-null.
for k in version description; do
  v="$(jq -r --arg k "$k" '.[$k] // ""' "$pj" 2>/dev/null)"
  if [ -n "$v" ] && [ "$v" != "null" ]; then _ok
  else fail "plugin.json $k is missing or empty: [$v]"; fi
done

# --- frontmatter ----------------------------------------------------------
# Prints the frontmatter block of a markdown file (between the first two --- lines).
frontmatter() { awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1{print}' "$1"; }

while IFS= read -r f; do
  fm="$(frontmatter "$f")"
  assert_contains "$fm" "name:" "$(basename "$(dirname "$f")")/SKILL.md has name:"
  assert_contains "$fm" "description:" "$(basename "$(dirname "$f")")/SKILL.md has description:"
done < <(find "$FOREMAN_ROOT/skills" -name SKILL.md 2>/dev/null)

while IFS= read -r f; do
  fm="$(frontmatter "$f")"
  assert_contains "$fm" "name:" "$(basename "$f") has name:"
  assert_contains "$fm" "description:" "$(basename "$f") has description:"
  assert_contains "$fm" "tools:" "$(basename "$f") has tools:"
done < <(find "$FOREMAN_ROOT/agents" -name '*.md' 2>/dev/null)

while IFS= read -r f; do
  assert_contains "$(frontmatter "$f")" "description:" "$(basename "$f") has description:"
done < <(find "$FOREMAN_ROOT/commands" -name '*.md' 2>/dev/null)

# --- no placeholders in shipped markdown ----------------------------------
for d in skills agents commands; do
  [ -d "$FOREMAN_ROOT/$d" ] || continue
  hits="$(grep -rlE '\b(TODO|TBD|FIXME)\b' "$FOREMAN_ROOT/$d" || true)"
  assert_eq "" "$hits" "no TODO/TBD/FIXME under $d/"
done
