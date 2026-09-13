func.func @broadcast(%arg0: memref<5xf32>, %arg1: memref<5x7xf32>,
                     %arg2: memref<3x7xf32>) {
  linalg.generic {
    indexing_maps = [affine_map<(i, j, k) -> (k)>,
                     affine_map<(i, j, k) -> (k, j)>,
                     affine_map<(i, j, k) -> (i, j)>],
    iterator_types = ["parallel", "parallel", "reduction"]}
    ins(%arg0, %arg1 : memref<5xf32>, memref<5x7xf32>)
    outs(%arg2 : memref<3x7xf32>) {
  ^bb0(%a: f32, %b: f32, %c: f32):
    %p = arith.mulf %a, %b : f32
    %v = arith.addf %c, %p : f32
    linalg.yield %v : f32
  }
  return
}
