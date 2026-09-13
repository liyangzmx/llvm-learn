#map0 = affine_map<(d0, d1, d2) -> (d0, d2)>
#map1 = affine_map<(d0, d1, d2) -> (d2, d1)>
#map2 = affine_map<(d0, d1, d2) -> (d0, d1)>
#map3 = affine_map<(d0, d1) -> (d0, d1)>
func.func @forward(%arg0: tensor<1x16xf32>) -> tensor<1x10xf32> {

  %cst = arith.constant dense<"0xA270..."> : tensor<1x10xf32>
  %cst_0 = arith.constant dense<"0xC44B..."> : tensor<16x10xf32>
  %zero = arith.constant dense<0.0> : tensor<1x10xf32>
  %0 = linalg.generic {
      indexing_maps = [#map0, #map1, #map2],
      iterator_types = ["parallel", "parallel", "reduction"]
    } ins(%arg0, %cst_0 : tensor<1x16xf32>, tensor<16x10xf32>)
      outs(%zero : tensor<1x10xf32>) {
  ^bb0(%arg1: f32, %arg2: f32, %arg3: f32):
    %1 = arith.mulf %arg1, %arg2 : f32
    %2 = arith.addf %arg3, %1 : f32
    linalg.yield %2 : f32
  } -> tensor<1x10xf32>
  %result = linalg.generic {
      indexing_maps = [#map3, #map3],
      iterator_types = ["parallel", "parallel"]
    } ins(%cst : tensor<1x10xf32>)
      outs(%0 : tensor<1x10xf32>) {
  ^bb0(%bias: f32, %product: f32):
    %sum = arith.addf %product, %bias : f32
    linalg.yield %sum : f32
  } -> tensor<1x10xf32>
  return %result : tensor<1x10xf32>
}
