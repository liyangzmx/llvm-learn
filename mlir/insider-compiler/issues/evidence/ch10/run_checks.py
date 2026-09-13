#!/usr/bin/env python3
"""Reproduce the chapter 10 lowering examples with local LLVM 18.1.8."""
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
    text = r.stdout + r.stderr
    (root/(name+'.out')).write_text(text)
    log.append('$ '+shlex.join(cmd)+'\nexit: '+str(r.returncode)+'\n'+text)
    (root/'commands-and-results.txt').write_text('\n\n'.join(log))
    if expect is not None:
        assert r.returncode == expect, (name,r.returncode,r.stderr)
    return r
run('version',['--version'])
for name, flags in [
    ('func',['--convert-func-to-llvm']),
    ('scf',['--convert-scf-to-cf']),
    ('arith',['--convert-arith-to-llvm']),
    ('index',['--convert-index-to-llvm']),
    ('complex',['--convert-complex-to-llvm']),
    ('alloc',['--finalize-memref-to-llvm']),
    ('shape',['--convert-shape-to-std']),
    ('math',['--convert-math-to-libm']),
]:
    run(name,[str(root/(name+'.mlir')),*flags])
run('cf',[str(root/'scf.out'),'--convert-cf-to-llvm'])
run('extract-default',[str(root/'extract.mlir'),'--one-shot-bufferize'],expect=0)
run('extract',[str(root/'extract.mlir'),'--one-shot-bufferize=allow-unknown-ops'])
run('math-llvm',[str(root/'math.mlir'),'--convert-math-to-llvm'])
run('func-call',[str(root/'func-call.mlir'),'--convert-func-to-llvm'],expect=None)
run('unranked',[str(root/'unranked.mlir')])
run('fma-no-contract',[str(root/'fma.mlir'),'--math-uplift-to-fma'])
(root/'fma-contract.mlir').write_text((root/'fma.mlir').read_text().replace('%a, %b : f32', '%a, %b fastmath<contract> : f32').replace('%m, %c : f32', '%m, %c fastmath<contract> : f32'))
run('fma-contract',[str(root/'fma-contract.mlir'),'--math-uplift-to-fma'])
run('scf-full',[str(root/'scf.mlir'),'--convert-scf-to-cf','--convert-cf-to-llvm','--convert-arith-to-llvm','--convert-func-to-llvm','--reconcile-unrealized-casts'])
run('index-reconcile',[str(root/'index.out'),'--reconcile-unrealized-casts'],expect=1)
run('index32',[str(root/'index.mlir'),'--convert-index-to-llvm=index-bitwidth=32'])
(root/'func-caller.mlir').write_text('func.func @my() { return }\nfunc.func @caller() { func.call @my() : () -> () return }\n')
run('func-caller',[str(root/'func-caller.mlir'),'--convert-func-to-llvm'])
assert 'math.fma' in (root/'fma-contract.out').read_text()
assert 'math.fma' not in (root/'fma-no-contract.out').read_text()
assert 'cf.br ' in (root/'cf.out').read_text()
assert 'cf.br ' not in (root/'scf-full.out').read_text()
assert 'to i32' in (root/'index32.out').read_text()
run('shape-constraint', [str(root/'shape-constraint.mlir'), '--remove-shape-constraints'])
r = (root/'shape-constraint.out').read_text()
assert 'shape.cstr_eq' not in r and 'shape.const_witness true' in r and 'shape.cstr_require' in r
run('math-no-approximation', [str(root/'math.mlir'), '--convert-math-to-llvm=approximate-log1p=false'])
assert 'math.log1p' in (root/'math-no-approximation.out').read_text()
run('lift-cf', [str(root/'scf.out'), '--lift-cf-to-scf'])
assert 'scf.' in (root/'lift-cf.out').read_text()
# Verify every exact MLIR listing after transcription, including partial-conversion IR.
markdown = (root.parent.parent.parent/'insider-compiler-ch10.md').read_text()
blocks = re.findall(r'```mlir\n(.*?)\n```', markdown, re.S)
assert len(blocks) == 20, len(blocks)
for number, block in enumerate(blocks, 1):
    path = root / ('listing-%02d.mlir' % number)
    path.write_text(block+'\n')
    run('listing-%02d' % number, [str(path)])
# This C computation checks the rounding distinction, not JIT execution of MLIR.
for name, cmd in [
    ('log1p-accuracy-compile', ['cc', '-std=c11', '-O0', str(root/'log1p-accuracy.c'), '-lm', '-o', '/private/tmp/insider-ch10-log1p']),
    ('log1p-accuracy-run', ['/private/tmp/insider-ch10-log1p']),
]:
    r = subprocess.run(cmd, text=True, capture_output=True)
    (root/(name+'.out')).write_text(r.stdout+r.stderr)
    log.append('$ '+shlex.join(cmd)+'\nexit: '+str(r.returncode)+'\n'+r.stdout+r.stderr)
    (root/'commands-and-results.txt').write_text('\n\n'.join(log))
    assert r.returncode == 0, (name,r.stderr)
print('PASS: 20 Markdown listings parse; examples lower; casts, index32, FMA, constraints, unranked memref, CFG lifting, and log1p accuracy verified')
