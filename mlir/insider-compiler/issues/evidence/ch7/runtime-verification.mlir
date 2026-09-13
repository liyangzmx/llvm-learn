func.func @expand_shape(%m: memref<?xf32>) -> memref<?x5xf32> {
  %0 = memref.expand_shape %m [[0, 1]] : memref<?xf32> into memref<?x5xf32>
  return %0 : memref<?x5xf32>
}
