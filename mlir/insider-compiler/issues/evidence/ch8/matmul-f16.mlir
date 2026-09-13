func.func @f16_result(%a: tensor<1x5x3xf16>, %b: tensor<1x3x6xf16>) -> tensor<1x5x6xf16> {
  %0 = tosa.matmul %a, %b : (tensor<1x5x3xf16>, tensor<1x3x6xf16>) -> tensor<1x5x6xf16>
  return %0 : tensor<1x5x6xf16>
}
func.func @f32_result(%a: tensor<1x5x3xf16>, %b: tensor<1x3x6xf16>) -> tensor<1x5x6xf32> {
  %0 = tosa.matmul %a, %b : (tensor<1x5x3xf16>, tensor<1x3x6xf16>) -> tensor<1x5x6xf32>
  return %0 : tensor<1x5x6xf32>
}
