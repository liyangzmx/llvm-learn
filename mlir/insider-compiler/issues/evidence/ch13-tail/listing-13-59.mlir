#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>
#mma = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = [16, 8]}>
module attributes {"triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, triton_gpu.shared = 128 : i32, "triton_gpu.target" = "cuda:80", "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @dont_divide_0() attributes {noinline = false} {
    %cst = arith.constant dense<0.0> : tensor<16x1xf32, #mma>
    %0 = triton_gpu.convert_layout %cst {allocation.offset = 0 : i32} : tensor<16x1xf32, #mma> -> tensor<16x1xf32, #blocked>
    tt.return
  }
}
