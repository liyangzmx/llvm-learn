#!/usr/bin/env python3
"""Enumerate 32 four-byte banks; arithmetic model, not a GPU benchmark."""
import json
from collections import Counter


def distribution(addresses):
    counts = Counter(word_address % 32 for word_address in addresses)
    return {"unique_banks": len(counts), "addresses_per_bank": dict(sorted(counts.items()))}


col = 0
result = {
    "assumptions": "32 banks; one f32 word per bank step; row increases across lanes; col=0; distinct addresses; no broadcast",
    "book_original_scalar_32_lanes": distribution([128 * row + col for row in range(32)]),
    "book_proposed_scalar_32_lanes": distribution([136 * row + col * 8 for row in range(32)]),
    "local_xor_scalar_32_lanes": distribution([128 * row + (col ^ ((row & 31) << 2)) for row in range(32)]),
    "original_eight_128bit_vectors": distribution([128 * row + col + element for row in range(8) for element in range(4)]),
    "local_xor_eight_128bit_vectors": distribution([128 * row + (col ^ ((row & 31) << 2)) + element for row in range(8) for element in range(4)]),
    "book_proposed_first_out_of_bounds_column": next(c for c in range(128) if c * 8 >= 136),
}
assert result["book_original_scalar_32_lanes"]["unique_banks"] == 1
assert result["book_proposed_scalar_32_lanes"]["unique_banks"] == 4
assert result["local_xor_scalar_32_lanes"]["unique_banks"] == 8
assert result["local_xor_eight_128bit_vectors"]["unique_banks"] == 32
print(json.dumps(result, ensure_ascii=False, indent=2))
