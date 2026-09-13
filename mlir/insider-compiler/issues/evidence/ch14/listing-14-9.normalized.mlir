module {
  func.func @should_fuse_with_slice_union() {
    %alloc = memref.alloc() : memref<100xf32>
    %c0 = arith.constant 0 : index
    %cst = arith.constant 0.000000e+00 : f32
    affine.for %arg0 = 0 to 100 {
      affine.store %cst, %alloc[%arg0] : memref<100xf32>
    }
    affine.for %arg0 = 10 to 20 {
      affine.for %arg1 = 10 to 20 {
        affine.store %cst, %alloc[%arg1] : memref<100xf32>
      }
      %0 = affine.load %alloc[%arg0] : memref<100xf32>
      affine.for %arg1 = 15 to 25 {
        %1 = affine.load %alloc[%arg1] : memref<100xf32>
      }
    }
    return
  }
}

