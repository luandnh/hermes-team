"""Acceptance tests for sum_last_n. Plain asserts, no pytest.

Run with: python3 tests.py
Exits 0 when every case passes, 1 on the first failure.
"""

import sys

from solution import sum_last_n

CASES = [
    # (items, n, expected, label)
    ([1, 2, 3, 4], 2, 7, "last two of four"),
    ([1, 2, 3, 4], 1, 4, "last one"),
    ([1, 2, 3, 4], 4, 10, "n equals length"),
    ([1, 2], 5, 3, "n larger than length"),
    ([5], 1, 5, "single element"),
    ([1, 2, 3], 0, 0, "n is zero"),
    ([1, 2, 3], -2, 0, "n is negative"),
    ([], 3, 0, "empty input"),
    ([10, 20, 30, 40, 50], 3, 120, "last three of five"),
    ([-1, -2, -3, -4], 2, -7, "negative values"),
]


def main():
    failed = 0
    for items, n, expected, label in CASES:
        got = sum_last_n(list(items), n)
        if got != expected:
            failed += 1
            print("FAIL  %-24s sum_last_n(%r, %d) -> %r, expected %r"
                  % (label, items, n, got, expected))
        else:
            print("ok    %-24s sum_last_n(%r, %d) -> %r"
                  % (label, items, n, got))

    total = len(CASES)
    print("%d/%d cases passed" % (total - failed, total))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
