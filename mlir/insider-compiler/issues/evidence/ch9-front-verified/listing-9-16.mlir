#map = affine_map<(d0, d1) -> (d0 * 4 + d1 * 2)>
module {
  func.func @generalize_pooling_nwc_max_f32(%arg0: tensor<1x16x1xf32>, %arg1: tensor<2xf32>, %arg2: tensor<1x4x1xf32>) -> tensor<1x4x1xf32> {
    %c2 = arith.constant 2 : index
    %c4 = arith.constant 4 : index
    %c1 = arith.constant 1 : index
    %c0 = arith.constant 0 : index
    %0 = bufferization.to_memref %arg0 : memref<1x16x1xf32, strided<[?, ?, ?], offset: ?>>
    %1 = bufferization.to_memref %arg2 : memref<1x4x1xf32, strided<[?, ?, ?], offset: ?>>
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<1x4x1xf32>
    memref.copy %1, %alloc : memref<1x4x1xf32, strided<[?, ?, ?], offset: ?>> to memref<1x4x1xf32>
    scf.for %arg3 = %c0 to %c1 step %c1 {
      scf.for %arg4 = %c0 to %c4 step %c1 {
        scf.for %arg5 = %c0 to %c1 step %c1 {
          scf.for %arg6 = %c0 to %c2 step %c1 {
            %3 = affine.apply #map(%arg4, %arg6)
            %4 = memref.load %0[%arg3, %3, %arg5] : memref<1x16x1xf32, strided<[?, ?, ?], offset: ?>>
            // 输入位置：第 0 批、第 0 通道，宽度为 0,2,4,6,8,10,12,14。
            %5 = memref.load %alloc[%arg3, %arg4, %arg5] : memref<1x4x1xf32>
            %6 = arith.maximumf %5, %4 : f32
            memref.store %6, %alloc[%arg3, %arg4, %arg5] : memref<1x4x1xf32>
          }
        }
      }
    }
    %2 = bufferization.to_tensor %alloc : memref<1x4x1xf32>
    return %2 : tensor<1x4x1xf32>
  }
}
