func.func @broadcast(%a: tensor<4xf32>, %b: tensor<2x4xf32>) -> tensor<2x4xf32> {
  %0 = tosa.add %a, %b : (tensor<4xf32>, tensor<2x4xf32>) -> tensor<2x4xf32>
  return %0 : tensor<2x4xf32>
}
