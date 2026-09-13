#map = affine_map<(d0) -> (d0)>
#map1 = affine_map<(d0) -> (d0 + 2)>
module {
  func.func @negative_inner_distance(%arg0: memref<5x5xi32>) {
    %c1_i32 = arith.constant 1 : i32
    affine.for %arg1 = 1 to 5 step 2 {
      affine.for %arg2 = 0 to 4 step 2 {
        affine.for %arg3 = #map(%arg1) to #map1(%arg1) {
          affine.for %arg4 = #map(%arg2) to #map1(%arg2) {
            %0 = affine.load %arg0[%arg3 - 1, %arg4 + 1] : memref<5x5xi32>
            %1 = arith.addi %0, %c1_i32 : i32
            affine.store %1, %arg0[%arg3, %arg4] : memref<5x5xi32>
          }
        }
      }
    }
    return
  }
}

