#!/usr/bin/env bash
# Prove the acceptance check is not vacuous: run it against the untouched
# fixture and require it to FAIL.
#
# Usage: bash evals/baseline.sh [scenario]
# Exit 0 when the baseline correctly fails, 1 when the acceptance check passes
# on untouched code (which makes it worthless).

set -u

cd "$(dirname "$0")/.." || exit 1
REPO_ROOT=$(pwd)

SCENARIO="${1:-off-by-one}"
SRC="evals/scenarios/$SCENARIO/fixture"
WORK="evals/work/baseline/$SCENARIO"

if [ ! -d "$SRC" ]; then
  echo "no such scenario: $SCENARIO" >&2
  echo "available: $(ls evals/scenarios 2>/dev/null | tr '\n' ' ')" >&2
  exit 2
fi
if [ ! -f "evals/scenarios/$SCENARIO/acceptance.sh" ]; then
  echo "scenario $SCENARIO has no acceptance.sh" >&2
  exit 2
fi

rm -rf "$WORK"
mkdir -p "$WORK" || exit 1
cp -a "$SRC/." "$WORK/" || exit 1

echo "== baseline: $SCENARIO"
echo "   fixture copied to $WORK"
echo "   running acceptance.sh on untouched code"
echo

OUT=$(cd "$WORK" && timeout 120 bash "$REPO_ROOT/evals/scenarios/$SCENARIO/acceptance.sh" 2>&1)
RC=$?

printf '%s\n' "$OUT"
echo
echo "   exit code: $RC"

# Pull "N/M cases passed" out of the test output for detail. The baseline score
# itself is the gate outcome: an acceptance check either passes (100%) or not
# (0%). The case count is reported alongside so a nearly-passing check is
# visible rather than hidden behind a binary number.
DETAIL=""
SCORE_LINE=$(printf '%s\n' "$OUT" | grep -E '^[0-9]+/[0-9]+ (cases|checks) passed' | tail -1)
if [ -n "$SCORE_LINE" ]; then
  DETAIL="$SCORE_LINE"
fi

if [ "$RC" -eq 0 ]; then
  echo "   baseline result: PASS (100%)${DETAIL:+, $DETAIL}"
  echo
  echo "################################################################"
  echo "WARNING: the acceptance check PASSED on untouched code."
  echo "The check is vacuous: it cannot distinguish a fix from no fix."
  echo "Fix the fixture or the check before trusting any eval result."
  echo "################################################################"
  exit 1
fi

echo "   baseline result: FAIL (0%)${DETAIL:+, $DETAIL}"
if [ -n "$DETAIL" ]; then
  NUM=${DETAIL%%/*}
  DEN=${DETAIL#*/}
  DEN=${DEN%% *}
  if [ "$DEN" -gt 0 ] 2>/dev/null; then
    echo "   case detail: ${NUM}/${DEN} cases matched ($((NUM * 100 / DEN))%)"
  fi
fi

echo
echo "baseline correctly fails: acceptance check is not vacuous"
exit 0
