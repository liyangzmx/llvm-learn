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
    // 原书加粗部分：流水线前言中的复制与谓词保护。
    %c0 = arith.constant 0 : index
    %12 = arith.muli %arg2, %c0 : index
    %13 = arith.addi %arg0, %12 : index
    %14 = arith.cmpi slt, %13, %arg1 : index
    %c0_8 = arith.constant 0 : index
    %15 = arith.muli %arg2, %c0_8 : index
    %16 = arith.addi %arg0, %15 : index
    %17 = arith.addi %c-1_i32, %c1_i32 : i32
    %18 = arith.cmpi slt, %17, %c2_i32 : i32
    %19 = arith.select %18, %17, %c0_i32 : i32
    %20 = triton_gpu.memdesc_subview %10[%19, %c0_i32_6, %c0_i32_6] : !tt.memdesc<2x128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %21 = tt.splat %14 : i1 -> tensor<128x32xi1, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %22 = triton_gpu.async_copy_global_to_local %4, %20 mask %21 : tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>> -> <128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %23 = triton_gpu.async_commit_group %22
    %24 = triton_gpu.memdesc_subview %11[%19, %c0_i32_7, %c0_i32_7] : !tt.memdesc<2x32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %25 = tt.splat %14 : i1 -> tensor<32x128xi1, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %26 = arith.andi %25, %cst_1 : tensor<32x128xi1, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %27 = triton_gpu.async_copy_global_to_local %9, %24 mask %26 other %cst_2 : tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>> -> <32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %28 = triton_gpu.async_commit_group %27
    %c1 = arith.constant 1 : index
    %29 = arith.muli %arg2, %c1 : index
    %30 = arith.addi %arg0, %29 : index
    %31 = arith.cmpi slt, %30, %arg1 : index
    %c1_9 = arith.constant 1 : index
    %32 = arith.muli %arg2, %c1_9 : index
    %33 = arith.addi %arg0, %32 : index
    %34 = tt.addptr %4, %cst_4 : tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<128x32xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %35 = tt.addptr %9, %cst_5 : tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<32x128xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %36 = arith.addi %19, %c1_i32 : i32
    %37 = arith.cmpi slt, %36, %c2_i32 : i32
    %38 = arith.select %37, %36, %c0_i32 : i32
    %39 = triton_gpu.memdesc_subview %10[%38, %c0_i32_6, %c0_i32_6] : !tt.memdesc<2x128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %40 = tt.splat %31 : i1 -> tensor<128x32xi1, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %41 = triton_gpu.async_copy_global_to_local %34, %39 mask %40 : tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>> -> <128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %42 = triton_gpu.async_commit_group %41
    %43 = triton_gpu.memdesc_subview %11[%38, %c0_i32_7, %c0_i32_7] : !tt.memdesc<2x32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %44 = tt.splat %31 : i1 -> tensor<32x128xi1, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %45 = arith.andi %44, %cst_1 : tensor<32x128xi1, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
    %46 = triton_gpu.async_copy_global_to_local %35, %43 mask %45 other %cst_2 : tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>> -> <32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %47 = triton_gpu.async_commit_group %46
    %48 = arith.addi %c-1_i32, %c1_i32 : i32
    %49 = arith.cmpi slt, %48, %c2_i32 : i32
    %50 = arith.select %49, %48, %c0_i32 : i32
    %51 = triton_gpu.async_wait %23 {num = 0 : i32}
    %52 = triton_gpu.memdesc_subview %10[%50, %c0_i32_6, %c0_i32_6] : !tt.memdesc<2x128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    %53 = triton_gpu.async_wait %28 {num = 0 : i32}
    %54 = triton_gpu.memdesc_subview %11[%50, %c0_i32_7, %c0_i32_7] : !tt.memdesc<2x32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    // 原循环尚未完成重写；此处是编译器内部的中间快照。
    %55:5 = scf.for %arg5 = %arg0 to %arg1 step %arg2 iter_args(
        %arg6 = %4, %arg7 = %9, %arg8 = %cst_3, %arg9 = %c-1_i32,
        %arg10 = %c-1_i32) -> (tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<128x128xf32, #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>>, i32, i32) {
      %57 = arith.addi %arg9, %c1_i32 : i32
      %58 = arith.cmpi slt, %57, %c2_i32 : i32
      %59 = arith.select %58, %57, %c0_i32 : i32
      %60 = arith.addi %arg10, %c1_i32 : i32
      %61 = arith.cmpi slt, %60, %c2_i32 : i32
      %62 = arith.select %61, %60, %c0_i32 : i32
      %63 = triton_gpu.memdesc_subview %10[%59, %c0_i32_6, %c0_i32_6] : !tt.memdesc<2x128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %64 = triton_gpu.async_copy_global_to_local %arg6, %63 : tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>> -> <128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %65 = triton_gpu.async_commit_group %64
      %66 = triton_gpu.async_wait %65 {num = 0 : i32}
      %67 = triton_gpu.memdesc_subview %10[%62, %c0_i32_6, %c0_i32_6] : !tt.memdesc<2x128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %68 = triton_gpu.local_load %67 token %66 : !tt.memdesc<128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> tensor<128x32xf16, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
      %69 = triton_gpu.convert_layout %68 : tensor<128x32xf16, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>> -> tensor<128x32xf16, #triton_gpu.dot_op<{opIdx = 0, parent = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>, kWidth = 2}>>
      %70 = triton_gpu.memdesc_subview %11[%59, %c0_i32_7, %c0_i32_7] : !tt.memdesc<2x32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %71 = triton_gpu.async_copy_global_to_local %arg7, %70 mask %cst_1 other %cst_2 : tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>> -> <32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %72 = triton_gpu.async_commit_group %71
      %73 = triton_gpu.async_wait %72 {num = 0 : i32}
      %74 = triton_gpu.memdesc_subview %11[%62, %c0_i32_7, %c0_i32_7] : !tt.memdesc<2x32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> !tt.memdesc<32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
      %75 = triton_gpu.local_load %74 token %73 : !tt.memdesc<32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable> -> tensor<32x128xf16, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
      %76 = triton_gpu.convert_layout %75 : tensor<32x128xf16, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>> -> tensor<32x128xf16, #triton_gpu.dot_op<{opIdx = 1, parent = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>, kWidth = 2}>>
      %77 = tt.dot %69, %76, %arg8 : tensor<128x32xf16, #triton_gpu.dot_op<{opIdx = 0, parent = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>, kWidth = 2}>> * tensor<32x128xf16, #triton_gpu.dot_op<{opIdx = 1, parent = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>, kWidth = 2}>> -> tensor<128x128xf32, #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>>
      %78 = tt.addptr %arg6, %cst_4 : tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<128x32xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>
      %79 = tt.addptr %arg7, %cst_5 : tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<32x128xi32, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>
      scf.yield %78, %79, %77, %59, %62 : tensor<128x32x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<32x128x!tt.ptr<f16>, #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>>, tensor<128x128xf32, #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>>, i32, i32
    }
    %56 = triton_gpu.async_wait {num = 0 : i32}
    triton_gpu.local_dealloc %10 : !tt.memdesc<2x128x32xf16, #triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    triton_gpu.local_dealloc %11 : !tt.memdesc<2x32x128xf16, #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>, #triton_gpu.shared_memory, mutable>
    tt.return
  }
}
