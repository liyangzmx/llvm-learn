// 定义符号名为 forward 的函数，参数为 1×16 的 f32 张量，返回 1×10 张量。
func.func @forward(%arg0: tensor<1x16xf32>) -> tensor<1x10xf32> {
  // 用 tosa.const 创建权重常量。value 是 DenseElementsAttr，携带 1×16×10 个 f32 元素。
  %0 = "tosa.const"() {value = dense<"0xC44B..."> : tensor<1x16x10xf32>} : () -> tensor<1x16x10xf32>
  // 创建偏置常量；此处为广播到 1×10 形状后的表示。
  %1 = "tosa.const"() {value = dense<"0xA270..."> : tensor<1x10xf32>} : () -> tensor<1x10xf32>
  // 改变 arg0 的形状：1×16 → 1×1×16；元素数和元素类型不变。
  %2 = "tosa.reshape"(%arg0) {new_shape = array<i64: 1, 1, 16>} : (tensor<1x16xf32>) -> tensor<1x1x16xf32>
  // 批矩阵乘：1×1×16 乘以 1×16×10，结果为 1×1×10。
  %3 = "tosa.matmul"(%2, %0) : (tensor<1x1x16xf32>, tensor<1x16x10xf32>) -> tensor<1x1x10xf32>
  // 改变乘积的形状：1×1×10 → 1×10。
  %4 = "tosa.reshape"(%3) {new_shape = array<i64: 1, 10>} : (tensor<1x1x10xf32>) -> tensor<1x10xf32>
  // 逐元素加偏置，两个输入和输出均为 1×10 的 f32 张量。
  %5 = "tosa.add"(%4, %1) : (tensor<1x10xf32>, tensor<1x10xf32>) -> tensor<1x10xf32>
  // 返回计算结果。
  return %5 : tensor<1x10xf32>
}
