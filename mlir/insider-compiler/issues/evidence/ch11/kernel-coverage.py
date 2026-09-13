#!/usr/bin/env python3
"""Check output coordinate coverage, not GPU execution or floating-point results."""
from collections import Counter
from pathlib import Path
import json

corrected = Counter()
original = Counter()
for bx in range(8):
    for by in range(32):
        for tx in range(16):
            for ty in range(16):
                r, c = bx * 16 + tx, by * 16 + ty
                if r < 128 and c < 512:
                    corrected[r, c] += 1
                r, c = bx * 128 + tx, by * 512 + ty
                if r < 128 and c < 512:
                    original[r, c] += 1
assert len(corrected) == 128 * 512
assert set(corrected.values()) == {1}
assert len(original) == 16 * 16
result = {'block': [16, 16], 'grid': [8, 32], 'expected_outputs': 128 * 512,
          'corrected_covered_once': len(corrected), 'original_covered': len(original)}
print(json.dumps(result, indent=2))
Path(__file__).with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
