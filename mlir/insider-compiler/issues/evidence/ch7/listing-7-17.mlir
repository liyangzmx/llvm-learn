module {
  func.func @foo(%a: memref<10x10xf32>, %b: memref<10xf32>, %c: memref<10xf32>) {
    affine.for %i = 0 to 10 {
      affine.for %j = 0 to 10 {
        %0 = affine.load %b[%i] : memref<10xf32>
        %1 = affine.load %a[%i, %j] : memref<10x10xf32>
        %2 = arith.addf %0, %1 : f32
        affine.store %2, %b[%i] : memref<10xf32>
      }
    }
    affine.for %i = 0 to 10 {
      %0 = affine.load %b[%i] : memref<10xf32>
      affine.store %0, %c[%i] : memref<10xf32>
    }
    return
  }
}
