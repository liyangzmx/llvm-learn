// memref.global 定义两个只读全局缓冲区并提供初始数据。
memref.global "private" constant @__constant_16x10xf32 : memref<16x10xf32> = dense<"0xC44B...">
memref.global "private" constant @__constant_1x10xf32 : memref<1x10xf32> = dense<"0xA270...">
func.func @forward(%arg0: memref<1x16xf32>, %arg1: memref<1x10xf32>) {
  %0 = memref.get_global @__constant_1x10xf32 : memref<1x10xf32>
  %1 = memref.get_global @__constant_16x10xf32 : memref<16x10xf32>

  // 与张量版一致，归约初值为零。
  %zero = arith.constant 0.0 : f32
  // 外层遍历输出列，下界 0、上界 10（不含），默认步长 1。
  affine.for %arg2 = 0 to 10 {
    // 在处理本列的归约之前，将其输出元素置零。
    affine.store %zero, %arg1[0, %arg2] : memref<1x10xf32>
    // 内层遍历归约维，下界 0、上界 16（不含），默认步长 1。
    affine.for %arg3 = 0 to 16 {
      // 按仿射下标加载输入、权重和累加值，进行乘加，再存回输出。
      %2 = affine.load %arg0[0, %arg3] : memref<1x16xf32>
      %3 = affine.load %1[%arg3, %arg2] : memref<16x10xf32>
      %4 = affine.load %arg1[0, %arg2] : memref<1x10xf32>
      %5 = arith.mulf %2, %3 : f32
      %6 = arith.addf %4, %5 : f32
      affine.store %6, %arg1[0, %arg2] : memref<1x10xf32>
    }
    // 本列的矩阵乘归约完成后，只加一次偏置并写回。
    %product = affine.load %arg1[0, %arg2] : memref<1x10xf32>
    %bias = affine.load %0[0, %arg2] : memref<1x10xf32>
    %sum = arith.addf %product, %bias : f32
    affine.store %sum, %arg1[0, %arg2] : memref<1x10xf32>
  }
  return
}
