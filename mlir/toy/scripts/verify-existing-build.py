#!/usr/bin/env python3
"""Run the Toy labs and upstream tests using existing LLVM 18 tools only.

Reads the tutorial's bash blocks; configuration/build/environment setup blocks
are skipped. Every command, exit code, stdout and stderr is saved under --output.
No CMake, Ninja, package installation or writes to llvm-project are performed.
"""

import argparse
import collections
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, help="New directory for evidence")
args = parser.parse_args()
OUT = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="toy18-check-"))
if args.output:
    OUT.mkdir(parents=True, exist_ok=False)
BUILD = Path(os.environ.get("TOY_BUILD", "/opt/llvm-project/build")).resolve()
SOURCE = Path("/opt/llvm-project")
BIN = BUILD / "bin"
env = dict(os.environ, TOY_ROOT=str(ROOT), TOY_BUILD=str(BUILD), TOY_LAB=str(OUT))
results = []


def run(name, command, *, expected=0, stdout=None, contains=(), absent=()):
    proc = subprocess.run(command, cwd=OUT, env=env, capture_output=True,
                          text=True, timeout=120)
    (OUT / (name + ".stdout")).write_text(proc.stdout)
    (OUT / (name + ".stderr")).write_text(proc.stderr)
    combined = proc.stdout + proc.stderr
    ok = (proc.returncode == expected
          and (stdout is None or proc.stdout == stdout)
          and all(word in combined for word in contains)
          and all(word not in combined for word in absent))
    results.append(dict(name=name, command=list(map(str, command)),
                        returncode=proc.returncode, expected=expected,
                        expected_stdout=stdout, contains=list(contains),
                        absent=list(absent), passed=ok))
    print(f'{"PASS" if ok else "FAIL"}: {name}', flush=True)
    return proc


def toy(name, chapter, path, *flags, **checks):
    return run(name, [str(BIN / f"toyc-ch{chapter}"), str(path), *flags], **checks)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


for tool in [*(f"toyc-ch{i}" for i in range(1, 8)), "FileCheck", "mlir-opt", "mlir-tblgen", "llvm-lit"]:
    require((BIN / tool).is_file(), f"Missing existing tool: {BIN / tool}")

run("source-revision", ["git", "-C", str(SOURCE), "rev-parse", "HEAD"])
run("binary-version", [str(BIN / "toyc-ch7"), "--version"], contains=("18.1.8",))
cache = (BUILD / "CMakeCache.txt").read_text()
(OUT / "build-config.txt").write_text("\n".join(
    line for line in cache.splitlines() if re.match(
        r"(?:CMAKE_BUILD_TYPE|LLVM_(?:ENABLE_PROJECTS|BUILD_EXAMPLES|INCLUDE_EXAMPLES|"
        r"TARGETS_TO_BUILD|ENABLE_ASSERTIONS|HOST_TRIPLE|DEFAULT_TARGET_TRIPLE)):", line)) + "\n")

# Re-run the documented command blocks in chapter order, in an isolated cwd.
labs = []
for document in sorted((ROOT / "aiversion").glob("0*.md")):
    text = document.read_text()
    for index, match in enumerate(re.finditer(r"^```bash\n(.*?)^```", text, re.M | re.S), 1):
        code = match[1]
        if "cmake -G" in code or re.search(r"^export ", code, re.M):
            continue
        code = re.sub(r"^cmake --build[^\n]*\n?", "", code, flags=re.M)
        if not code.strip():
            continue
        require(not re.search(r"\b(?:cmake|ninja)\b(?! --version)", code),
                f"Unexpected build command in {document.name}")
        name = f"lab-{document.stem}-{index:02}"
        (OUT / (name + ".sh")).write_text(code)
        expected = 1 if "diff -u " in code and document.name[:2] in {"03", "05", "06", "07"} else 0
        run(name, ["bash", "-e", "-o", "pipefail", "-c", code], expected=expected)
        labs.append(dict(name=name, document=str(document.relative_to(ROOT)),
                         line=text[:match.start()].count("\n") + 1, command=code))
(OUT / "labs.json").write_text(json.dumps(labs, ensure_ascii=False, indent=2) + "\n")

# Independently check observable results: upstream jit.toy only checks exit 0.
matrix = "1.000000 2.000000 \n3.000000 4.000000 \n"
product = "1.000000 16.000000 \n4.000000 25.000000 \n9.000000 36.000000 \n"
for chapter in (6, 7):
    for opt in (False, True):
        flags = ["-emit=jit"] + (["-opt"] if opt else [])
        for filename, expected in (("jit.toy", matrix), ("llvm-lowering.mlir", product)):
            toy(f"numeric-ch{chapter}-{filename}-opt{int(opt)}", chapter,
                SOURCE / f"mlir/test/Examples/Toy/Ch{chapter}" / filename,
                *flags, stdout=expected)
        if chapter == 7:
            toy(f"numeric-struct-opt{int(opt)}", 7,
                SOURCE / "mlir/test/Examples/Toy/Ch7/struct-codegen.toy",
                *flags, stdout=product)
require(all(result["passed"] for result in results if result["name"].startswith("numeric-")),
        "Toy JIT probes failed; cannot enable host-supports-jit for lit")

# Load the actual upstream lit configuration and tests, redirecting only outputs.
# The optional mlir-cpu-runner probe can be absent although Toy JIT works. The
# numerical probes above must pass before this local feature override is used.
lit_dir = OUT / "lit"
lit_dir.mkdir()
(lit_dir / "lit.cfg.py").write_text(
    "lit_config.load_config(config, " + repr(str(BUILD / "tools/mlir/test/lit.site.cfg.py")) + ")\n"
    "config.name = 'MLIR-Toy-existing-build'\n"
    "config.test_source_root = " + repr(str(SOURCE / "mlir/test/Examples/Toy")) + "\n"
    "config.test_exec_root = " + repr(str(lit_dir)) + "\n"
    "config.available_features.add('host-supports-jit')\n")
run("upstream-lit", [sys.executable, str(BIN / "llvm-lit"), "-v", "-j", "2",
                     "--output", str(OUT / "lit-results.json"), str(lit_dir)])
lit = json.loads((OUT / "lit-results.json").read_text())
counts = collections.Counter(test["code"] for test in lit["tests"])
require(counts == {"PASS": 56}, f"Unexpected upstream test coverage: {dict(counts)}")

# Check complete Toy/MLIR fenced programs, not incomplete pedagogical fragments.
for document in sorted((ROOT / "aiversion").glob("0[1-7]-*.md")):
    chapter = int(document.name[:2])
    for index, match in enumerate(re.finditer(r"^```(toy|mlir)\n(.*?)^```", document.read_text(), re.M | re.S), 1):
        language, code = match.groups()
        if language != "toy" and not re.match(r"(module\s*\{|(?:toy\.|func\.)func\s)", code):
            continue
        name = f"snippet-ch{chapter}-{index:02}"
        path = OUT / (name + "." + language)
        path.write_text(code)
        if language == "mlir" and "func.func" in code:
            # LLVM 18 permits an unknown last op to potentially be a terminator.
            # This is opaque parsing, not validation against Toy's registered ODS.
            run(name, [str(BIN / "mlir-opt"), str(path), "-allow-unregistered-dialect"],
                contains=('"toy.print"()',) if '"toy.print"()' in code else ())
        else:
            toy(name, chapter, path, "-emit=ast" if chapter == 1 else "-emit=mlir")

shared = toy("shared-transpose", 3, ROOT / "aiversion/examples/03-shared-transpose.mlir",
             "-emit=mlir", "-opt")
match = re.search(r"(%\w+) = toy.transpose\((%\w+)", shared.stderr)
prints = re.findall(r"toy.print (%\w+)", shared.stderr)
require(shared.stderr.count("toy.transpose") == 1 and match
        and prints == [match[1], match[2]], "Shared transpose use-def relation differs")
reshape = ROOT / "aiversion/examples/05-live-reshape.toy"
toy("live-reshape-mlir", 5, reshape, "-emit=mlir", "-opt", contains=("toy.reshape",))
toy("live-reshape-rejected", 5, reshape, "-emit=mlir-affine", expected=4,
    contains=("failed to legalize operation 'toy.reshape'",))

# Scalar/1D printing has no final newline; preserve the exact whitespace contract.
for name, code, expected in (("scalar", "5.5", "5.500000 "),
                             ("vector", "[1, 2, 3]", "1.000000 2.000000 3.000000 ")):
    path = OUT / (name + ".toy")
    path.write_text(f"def main() {{ print({code}); }}\n")
    toy("print-" + name, 6, path, "-emit=jit", stdout=expected)

# Parser precedence is an AST property, independent of shape correctness.
path = OUT / "precedence.toy"
path.write_text("def f(a, b) { return a + a * b; }\n")
precedence = toy("precedence", 1, path, "-emit=ast")
require(precedence.stderr.index("BinOp: +") < precedence.stderr.index("BinOp: *"),
        "AST does not place addition above multiplication")

# Documented upstream limitations: an exit code alone does not cover diagnostics,
# and rank propagation does not validate shape compatibility. Never JIT bad shapes.
path = OUT / "unknown-variable.toy"
path.write_text("def main() { print(missing); }\n")
toy("known-error-propagation-gap", 2, path, "-emit=mlir",
    contains=("unknown variable 'missing'", "toy.return"))
path = OUT / "mismatched-shapes.toy"
path.write_text("def main() { var a = [[1,2,3],[4,5,6]]; "
                "var b = [[1,2],[3,4],[5,6]]; print(a * b); }\n")
toy("known-shape-validation-gap", 4, path, "-emit=mlir", "-opt",
    contains=("toy.mul", "tensor<2x3xf64>", "tensor<3x2xf64>"), absent=("error:",))

summary = dict(source=str(SOURCE), build=str(BUILD), output=str(OUT),
               rebuilt=False, lab_blocks=len(labs), lit_counts=dict(counts),
               checks=results, passed=all(result["passed"] for result in results))
(OUT / "results.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
print(f"Evidence: {OUT}")
sys.exit(0 if summary["passed"] else 1)
