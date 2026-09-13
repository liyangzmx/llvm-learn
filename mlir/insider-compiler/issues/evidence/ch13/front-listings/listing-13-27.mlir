#blocked = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [8, 4],
    warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 2],
    CTASplitNum = [1, 2], CTAOrder = [1, 0]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [2, 16],
    warpsPerCTA = [1, 4], order = [1, 0], CTAsPerCGA = [2, 1],
    CTASplitNum = [1, 1], CTAOrder = [1, 0]}>
#shared = #triton_gpu.shared<{vec = 1, perPhase = 1, maxPhase = 1, order = [1, 0],
    CTAsPerCGA = [2, 1], CTASplitNum = [1, 1], CTAOrder = [1, 0], hasLeadingOffset = false}>
module attributes {"triton_gpu.num-ctas" = 2 : i32, "triton_gpu.num-warps" = 4 : i32} {
  tt.func @matmul_fmadot(%arg0: !tt.ptr<f32> {tt.divisibility = 16 : i32},
      %arg1: !tt.memdesc<32x32xf32, #shared, #triton_gpu.shared_memory>,
      %arg2: !tt.memdesc<32x32xf32, #shared, #triton_gpu.shared_memory>) {
    %cst = arith.constant dense<0.000000e+00> : tensor<32x32xf32, #blocked>
    %0 = triton_gpu.local_load %arg1
        : !tt.memdesc<32x32xf32, #shared, #triton_gpu.shared_memory>
        -> tensor<32x32xf32, #triton_gpu.dot_op<{opIdx = 0, parent = #blocked1}>>
    %1 = triton_gpu.local_load %arg2
        : !tt.memdesc<32x32xf32, #shared, #triton_gpu.shared_memory>
        -> tensor<32x32xf32, #triton_gpu.dot_op<{opIdx = 1, parent = #blocked1}>>
    %2 = triton_gpu.convert_layout %0
        : tensor<32x32xf32, #triton_gpu.dot_op<{opIdx = 0, parent = #blocked1}>>
        -> tensor<32x32xf32, #triton_gpu.dot_op<{opIdx = 0, parent = #blocked}>>
    %3 = triton_gpu.convert_layout %1
        : tensor<32x32xf32, #triton_gpu.dot_op<{opIdx = 1, parent = #blocked1}>>
        -> tensor<32x32xf32, #triton_gpu.dot_op<{opIdx = 1, parent = #blocked}>>
    %4 = tt.dot %2, %3, %cst, inputPrecision = ieee
        : tensor<32x32xf32, #triton_gpu.dot_op<{opIdx = 0, parent = #blocked}>>

        * tensor<32x32xf32, #triton_gpu.dot_op<{opIdx = 1, parent = #blocked}>>
        -> tensor<32x32xf32, #blocked>
    %5 = tt.splat %arg0 : !tt.ptr<f32> -> tensor<32x1x!tt.ptr<f32>, #blocked>
    %6 = tt.broadcast %5 : tensor<32x1x!tt.ptr<f32>, #blocked>
        -> tensor<32x32x!tt.ptr<f32>, #blocked>
    tt.store %6, %4 : tensor<32x32x!tt.ptr<f32>, #blocked>
    tt.return
  }
}
