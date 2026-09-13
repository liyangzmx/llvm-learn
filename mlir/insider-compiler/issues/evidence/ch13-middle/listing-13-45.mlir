module attributes {"triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32} {
  tt.func @matmul_loop(%arg0: index, %arg1: index, %arg2: index,
      %arg3: !tt.ptr<f16> {tt.divisibility = 16 : i32},
      %arg4: !tt.ptr<f16> {tt.divisibility = 16 : i32}) {
    %0 = tt.splat %arg3 : !tt.ptr<f16> -> tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %1 = tt.make_range {end = 32 : i32, start = 0 : i32} : tensor<32xi32, #triton_gpu.slice<{dim = 0, parent = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>}>>
    %2 = tt.expand_dims %1 {axis = 0 : i32} : tensor<32xi32, #triton_gpu.slice<{dim = 0, parent = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>}>> -> tensor<1x32xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %3 = tt.broadcast %2 : tensor<1x32xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>> -> tensor<128x32xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %4 = tt.addptr %0, %3 : tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<128x32xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %5 = tt.splat %arg4 : !tt.ptr<f16> -> tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %6 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>}>>
    %7 = tt.expand_dims %6 {axis = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>}>> -> tensor<1x128xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %8 = tt.broadcast %7 : tensor<1x128xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>> -> tensor<32x128xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %9 = tt.addptr %5, %8 : tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<32x128xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %cst = arith.constant dense<true> : tensor<128x32xi1, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %cst_0 = arith.constant dense<0.000000e+00> : tensor<128x32xf16, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %cst_1 = arith.constant dense<true> : tensor<32x128xi1, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %cst_2 = arith.constant dense<0.000000e+00> : tensor<32x128xf16, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %cst_3 = arith.constant dense<0.000000e+00> : tensor<128x128xf32, #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>>
    %cst_4 = arith.constant dense<4> : tensor<128x32xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %cst_5 = arith.constant dense<4> : tensor<32x128xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %10 = triton_gpu.local_alloc : () -> !tt.memdesc<2x128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %11 = triton_gpu.local_alloc : () -> !tt.memdesc<2x32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %c-1_i32 = arith.constant -1 : i32
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %c2_i32 = arith.constant 2 : i32
    %c0_i32_6 = arith.constant 0 : i32
    %c0_i32_7 = arith.constant 0 : i32
    %12:5 = scf.for %arg5 = %arg0 to %arg1 step %arg2 iter_args(
        %arg6 = %4, %arg7 = %9, %arg8 = %cst_3, %arg9 = %c-1_i32,
        %arg10 = %c-1_i32) -> (tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<128x128xf32, #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>>, i32, i32) {
      %14 = arith.addi %arg9, %c1_i32 : i32
      %15 = arith.cmpi slt, %14, %c2_i32 : i32
      %16 = arith.select %15, %14, %c0_i32 : i32
      %17 = arith.addi %arg10, %c1_i32 : i32
      %18 = arith.cmpi slt, %17, %c2_i32 : i32
      %19 = arith.select %18, %17, %c0_i32 : i32
      %20 = triton_gpu.memdesc_subview %10[%16, %c0_i32_6, %c0_i32_6] : !tt.memdesc<2x128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %21 = triton_gpu.async_copy_global_to_local %arg6, %20 : tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>> -> <128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %22 = triton_gpu.async_commit_group %21
      %23 = triton_gpu.async_wait %22 {num = 0 : i32}
      %24 = triton_gpu.memdesc_subview %10[%19, %c0_i32_6, %c0_i32_6] : !tt.memdesc<2x128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %25 = triton_gpu.local_load %24 token %23 : !tt.memdesc<128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> tensor<128x32xf16, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
      %26 = triton_gpu.convert_layout %25 : tensor<128x32xf16, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>> -> tensor<128x32xf16, #triton_gpu.dot_op<{opIdx = 0, parent = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>, kWidth = 2}>>
      %27 = triton_gpu.memdesc_subview %11[%16, %c0_i32_7, %c0_i32_7] : !tt.memdesc<2x32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %28 = triton_gpu.async_copy_global_to_local %arg7, %27 mask %cst_1 other %cst_2 : tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>> -> <32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %29 = triton_gpu.async_commit_group %28
      %30 = triton_gpu.async_wait %29 {num = 0 : i32}
      %31 = triton_gpu.memdesc_subview %11[%19, %c0_i32_7, %c0_i32_7] : !tt.memdesc<2x32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %32 = triton_gpu.local_load %31 token %30 : !tt.memdesc<32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> tensor<32x128xf16, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
      %33 = triton_gpu.convert_layout %32 : tensor<32x128xf16, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>> -> tensor<32x128xf16, #triton_gpu.dot_op<{opIdx = 1, parent = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>, kWidth = 2}>>
      %34 = tt.dot %26, %33, %arg8 : tensor<128x32xf16, #triton_gpu.dot_op<{opIdx = 0, parent = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>, kWidth = 2}>> * tensor<32x128xf16, #triton_gpu.dot_op<{opIdx = 1, parent = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>, kWidth = 2}>> -> tensor<128x128xf32, #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>>
      %35 = tt.addptr %arg6, %cst_4 : tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<128x32xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
      %36 = tt.addptr %arg7, %cst_5 : tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<32x128xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
      scf.yield %35, %36, %34, %16, %19 : tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<128x128xf32, #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>>, i32, i32
    }
    %13 = triton_gpu.async_wait {num = 0 : i32}
    triton_gpu.local_dealloc %10 : !tt.memdesc<2x128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    triton_gpu.local_dealloc %11 : !tt.memdesc<2x32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    tt.return
  }
}
