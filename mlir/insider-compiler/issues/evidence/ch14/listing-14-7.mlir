module {
  func.func @should_fuse_raw_dep_for_locality() {
    %alloc = memref.alloc() : memref<1xf32>
    %cst = arith.constant 7.000000e+00 : f32
    affine.for %arg0 = 0 to 10 {
      affine.store %cst, %alloc[0] : memref<1xf32>
      %0 = affine.load %alloc[0] : memref<1xf32>
    }
    return
  }
}
