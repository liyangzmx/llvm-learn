#blocked = #triton_gpu.blocked<{sizePerThread = [4], threadsPerWarp = [32],
    warpsPerCTA = [4], order = [0]}>
module attributes {"triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32} {
  tt.func @cst() -> tensor<1024xi32, #blocked> {
    %cst = arith.constant dense<0> : tensor<1024xi32, #blocked>
    tt.return %cst : tensor<1024xi32, #blocked>
  }
}
