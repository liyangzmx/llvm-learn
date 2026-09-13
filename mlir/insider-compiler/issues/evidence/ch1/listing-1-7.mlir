// memref.global 定义两个只读全局缓冲区并提供初始数据。
memref.global "private" constant @__constant_16x10xf32 : memref<16x10xf32> = dense<"0xC44B...">
memref.global "private" constant @__constant_1x10xf32 : memref<1x10xf32> = dense<"0xA270...">
func.func @forward(%arg0: memref<1x16xf32>, %arg1: memref<1x10xf32>) {
  %0 = memref.get_global @__constant_1x10xf32 : memref<1x10xf32>
  %1 = memref.get_global @__constant_16x10xf32 : memref<16x10xf32>
  // 把偏置复制到输出缓冲区 arg1，作为循环的初始累加值。
  memref.copy %0, %arg1 : memref<1x10xf32> to memref<1x10xf32>
  // 外层遍历输出列，下界 0、上界 10（不含），默认步长 1。
  affine.for %arg2 = 0 to 10 {
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
  }
  return
}
