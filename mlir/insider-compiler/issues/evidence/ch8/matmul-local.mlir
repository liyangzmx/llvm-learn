func.func @matmul(%arg0: tensor<1x5x3xf32>, %arg1: tensor<1x3x6xf32>) -> tensor<1x5x6xf32> {
  // 保留原示例的两个零常量以展示后续死代码清理；本地matmul不以它们为操作数。
  %a_zp = "tosa.const"() <{value = dense<0.0> : tensor<1xf32>}> : () -> tensor<1xf32>
  %b_zp = "tosa.const"() <{value = dense<0.0> : tensor<1xf32>}> : () -> tensor<1xf32>
  %0 = tosa.matmul %arg0, %arg1 : (tensor<1x5x3xf32>, tensor<1x3x6xf32>) -> tensor<1x5x6xf32>
  return %0 : tensor<1x5x6xf32>
}
