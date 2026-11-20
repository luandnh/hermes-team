"""Fixture with a deliberate off-by-one. Do not fix this in the repo."""


def sum_last_n(items, n):
    """Return the sum of the last n items of `items`.

    Contract:
      - n <= 0 or empty items  -> 0
      - n >= len(items)        -> sum of everything
      - otherwise              -> sum of exactly the last n elements
    """
    if n <= 0 or not items:
        return 0
    if n >= len(items):
        return sum(items)
    return sum(items[-n - 1:])
