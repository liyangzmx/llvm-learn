#map = affine_map<(d0, d1)[s0, s1] -> (d0 * 2 - d1 * 4 + s1)>
#map1 = affine_map<(d0, d1)[s0, s1] -> (d1 * 3 - s0)>
module {
  func.func @access(%arg0: memref<?x?xf32>, %arg1: f32, %arg2: index, %arg3: index, %arg4: index) {
    affine.for %arg5 = 0 to 100 {
      affine.for %arg6 = 0 to 50 {
        %0 = affine.apply #map(%arg5, %arg6)[%arg2, %arg3]
        %1 = affine.apply #map1(%arg5, %arg6)[%arg2, %arg3]
        affine.store %arg1, %arg0[%0, %1] : memref<?x?xf32>
      }
    }
    return
  }
}

