func.func @mixed_alloc(%arg0: index, %arg1: index) -> memref<?x42x?xf32> {
  %0 = memref.alloc(%arg0, %arg1) : memref<?x42x?xf32>
  return %0 : memref<?x42x?xf32>
}
