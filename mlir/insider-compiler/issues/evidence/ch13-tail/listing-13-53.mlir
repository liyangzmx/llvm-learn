#blocked = #triton_gpu.blocked<{sizePerThread = [1, 1], threadsPerWarp = [2, 16], warpsPerCTA = [4, 1], order = [1, 0]}>
#mma = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>
#dot = #triton_gpu.dot_op<{opIdx = 0, parent = #mma, kWidth = 2}>
#shared = #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = true}>
#shared1 = #triton_gpu.shared<{vec = 8, perPhase = 4, maxPhase = 2, order = [1, 0], hasLeadingOffset = false}>
module attributes {"triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.target" = "cuda:80", "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @kernel_() -> tensor<16x16xf32, #dot> {
    %cst = arith.constant dense<0.0> : tensor<16x16xf32, #blocked>
    %0 = triton_gpu.local_alloc %cst : (tensor<16x16xf32, #blocked>) -> !tt.memdesc<16x16xf32, #shared, #triton_gpu.shared_memory>
    %1 = triton_gpu.local_load %0 : !tt.memdesc<16x16xf32, #shared, #triton_gpu.shared_memory> -> tensor<16x16xf32, #blocked>
    %2 = triton_gpu.local_alloc %1 : (tensor<16x16xf32, #blocked>) -> !tt.memdesc<16x16xf32, #shared1, #triton_gpu.shared_memory>
    %3 = triton_gpu.local_load %2 : !tt.memdesc<16x16xf32, #shared1, #triton_gpu.shared_memory> -> tensor<16x16xf32, #dot>
    tt.return %3 : tensor<16x16xf32, #dot>
  }
}
