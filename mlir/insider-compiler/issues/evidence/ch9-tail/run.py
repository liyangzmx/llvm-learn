#!/usr/bin/env python3
from pathlib import Path
import subprocess
import json
D=Path(__file__).resolve().parent
OPT='/opt/llvm-project/build/bin/mlir-opt'
payload='''module {
  func.func @matmul(%arg0: tensor<1024x512xf32>, %arg1: tensor<512x2000xf32>, %arg2: tensor<1024x2000xf32>) -> tensor<1024x2000xf32> {
    %0 = linalg.matmul ins(%arg0, %arg1 : tensor<1024x512xf32>, tensor<512x2000xf32>) outs(%arg2 : tensor<1024x2000xf32>) -> tensor<1024x2000xf32>
    return %0 : tensor<1024x2000xf32>
  }
}
'''
prefix='''module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg0: !transform.any_op {transform.readonly}) {
    %0 = transform.structured.match ops{["linalg.matmul"]} in %arg0 : (!transform.any_op) -> !transform.any_op
    %tiled_linalg_op, %loops:3 = transform.structured.tile_using_for %0 [8, [16], 1] : (!transform.any_op) -> (!transform.any_op, !transform.op<"scf.for">, !transform.op<"scf.for">, !transform.op<"scf.for">)
'''
vector='''    %1 = transform.structured.match ops{["linalg.matmul"]} in %tiled_linalg_op : (!transform.any_op) -> !transform.any_op
    transform.structured.vectorize %1 vector_sizes [8, [16], 1] : !transform.any_op
'''
suffix='''    transform.yield
  }
}
'''
(D/'payload.mlir').write_text(payload)
(D/'transform.mlir').write_text(prefix+vector+suffix)
cases={
 'tiled':(payload+prefix+suffix,['--transform-interpreter']),
 'vectorized':(payload+prefix+vector+suffix,['--transform-interpreter']),
 'vector-broadcast':('''func.func @vect() -> vector<4x16xf32> {
  %10 = arith.constant 0.0 : f32
  %11 = vector.broadcast %10 : f32 to vector<16xf32>
  %12 = vector.broadcast %11 : vector<16xf32> to vector<4x16xf32>
  return %12 : vector<4x16xf32>
}
''',['--convert-vector-to-llvm']),
 'clone':('''func.func @conversion_static(%arg0: memref<2xf32>) -> memref<2xf32> {
  %0 = bufferization.clone %arg0 : memref<2xf32> to memref<2xf32>
  memref.dealloc %arg0 : memref<2xf32>
  return %0 : memref<2xf32>
}
''',['--convert-bufferization-to-memref']),
}
records=[]
for name,(source,flags) in cases.items():
 inp=D/(name+'.mlir');inp.write_text(source)
 cmd=[OPT,str(inp),*flags]
 r=subprocess.run(cmd,text=True,capture_output=True)
 (D/(name+'.out.mlir')).write_text(r.stdout)
 (D/(name+'.stderr.txt')).write_text(r.stderr)
 records.append({'name':name,'command':cmd,'returncode':r.returncode})
 print(name,r.returncode)
 if r.returncode: print(r.stderr)
(D/'results.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
raise SystemExit(any(r['returncode'] for r in records))
