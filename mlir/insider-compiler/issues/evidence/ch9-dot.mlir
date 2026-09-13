func.func @dot(%arg0: memref<?xf32, strided<[1], offset: ?>>,
               %arg1: memref<?xf32, strided<[1], offset: ?>>,
               %arg2: memref<f32>) {
  linalg.dot ins(%arg0, %arg1 : memref<?xf32, strided<[1], offset: ?>>,
                              memref<?xf32, strided<[1], offset: ?>>)
             outs(%arg2 : memref<f32>)
  return
}
