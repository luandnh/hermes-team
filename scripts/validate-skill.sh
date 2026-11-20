#!/usr/bin/env bash
# Structural checks for the hermes-agent-team skill and the repo it lives in.
# Usage: bash scripts/validate-skill.sh
# Exit 0 when every check passes, 1 otherwise.

set -u

cd "$(dirname "$0")/.." || exit 1
REPO_ROOT=$(pwd)

SKILL="skills/hermes-agent-team/SKILL.md"
PLAN="templates/plan.md"
README="README.md"

pass=0
fail=0
n=0

ok() {
  n=$((n + 1))
  pass=$((pass + 1))
  printf '%2d. PASS  %s\n' "$n" "$1"
}

bad() {
  n=$((n + 1))
  fail=$((fail + 1))
  printf '%2d. FAIL  %s\n' "$n" "$1"
  if [ $# -gt 1 ]; then
    printf '          -> %s\n' "$2"
  fi
}

check() {
  # check <description> <command...>
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    ok "$desc"
  else
    bad "$desc"
  fi
}

# --- file existence ---------------------------------------------------------

check "SKILL.md exists at $SKILL" test -f "$SKILL"

if [ ! -f "$SKILL" ]; then
  printf '\n%d/%d checks passed\n' "$pass" "$n"
  exit 1
fi

# The body is everything after the closing frontmatter delimiter.
fm_count=$(grep -c '^---$' "$SKILL")
BODY=$(awk 'BEGIN{d=0} /^---$/{d++; next} d>=2{print}' "$SKILL")

# --- frontmatter ------------------------------------------------------------

if [ "$fm_count" -ge 2 ] && sed -n '1p' "$SKILL" | grep -qx -- '---'; then
  ok "frontmatter is delimited by ---"
else
  bad "frontmatter is delimited by ---" "found $fm_count delimiter lines"
fi

check "frontmatter has a name field" grep -qE '^name: ' "$SKILL"
check "frontmatter has a description field" grep -qE '^description: ' "$SKILL"

DESC=$(grep -m1 -E '^description: ' "$SKILL" | sed -E 's/^description:[[:space:]]*//' | sed -E 's/^"(.*)"$/\1/' | sed -E "s/^'(.*)'$/\1/")
DESC_LEN=${#DESC}

if [ "$DESC_LEN" -le 60 ] && [ "$DESC_LEN" -gt 0 ]; then
  ok "description is <= 60 chars (${DESC_LEN})"
else
  bad "description is <= 60 chars" "length ${DESC_LEN}: $DESC"
fi

case "$DESC" in
  "Use when"*) ok "description starts with 'Use when'" ;;
  *) bad "description starts with 'Use when'" "got: $DESC" ;;
esac

SKILL_NAME=$(grep -m1 -E '^name: ' "$SKILL" | sed -E 's/^name:[[:space:]]*//' | tr -d '"'"'"' \r')
DIR_NAME=$(basename "$(dirname "$SKILL")")
if [ "$SKILL_NAME" = "$DIR_NAME" ]; then
  ok "name matches directory name ($SKILL_NAME)"
else
  bad "name matches directory name" "name=$SKILL_NAME dir=$DIR_NAME"
fi

check "version is present" grep -qE '^version: [0-9]+\.[0-9]+\.[0-9]+$' "$SKILL"
check "tags list is present" grep -qE '^[[:space:]]+tags: \[.*\]$' "$SKILL"

# --- required headings ------------------------------------------------------

for h in "## When to Use" "## Runtime facts" "## Roles" "## Protocol" "## When not to fan out" "## Pitfalls"; do
  if printf '%s\n' "$BODY" | grep -qxF "$h"; then
    ok "required heading present: $h"
  else
    bad "required heading present: $h"
  fi
done

# --- hygiene ----------------------------------------------------------------

if printf '%s\n' "$BODY" | grep -qE '(/root/|/home/|~/\.)'; then
  bad "no absolute /root or /home paths in body" "matches: $(printf '%s\n' "$BODY" | grep -oE '(/root/[^ )]*|/home/[^ )]*)' | head -3 | tr '\n' ' ')"
else
  ok "no absolute /root or /home paths in body"
fi

if grep -qP '\t' "$SKILL"; then
  bad "no tab characters in SKILL.md"
else
  ok "no tab characters in SKILL.md"
fi

LINES=$(wc -l < "$SKILL" | tr -d ' ')
if [ "$LINES" -lt 500 ]; then
  ok "SKILL.md is under 500 lines (${LINES})"
else
  bad "SKILL.md is under 500 lines" "got ${LINES}"
fi

check "plan template exists at $PLAN" test -f "$PLAN"
check "README.md exists" test -f "$README"

# --- summary ----------------------------------------------------------------

printf '\n%d/%d checks passed\n' "$pass" "$n"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
