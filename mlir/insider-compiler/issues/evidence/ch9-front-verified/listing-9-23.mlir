#map = affine_map<(d0, d1) -> (d0 + d1)>
module {
  func.func @conv1d_8_tensor(%arg0: tensor<11xf32>, %arg1: tensor<4xf32>, %arg2: tensor<8xf32>) -> tensor<8xf32> {
    %c4 = arith.constant 4 : index
    %c1 = arith.constant 1 : index
    %c8 = arith.constant 8 : index
    %c0 = arith.constant 0 : index
    %0 = bufferization.to_memref %arg1 : memref<4xf32, strided<[?], offset: ?>>
    %1 = bufferization.to_memref %arg0 : memref<11xf32, strided<[?], offset: ?>>
    %2 = bufferization.to_memref %arg2 : memref<8xf32, strided<[?], offset: ?>>
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<8xf32>
    memref.copy %2, %alloc : memref<8xf32, strided<[?], offset: ?>> to memref<8xf32>
    scf.for %arg3 = %c0 to %c8 step %c1 {
      scf.for %arg4 = %c0 to %c4 step %c1 {
        %4 = affine.apply #map(%arg3, %arg4)
        %5 = memref.load %1[%4] : memref<11xf32, strided<[?], offset: ?>>
        %6 = memref.load %0[%arg4] : memref<4xf32, strided<[?], offset: ?>>
        %7 = memref.load %alloc[%arg3] : memref<8xf32>
        %8 = arith.mulf %5, %6 : f32
        %9 = arith.addf %7, %8 : f32
        memref.store %9, %alloc[%arg3] : memref<8xf32>
      }
    }
    %3 = bufferization.to_tensor %alloc : memref<8xf32>
    return %3 : tensor<8xf32>
  }
}
