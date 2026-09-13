// 书页151代码清单8-1的目视转写；保留书中的接口和属性名称，仅用于版本差异验证。
func.func @matmul(%arg0: tensor<1x5x3xf32>, %arg1: tensor<1x3x6xf32>) -> tensor<1x5x6xf32> {
  %a_zp = "tosa.const"() <{value = dense<0.0> : tensor<1xf32>}> : () -> tensor<1xf32>
  %b_zp = "tosa.const"() <{value = dense<0.0> : tensor<1xf32>}> : () -> tensor<1xf32>
  %0 = tosa.matmul %arg0, %arg1, %a_zp, %b_zp : (tensor<1x5x3xf32>, tensor<1x3x6xf32>, tensor<1xf32>, tensor<1xf32>) -> tensor<1x5x6xf32>
  return %0 : tensor<1x5x6xf32>
}
