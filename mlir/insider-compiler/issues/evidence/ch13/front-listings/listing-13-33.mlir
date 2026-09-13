#blocked = #triton_gpu.blocked<{sizePerThread = [4, 4], threadsPerWarp = [1, 32],
    warpsPerCTA = [32, 1], order = [1, 0]}>
#mma = #triton_gpu.nvidia_mma<{versionMajor = 3, versionMinor = 0,
    warpsPerCTA = [8, 4], instrShape = [16, 32, 16]}>
#shared = #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8,
    order = [1, 0], hasLeadingOffset = true}>
module attributes {"triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 32 : i32,
    triton_gpu.target = "cuda:90", "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func @check_instrShape_per_warps(%arg0: !tt.ptr<f32> {tt.divisibility = 16 : i32}) {
    %cst = arith.constant dense<0.000000e+00>
        : tensor<128x128xf16, #triton_gpu.dot_op<{opIdx = 1, parent = #blocked}>>
    %cst_0 = arith.constant dense<true> : tensor<128x128xi1, #blocked>
    %cst_1 = arith.constant dense<0.000000e+00> : tensor<128x128xf32, #blocked>
    %cst_2 = arith.constant dense<0.000000e+00>
        : tensor<128x128xf16, #triton_gpu.dot_op<{opIdx = 0, parent = #blocked}>>
    %0 = triton_gpu.local_alloc %cst_2
        : (tensor<128x128xf16, #triton_gpu.dot_op<{opIdx = 0, parent = #blocked}>>)
        -> !tt.memdesc<128x128xf16, #shared, #triton_gpu.shared_memory>
    %1 = triton_gpu.local_alloc %cst
        : (tensor<128x128xf16, #triton_gpu.dot_op<{opIdx = 1, parent = #blocked}>>)
        -> !tt.memdesc<128x128xf16, #shared, #triton_gpu.shared_memory>
    %2 = triton_gpu.convert_layout %cst_1 : tensor<128x128xf32, #blocked>
        -> tensor<128x128xf32, #mma>
    %3 = triton_nvidia_gpu.warp_group_dot %0, %1, %2
        : !tt.memdesc<128x128xf16, #shared, #triton_gpu.shared_memory>
        * !tt.memdesc<128x128xf16, #shared, #triton_gpu.shared_memory>
        -> tensor<128x128xf32, #mma>
    %4 = triton_gpu.convert_layout %3 : tensor<128x128xf32, #mma> -> tensor<128x128xf32, #blocked>
    %5 = tt.splat %arg0 : !tt.ptr<f32> -> tensor<128x128x!tt.ptr<f32>, #blocked>

    tt.store %5, %4, %cst_0 : tensor<128x128x!tt.ptr<f32>, #blocked>
    tt.return
  }
}
