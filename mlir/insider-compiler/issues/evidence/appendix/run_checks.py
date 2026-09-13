#!/usr/bin/env python3
"""Bounded parse/conversion checks for the appendix, using local LLVM 18.

This does not execute asynchronous/distributed/quantized programs or validate
the newer dialects that are absent from the local checkout.
"""
from pathlib import Path
import json
import subprocess

HERE = Path(__file__).resolve().parent
LLVM = Path("/opt/llvm-project")
OPT = LLVM / "build/bin/mlir-opt"


def run(name, args, expected=0):
    command = [str(OPT), *args]
    result = subprocess.run(command, cwd=HERE, text=True, capture_output=True)
    (HERE / f"{name}.stdout.txt").write_text(result.stdout)
    (HERE / f"{name}.stderr.txt").write_text(result.stderr)
    assert result.returncode == expected, (name, result.returncode, result.stderr)
    record = {"name": name, "command": command, "cwd": str(HERE),
              "returncode": result.returncode, "expected_returncode": expected}
    records.append(record)
    return result.stdout, result.stderr


records = []
version, _ = run("version", ["--version"])
assert "LLVM version 18.1.8" in version
revision = subprocess.check_output(
    ["git", "-C", str(LLVM), "rev-parse", "HEAD"], text=True).strip()
assert revision == "3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff"
dlti, _ = run("dlti-18", ["dlti-18.mlir"])
assert "dlti.stack_alignment" in dlti and "vector<4xi64>" in dlti
_, unsupported = run("dlti-newer", ["dlti-newer.mlir"], expected=1)
assert "unknown attrribute type: target_system_spec" in unsupported
ub, _ = run("ub-to-llvm", ["ub.mlir", "--convert-ub-to-llvm"])
assert "llvm.mlir.poison" in ub and "ub.poison" not in ub
quant, _ = run("quant-canonicalize", ["quant.mlir", "--canonicalize"])
assert "quant.qcast" in quant and "quant.dcast" in quant
assert "quant.scast" not in quant
assert "!quant.uniform<i8:f32:1," in quant
mesh, _ = run("mesh-propagation", ["mesh.mlir", "--sharding-propagation"])
annotated, unannotated = mesh.split("func.func @unannotated", 1)
assert annotated.count("mesh.shard") == 2
assert "annotate_for_users" in annotated
assert "mesh.shard" not in unannotated
help_text, _ = run("available", ["--help"])
assert "--sharding-propagation " in help_text
assert "--mesh-spmdization " not in help_text
assert "--test-mesh-resharding-spmdization " in help_text
available_line = next(line for line in help_text.splitlines()
                      if line.startswith("Available Dialects:"))
available_dialects = set(available_line.partition(":")[2].strip().split(", "))
assert "ptr" not in available_dialects and "polynomial" not in available_dialects
for name in ("Ptr", "Polynomial"):
    assert not (LLVM / "mlir/include/mlir/Dialect" / name).exists()
    assert not (LLVM / "mlir/lib/Dialect" / name).exists()
report = {"llvm_commit": revision, "checks": records,
          "available_dialects": sorted(available_dialects),
          "limitations": ["No newer LLVM build; missing dialects are version boundaries.",
                          "No JIT, distributed execution, async runtime execution, or numerical quantization test."]}
(HERE / "results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(f"PASS: {len(records)} tool invocations; LLVM {revision}")
