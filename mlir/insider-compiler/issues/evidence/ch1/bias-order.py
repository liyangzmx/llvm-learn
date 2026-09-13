#!/usr/bin/env python3
"""Counterexample for bias placement in the chapter's f32 reduction.

Explicitly round each scalar multiplication/addition to IEEE binary32.
This models two sequential evaluation orders, not a particular GPU kernel.
"""
import json
import struct


def f32(value):
    return struct.unpack("<f", struct.pack("<f", value))[0]


x = [f32(1)] * 16
column = [f32(2**24), f32(-(2**24))] + [f32(0)] * 14
bias = f32(1)
products = [f32(a * b) for a, b in zip(x, column)]
zero_acc = f32(0)
bias_acc = bias
for product in products:
    zero_acc = f32(zero_acc + product)
    bias_acc = f32(bias_acc + product)
post_bias = f32(zero_acc + bias)
assert post_bias == 1.0 and bias_acc == 0.0
print(json.dumps({
    "scope": "Two explicit sequential binary32 evaluation orders; no PyTorch, TOSA runtime, GPU, or performance measurement.",
    "shape": {"x": [1, 16], "weights": [16, 10], "bias": [1, 10]},
    "construction": "Use the same weights column and bias for all 10 output columns.",
    "x": x,
    "weights_column": column,
    "bias": bias,
    "zero_initialized_sum_then_bias": post_bias,
    "bias_initialized_sum": bias_acc,
    "bitwise_equivalent": False,
}, indent=2) + "\n", end="")
