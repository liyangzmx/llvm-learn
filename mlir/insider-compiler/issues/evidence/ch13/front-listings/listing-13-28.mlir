#layout0 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32],
    warpsPerCTA = [4], order = [0]}>
#layout1 = #triton_gpu.blocked<{sizePerThread = [4], threadsPerWarp = [32],
    warpsPerCTA = [4], order = [0]}>
module attributes {"triton_gpu.num-warps" = 4 : i32, "triton_gpu.num-ctas" = 1 : i32} {
  tt.func @cst() -> tensor<1024xi32, #layout1> {
    %cst = arith.constant dense<0> : tensor<1024xi32, #layout0>
    %1 = triton_gpu.convert_layout %cst : tensor<1024xi32, #layout0>
        -> tensor<1024xi32, #layout1>
    tt.return %1 : tensor<1024xi32, #layout1>
  }
}
