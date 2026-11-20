#!/usr/bin/env bash
# Install the skill into a Hermes profile.
# Usage: bash scripts/install.sh [--force]
# HERMES_HOME overrides the profile root (default: $HOME/.hermes).

set -u

cd "$(dirname "$0")/.." || exit 1
REPO_ROOT=$(pwd)

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help)
      echo "usage: bash scripts/install.sh [--force]"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

echo "== validating skill before install"
if ! bash scripts/validate-skill.sh; then
  echo "install aborted: validation failed" >&2
  exit 1
fi

DEST_ROOT="${HERMES_HOME:-$HOME/.hermes}/skills/autonomous-ai-agents/hermes-agent-team"
DEST="$DEST_ROOT/SKILL.md"
SRC="skills/hermes-agent-team/SKILL.md"

if [ -e "$DEST" ] && [ "$FORCE" -ne 1 ]; then
  if cmp -s "$SRC" "$DEST"; then
    echo "already installed and identical: $DEST"
    exit 0
  fi
  echo "refusing to overwrite existing target: $DEST" >&2
  echo "re-run with --force to replace it" >&2
  exit 1
fi

mkdir -p "$DEST_ROOT" || exit 1
cp "$SRC" "$DEST" || exit 1

echo "== installed"
echo "destination: $DEST"
echo "size: $(wc -c < "$DEST" | tr -d ' ') bytes, $(wc -l < "$DEST" | tr -d ' ') lines"
echo "restart the Hermes session (or run /reload) for the skill index to pick it up."
