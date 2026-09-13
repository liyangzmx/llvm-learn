#!/usr/bin/env python3
"""Reproduce LLVM 18 tiling's fixed-negative-distance semantic counterexample."""
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
OPT = Path('/opt/llvm-project/build/bin/mlir-opt')
# Built from ../ch11/translate.cpp and ../ch11/CMakeLists.txt.
TRANSLATE = Path(sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/insider-ch11-build/ch11-translate')
records = []

def run(args, output=None):
    p = subprocess.run([str(a) for a in args], capture_output=True, text=True)
    records.append({'command': [str(a) for a in args], 'exit_code': p.returncode,
                    'stdout': p.stdout, 'stderr': p.stderr})
    p.check_returncode()
    if output:
        output.write_text(p.stdout)
    return p.stdout

lowering = ['-lower-affine', '-convert-scf-to-cf', '-convert-arith-to-llvm',
            '-finalize-memref-to-llvm', '-convert-func-to-llvm', '-reconcile-unrealized-casts']
results = {}
with tempfile.TemporaryDirectory(prefix='insider-tiling-') as tmp:
    for label, passes in [('original', []), ('transformed', ['-affine-loop-tile=tile-size=2'])]:
        ir = HERE / f'tiling-{label}.llvm.mlir'
        ll = HERE / f'tiling-{label}.ll'
        exe = Path(tmp) / label
        run([OPT, HERE / 'tiling-negative-distance.runtime.mlir', *passes, *lowering, '-o', ir])
        run([TRANSLATE, ir], ll)
        run(['/usr/bin/clang', ll, HERE / 'tiling-negative-distance.runtime.c', '-o', exe])
        results[label] = int(run([exe]).strip())
assert results == {'original': 2, 'transformed': 1}, results
source = HERE / 'tiling-negative-distance.runtime.mlir'
report = {'status': 'semantic_mismatch_reproduced', 'host_execution': 'native macOS arm64 via /usr/bin/clang',
          'llvm_source_commit': '3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff',
          'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'observed_A_2_1': results, 'records': records}
(HERE / 'tiling-runtime-check.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'status': report['status'], 'observed_A_2_1': results}))
