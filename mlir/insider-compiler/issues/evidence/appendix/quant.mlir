func.func @casts(%input: tensor<4xf32>) -> tensor<4xf32> {
  %q = "quant.qcast"(%input) : (tensor<4xf32>) -> tensor<4x!quant.uniform<i8:f32, 0.5>>
  %storage = "quant.scast"(%q) : (tensor<4x!quant.uniform<i8:f32, 0.5>>) -> tensor<4xi8>
  %restored = "quant.scast"(%storage) : (tensor<4xi8>) -> tensor<4x!quant.uniform<i8:f32, 0.5>>
  %expressed = "quant.dcast"(%restored) : (tensor<4x!quant.uniform<i8:f32, 0.5>>) -> tensor<4xf32>
  return %expressed : tensor<4xf32>
}

func.func @per_axis(%input: tensor<2x3xf32>) -> tensor<2x3x!quant.uniform<i8:f32:1, {0.5, 0.25, 0.125}>> {
  %q = "quant.qcast"(%input) : (tensor<2x3xf32>) -> tensor<2x3x!quant.uniform<i8:f32:1, {0.5, 0.25, 0.125}>>
  return %q : tensor<2x3x!quant.uniform<i8:f32:1, {0.5, 0.25, 0.125}>>
}
