#!/usr/bin/env python3
"""Record the nonzero-lower-bound bug and indirect-call type checking."""
import json
import subprocess
from pathlib import Path

here = Path(__file__).resolve().parent
opt = "/opt/llvm-project/build/bin/mlir-opt"
cases = [
    ("range-folding", ["range-folding.mlir", "--scf-for-loop-range-folding"], 0),
    ("invalid-indirect-call", ["invalid-indirect-call.mlir"], 1),
]
results = []
for name, args, expected in cases:
    process = subprocess.run([opt, *args], cwd=here, capture_output=True, text=True)
    (here / f"{name}.output.mlir").write_text(process.stdout)
    (here / f"{name}.stderr.txt").write_text(process.stderr)
    results.append({"case": name, "command": [opt, *args],
                    "exit_code": process.returncode, "expected_exit_code": expected,
                    "passed": process.returncode == expected})
    assert process.returncode == expected
(here / "results.json").write_text(json.dumps(results, indent=2) + "\n")
print(json.dumps(results, indent=2))
