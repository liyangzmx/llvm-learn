#blocked = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [2, 16],
    warpsPerCTA = [1, 4], order = [1, 0], CTAsPerCGA = [2, 1],
    CTASplitNum = [1, 1], CTAOrder = [1, 0]}>
#shared = #triton_gpu.shared<{vec = 1, perPhase = 1, maxPhase = 1,
    order = [1, 0], CTAsPerCGA = [2, 1], CTASplitNum = [1, 1], CTAOrder = [1, 0]}>
#dot_operand_a = #triton_gpu.dot_op<{opIdx = 0, parent = #blocked}>
#dot_operand_b = #triton_gpu.dot_op<{opIdx = 1, parent = #blocked}>
module attributes {"triton_gpu.num-ctas" = 2 : i32, "triton_gpu.num-warps" = 4 : i32} {
  tt.func @matmul_fmadot(%ptr: !tt.ptr<f32> {tt.divisibility = 16 : i32},
      %a: !tt.memdesc<32x32xf32, #shared, #triton_gpu.shared_memory>,

      %b: !tt.memdesc<32x32xf32, #shared, #triton_gpu.shared_memory>) {
    %cst = arith.constant dense<0.000000e+00> : tensor<32x32xf32, #blocked>
    %a_mat = triton_gpu.local_load %a
        : !tt.memdesc<32x32xf32, #shared, #triton_gpu.shared_memory>
        -> tensor<32x32xf32, #dot_operand_a>
    %b_mat = triton_gpu.local_load %b
        : !tt.memdesc<32x32xf32, #shared, #triton_gpu.shared_memory>
        -> tensor<32x32xf32, #dot_operand_b>
    %28 = tt.dot %a_mat, %b_mat, %cst, inputPrecision = ieee
        : tensor<32x32xf32, #dot_operand_a> * tensor<32x32xf32, #dot_operand_b>
        -> tensor<32x32xf32, #blocked>
    %30 = tt.splat %ptr : !tt.ptr<f32> -> tensor<32x1x!tt.ptr<f32>, #blocked>
    %36 = tt.broadcast %30 : tensor<32x1x!tt.ptr<f32>, #blocked>
        -> tensor<32x32x!tt.ptr<f32>, #blocked>
    tt.store %36, %28 : tensor<32x32x!tt.ptr<f32>, #blocked>
    tt.return
  }
}
