#!/usr/bin/env python3
"""Reproduce Chapter 7 source-based pass checks; writes inputs, outputs and log."""
from pathlib import Path
import subprocess
D = Path(__file__).resolve().parent
OPT = '/opt/llvm-project/build/bin/mlir-opt'
cases = {
'sort': ('''func.func @sort(%a: i32, %b: i32) -> i32 {
  %c = arith.constant 0 : i32
  %m = "foo.mul"(%a, %b) : (i32, i32) -> i32
  %n = "foo.mul"(%m, %c) : (i32, i32) -> i32
  %a0 = "foo.add"(%m, %c) : (i32, i32) -> i32
  %r = "test.op_commutative"(%c, %m, %n, %a0) : (i32, i32, i32, i32) -> i32
  return %r : i32
}
''', ['--test-commutativity-utils', '--allow-unregistered-dialect']),
'canonicalize': ('''func.func @and_ext(%x: i8, %y: i8) -> i32 {
  %a = arith.extui %x : i8 to i32
  %b = arith.extui %y : i8 to i32
  %r = arith.andi %a, %b : i32
  return %r : i32
}
''', ['--canonicalize']),
'sink': ('''func.func @test_scf_if_sink(%arg0: i1, %arg1: i32) -> i32 {
  %0 = arith.addi %arg1, %arg1 : i32
  %1 = arith.muli %arg1, %arg1 : i32
  %result = scf.if %arg0 -> i32 {
    scf.yield %0 : i32
  } else {
    scf.yield %1 : i32
  }
  return %result : i32
}
''', ['--control-flow-sink']),
'cse': ('''func.func @check_cummutative_cse(%a: i32, %b: i32) -> i32 {
  %1 = arith.addi %a, %b : i32
  %2 = arith.addi %b, %a : i32
  %3 = arith.muli %1, %2 : i32
  return %3 : i32
}
''', ['--cse']),
'cse-unknown': ('''func.func @unknown(%a: i32) -> (i32, i32) {
  %0 = "unknown.op"(%a) : (i32) -> i32
  %1 = "unknown.op"(%a) : (i32) -> i32
  return %0, %1 : i32, i32
}
''', ['--cse', '--allow-unregistered-dialect']),
'licm': ('''func.func @nested_loops_both_having_invariant_code() {
  %m = memref.alloc() : memref<10xf32>
  %cf7 = arith.constant 7.0 : f32
  %cf8 = arith.constant 8.0 : f32
  affine.for %arg0 = 0 to 10 {
    %v0 = arith.addf %cf7, %cf8 : f32
    affine.for %arg1 = 0 to 10 {
      %v1 = arith.addf %v0, %cf8 : f32
      affine.store %v0, %m[%arg0] : memref<10xf32>
    }
  }
  return
}
''', ['--loop-invariant-code-motion']),
'mem2reg': ('''func.func @cycle(%arg0: i64, %arg1: i1, %arg2: i64) {
  %alloca = memref.alloca() : memref<i64>
  memref.store %arg2, %alloca[] : memref<i64>
  cf.cond_br %arg1, ^bb1, ^bb2
^bb1:
  %use = memref.load %alloca[] : memref<i64>
  call @use(%use) : (i64) -> ()
  memref.store %arg0, %alloca[] : memref<i64>
  cf.br ^bb2
^bb2:
  cf.br ^bb1
}
func.func @use(%arg: i64) { return }
''', ['--mem2reg']),
'sroa': ('''llvm.func @basic_array() -> i32 {
  %0 = llvm.mlir.constant(1 : i32) : i32
  %1 = llvm.alloca %0 x !llvm.array<10 x i32> {alignment = 8 : i64} : (i32) -> !llvm.ptr
  %2 = llvm.getelementptr inbounds %1[0, 2] : (!llvm.ptr) -> !llvm.ptr, !llvm.array<10 x i32>
  %3 = llvm.load %2 : !llvm.ptr -> i32
  llvm.return %3 : i32
}
''', ['--sroa']),
'sort-topological': ('''test.graph_region {
  %0 = "test.foo"() {selected} : () -> i32
  "test.bar"(%1, %0) {selected} : (i32, i32) -> ()
  %1 = "test.baz"() {selected} : () -> i32
}
''', ['--topological-sort']),
'inline': ('''func.func @foo(%a: memref<10x10xf32>, %b: memref<10xf32>, %c: memref<10xf32>) {
  func.call @foo_0(%a, %b) : (memref<10x10xf32>, memref<10xf32>) -> ()
  func.call @foo_1(%b, %c) : (memref<10xf32>, memref<10xf32>) -> ()
  return
}
func.func private @foo_0(%a: memref<10x10xf32>, %b: memref<10xf32>) {
  affine.for %i0 = 0 to 10 {
    affine.for %i1 = 0 to 10 {
      %v0 = affine.load %b[%i0] : memref<10xf32>
      %v1 = affine.load %a[%i0, %i1] : memref<10x10xf32>
      %v3 = arith.addf %v0, %v1 : f32
      affine.store %v3, %b[%i0] : memref<10xf32>
    }
  }
  return
}
func.func private @foo_1(%b: memref<10xf32>, %c: memref<10xf32>) {
  affine.for %i2 = 0 to 10 {
    %v4 = affine.load %b[%i2] : memref<10xf32>
    affine.store %v4, %c[%i2] : memref<10xf32>
  }
  return
}
''', ['--inline']),
'inline-public': ('''func.func @callee(%x: i32) -> i32 { return %x : i32 }
func.func @caller(%x: i32) -> i32 {
  %r = call @callee(%x) : (i32) -> i32
  return %r : i32
}
''', ['--inline']),
'sccp': ('''func.func @conditional() -> i32 {
  %c = arith.constant true
  %a = arith.constant 42 : i32
  %b = arith.constant 99 : i32
  cf.cond_br %c, ^yes, ^no
^yes:
  cf.br ^join(%a : i32)
^no:
  cf.br ^join(%b : i32)
^join(%r: i32):
  return %r : i32
}
''', ['--sccp']),
}
logs = [subprocess.check_output([OPT, '--version'], text=True)]
failed = False
for name, (source, flags) in cases.items():
    inp = D / (name + '.mlir')
    inp.write_text(source)
    command = [OPT, str(inp), *flags]
    r = subprocess.run(command, text=True, capture_output=True)
    (D / (name + '.out.mlir')).write_text(r.stdout)
    logs.append('$ ' + ' '.join(command) + '\nexit=' + str(r.returncode) + '\n' + r.stderr)
    print(name, 'exit', r.returncode)
    if r.returncode:
        failed = True
        print(r.stderr)
(D / 'checks.log').write_text('\n'.join(logs))
raise SystemExit(1 if failed else 0)
