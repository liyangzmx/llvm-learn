// 将原书反复内联的相同布局写成别名；没有省略操作或布局参数。
#AL = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8],
    warpsPerCTA = [4, 1], order = [1, 0]}>
#BL = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32],
    warpsPerCTA = [4, 1], order = [1, 0]}>
#S = #triton_gpu.shared<{vec = 2, perPhase = 2, maxPhase = 4,
    order = [1, 0], hasLeadingOffset = false}>
#C = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0,
    warpsPerCTA = [4, 1], instrShape = []}>
#A_OP = #triton_gpu.dot_op<{opIdx = 0, parent = #C, kWidth = 2}>
#B_OP = #triton_gpu.dot_op<{opIdx = 1, parent = #C, kWidth = 2}>
module attributes {"triton_gpu.num-warps" = 4 : i32} {
  tt.func @matmul_loop_mixed(%arg0: index, %arg1: index, %arg2: index,
      %arg3: !tt.ptr<f8E5M2>, %arg4: !tt.ptr<f16>) -> tensor<128x128xf32, #C> {
    %cst = arith.constant dense<4> : tensor<16x128xi32, #BL>
    %cst_0 = arith.constant dense<4> : tensor<128x16xi32, #AL>
    %cst_1 = arith.constant dense<0.000000e+00> : tensor<128x128xf32, #C>
    // 原书此行误写成 16×16，按使用者修复为 16×128。
    %cst_2 = arith.constant dense<0.000000e+00> : tensor<16x128xf16, #BL>
    %cst_3 = arith.constant dense<true> : tensor<16x128xi1, #BL>
    %cst_4 = arith.constant dense<0.000000e+00> : tensor<128x16xf8E5M2, #AL>
    %cst_5 = arith.constant dense<true> : tensor<128x16xi1, #AL>
    %0 = tt.splat %arg3 : !tt.ptr<f8E5M2> -> tensor<128x16x!tt.ptr<f8E5M2>, #AL>
    %1 = tt.splat %arg4 : !tt.ptr<f16> -> tensor<16x128x!tt.ptr<f16>, #BL>
    %2 = tt.load %0, %cst_5, %cst_4 : tensor<128x16x!tt.ptr<f8E5M2>, #AL>
    %3 = triton_gpu.local_alloc %2 : (tensor<128x16xf8E5M2, #AL>)
        -> !tt.memdesc<128x16xf8E5M2, #S, #triton_gpu.shared_memory>
    %4 = tt.load %1, %cst_3, %cst_2 : tensor<16x128x!tt.ptr<f16>, #BL>
    %5 = triton_gpu.local_alloc %4 : (tensor<16x128xf16, #BL>)
        -> !tt.memdesc<16x128xf16, #S, #triton_gpu.shared_memory>

    %c0_i32 = arith.constant 0 : i32
    %c0_i32_6 = arith.constant 0 : i32
    %6 = triton_gpu.memdesc_subview %3[%c0_i32, %c0_i32_6]
        : !tt.memdesc<128x16xf8E5M2, #S, #triton_gpu.shared_memory>
        -> !tt.memdesc<128x16xf8E5M2, #S, #triton_gpu.shared_memory>
    %7 = triton_gpu.local_load %6
        : !tt.memdesc<128x16xf8E5M2, #S, #triton_gpu.shared_memory>
        -> tensor<128x16xf8E5M2, #A_OP>
    %8 = tt.fp_to_fp %7 : tensor<128x16xf8E5M2, #A_OP> -> tensor<128x16xf16, #A_OP>
    %c0_i32_7 = arith.constant 0 : i32
    %c0_i32_8 = arith.constant 0 : i32
    %9 = triton_gpu.memdesc_subview %5[%c0_i32_7, %c0_i32_8]
        : !tt.memdesc<16x128xf16, #S, #triton_gpu.shared_memory>
        -> !tt.memdesc<16x128xf16, #S, #triton_gpu.shared_memory>
    %10 = triton_gpu.local_load %9
        : !tt.memdesc<16x128xf16, #S, #triton_gpu.shared_memory> -> tensor<16x128xf16, #B_OP>
    %11:5 = scf.for %arg5 = %arg0 to %arg1 step %arg2
        iter_args(%arg6 = %0, %arg7 = %1, %arg8 = %3, %arg9 = %5, %arg10 = %cst_1)
        -> (tensor<128x16x!tt.ptr<f8E5M2>, #AL>, tensor<16x128x!tt.ptr<f16>, #BL>,
            !tt.memdesc<128x16xf8E5M2, #S, #triton_gpu.shared_memory>,
            !tt.memdesc<16x128xf16, #S, #triton_gpu.shared_memory>, tensor<128x128xf32, #C>) {
      %12 = triton_gpu.local_load %arg8
          : !tt.memdesc<128x16xf8E5M2, #S, #triton_gpu.shared_memory>
          -> tensor<128x16xf8E5M2, #A_OP>
      %13 = tt.fp_to_fp %12 : tensor<128x16xf8E5M2, #A_OP> -> tensor<128x16xf16, #A_OP>
      %14 = triton_gpu.local_load %arg9
          : !tt.memdesc<16x128xf16, #S, #triton_gpu.shared_memory> -> tensor<16x128xf16, #B_OP>

      %15 = tt.dot %13, %14, %arg10
          : tensor<128x16xf16, #A_OP> * tensor<16x128xf16, #B_OP> -> tensor<128x128xf32, #C>
      %16 = tt.addptr %arg6, %cst_0
          : tensor<128x16x!tt.ptr<f8E5M2>, #AL>, tensor<128x16xi32, #AL>
      %17 = tt.addptr %arg7, %cst
          : tensor<16x128x!tt.ptr<f16>, #BL>, tensor<16x128xi32, #BL>
      %18 = tt.load %16, %cst_5, %cst_4 : tensor<128x16x!tt.ptr<f8E5M2>, #AL>
      %19 = triton_gpu.local_alloc %18 : (tensor<128x16xf8E5M2, #AL>)
          -> !tt.memdesc<128x16xf8E5M2, #S, #triton_gpu.shared_memory>
      // 校订：保留下一轮 B 的加载，并用其结果初始化共享缓冲区。
      %next_b = tt.load %17, %cst_3, %cst_2 : tensor<16x128x!tt.ptr<f16>, #BL>
      %20 = triton_gpu.local_alloc %next_b : (tensor<16x128xf16, #BL>)
          -> !tt.memdesc<16x128xf16, #S, #triton_gpu.shared_memory>
      scf.yield %16, %17, %19, %20, %15
          : tensor<128x16x!tt.ptr<f8E5M2>, #AL>, tensor<16x128x!tt.ptr<f16>, #BL>,
            !tt.memdesc<128x16xf8E5M2, #S, #triton_gpu.shared_memory>,
            !tt.memdesc<16x128xf16, #S, #triton_gpu.shared_memory>, tensor<128x128xf32, #C>
    }
    tt.return %11#4 : tensor<128x128xf32, #C>
  }
}
