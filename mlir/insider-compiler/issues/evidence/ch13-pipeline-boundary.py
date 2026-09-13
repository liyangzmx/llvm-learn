#!/usr/bin/env python3
"""Check abstract three-stage iteration coverage; does not run Triton."""
import json
from collections import Counter


def schedule(n, corrected):
    if n < 2:
        return [(stage, i) for i in range(n) for stage in range(3)]
    events = [(0, 0), (0, 1), (1, 0)]
    for i in range(n - 2):
        events.extend([(0, i + 2), (1, i + 1), (2, i)])
    events.extend([(1, n - 1), (2, n - 2), (2, n - 1)] if corrected
                  else [(1, n), (2, n - 1), (2, n)])
    return events


report = []
for n in range(65):
    expected = Counter((stage, i) for i in range(n) for stage in range(3))
    assert Counter(schedule(n, True)) == expected
    if n in (2, 3, 5):
        book = Counter(schedule(n, False))
        report.append({"N": n, "book_missing": list((expected - book).elements()),
                       "book_extra": list((book - expected).elements())})
print(json.dumps({"scope": "Abstract S0/S1/S2 schedule; half-open [0,N); scalar fallback for N<2",
                  "corrected_coverage": "PASS N=0..64; every (stage, iteration) exactly once",
                  "book_counterexamples": report}, indent=2))
