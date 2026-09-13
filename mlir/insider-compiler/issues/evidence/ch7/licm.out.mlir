module {
  func.func @nested_loops_both_having_invariant_code() {
    %alloc = memref.alloc() : memref<10xf32>
    %cst = arith.constant 7.000000e+00 : f32
    %cst_0 = arith.constant 8.000000e+00 : f32
    %0 = arith.addf %cst, %cst_0 : f32
    %1 = arith.addf %0, %cst_0 : f32
    affine.for %arg0 = 0 to 10 {
      affine.for %arg1 = 0 to 10 {
        affine.store %0, %alloc[%arg0] : memref<10xf32>
      }
    }
    return
  }
}

