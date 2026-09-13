func.func @max_nested_1(%arg0: memref<4096x4096xf32>, %arg1: memref<4096x4096xf32>, %arg2: memref<4096x4096xf32>) {
  %0 = memref.alloc() : memref<4096x4096xf32>
  %zero = arith.constant 0.0 : f32
  affine.for %arg3 = 0 to 4096 {
    affine.for %arg4 = 0 to 4096 {
      affine.store %zero, %0[%arg3, %arg4] : memref<4096x4096xf32>
      affine.for %arg5 = 0 to 4096 {
        %1 = affine.load %arg0[%arg3, %arg5] : memref<4096x4096xf32>
        %2 = affine.load %arg1[%arg5, %arg4] : memref<4096x4096xf32>
        %3 = affine.load %0[%arg3, %arg4] : memref<4096x4096xf32>
        %4 = arith.mulf %1, %2 : f32
        %5 = arith.addf %3, %4 : f32
        affine.store %5, %0[%arg3, %arg4] : memref<4096x4096xf32>
      }
    }
  }
  memref.dealloc %0 : memref<4096x4096xf32>
  return
}
