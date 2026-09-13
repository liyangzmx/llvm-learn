func.func @max_nested_1(%arg0: memref<4096x4096xf32>,
                        %arg1: memref<4096x4096xf32>,
                        %arg2: memref<4096x4096xf32>) {
  %alloc = memref.alloc() : memref<4096x4096xf32>
  %cst = arith.constant 0.000000e+00 : f32
  affine.parallel (%arg3) = (0) to (4096) {
    affine.parallel (%arg4) = (0) to (4096) {
      affine.store %cst, %alloc[%arg3, %arg4] : memref<4096x4096xf32>
      affine.for %arg5 = 0 to 4096 {
        %0 = affine.load %arg0[%arg3, %arg5] : memref<4096x4096xf32>
        %1 = affine.load %arg1[%arg5, %arg4] : memref<4096x4096xf32>
        %2 = affine.load %alloc[%arg3, %arg4] : memref<4096x4096xf32>
        %3 = arith.mulf %0, %1 : f32
        %4 = arith.addf %2, %3 : f32
        affine.store %4, %alloc[%arg3, %arg4] : memref<4096x4096xf32>
      }
    }
  }
  memref.dealloc %alloc : memref<4096x4096xf32>
  return
}
