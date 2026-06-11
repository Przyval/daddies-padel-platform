"""Reference comparators + an explicit port of Dart's List.sort.

Dart's List.sort uses *insertion sort* for lists of length <= 32 (the
`_INSERTION_SORT_THRESHOLD`). Every Americano standings sort is well under that.
Insertion sort is order-sensitive, which matters because the head-to-head
comparator is PAIRWISE and therefore non-transitive — `sorted(cmp_to_key(...))`
(TimSort) can return a different order for a cycle. We port Dart's insertion
sort exactly so the order matches the reference byte-for-byte.
"""
from __future__ import annotations

from typing import Callable, Sequence


def _cmp(x: int, y: int) -> int:
    """Dart int.compareTo(): sign(x - y)."""
    return (x > y) - (x < y)


def compare_by_score(a, b) -> int:
    """Dart PlayerStanding.compareByScore — score → wins → losses → bonus → diffPts."""
    c = _cmp(b.score, a.score)
    if c:
        return c
    c = _cmp(b.wins, a.wins)
    if c:
        return c
    c = _cmp(a.losses, b.losses)
    if c:
        return c
    c = _cmp(b.bonus_points, a.bonus_points)
    if c:
        return c
    return _cmp(b.diff_pts, a.diff_pts)


def make_compare_by_wins(use_head2head: bool) -> Callable:
    """Dart PlayerStanding.compareByWins — wins → losses → [h2h] → score → bonus → diffPts."""
    def cmp(a, b) -> int:
        c = _cmp(b.wins, a.wins)
        if c:
            return c
        c = _cmp(a.losses, b.losses)
        if c:
            return c
        if use_head2head:
            h2h = a.h2h.get(b.player_id, 0)  # a.deltaWinsAgainst(b)
            if h2h != 0:
                return -1 if h2h > 0 else 1
        c = _cmp(b.score, a.score)
        if c:
            return c
        c = _cmp(b.bonus_points, a.bonus_points)
        if c:
            return c
        return _cmp(b.diff_pts, a.diff_pts)
    return cmp


def dart_sort(items: Sequence, compare: Callable) -> list:
    """Port of Dart's insertion sort (used for lists <= 32 elements).

    `compare(x, y) < 0` means x ranks before y. Preserves input order for
    equal elements; reproduces reference order under non-transitive comparators.
    """
    a = list(items)  # never mutate the caller's sequence
    for i in range(1, len(a)):
        element = a[i]
        j = i
        while j > 0 and compare(element, a[j - 1]) < 0:
            a[j] = a[j - 1]
            j -= 1
        a[j] = element
    return a
