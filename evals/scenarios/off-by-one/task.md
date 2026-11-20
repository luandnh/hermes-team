# Scenario: off-by-one in sum_last_n

`fixture/solution.py` contains `sum_last_n(items, n)`, which is supposed to
return the sum of the last `n` items of `items`:

- `n <= 0` or an empty `items` returns `0`
- `n >= len(items)` returns the sum of everything
- otherwise it returns the sum of exactly the last `n` elements

It currently returns the wrong value for the middle case.

## Task for the agent arm

Fix `solution.py` so that `python3 tests.py` passes. Change only
`solution.py`; do not edit `tests.py`, and do not weaken the contract. Report
the command you ran and its full output.

## Acceptance

```bash
bash acceptance.sh
```

Exit code 0 and `10/10 cases passed` in the output.

## Note

This fixture fails as shipped. That is on purpose: `evals/baseline.sh` runs the
acceptance check against the untouched fixture and requires it to fail. An
acceptance check that passes before any work is done measures nothing.
