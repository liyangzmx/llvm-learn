#!/usr/bin/env python3
"""Reproduce the local LLVM 18.1.8 bufferization audit (no LLVM source edits)."""
import json
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
OPT = "/opt/llvm-project/build/bin/mlir-opt"
cases = [
    ("one-shot", ["analysis.mlir", "--one-shot-bufferize=bufferize-function-boundaries"], True),
    ("deallocated", ["one-shot.mlir", "--pass-pipeline=builtin.module(buffer-deallocation-pipeline)"], True),
    ("pipeline", ["analysis.mlir", "--pass-pipeline=builtin.module(buffer-deallocation-pipeline)", "--dump-pass-pipeline"], True),
    ("unsupported-order", ["analysis.mlir", "--one-shot-bufferize=analysis-heuristic=bottom-up-from-terminators"], False),
]
results = []
for name, args, expected_success in cases:
    process = subprocess.run([OPT, *args], cwd=HERE, capture_output=True, text=True)
    (HERE / f"{name}.mlir").write_text(process.stdout)
    (HERE / f"{name}.stderr.txt").write_text(process.stderr)
    result = {"case": name, "command": [OPT, *args], "exit_code": process.returncode,
              "expected_success": expected_success,
              "passed": (process.returncode == 0) == expected_success}
    results.append(result)
    if not result["passed"]:
        raise SystemExit(json.dumps(result, ensure_ascii=False))
one_shot = (HERE / "one-shot.mlir").read_text()
deallocated = (HERE / "deallocated.mlir").read_text()
assert "memref.copy" in one_shot
assert "memref.dealloc" not in one_shot
assert "memref.dealloc" in deallocated
(HERE / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(results, ensure_ascii=False, indent=2))
