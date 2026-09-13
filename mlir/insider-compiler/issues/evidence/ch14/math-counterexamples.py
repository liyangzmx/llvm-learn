#!/usr/bin/env python3
"""Exact counterexamples supplement, rather than replace, the written proofs."""
import json
from fractions import Fraction as F
from math import gcd
from pathlib import Path

f = lambda x: x * x * (1 - x)
points = [F(-1, 2), F(-1, 10), F(1, 10), F(1, 2)]
assert all(f(x) > f(F(0)) for x in points)
assert f(F(2)) == -4
assert (1000 % gcd(1, 1)) == 0
assert not any(i == j + 1000 for i in range(1, 101) for j in range(1, 101))
midpoint = (F(1) + F(2)) / 2
assert midpoint.denominator != 1
# Convexity at x=-1,y=1, alpha=1/2 fails for -x^2.
assert -(F(0) ** 2) > (-(F(-1) ** 2) - F(1) ** 2) / 2
# x^2-y^2 fails both convexity and concavity along coordinate axes.
assert F(0) > (F(-1) + F(-1)) / 2
assert F(0) < (F(1) + F(1)) / 2
result = {
    "arithmetic": "fractions.Fraction and exact integers",
    "bounded_gcd_test": {"passes_gcd": True, "bounded_solution_exists": False},
    "nonconvex_integer_set": {"endpoints": [1, 2], "midpoint": str(midpoint)},
    "convex_domain_nonconvex_objective": {
        "f(0)": "0", "f(2)": "-4",
        "nearby_samples": {str(x): str(f(x)) for x in points},
        "local_minimum_proof": "x^2 > 0 and 1-x > 0 for 0 < abs(x) < 1"
    },
    "negative_weight_convexity_counterexample": "passed",
    "affine_restriction_counterexample": "f(x,y)=x^2-y^2; f(t,0)=t^2",
    "status": "passed",
}
Path(__file__).with_suffix(".json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
