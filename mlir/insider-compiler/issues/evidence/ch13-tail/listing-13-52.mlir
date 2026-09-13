#C = #triton_gpu.nvidia_mma<{versionMajor = 2, warpsPerCTA = [4, 1]}>
#shared = #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = true}>
#dot_op = #triton_gpu.dot_op<{opIdx = 0, parent = #C, kWidth = 2}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1, 1], threadsPerWarp = [2, 16], warpsPerCTA = [4, 1], order = [1, 0]}>
module attributes {"triton_gpu.target" = "cuda:80", "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @kernel_() -> tensor<16x16xf32, #dot_op> {
    %cst_0 = arith.constant dense<0.0> : tensor<16x16xf32, #blocked1>
    %1 = triton_gpu.local_alloc %cst_0 : (tensor<16x16xf32, #blocked1>) -> !tt.memdesc<16x16xf32, #shared, #triton_gpu.shared_memory>
    %2 = triton_gpu.local_load %1 : !tt.memdesc<16x16xf32, #shared, #triton_gpu.shared_memory> -> tensor<16x16xf32, #dot_op>
    tt.return %2 : tensor<16x16xf32, #dot_op>
  }
}
