#!/usr/bin/env python3
"""Reproduce chapter 8's LLVM 18.1.8 checks; keep commands and results beside inputs."""
from pathlib import Path
import re
import shlex
import subprocess
root = Path(__file__).resolve().parent
opt = '/opt/llvm-project/build/bin/mlir-opt'
log = []
def run(name, args, expect=0):
    cmd = [opt, *args]
    r = subprocess.run(cmd, text=True, capture_output=True)
    log.append('$ ' + shlex.join(cmd) + '\nexit: ' + str(r.returncode) + '\n' + r.stdout + r.stderr)
    assert r.returncode == expect, (name, r.returncode, r.stderr)
    (root / (name + '.out')).write_text(r.stdout + r.stderr)
    return r.stdout + r.stderr
run('version', ['--version'])
pipeline = '--pass-pipeline=builtin.module(func.func(tosa-to-linalg-named))'
r = run('matmul-local', [str(root/'matmul-local.mlir'), pipeline])
assert 'linalg.batch_matmul ' in r and 'linalg.fill ' in r
assert r.count('tosa.const') == 2
r = run('matmul-f16', [str(root/'matmul-f16.mlir'), pipeline])
assert r.count('linalg.batch_matmul ') == 2 and 'tensor<1x5x6xf32>' in r
r = run('matmul-cse', [str(root/'matmul-local.mlir'), '--pass-pipeline=builtin.module(func.func(tosa-to-linalg-named,cse))'])
assert 'tosa.const' not in r
r = run('matmul-quantized', [str(root/'matmul-quantized.mlir'), pipeline])
assert 'linalg.quantized_batch_matmul' in r
r = run('broadcast', [str(root/'broadcast.mlir'), '--pass-pipeline=builtin.module(func.func(tosa-make-broadcastable))'])
assert 'tosa.reshape' in r and 'tensor<1x4xf32>' in r
run('book-8-1', [str(root/'book-8-1.mlir')], expect=1)
fixed = (root/'book-8-1.mlir').read_text().replace('values =', 'value =')
(root/'book-four-operands.mlir').write_text(fixed)
run('book-four-operands', [str(root/'book-four-operands.mlir')], expect=1)
(root/'commands-and-results.txt').write_text('\n\n'.join(log))
print('PASS: local matmul lowering, zero-point quantized lowering, cse dead constants, rank broadcasting; book forms rejected as expected')
