#blocked = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32],
    warpsPerCTA = [4, 1], order = [1, 0]}>

#blocked1 = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8],
    warpsPerCTA = [4, 1], order = [1, 0]}>
#mma = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0,
    warpsPerCTA = [4, 1], instrShape = []}>
#shared = #triton_gpu.shared<{vec = 2, perPhase = 2, maxPhase = 4,
    order = [1, 0], hasLeadingOffset = false}>
#A_OP = #triton_gpu.dot_op<{opIdx = 0, parent = #mma, kWidth = 2}>
#B_OP = #triton_gpu.dot_op<{opIdx = 1, parent = #mma, kWidth = 2}>
module attributes {"triton_gpu.num-warps" = 4 : i32} {
  tt.func @matmul_loop_mixed(%arg0: index, %arg1: index, %arg2: index,
      %arg3: !tt.ptr<f8E5M2>, %arg4: !tt.ptr<f16>) -> tensor<128x128xf32, #mma> {
    %c0_i32 = arith.constant 0 : i32
    %cst = arith.constant dense<4> : tensor<16x128xi32, #blocked>
    %cst_0 = arith.constant dense<4> : tensor<128x16xi32, #blocked1>
    %cst_1 = arith.constant dense<0.000000e+00> : tensor<128x128xf32, #mma>
    %0 = tt.splat %arg3 : !tt.ptr<f8E5M2> -> tensor<128x16x!tt.ptr<f8E5M2>, #blocked1>
    %1 = tt.splat %arg4 : !tt.ptr<f16> -> tensor<16x128x!tt.ptr<f16>, #blocked>
    %2 = tt.load %0 : tensor<128x16x!tt.ptr<f8E5M2>, #blocked1>
    %3 = triton_gpu.local_alloc %2 : (tensor<128x16xf8E5M2, #blocked1>)
        -> !tt.memdesc<128x16xf8E5M2, #shared, #triton_gpu.shared_memory>
    %4 = tt.load %1 : tensor<16x128x!tt.ptr<f16>, #blocked>
    %5 = triton_gpu.local_alloc %4 : (tensor<16x128xf16, #blocked>)
        -> !tt.memdesc<16x128xf16, #shared, #triton_gpu.shared_memory>
    %6 = triton_gpu.memdesc_subview %3[%c0_i32, %c0_i32]
        : !tt.memdesc<128x16xf8E5M2, #shared, #triton_gpu.shared_memory>
        -> !tt.memdesc<128x16xf8E5M2, #shared, #triton_gpu.shared_memory>
    %7 = triton_gpu.local_load %6
        : !tt.memdesc<128x16xf8E5M2, #shared, #triton_gpu.shared_memory>
        -> tensor<128x16xf8E5M2, #A_OP>
    %8 = tt.fp_to_fp %7 : tensor<128x16xf8E5M2, #A_OP> -> tensor<128x16xf16, #A_OP>
    %9 = triton_gpu.memdesc_subview %5[%c0_i32, %c0_i32]
        : !tt.memdesc<16x128xf16, #shared, #triton_gpu.shared_memory>
        -> !tt.memdesc<16x128xf16, #shared, #triton_gpu.shared_memory>
    %10 = triton_gpu.local_load %9
        : !tt.memdesc<16x128xf16, #shared, #triton_gpu.shared_memory>
        -> tensor<16x128xf16, #B_OP>
    %11:5 = scf.for %arg5 = %arg0 to %arg1 step %arg2
        iter_args(%arg6 = %0, %arg7 = %1, %arg8 = %cst_1, %arg9 = %8, %arg10 = %10)
        -> (tensor<128x16x!tt.ptr<f8E5M2>, #blocked1>,
            tensor<16x128x!tt.ptr<f16>, #blocked>, tensor<128x128xf32, #mma>,
            tensor<128x16xf16, #A_OP>, tensor<16x128xf16, #B_OP>) {
      %12 = tt.addptr %arg6, %cst_0
          : tensor<128x16x!tt.ptr<f8E5M2>, #blocked1>, tensor<128x16xi32, #blocked1>
      %13 = tt.addptr %arg7, %cst
          : tensor<16x128x!tt.ptr<f16>, #blocked>, tensor<16x128xi32, #blocked>
      %14 = tt.load %12 : tensor<128x16x!tt.ptr<f8E5M2>, #blocked1>
      %15 = triton_gpu.local_alloc %14 : (tensor<128x16xf8E5M2, #blocked1>)
          -> !tt.memdesc<128x16xf8E5M2, #shared, #triton_gpu.shared_memory>
      %next_b = tt.load %13 : tensor<16x128x!tt.ptr<f16>, #blocked>
      %16 = triton_gpu.local_alloc %next_b : (tensor<16x128xf16, #blocked>)
          -> !tt.memdesc<16x128xf16, #shared, #triton_gpu.shared_memory>
      %17 = triton_gpu.memdesc_subview %15[%c0_i32, %c0_i32]
          : !tt.memdesc<128x16xf8E5M2, #shared, #triton_gpu.shared_memory>
          -> !tt.memdesc<128x16xf8E5M2, #shared, #triton_gpu.shared_memory>

      %18 = triton_gpu.local_load %17
          : !tt.memdesc<128x16xf8E5M2, #shared, #triton_gpu.shared_memory>
          -> tensor<128x16xf8E5M2, #A_OP>
      %19 = tt.fp_to_fp %18 : tensor<128x16xf8E5M2, #A_OP> -> tensor<128x16xf16, #A_OP>
      %20 = triton_gpu.memdesc_subview %16[%c0_i32, %c0_i32]
          : !tt.memdesc<16x128xf16, #shared, #triton_gpu.shared_memory>
          -> !tt.memdesc<16x128xf16, #shared, #triton_gpu.shared_memory>
      %21 = triton_gpu.local_load %20
          : !tt.memdesc<16x128xf16, #shared, #triton_gpu.shared_memory>
          -> tensor<16x128xf16, #B_OP>
      %22 = tt.dot %arg9, %arg10, %arg8
          : tensor<128x16xf16, #A_OP> * tensor<16x128xf16, #B_OP>
          -> tensor<128x128xf32, #mma>
      scf.yield %12, %13, %22, %19, %21
          : tensor<128x16x!tt.ptr<f8E5M2>, #blocked1>,
            tensor<16x128x!tt.ptr<f16>, #blocked>, tensor<128x128xf32, #mma>,
            tensor<128x16xf16, #A_OP>, tensor<16x128xf16, #B_OP>
    }
    tt.return %11#2 : tensor<128x128xf32, #mma>
  }
}
