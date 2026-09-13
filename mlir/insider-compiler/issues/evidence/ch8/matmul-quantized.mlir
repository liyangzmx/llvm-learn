func.func @matmul_quantized(%a: tensor<1x5x3xi8>, %b: tensor<1x3x6xi8>) -> tensor<1x5x6xi32> {
  %0 = tosa.matmul %a, %b {quantization_info = #tosa.matmul_quant<a_zp = 0, b_zp = 0>} : (tensor<1x5x3xi8>, tensor<1x3x6xi8>) -> tensor<1x5x6xi32>
  return %0 : tensor<1x5x6xi32>
}
