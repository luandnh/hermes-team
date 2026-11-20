#!/usr/bin/env bash
# Run one eval scenario.
#
# Usage: bash evals/run.sh <scenario> [--live]
#
# Default (dry): structural checks only. Confirms the fixture is present, the
# acceptance check runs, and it fails on the untouched fixture. Prints what a
# live run would do.
#
# --live: copies the fixture to evals/work/<scenario>-<timestamp>/ and runs
# `hermes chat -q "<task>"` inside it with a timeout. Times the run, then runs
# the acceptance check and writes metrics.json. This measures pass/fail and
# wall clock for a single agent run. It does not measure code quality.

set -u

cd "$(dirname "$0")/.." || exit 1
REPO_ROOT=$(pwd)

SCENARIO="${1:-}"
MODE="dry"

if [ -z "$SCENARIO" ]; then
  echo "usage: bash evals/run.sh <scenario> [--live]" >&2
  echo "available: $(ls evals/scenarios 2>/dev/null | tr '\n' ' ')" >&2
  exit 2
fi
shift || true
for arg in "$@"; do
  case "$arg" in
    --live) MODE="live" ;;
    -h|--help)
      echo "usage: bash evals/run.sh <scenario> [--live]"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

SCEN_DIR="evals/scenarios/$SCENARIO"
FIXTURE="$SCEN_DIR/fixture"
ACCEPT="$SCEN_DIR/acceptance.sh"
TASK_MD="$SCEN_DIR/task.md"

fail=0
check() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS  $desc"
  else
    echo "  FAIL  $desc"
    fail=$((fail + 1))
  fi
}

echo "== scenario: $SCENARIO ($MODE)"
check "scenario directory exists" test -d "$SCEN_DIR"
check "fixture present" test -d "$FIXTURE"
check "acceptance.sh present" test -f "$ACCEPT"
check "task.md present" test -f "$TASK_MD"

if [ "$fail" -ne 0 ]; then
  echo
  echo "structural check failed ($fail problems); not running anything"
  exit 1
fi

# --- dry -------------------------------------------------------------------

if [ "$MODE" = "dry" ]; then
  TMP="evals/work/dry-$SCENARIO"
  rm -rf "$TMP"
  mkdir -p "$TMP"
  cp -a "$FIXTURE/." "$TMP/"

  echo "  checking that the acceptance check is runnable and fails as shipped"
  OUT=$(cd "$TMP" && timeout 120 bash "$REPO_ROOT/$ACCEPT" 2>&1)
  RC=$?
  OUT_SUMMARY=$(printf '%s\n' "$OUT" | grep -E '^[0-9]+/[0-9]+ (cases|checks) passed' | tail -1)
  if [ "$RC" -eq 0 ]; then
    echo "  FAIL  acceptance check passes on the untouched fixture (vacuous)"
    fail=$((fail + 1))
  else
    echo "  PASS  acceptance check fails on the untouched fixture (exit $RC${OUT_SUMMARY:+, $OUT_SUMMARY})"
  fi

  echo
  echo "a live run would:"
  echo "  1. copy evals/scenarios/$SCENARIO/fixture to evals/work/$SCENARIO-<timestamp>/"
  echo "  2. run: hermes chat -q '<task from $TASK_MD>' there, with a timeout"
  echo "  3. time it with date +%s%N and write evals/work/<id>/metrics.json"
  echo "  4. run acceptance.sh in that copy and record pass/fail"
  echo
  echo "  re-run with --live to do it (spends real tokens and minutes)"

  rm -rf "$TMP"
  if [ "$fail" -ne 0 ]; then
    exit 1
  fi
  echo "dry check passed"
  exit 0
fi

# --- live ------------------------------------------------------------------

HERMES_BIN="${HERMES_BIN:-$(command -v hermes || true)}"
if [ -z "$HERMES_BIN" ]; then
  echo "hermes binary not found; set HERMES_BIN=/path/to/hermes" >&2
  exit 2
fi

TS=$(date -u +%Y%m%dT%H%M%SZ)
RUN_ID="$SCENARIO-$TS"
WORK="evals/work/$RUN_ID"
mkdir -p "$WORK" || exit 1
cp -a "$FIXTURE/." "$WORK/" || exit 1

# The task text is the "## Task for the agent arm" section of task.md, minus
# the heading.
TASK_TEXT=$(awk '
  /^## Task for the agent arm/ { ingest = 1; next }
  /^## / { ingest = 0 }
  ingest { print }
' "$TASK_MD" | sed '/^[[:space:]]*$/d')
if [ -z "$TASK_TEXT" ]; then
  TASK_TEXT=$(cat "$TASK_MD")
fi

TIMEOUT_S="${EVAL_TIMEOUT:-600}"
echo "== live run: $RUN_ID"
echo "   work dir: $WORK"
echo "   timeout: ${TIMEOUT_S}s"

START_NS=$(date +%s%N)
( cd "$WORK" && timeout "$TIMEOUT_S" "$HERMES_BIN" chat -q "$TASK_TEXT" ) > "$WORK/agent.log" 2>&1
AGENT_RC=$?
END_NS=$(date +%s%N)
WALL_S=$(awk -v a="$START_NS" -v b="$END_NS" 'BEGIN { printf "%.2f", (b - a) / 1000000000 }')

echo "   agent exit: $AGENT_RC, wall clock: ${WALL_S}s"

OUT=$(cd "$WORK" && timeout 120 bash "$REPO_ROOT/$ACCEPT" 2>&1)
ACC_RC=$?
printf '%s\n' "$OUT" > "$WORK/acceptance.log"

if [ "$ACC_RC" -eq 0 ]; then
  ACC_PASS="true"
else
  ACC_PASS="false"
fi

cat > "$WORK/metrics.json" <<JSON
{
  "scenario": "$SCENARIO",
  "run_id": "$RUN_ID",
  "wall_clock_s": $WALL_S,
  "acceptance_pass": $ACC_PASS,
  "exit_code": $ACC_RC,
  "agent_exit_code": $AGENT_RC,
  "timeout_s": $TIMEOUT_S
}
JSON

echo
cat "$WORK/metrics.json"
echo
echo "metrics: $WORK/metrics.json"
echo "agent log: $WORK/agent.log"
echo "note: this records pass/fail and time only. It says nothing about code quality."

if [ "$ACC_RC" -ne 0 ]; then
  exit 1
fi
exit 0
