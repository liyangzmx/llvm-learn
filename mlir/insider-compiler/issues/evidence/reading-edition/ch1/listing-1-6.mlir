memref.global "private" constant @__constant_16x10xf32 : memref<16x10xf32> = dense<"0xC44B...">
memref.global "private" constant @__constant_1x10xf32 : memref<1x10xf32> = dense<"0xA270...">
func.func @forward(%arg0: memref<1x16xf32>, %arg1: memref<1x10xf32>) {
  %0 = memref.get_global @__constant_1x10xf32 : memref<1x10xf32>
  %1 = memref.get_global @__constant_16x10xf32 : memref<16x10xf32>
  %zero = arith.constant 0.0 : f32
  affine.for %arg2 = 0 to 10 {
    affine.store %zero, %arg1[0, %arg2] : memref<1x10xf32>
    affine.for %arg3 = 0 to 16 {
      %2 = affine.load %arg0[0, %arg3] : memref<1x16xf32>
      %3 = affine.load %1[%arg3, %arg2] : memref<16x10xf32>
      %4 = affine.load %arg1[0, %arg2] : memref<1x10xf32>
      %5 = arith.mulf %2, %3 : f32
      %6 = arith.addf %4, %5 : f32
      affine.store %6, %arg1[0, %arg2] : memref<1x10xf32>
    }
    %product = affine.load %arg1[0, %arg2] : memref<1x10xf32>
    %bias = affine.load %0[0, %arg2] : memref<1x10xf32>
    %sum = arith.addf %product, %bias : f32
    affine.store %sum, %arg1[0, %arg2] : memref<1x10xf32>
  }
  return
}
