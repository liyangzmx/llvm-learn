#!/usr/bin/env python3
from pathlib import Path
import os
import json
import re
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import Lab

lab = Lab('ch13')
source = Path(os.environ.get('LLVM_SRC', '/opt/llvm-project'))
records = lab.output / 'Book-records.json'
lab.run('tablegen-records', [lab.tool('llvm-tblgen'), '-I', source / 'llvm/include',
                            '--dump-json', lab.input / 'Book.td', '-o', records])
bits = json.loads(records.read_text())['ADDrr']['Inst']
operands = {'dst': 1, 'lhs': 2, 'rhs': 3}
word = sum((bit if isinstance(bit, int) else ((operands[bit['var']] >> bit['index']) & 1)) << i
           for i, bit in enumerate(bits))
lab.check('encoding-layout', word == 0x16C0, f'TableGen bit assignment for add r1,r2,r3 is 0x{word:04x}; this checks the record, not an installed CPU backend.')
for generator, token in [('register-info', 'Book'), ('instr-info', 'ADDrr'),
                          ('asm-writer', 'printInstruction'), ('emitter', 'getBinaryCodeForInstr'),
                          ('dag-isel', 'SelectCode')]:
    dest = lab.output / f'BookGen-{generator}.inc'
    lab.run('tablegen-' + generator, [lab.tool('llvm-tblgen'), '-I', source / 'llvm/include',
                                     '-gen-' + generator, lab.input / 'Book.td', '-o', dest])
    lab.check('generated-' + generator, token in dest.read_text(), f'Generated file contains {token}.')
lab.run('verify-input', [lab.tool('opt'), '-passes=verify', '-disable-output', lab.input / 'backend.ll'])
lab.run('select', [lab.tool('llc'), '-mtriple=bpfel', '-mcpu=v1', '-O2', '-verify-machineinstrs',
                  '-stop-after=finalize-isel', lab.input / 'backend.ll', '-o', lab.output / 'selected.mir'])
lab.check('selected-opcodes', 'ADD_rr' in (lab.output / 'selected.mir').read_text(), 'Target instruction selection produces ADD_rr.')
lab.run('emit-assembly', [lab.tool('llc'), '-mtriple=bpfel', '-mcpu=v1', '-O2', '-verify-machineinstrs',
                         lab.input / 'backend.ll', '-o', lab.output / 'backend.s'])
assembly = (lab.output / 'backend.s').read_text()
def function_body(name):
    match = re.search(r'^' + re.escape(name) + r':.*?^\.Lfunc_end\d+:', assembly, re.M | re.S)
    if not match:
        raise AssertionError('Missing assembly function: ' + name)
    return match.group(0)

add_body = function_body('add64')
lab.check('argument-and-return-registers', bool(re.search(r'r0 = r1\s+r0 \+= r2\s+exit', add_body)),
          'add64 consumes the two i64 arguments in r1/r2 and returns their sum in r0.')
stack_body = function_body('stack_roundtrip')
lab.check('frame-index-eliminated', '*(u64 *)(r10 - 8) = r1' in stack_body and 'r0 = *(u64 *)(r10 - 8)' in stack_body,
          'The volatile object is stored and reloaded at the same r10-8 address using 8-byte accesses.')
lab.check('external-call-symbol', 'call external' in function_body('call_external'),
          'The external call remains symbolic before object relocation and linking.')
for triple, encoding in [('bpfel', 'LittleEndian'), ('bpfeb', 'BigEndian')]:
    obj = lab.output / (triple + '.o')
    lab.run('emit-' + triple, [lab.tool('llc'), '-mtriple=' + triple, '-mcpu=v1', '-O2', '-verify-machineinstrs',
                              '-filetype=obj', lab.input / 'backend.ll', '-o', obj])
    lab.run('inspect-' + triple, [lab.tool('llvm-readobj'), '--file-headers', '--relocations', obj],
            contains=('EM_BPF', encoding, 'R_BPF_64_32', 'external'))
    lab.run('disassemble-' + triple, [lab.tool('llvm-objdump'), '-d', obj], contains=('<add64>:', 'exit'))
lab.run('reject-stack-arguments', [lab.tool('llc'), '-mtriple=bpfel', '-mcpu=v1', lab.input / 'six-arguments.ll', '-o', lab.output / 'unsupported.s'],
        expected=None, contains=('stack arguments are not supported',))
lab.finish()
