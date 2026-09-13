func.func @transpose(%arg0: memref<5x3xf32>, %arg1: memref<5x7xf32>,
                     %arg2: memref<3x7xf32>) {
  linalg.matmul indexing_maps = [
    affine_map<(d0, d1, d2) -> (d2, d0)>,
    affine_map<(d0, d1, d2) -> (d2, d1)>,
    affine_map<(d0, d1, d2) -> (d0, d1)>]
    ins(%arg0, %arg1 : memref<5x3xf32>, memref<5x7xf32>)
    outs(%arg2 : memref<3x7xf32>)
  return
}
