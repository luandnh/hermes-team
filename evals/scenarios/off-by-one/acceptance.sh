#!/usr/bin/env bash
# Acceptance check for the off-by-one scenario.
# Runs the plain-python test file and exits with its code.
#
# Usage:
#   bash acceptance.sh              # run in the current dir if it has tests.py,
#                                   # otherwise in the shipped fixture
#   bash acceptance.sh <dir>        # run in <dir>

set -u

if [ "$#" -ge 1 ]; then
  cd "$1" || exit 1
elif [ -f tests.py ]; then
  :
else
  cd "$(dirname "$0")/fixture" || exit 1
fi

if [ ! -f tests.py ]; then
  echo "no tests.py in $(pwd)" >&2
  exit 2
fi

python3 tests.py
