#!/usr/bin/env python3
from pathlib import Path
import re
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import Lab

lab = Lab('ch1')
version = lab.run('llc-version', [lab.tool('llc'), '--version'], contains=('LLVM version 18.1.8',))
registered = set(re.findall(r'^\s+(\S+)\s+-\s+', version.stdout, re.M))
lab.check('registered-targets', {'bpfel', 'aarch64', 'x86', 'riscv32', 'hexagon', 'ppc32', 'arm'} <= registered,
          'Required code-generation targets are present in the executable: ' + ', '.join(sorted(registered)))
lab.run('clang-version', [lab.tool('clang'), '--version'], contains=('clang version 18.1.8',))
raw = lab.output / 'sum.ll'
ssa = lab.output / 'sum-ssa.ll'
optimized = lab.output / 'sum-opt.ll'
bitcode = lab.output / 'sum.bc'
lab.run('clang-ir', [lab.tool('clang'), '--target=bpfel', '-O0', '-Xclang', '-disable-O0-optnone', '-fno-discard-value-names', '-S', '-emit-llvm', lab.input / 'sum.c', '-o', raw])
lab.check('frontend-stack-form', 'alloca i32' in raw.read_text(), 'At O0 the frontend emits addressable locals before mem2reg.')
lab.run('ssa', [lab.tool('opt'), '-passes=mem2reg', '-verify-each', '-S', raw, '-o', ssa])
lab.check('ssa-phi', 'phi i32' in ssa.read_text() and 'alloca ' not in ssa.read_text(), 'Promotable locals become SSA values, including loop PHIs.')
lab.run('assemble', [lab.tool('llvm-as'), ssa, '-o', bitcode])
lab.run('disassemble', [lab.tool('llvm-dis'), bitcode, '-o', lab.output / 'roundtrip.ll'])
lab.run('roundtrip-verify', [lab.tool('opt'), '-passes=verify', '-disable-output', lab.output / 'roundtrip.ll'])
lab.run('middle-end', [lab.tool('opt'), '-passes=default<O2>', '-verify-each', '-S', ssa, '-o', optimized])
lab.run('bpf-asm', [lab.tool('llc'), '-mtriple=bpfel', '-mcpu=v1', '-O2', '-verify-machineinstrs', optimized, '-o', lab.output / 'sum.s'])
lab.run('bpf-object', [lab.tool('llc'), '-mtriple=bpfel', '-mcpu=v1', '-O2', '-verify-machineinstrs', '-filetype=obj', optimized, '-o', lab.output / 'sum.o'])
lab.run('object-header', [lab.tool('llvm-readobj'), '--file-headers', lab.output / 'sum.o'], contains=('EM_BPF',))
lab.run('object-disassembly', [lab.tool('llvm-objdump'), '-d', lab.output / 'sum.o'], contains=('<sum>:', '<main>:', 'exit'))
# Interpret only this scalar, library-free program; this does not execute BPF
# machine instructions or make arbitrary bitcode portable across target ABIs.
lab.run('execute-before', [lab.tool('lli'), '--force-interpreter', '-mtriple=bpfel', raw])
lab.run('execute-after', [lab.tool('lli'), '--force-interpreter', '-mtriple=bpfel', optimized])
lab.run('host-ir', [lab.tool('clang'), '-O0', '-S', '-emit-llvm', lab.input / 'sum.c',
                    '-o', lab.output / 'host.ll'])
lab.run('host-jit', [lab.tool('lli'), lab.output / 'host.ll'])
lab.finish()
